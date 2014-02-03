var Uploader = require( './lib/uploader' );
var async = require( 'async' );
var util = require( 'util' );
var config = require( './package.json' );

var filename = '/home/peebles/video-test/test2.mp4';
// var uuid = '682DC812-05C3-11E3-839F-54DE3DA5649D';
var uuid = '86FD9216-A8B9-11E2-9637-3B9C97344F04';

var q = async.queue( function( o, cb ) {
    o.upload( cb );
}, 4 );

var handler = function( f, err, results ) {
    if ( err ) {
	console.log( 'error: ' + err.message );
	f.retries += 1;
	if ( f.retries > config.max_retries ) {
	    console.log( 'max retries exceeded for ' + ( f.fileid || f.filename ) );
	}
	else {
	    setTimeout( function() {
		q.push( f, function( err, results ) {
		    handler( f, err, results );
		});
	    }, 1000 * f.retries );
	}
    }
    else {
	console.log( f.fileid + ' is finished.' );
    }
}

var f = new Uploader( filename, uuid );
q.push( f, function( err, results ) {
    handler( f, err, results );
});

f.on( 'progress', function() {
    console.log( f.offset, f.length );
});

q.drain = function() {
    console.log( 'DONE' );
}
