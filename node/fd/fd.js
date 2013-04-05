var express = require( "express" );
var fs = require('fs');
var url = require('url');
var http = require('http');
var mkdirp = require('mkdirp');
var path = require( 'path' );

// Configuration
var Config = require( "konphyg" )( __dirname );
var config = Config( "fd" );

var Memcached = require( "memcached" );
var memcached = new Memcached( config.memcached );
var ONE_DAY = 86400; 
var PERSIST_FOR = ONE_DAY; // objects persist for a day

// This holds a dynamic dist associating in-flight
// requests with download ids.  Used to abort in-flight
// requests.
var requests = {};

var app = express();

app.configure('development', function( ){
    app.use(express.logger('dev'));
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function( ){
    app.use(express.logger('default'));
    app.use(express.errorHandler());
});

app.configure( function() {
    app.set( 'jsonp callback name', 'callback' );
    app.set( 'port', process.env.PORT || 3001 );
    app.use(express.bodyParser());
    app.use( app.router );
    app.use( function( req, res, next ) {
	if ( req.param( app.get( 'jsonp callback name' ) ) ) {
	    res.jsonp( res.stash );
	}
	else {
	    res.json( res.stash );
	}
    });
});

app.get( '/progress', function( req, res, next ) {
    var id = req.param( 'id' );
    memcached.get( id, function( err, fpfile ) {
	if ( err ) {
	    res.stash = { error: true,
			 message: "Failed to obtain (err).",
			 detail: err };
	    next();
	}
	else {
	    if ( fpfile === false ) {
		res.stash = { error: true,
			      message: "Failed to obtain (false)." };
		next();
	    }
	    else {
		if ( fpfile.done ) {
		    memcached.del( fpfile.id, function() {} );
		}
		res.stash = fpfile;
		next();
	    }
	}
    });
});

app.get( '/abort', function( req, res, next ) {
    var id = req.param( 'id' );
    if ( requests[id] ) {
	requests[id].abort();
	res.stash = { error: false };
	delete requests[id];
	next();
    }
    else {
	res.stash = { error: true,
		      message: "Unable to abort download.",
		      detail: "ID '" + id + "' not found on this server." };
	next();
    }
});

app.get( '/remove', function( req, res, next ) {
    if ( ! req.param( 'filename' ) ) {
	res.stash = { error: true,
		      message: "Missing required 'filename' parameter" };
	return next();
    }
    var fullpath = path.join( config.storage.filedir, req.param( 'filename' ) );
    fs.unlink( fullpath, function(err) {
	if ( err ) 
	    res.stash = { error: true,
			  message: "Unable to remove file.",
			  detail: e.message };
	else
	    res.stash = { error: false };
	next();
    });
});

app.get( '/download', function( req, res, next ) {

    // Check for the required parameters (id and url)
    //
    if ( ! req.param( 'url' ) ) {
	res.stash = { error: true,
		      message: "Missing required 'url' parameter" };
	return next();
    }

    if ( ! req.param( 'id' ) ) {
	res.stash = { error: true,
		      message: "Missing required 'id' parameter" };
	return next();
    }

    if ( ! req.param( 'filename' ) ) {
	res.stash = { error: true,
		      message: "Missing required 'filename' parameter" };
	return next();
    }

    var fpurl = req.param( 'url' );
    var fpfile = 
	{ id: req.param( 'id' ),
	  expected: 0,
	  received: 0,
	  done: false,
	  errored: false,
	  aborted: false };

    // make sure we can store this file somewhere
    var fullpath = path.join( config.storage.filedir, req.param( 'filename' ) );
    var dirname  = path.dirname( fullpath );

    if ( ! fs.existsSync( dirname ) ) {
	mkdirp.sync( dirname );
    }

    // Store the progress record
    //
    memcached.set( fpfile.id, fpfile, PERSIST_FOR, function( err, success ) {
	if ( err || ! success ) {
	    res.stash = { error: true,
			  message: "Failed to persist.",
			  detail: err };
	    next();
	}
	else {
	    // Create a file to stream into
	    var fp = fs.createWriteStream( fullpath );

	    // Initiate the download
	    var rq = http.get(
		{ host: url.parse(fpurl).host,
		  port: 80,
		  path: url.parse(fpurl).pathname},
		function( get_response ) {
		    // Grab the content length from the headers.  If there is
		    // no content length, set expected to -1 so we can treat as
		    // a special case in progress endpoint.
		    var expected = parseInt( get_response.headers['content-length'] || "-1" );
		    // persist the expected length
		    fpfile.expected = expected;
		    memcached.set( fpfile.id, fpfile, PERSIST_FOR, function() {} );
		    // set up the data transfer events
		    get_response.on( 'data', function( data ) {
			// got some data, persist the amount received so far
			fp.write( data );
			fpfile.received += data.length;
			memcached.set( fpfile.id, fpfile, PERSIST_FOR, function() {} );
		    });
		    get_response.on( 'end', function() {
			fp.end();
			// mark it done, in case expected is -1
			fpfile.done = true;
			memcached.set( fpfile.id, fpfile, PERSIST_FOR, function() {} );
			// and return to caller what we have so far
			res.stash = fpfile;
			delete requests[fpfile.id];
			next();
		    });
		    get_response.on( 'error', function(e) {
			fpfile.done = true;
			fpfile.errored = true;
			memcached.set( fpfile.id, fpfile, PERSIST_FOR, function() {} );
			fpfile.error = true;
			fpfile.message = "Download was errored.";
			fpfile.detail = e.message;
			res.stash = fpfile;
			delete requests[fpfile.id];
			fs.unlinkSync( fullpath );
		    });
		    get_response.on( 'close', function() {
			fpfile.done = true;
			fpfile.aborted = true;
			memcached.set( fpfile.id, fpfile, PERSIST_FOR, function() {} );
			fpfile.error = true;
			fpfile.message = "Download was aborted.";
			res.stash = fpfile;
			delete requests[fpfile.id];
			fs.unlinkSync( fullpath );
		    });
		});
	    // Save an in-memory reference to the request so
	    // the client can abort it.  Of course, this only works
	    // if the client that initiated the download connects
	    // to this server to abort.
	    requests[fpfile.id] = rq;
	}
    });
});

app.post( '/workorder', function( req, res, next ) {
    var wo = req.body;

    // DETACH NOW!!!  The caller gets control back
    // so the rest if this routine happens async
    // with respect to caller.
    res.end();

    var TOTAL = wo.media.length;

    wo.media.forEach( function( fpfile, ii ) {

	wo.media[ii].expected = 0;
	wo.media[ii].received = 0;
	wo.media[ii].done = false;
	wo.media[ii].errored = false;
	wo.media[ii].aborted = false;

	var filename = wo.media[ii].uuid + '_' + wo.media[ii].filename;

	// make sure we can store this file somewhere
	var fullpath = path.join( config.storage.filedir, filename );
	var dirname  = path.dirname( fullpath );

	if ( ! fs.existsSync( dirname ) ) {
            mkdirp.sync( dirname );
	}

	// Create a file to stream into
	var fp = fs.createWriteStream( fullpath );

	wo.media[ii].localpath = fullpath;

	var rq = http.get(
            { host: url.parse(wo.media[ii].url).host,
              port: 80,
              path: url.parse(wo.media[ii].url).pathname},
            function( get_response ) {
		var expected = parseInt( get_response.headers['content-length'] || "-1" );
		wo.media[ii].expected = expected;

		get_response.on( 'data', function( data ) {
                    fp.write( data );
                    wo.media[ii].received += data.length;
		});
		get_response.on( 'end', function() {
                    fp.end();
                    wo.media[ii].done = true;
                    delete requests[wo.media[ii].id];
		    if ( --TOTAL == 0 ) {
			// Initiate the work.  The work is done by a C program,
			// and I am not sure yet exactly how we talk to it.  Might
			// be a socket connection, so that me and my C program
			// are a linked pair?, and I send the wo through this 
			// socket to start work?  The C program would need to fork
			// in case I get another download request.
			//
			// Or I could spawn a child process and pass the wo
			// to it through stdin.  If I do this, I may or may
			// not want to unsubscribe to new workorder requests,
			// although I don't have to unsubscribe, since nodejs will
			// keep handling incoming requests ... but I could end up
			// spawning a lot of jobs!
			//

			// Now, we are going to span a child process.  We'll 
			// use the wo uuid to create a temp file to write the
			// wo into, and pass that as an argument to the worker
			// process.  We'll do our best to divorce ourselves from
			// the worker (process wise).
			var tmpfile = "/tmp/" + wo.wo.uuid + ".wo";
			fs.writeFile( tmpfile, JSON.stringify( wo ), function( err ) {
			    if ( err ) {
				// Boy, what now?
			    }
			    else {
				config.worker.args[1] = tmpfile;
				config.worker.options.env = process.env;
				var spawn = require( 'child_process' ).spawn,
				worker = spawn( config.worker.command,
						config.worker.args,
						config.worker.options );
				worker.on( 'close', function(code) {
				    // console.log( "Worker done, exitted with code: " + code );
				});
				// By default, the parent will wait for the detached child to exit. 
				// To prevent the parent from waiting for a given child, use the child.unref() 
				// method, and the parent's event loop will not include the child in its reference count.
				worker.unref();
			    }
			});
		    }
		});
		get_response.on( 'error', function(e) {
                    wo.media[ii].done = true;
                    wo.media[ii].errored = true;
                    wo.media[ii].error = true;
                    wo.media[ii].message = "Download was errored.";
                    wo.media[ii].detail = e.message;
                    delete requests[wo.media[ii].id];
                    fs.unlinkSync( fullpath );
		});
	    });
	requests[wo.media[ii].id] = rq;
    });
});

http.createServer(app).listen(app.get('port'), function(){
    console.log("File Picker Downloader listening on port " + app.get('port'));
});
