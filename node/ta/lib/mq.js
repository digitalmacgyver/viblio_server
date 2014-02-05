/*
  The pub/sub queue object
*/
var faye = require('faye');
var mq;

module.exports = {
    init: function() {
	mq = new faye.NodeAdapter({
	    mount:    '/faye',
	    timeout:  45
	});
    },
    attach: function( server ) {
	mq.attach(server);
    },
    send: function( mtype, data ) {
	mq.getClient().publish( '/messages', { mtype: mtype, data: data } );
    }
};
