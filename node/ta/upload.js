var queuer = require( './lib/queuer' );

var files = [];
for( var i=2; i<process.argv.length; i++ )
    files.push( process.argv[i] );
var num = 0;
var e1, e2;

var log = {
    debug: function() {
	console.log.apply( null, arguments );
    }
};

queuer.setLogger( log );

queuer.on( 'file:done', function( f ) {
    e2 = new Date().getTime();
    log.debug( 'DONE!' );
    log.debug( JSON.stringify( JSON.parse(f.toJSON()), null, 2 ) );
    if ( ++num == files.length ) {
	var seconds = ( e2 - e1 ) / 1000;
	queuer.stats().then( function( s ) {
	    var bytes = s.bytes;
	    var bps = ( bytes * 8 ) / seconds;
	    if ( bps > (1024*1024) )
		console.log( (bps/(1024*1024)) + ' Mbp/s' );
	    else if ( bps > 1024 )
		console.log( (bps/1024) + ' Kbp/s' );
	    else
		console.log( bps + ' bp/s' );
	});
    }
});

queuer.on( 'file:progress', function( f ) {
    log.debug( f.offset, f.length );
});

queuer.on( 'file:retry', function( f ) {
    log.debug( 'Retry: ' + f.retries );
});

e1 = new Date().getTime();
files.forEach( function( filename ) {
    queuer.add( filename );
});

