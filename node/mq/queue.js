// In memory version of the queue.  Is written using callbacks,
// so should be easy to implement a version that uses database like
// SQLite3 or something.
//
var Queue = function() {}

// Inherit Array methods like push and length.
//
Queue.prototype = new Array();

// PRIVATE
Queue.prototype.removeItem = function( key ) {
   if (!this.hasOwnProperty(key))
      return
   if (isNaN(parseInt(key)) || !(this instanceof Array))
      delete this[key]
   else
      this.splice(key, 1)
};

//PRIVATE
Queue.prototype.findAndRemoveOne = function( uid ) {
    for( var i=0; i<this.length; i++ ) {
	if ( this[i].uid == uid ) {
	    var item = this[i].message;
	    this.removeItem( i );
	    return item;
	}
    }
    return null;
};

Queue.prototype.count = function( uid, callback ) {
    var n = 0;
    for( var i=0; i<this.length; i++ ) {
	if ( this[i].uid == uid ) {
	    n += 1;
	}
    }
    callback( null, n );
};

Queue.prototype.messagesFor = function( uid, callback ) {
    var found = new Array();
    var item;
    while( item = this.findAndRemoveOne( uid ) ) 
	found.push( item );
    callback( null, found );
};

Queue.prototype.enqueue = function( uid, msg, callback ) {
    this.push( { uid: uid, message: msg } );
    callback( null );
};

exports = module.exports = Queue;
