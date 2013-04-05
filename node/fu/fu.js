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

var s3 = new amazonS3.S3({
    'accessKeyId'     : 'AKIAJHD46VMHB2FBEMMA',
    'secretAccessKey' : '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',
    'region'          : amazonS3.US_EAST_1
});

var args_startat = 2;

var no_uuids = false;
if ( process.argv[args_startat] == '--no-uuids' ) {
    no_uuids = true;
    args_startat += 1;
}

process.argv.forEach( function( filename, index ) {
    if ( index < args_startat ) return;  // args start at 2

    var s3key;
    if ( no_uuids ) {
	s3key = path.basename( filename );
    }
    else {
	s3key = ugen() + '_' + path.basename( filename );
    }

    fs.stat( filename, function( err, file_info ) {
	var bodyStream = fs.createReadStream( filename );

	var options = {
            BucketName    : 'viblio.filepicker.io',
            ObjectName    : s3key,
            ContentLength : file_info.size,
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
	    if ( err ) error = "true";
	    else error = "false";
	    console.log(JSON.stringify({
		filename: filename,
		s3key: s3key,
		error: error}));
	});
    });
    
});

