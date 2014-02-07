var queuer = require( './lib/queuer' );

var log = {
    debug: function() {
	console.log.apply( null, arguments );
    }
};

queuer.setLogger( log );

queuer.on( 'file:done', function( f ) {
    log.debug( 'DONE!' );
    log.debug( JSON.stringify( JSON.parse(f.toJSON()), null, 2 ) );
});

queuer.on( 'file:progress', function( f ) {
    log.debug( f.offset, f.length );
});

queuer.on( 'file:retry', function( f ) {
    log.debug( 'Retry: ' + f.retries );
});

queuer.restore();
