// redis db version of queue
//
var redis = require( "redis" );

var Queue = function(port, host, options) {
    try {
	this.client = redis.createClient(
	    port || 6379,
	    host || "10.100.10.26",
	    options || {}
	);
    } catch( err ) {
	console.log( "Failed to connect to REDIS: " + err.message );
	return null;
    }
}

Queue.prototype.count = function( uid, callback ) {
    try {
	this.client.llen( uid, callback );
    } catch(err) {
	callback( err.message, 0 );
    }
};

Queue.prototype.messagesFor = function( uid, callback ) {
    var found = new Array();
    var client = this.client;
    try {
	this.client.lrange( uid, 0, -1, function( err, range ) {
	    if ( err )
		return callback( err, found );
	    for( var i=0; i<range.length; i++ ) {
		found.push( JSON.parse( range[i] ) );
	    }
	    try {
		client.del( uid ); // remove them from db
	    } catch( err ) {
		callback( err.message, found );
	    }
	    callback( null, found );
	});
    } catch( err ) {
	callback( err.message, found );
    }
};

Queue.prototype.enqueue = function( uid, msg, callback ) {
    try {
	this.client.rpush( uid, JSON.stringify( msg ), callback );
    } catch( err ) {
	callback( err.message, 0 );
    }
};

exports = module.exports = Queue;
