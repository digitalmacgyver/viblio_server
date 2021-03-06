//
// Usage: node fu [--no-uuids] file [file file ...]
//
// Uploads a list of files from the local disk to S3 in parallel.
// If --no-uuids is *not* present, the s3key will be <uuid>_basename(file)
// otherwise just basename(file).  This script will spit out one line
// per uploaded file; a json string that contains filename, s3key and
// error ("true" if there was an error, "false" if the upload was
// successful).
//
var fs = require('fs');
var amazonS3 = require('awssum-amazon-s3');
var ugen = require( 'cuid' );
var path = require( 'path' );
var mime = require( 'mime' );

// Logging
var log = require( "winston" );
log.add( log.transports.File, { filename: '/tmp/fu.log', json: false } );
log.remove(log.transports.Console);

var s3 = new amazonS3.S3({
    'accessKeyId'     : 'AKIAJHD46VMHB2FBEMMA',
    'secretAccessKey' : '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',
    'region'          : amazonS3.US_WEST_1
});

var args_startat = 2;

var no_uuids = false;
if ( process.argv[args_startat] == '--no-uuids' ) {
    no_uuids = true;
    args_startat += 1;
}

process.argv.forEach( function( filespec, index ) {
    if ( index < args_startat ) return;  // args start at 2

    var ii = filespec.split( "^" );
    var spath = ii[0];
    var filename = ii[1];

    var s3key;
    if ( no_uuids ) {
	s3key = spath + '/' + path.basename( filename );
    }
    else {
	s3key = spath + '/' + ugen() + '_' + path.basename( filename );
    }

    log.info( filename );

    fs.stat( filename, function( err, file_info ) {

	if ( err ) {
	    log.info( filename, "not found" );
	    return;
	}

	var bodyStream = fs.createReadStream( filename );

	var options = {
            BucketName    : 'viblio-mediafiles',
            ObjectName    : s3key,
            ContentLength : file_info.size,
	    ContentType   : mime.lookup( filename ),
            Body          : bodyStream
	};

	// Useful for Debug...
	//
	//bodyStream.on( 'data', function( data ) {
	//    console.log( s3key + ": sent " + data.length );
	//});
	//
	//bodyStream.on( 'end', function() {
	//    console.log( s3key + ": COMPLETE" );
	//});
	
	s3.PutObject(options, function(err, data) {
	    var error;
	    if ( err ) {
		error = "true";
		log.info( filename, err );
	    }
	    else {
		error = "false";
		log.info( filename, "success: " + s3key );
	    }
	    console.log(JSON.stringify({
		filename: filename,
		s3key: s3key,
		error: error}));
	});
    });
    
});

