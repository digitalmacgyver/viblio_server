var platform = require( './lib/platform' );
var Scanner = require( './lib/scan' );
var async = require( 'async' );
var path = require( 'path' );

var con = 1;
var skips = platform.dirskips();
var dirs = [];
var showdirs = false;
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
    else if ( arg == '-showdirs' )
	showdirs = true;
}

if ( dirs.length == 0 )
    dirs = platform.defaultWatchDirs();
console.log( 'Going to scan:' );
dirs.forEach( function( dir ) {
    console.log( dir );
});
console.log( '... Start ...' );
var scanner = new Scanner( null, skips );
scanner.on( 'file', function( s ) {
    console.log( s.file );
});
if ( showdirs ) {
    scanner.on( 'log', function( msg ) {
	console.log( '+' + msg );
    });
}
var e1 = new Date().getTime();
async.map( dirs, 
	   function( dir, cb ) {
	       scanner.scanForFiles( dir ).then(
		   function( files ) { 
		       cb( null, { dir: dir, files: files } ); 
		   } 
	       );
	   },
	   function( err, results ) {
	       console.log( '... DONE ...' );
	       var e2 = new Date().getTime();
	       results.forEach( function( s ) {
		   console.log( '==> ' + ( path.basename( s.dir ) || '(root)' ) + ': ' + s.files.length );
	       });
	       console.log( 'Took ' + 
			    ( ( e2 - e1 )/1000 ) + ' seconds' );
	   }
	 );

