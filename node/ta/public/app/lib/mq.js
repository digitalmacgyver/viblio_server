define(['durandal/app','durandal/system'], function(app, system) {
    var mq = null;
    var subscribed = false;

    try {
	mq = new Faye.Client( '/faye', {
	    timeout: 120 });
	// These two disable statements are needed when using
	// nginx as a front end to reverse-proxy the faye server.
	mq.disable( 'websocket' );
	mq.disable('eventsource'); 
    } catch( e ) {
	system.log( 'Failed to connect to Faye.' );
    };

    return {
	subscribe: function( callback ) {
	    if ( mq ) {
		if ( ! subscribed ) {
		    try {
			var s = mq.subscribe( '/messages', function( msg ) {
			    system.log( 'received a message!', msg );
			    app.trigger( 'mq:'+msg.mtype, msg.data );
			});
			s.callback( function(arg) {
			    subscribed = true;
			});
			s.errback( function( err ) {
			    system.log( 'Failed to subscribe to message queue: ' + err );
			    subscribed = false;
			});
		    }
		    catch(e) {
			system.log( 'Failed to subscribe to message queue!' );
		    }
		}
	    }
	    else {
		system.log( 'Attempt to subscribe to Faye failed: never connected.' );
	    }
	},
	unsubscribe: function() {
	    if ( mq && subscribed ) {
		mq.unsubscribe( '/messages' );
	    }
	}
    };

});
