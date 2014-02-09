w = require( './lib/watcher' );
async = require( 'async' );

w.on( 'error', function( err ) {
    console.log( 'Error: ' + err.message );
});

w.on( 'log', function( msg ) {
    console.log( msg );
});

var uploads = {};
var id = 1;

w.on( 'change', function( filename, stat, prev ) {
    //console.log( filename, stat.size, ( prev ? prev.size : 0 ) );
    if ( uploads[filename] ) {
	console.log( 'cancelling', uploads[filename] );
	delete uploads[filename];
    }
    uploads[filename] = (id++) + '-' + filename;
    console.log( 'uploading', filename, stat.size );
    setTimeout( function() {
	delete uploads[filename];
    }, 1000 * 60 * 60 );
});

var dirs = [];
for( var i=2; i<process.argv.length; i++ )
    dirs.push( process.argv[i] );

async.mapSeries( dirs, 
		 function( dir, cb ) {
		     w.add( dir ).then( function() {
			 cb();
		     });
		 },
		 function(err) {
		 }
	       );
