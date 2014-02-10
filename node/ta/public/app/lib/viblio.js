define(['durandal/system', 'lib/mq', 'knockout'], function(system, mq, ko) {
    $.ajaxSetup({cache:false});
    var user = ko.observable();

    var service = function( path ) {
	var h = window.location.protocol + '//' +
	    window.location.hostname;
	if ( window.location.port )
	    h += ':' + window.location.port;
	return h + path;
    };

    var setUser = function( u ) {
        if ( u ) {
            if ( u.uuid != user().uuid ) {
                // Don't change it if its the same user, to prevent
                // subscribe callbacks from firing.
                user( u );
                // subscribe to the async message queue
                mq.subscribe();
            }
            if ( u.displayname != user().displayname ) {
                user( u );
            }
        }
        else {
            user({
                displayname: 'anonymous',
                uuid: null
            });
            mq.unsubscribe();
        }
    };
    setUser( null );

    var getUser = function() {
        return user();
    };

    var last_attempted_url = null;

    return {
	debug: function() {
            system.log.apply( null, arguments );
	},
	
	log: function() {
            system.log.apply( null, arguments );
	},
	
	log_error: function() {
            system.log.apply( null, arguments );
	},

	setLastAttempt: function( attempt ) {
            last_attempted_url = attempt;
        },
        getLastAttempt: function() {
            return last_attempted_url;
        },
        
        setUser: setUser,
        getUser: getUser,
        user: user,

	isUserLoggedIn: function() {
            return user().uuid;
        },

	api: function( path, data, sync ) {
            var deferred = $.Deferred();
            var promise  = deferred.promise();
	    if ( sync ) async = false; else async = true;
            var x = $.ajax({
		url: service( path ),
		data: data,
		method: 'POST',
		async: async,
		dataType: 'json' });
            x.fail( function( xhr, text, error ) {
		var code = xhr.status || 403
		var message = xhr.responseText;
		if ( message == "" )
                    message = "Authentication Failure";
		var data = { error: 1,
                             code: code,
                             message: message };
                deferred.reject( data );
            });
            x.done( function( data, status, xhr ) {
		if ( data && data.error ) {
		    deferred.reject( data );
		}
		else {
                    deferred.resolve( data );
		}
            });
            return promise;
	},

	auth_ping: function() {
	    return this.api( '/authping' );
	},

	ping: function() {
	    return this.api( '/ping' );
	}
    };

});
