var Uploader = require( '../lib/uploader' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var fs = require( 'fs' );
var config = require( '../lib/app-config' );
var events = require( 'events' );
var settings = require( '../lib/storage' )( 'settings' );
var privates = require( '../lib/storage' )( 'private' );
var queue    = require( '../lib/storage' )( 'q' );
var crypto   = require( 'crypto' );
var mq = require( '../lib/mq' );

var Queuer = function() {
    this.q = async.queue( function( o, cb ) {
	o.upload( cb );
    }, config.max_uploads );
    events.EventEmitter.call( this );
};

// I am an event emitter
Queuer.super_ = events.EventEmitter;
Queuer.prototype = Object.create(events.EventEmitter.prototype, {
    constructor: {
        value: Queuer,
        enumerable: false
    }
});

Queuer.prototype.setLogger = function( _log ) {
    this.log = _log;
};

Queuer.prototype.handler = function( f, err, results ) {
    var self = this;
    if ( err ) {
	self.log.debug( 'retrying because: ' + err.message );
	f.retries += 1;
	if ( f.retries > config.max_retries ) {
	    self.log.debug( 'max retries exceeded for ' + ( f.fileid || f.filename ) );
	    f.retries = 0;
	    self.emit( 'file:failed', f );
	    mq.send( 'file:failed', JSON.parse( f.toJSON() ) )
	    f.started = false;  // make sure it starts over from scratch
	    queue.set( 'failed:'+f.id, f.toJSON() );
	}
	else {
	    self.emit( 'file:retry', f );
	    mq.send( 'file:retry', JSON.parse( f.toJSON() ) )
	    setTimeout( function() {
		self.q.push( f, function( err, results ) {
		    self.handler( f, err, results );
		});
	    }, 1000 * f.retries );
	}
    }
    else {
	self.log.debug( f.fileid + ' is finished.' );
	queue.set( 'md5:'+f.md5, f.toJSON() );  // Done uploading, remember md5
	queue.del( 'id:'+f.id );                // remove from queue storage
	self.emit( 'file:done', f );
	mq.send( 'file:done', JSON.parse( f.toJSON() ) )
    }
};

Queuer.prototype.add = function( filename, data ) {
    var self = this;
    var dfd  = new Deferred();
    var _md5;
    privates.get( 'uuid' ).then( function( uuid ) {
	async.series([
	    function( xcb ) {
		if ( data ) {
		    _md5 = data.md5;
		    xcb();
		}
		else {
		    var md5 = crypto.createHash( 'md5' );
		    var s = fs.ReadStream( filename );
		    s.on( 'data', function(d) {
			md5.update(d);
		    });
		    s.on( 'end', function() {
			_md5 = md5.digest( 'hex' );
			xcb();
		    });
		}
	    },
	    function( xcb ) {
		var f = new Uploader( filename, uuid );
		if ( data ) 
		    f.initialize( data );
		else
		    f.md5 = _md5;
		queue.get( 'md5:'+_md5 ).then( function( val ) {
		    if ( val ) {
			// This file has already been uploaded
			self.log.debug( 'File ' + filename + ' has already been uploaded.' );
		    }
		    else {
			self.log.debug( 'File ' + filename + ' added to the queue.' );
			queue.set( 'id:'+f.id, f.toJSON() ).then( function() {
			    self.q.push( f, function( err, results ) {
				self.handler( f, err, results );
			    });
			    f.on( 'progress', function() {
				self.emit( 'file:progress', f );
				mq.send( 'file:progress', JSON.parse( f.toJSON() ) )
				// Remember offset in queue storage...
				queue.get( 'id:'+f.id ).then( function( json ) {
				    var struct = JSON.parse( json );
				    struct.offset = f.offset;
				    queue.set( 'id:'+f.id, f.toJSON() );
				});
			    });
			});
		    }
		    xcb();
		});
	    }
	], function( err, res ) {
	    dfd.resolve();
	});
    });
    return dfd.promise;
};

Queuer.prototype.restore = function() {
    var self = this;
    var dfd = new Deferred();
    async.series([
	function( cb ) {
	    // Retry the failed ones
	    queue.values( 'failed' ).then( function( files ) {
		files.forEach( function( json ) {
		    try {
			var f = JSON.parse( json );
			queue.del( 'failed:'+f.id );
			self.add( f.filename, f );
		    } catch(e) {
			self.log.error( 'Parsing JSON: ' + e.message + ': ' + json );
		    };
		});
		cb();
	    });
	},
	function( cb ) {
	    // And anything that was in the queue
	    queue.values( 'id' ).then( function( files ) {
		files.forEach( function( json ) {
		    try {
			var f = JSON.parse( json );
			self.add( f.filename, f );
		    } catch(e) {
			self.log.error( 'Parsing JSON: ' + e.message + ': ' + json );
		    };
		});
		cb();
	    });
	}
    ], function( err, results ) {
	dfd.resolve();
    });
    return dfd.promise;
};

Queuer.prototype.stats = function() {
    var self = this;
    var dfd = new Deferred();
    var total = 0;
    var bytes = 0;
    queue.values( 'md5' ).then( function( files ) {
	files.forEach( function( json ) {
	    var f = JSON.parse( json );
	    total += 1;
	    bytes += f.length;
	});
	dfd.resolve({ total: total, bytes: bytes });
    });
    return dfd.promise;
}

var queuer = new Queuer();
module.exports = queuer;

