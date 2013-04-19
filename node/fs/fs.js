var express = require( 'express' );
var http    = require( 'http' );
var mkdirp  = require( 'mkdirp' );
var uuid    = require( 'node-uuid' );
var fs      = require( 'fs' );
var path    = require( 'path' );

// thumnails
var qt = require( './allthumb' );

// config
var kphyg = require( "konphyg" )( __dirname );
var config = kphyg( 'fs' ); // fs.json

// logging
var winston = require( "winston" );
var log = require( "winston" );
log.add( winston.transports.File, 
	 { filename: config.logfile, 
	   json: false } );

var app = express();

app.configure('development', function( ){
    app.use(express.logger('dev'));
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function( ){
    app.use(express.logger('default'));
    app.use(express.errorHandler());
});

app.configure(function() {
    app.set('port', process.env.PORT || 3003);
    app.use(express.methodOverride());
    /*
    app.use( function( req, res, next ) {
	if (req.method.toUpperCase() === "OPTIONS"){
            // Echo back the Origin (calling domain) so that the
            // client is granted access to make subsequent requests
            // to the API.
            res.writeHead(
                "204",
                "No Content",
                {
                    "access-control-allow-origin": '*',
                    "access-control-allow-methods": "GET, POST, PUT, DELETE, OPTIONS",
                    "access-control-allow-headers": "content-type, accept",
                    "access-control-max-age": 10, // Seconds.
                    "content-length": 0
                }
            );
             // End the response - we're not sending back any content.
            return( res.end() );
	}
	else {
	    next();
	}
    });
    */
    app.use(express.bodyParser( config.body_parser_options ));
    app.use(app.router);
    app.use('/thumb', 
	    qt.static( path.dirname(config.body_parser_options.uploadDir),
		       { type: 'crop' } ));
});

// Enable CORS
app.all('/*', function(req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "X-Requested-With");
    res.header("Access-Control-Allow-Methods", "POST, GET, PUT, DELETE, OPTIONS" );
    next();
});

// The form field must be named 'upload' and can be a multi-file
// submission; ie. <input type="file" name="upload" multiple="multiple" />
//
// Files are not copied; it is expected that bodyParser's uploadDir
// points directly at local storage.  This eliminates the need to
// burn time in file copy, or to ensure that uploadDir and final
// storage is on same file system for moves.
//
// We don't provide progress reporting.  It is expected that
// mobile clients do their own upload progress, or that web apps
// use html5 xhr progress (see public/js/script.js).
//

app.post( '/upload', function( req, res, next ) {
    var dir   = config.body_parser_options.uploadDir;
    var file  = req.files.upload;
    var files = new Array();

    if ( file instanceof Array ) {
	files = file;
    }
    else {
	files[0] = file;
    }

    var ret = new Array();
    for( var i=0; i<files.length; i++ ) {
	// If the uploaded file is .mov (quicktime) then rename it to .mp4 and change the mime type.
	// This makes the web app do html5 video instead of quicktime plugin for iPhone video uploads.
	//
	if ( files[i].path.match( /\.mov$/ ) ) {
	    var rnamed = files[i].path.replace( '.mov', '.mp4' );
	    fs.renameSync( files[i].path, rnamed );
	    files[i].path = rnamed;
	    files[i].type = 'video/mp4';
	}
	log.info( "upload", files[i].path + ' ' + files[i].size);
	ret.push( { path: '/' + path.basename( config.body_parser_options.uploadDir ) + '/' + path.basename( files[i].path ),
		    name: files[i].name,
		    mimetype: files[i].type,
		    size: files[i].size } );
    }

    if ( ret.length == 1 ) {
	res.jsonp( ret[0] );
    }
    else {
	res.jsonp( { files: ret } );
    }
});

// Input is the 'path' returned from /upload
app.get( '/delete', function( req, res, next ) {
    var fullpath = path.join( path.dirname( config.body_parser_options.uploadDir ),
			      req.param( 'path' ) );
    fs.exists( fullpath, function( exists ) {
	if ( exists ) {
	    fs.unlink( fullpath, function( err ) {
		if ( err ) {
		    log.error( "Attempt to unlink failed: " + fullpath );
		    res.status( 500 );
		    res.end();
		}
		else {
		    log.info( 'delete', fullpath );
		    res.jsonp({success: true});
		}
	    });
	}
	else {
	    log.error( "Tried to delete non-existent file: " + fullpath );
	    res.status( 404 );
	    res.end();
	}
    });
});

mkdirp( config.body_parser_options.uploadDir, function( err ) {
    if ( err ) {
	log.error( "Could not create " + config.body_parser_options.uploadDir );
    }
    else {
	http.createServer(app).listen(app.get('port'), function(){
	    log.info("FS listening on port " + app.get('port'));
	});
    }
});
