var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var request = require( 'request' );
var config = require( '../lib/app-config' );
var privates = require( '../lib/storage' )( 'private' );
var open = require( 'open' );

// Calling viblio apis

(function() {

    var cookies = request.jar();
    var upgradeTmr;
    var authKeepAliveTmr;

    function api( service, data ) {
	var dfd = new Deferred();
	request({
	    url: config.viblio_server_endpoint + service,
	    method: 'POST',
	    jar: cookies,
	    form: data,
	    strictSSL: false
	}, function( err, res, body ) {
	    if ( err ) 
		dfd.reject({ error: 1, message: err.message });
	    else if ( res.statusCode != 200 ) 
		dfd.reject({ error: 1, message: 'HTTP response: ' + res.statusCode });
	    else {
		try {
		    var json = JSON.parse( body );
		    if ( json && json.error ) {
			dfd.reject( json );
		    }
		    else {
			dfd.resolve( json );

			// extract and save the session cookie for this user
			if ( res.headers['set-cookie'] )
			    privates.set( 'cookie',
					  res.headers['set-cookie'][0] );
		    }
		}
		catch( e ) {
		    dfd.reject({error: 1, message: e.message });
		}
	    }
	});
	return dfd.promise;
    }

    // This checks to see if we have an authenticated session with the 
    // viblio cat server.  If so, it resolves.  If not, it pops up the 
    // local browser to prompt the user.  When the user authenticates,
    // the uuid field in the privates storage area will change.
    function authenticate( dont_open ) {
	var dfd = new Deferred();

	privates.get( 'cookie' ).then(
	    function( cookie ) {
		if ( cookie )
		    cookies.setCookie( cookie, config.viblio_server_endpoint );
		api( '/services/user/me' ).then(
		    function() {
			dfd.resolve();
		    },
		    function( res ) {
			var tmr = null;
			privates.once( 'set:uuid', function( val ) {
			    if ( tmr ) clearTimeout( tmr );
			    dfd.resolve();
			});
			if ( ! dont_open ) {
			    var child;
			    child = open( 'http://localhost:' + config.port, function( err ) {
				if ( err ) {
				    dfd.reject( err );
				}
				else {
				    // The browser is open, but what if no one is around to
				    // interact with it?  Give it five minutes.  If the user
				    // has not logged in by then, kill the browser process
				    // and continue.
				    //
				    // Actually ... why not just leave it be?  
				    // tmr = setTimeout( function() {
				    //    dfd.resolve();
				    // }, 1000 * 60 * 5 );
				}
			    });
			}
		    }
		);
	    }
	);
	
	return dfd.promise;
    }

    function fireTimers() {
	// This keeps the session cookie going forever
	authKeepAliveTmr = setInterval( function() {
	    api( '/services/user/me' );
	}, 1000 * config.keepalive_period );

	// This checks for software upgrades
	//upgradeTmr = setInterval( function() {
	//}, 1000 * config.upgrade_period );
    }

    function cancelTimers() {
	if ( authKeepAliveTmr ) clearInterval( authKeepAliveTmr );
	if ( upgradeTmr ) clearInterval( upgradeTmr );
    }

    module.exports.api = api;
    module.exports.authenticate = authenticate;
    module.exports.fireTimers = fireTimers;
    module.exports.cancelTimers = cancelTimers;

})();
