/*
  The pub/sub queue object
*/
var faye = require('faye');
var mq;
var subscribed = false;
var attached = false;

module.exports = {
    init: function() {
	mq = new faye.NodeAdapter({
	    mount:    '/faye',
	    timeout:  45
	});
    },
    attach: function( server ) {
	mq.attach(server);
	attached = true;

	mq.bind( 'subscribe', function( clientID, channel ) {
	    subscribed = true;
	});
    },
    send: function( mtype, data ) {
	if ( attached && subscribed ) {
	    mq.getClient().publish( '/TA', { mtype: mtype, data: data } );
	}
    }
};
