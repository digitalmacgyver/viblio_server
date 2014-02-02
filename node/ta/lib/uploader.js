var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var request = require( 'request' );
var events = require( 'events' );
var config = require( '../package.json' );

var Uploader = function( filename, uuid ) {
    this.filename = filename;
    this.uuid = uuid;

    this.cancel = false;
    this.cancelled = false;

    this.pause = false;
    this.paused = false;

    this.done = false;
    this.started = false;
    this.offset = 0;
    this.length = 0;

    this.error = null;
    this.retries = 0;

    events.EventEmitter.call( this );
};

Uploader.super_ = events.EventEmitter;
Uploader.prototype = Object.create(events.EventEmitter.prototype, {
    constructor: {
        value: Uploader,
        enumerable: false
    }
});

// o.upload() is indended to be run withing the function 
// passed to async.queue().  Both o.pause() and o.cancel()
// will cause processing to stop after the current PATCH
// is complete, and so the job exists the queue.  In
// the case of cancel, we'll issue a o.delete() and be
// done.  In the case of o.pause() we will not to the delete
// and may place the object back in the queue later (probably
// with an "unshift").
//
Uploader.prototype.upload = function( doneCallback ) {
    var self = this;
    async.series({
	start: function( cb ) {
	    if ( self.paused ) {
		// Do a HEAD to get offset
		cb( err );
	    }
	    else {
		// Do a POST to get fileID
		cb( err );
	    }
	},
	patch: function( cb ) {
	    async.doWhilst( 
		self._doChunk,
		function() {
		    return self.offset < self.length &&
			! self.pause && ! self.cancel;
		},
		function( err ) {
		    cb( err );
		}
	    );
	}
    }, function( err, results ) {
	if ( err ) self.emit( 'error', err );
	else if ( self.pause ) self.emit( 'paused' );
	else if ( self.cancelled ) self.emit( 'cancelled' );
	else {
	    self.done = true;
	    self.emit( 'done' );
	}
	doneCallback( err );
    });
}

// Do one POST
Uploader.prototype._doChunk = function( doneCallback ) {
    var self = this;

    doneCallback( err );
}

// o.pause().then( function() { log.debug( 'paused' ); }
Uploader.prototype.pause = function() {
    var self = this;
    var dfd  = new Deferred();

    self.on( 'paused', function() {
	self.paused = true;
	dfd.resolve( self );
    });

    self.on( 'done', function() {
	dfd.resolve( self );
    });

    self.on( 'error', function( err ) {
	self.error = err;
	dfd.reject( self );
    });

    self.pause = true;  // initiate the pause
    return dfd.promise;
}

// o.pause().then( function() { log.debug( 'paused' ); }
Uploader.prototype.cancel = function() {
    var self = this;
    var dfd  = new Deferred();

    self.on( 'cancelled', function() {
	self.cancelled = true;
	dfd.resolve( self );
    });

    self.on( 'done', function() {
	dfd.resolve( self );
    });

    self.on( 'error', function( err ) {
	self.error = err;
	dfd.reject( self );
    });

    self.cancel = true;  // initiate the cancel
    return dfd.promise;
}

// Issue a DELETE to the server
Uploader.prototype.delete = function() {
    var self = this;
    var dfd = new Deferred();

    return dfd.promise;
}

module.exports = Uploader;
