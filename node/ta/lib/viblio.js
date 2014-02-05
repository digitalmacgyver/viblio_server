var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var request = require( 'request' );
var config = require( '../lib/app-config' );
var privates = require( '../lib/storage' )( 'private' );
var open = require( 'open' );

// Calling viblio apis

(function() {

    function api( service, data ) {
	var dfd = new Deferred();
	request({
	    url: config.viblio_server_endpoint + service,
	    method: 'POST',
	    jar: true,
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
		    if ( json && json.error ) 
			dfd.reject( json );
		    else
			dfd.resolve( json );
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
    function authenticate() {
	var dfd = new Deferred();

	api( '/services/user/me' ).then(
	    function() {
		dfd.resolve();
	    },
	    function( res ) {
		privates.on( 'uuid', function() {
		    dfd.resolve();
		});
		open( 'http://localhost:' + config.port );
	    }
	);
	
	return dfd.promise;
    }

    module.exports.api = api;
    module.exports.authenticate = authenticate;

})();
