var express = require( 'express' );
var http = require( 'http' );
var formidable = require( 'formidable' );
var fs = require( 'fs' );
var request = require( 'request' );
var util = require( 'util' );
var async = require( 'async' );

var config = require( './package.json' );

// Logging
var expressWinston = require('express-winston');
var winston = require( "winston" );

var app = express();

var log = new (winston.Logger)({
    transports: [
        new (winston.transports.Console)({ level: ((config.trace && 'debug')||'info') }),
        new (winston.transports.File)({ filename: '/tmp/yv.log' })
    ]
});

function logdump( o ) {
    log.debug( JSON.stringify( o, null, 2 ) );
}

app.configure(function() {
    app.set('port', config.port || process.env.PORT || 3000);
    app.use( express.logger( 'dev' ) );

    app.engine('html', require('ejs').renderFile);
    app.set('view engine', 'html');

    app.use(expressWinston.logger({
        transports: [
            new winston.transports.Console({
                json: false,
                colorize: true
            }),
            new winston.transports.File({ 
                filename: '/tmp/yv.log', 
                json: false 
            })
        ]
    }));

    app.use(app.router);
    app.use(expressWinston.errorLogger({
        transports: [
            new winston.transports.Console({
                json: false,
                colorize: true
            }),
            new winston.transports.File({ 
                filename: '/tmp/yv.log', 
                json: false 
            })
        ]
    }));
});

app.configure('development', function( ){
    app.use(express.logger('dev'));
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function( ){
    app.use(express.logger('default'));
    app.use(express.errorHandler());
});

var headers = {};

function auth( req, res, next ) {
    var r = request.post( 'https://aas.yesvideo.com/oauth/token',
			  { auth: { user: config.client_id, pass: config.secret },
			    json: true,
			    form: { grant_type: 'client_credentials' } },
			  function( err, response, body ) {
			      if ( err ) {
				  res.json( { error: true, details: err } );
			      }
			      else {
				  if ( response.statusCode == 200 ) {
				      headers['Authorization'] = 'Bearer ' + body.access_token;
				  }
				  else {
				      // Errors look like:
				      // {
				      //   "error": "invalid_client",
				      //   "error_description": "Client authentication failed"
				      // }
				      res.json( body );
				  }
			      }
			      next();
			  } );
}

function api( method, endpoint, data, callback ) {
    var options = {
	headers: headers,
	method: method,
	uri: 'https://aas.yesvideo.com' + endpoint,
	json: true
    };
    if ( method == 'POST' ) {
	options['form'] = data;
    }
    else {
	options['qs'] = data;
    }
    request( options, function( err, response, body ) {
	if ( err ) {
	    callback( err, { error: true, details: err } );
	}
	else {
	    callback( err, body );
	}
    });
}

// Can use '/' as a health check.  Does not atempt to authenticate with yes video.
app.get( '/', function( req, res, next ) {
    res.json({ healthy: true });
});

// Can use '/collections' as a health check, with yes video authentication.
app.get( '/collections', auth, function( req, res, next ) {
    api( 'GET', '/api/v1/collections', {}, function( err, data ) {
	res.json( data );
    });
});

// Can call any api with this endpoint:
//
// /any?method=POST&endpoint=/api/v1/collections&type=dvd_4_7G
//
// Will return the api data.
//
app.get( '/any', auth, function( req, res, next ) {
    var method = req.query.method;
    var endpoint = req.query.endpoint;
    delete req.query['method'];
    delete req.query['endpoint'];
    logdump( req.query );
    api( method, endpoint, req.query, function( err, data ) {
	res.json( data );
    });
});

// THE MAIN ENTRY POINT
//
// Given a structure that contains a collection ID and a list
// of S3 URLS for the videos to upload, build the collection.
//
// This takes a log time (if we have to download, then upload
// the files).  So we return right away.
//
// Using curl to pass array:
//
// curl 'http://localhost:3000/build?arr=1&arr=2&arr=3'
//
app.get( '/build', auth, function( req, res, next ) {
    var collection_id = req.query.collection_id;
    var s3_uris = req.query.s3_uri;

    // Return right away
    res.json( req.query );

    // Use async to run our uploads in parallel
    async.map( s3_uris, function( s3_uri, callback ) {
	var seconds = Math.floor((Math.random()*10)+1) * 1000;
	log.debug( s3_uri + ' ' + seconds );
	setTimeout( function() {
	    log.debug( s3_uri + ' done' );
	    callback( null, s3_uri );
	}, seconds);
    }, function( err, results ) {
	log.debug( 'UPLOAD COMPLETE' );
    });
});

http.createServer(app).listen(app.get('port'), function() {
  log.info("yes-video server listening on port " + app.get('port'));
});
