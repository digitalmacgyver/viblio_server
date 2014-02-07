var platform = require( './lib/platform' );
var Scanner = require( './lib/scan' );
var async = require( 'async' );

var con = 1;
var skips = platform.dirskips();
var dirs = [];
process.argv.shift();
process.argv.shift();
var arg;
while( arg = process.argv.shift() ) {
    if ( arg == '-c' )
	con = parseInt( process.argv.shift() );
    else if ( arg == '-d' ) 
	dirs.push( process.argv.shift() );
    else if ( arg == '-skip' )
	skips = process.argv.shift();
}

if ( dirs.length == 0 )
    dirs = platform.defaultWatchDirs();
console.log( 'Going to scan:' );
dirs.forEach( function( dir ) {
    console.log( dir );
});
console.log( '... Start ...' );
var scanner = new Scanner( null, skips );
scanner.on( 'dir', function( dir ) {
    console.log( dir );
});
var e1 = new Date().getTime();
async.map( dirs, 
	   function( dir, cb ) {
	       scanner.scanForDirs( dir ).then(
		   function() { cb( null, null ); } );
	   },
	   function( err, results ) {
	       console.log( '... DONE ...' );
	       var e2 = new Date().getTime();
	       console.log( 'Took ' + 
			    ( ( e2 - e1 )/1000 ) + ' seconds' );
	   }
	 );

