var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var request = require( 'request' );
var config = require( '../package.json' );

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

    module.exports.api = api;
})();
