var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var request = require( 'request' );
var events = require( 'events' );
var config = require( '../package.json' );
var fs = require( 'fs' );
var url = require( 'url' );
var path = require ( 'path' );
var cookie = require( 'cookie' );
var gen_uuid = require( 'node-uuid' );

// Utility function to allow me to wait on an OR of
// many events, and react to the first that occurs.
// Used in pauseUpload() and cancelUpload().
function onMany(emitter, events, callback) {
    function cb() {
        callback.apply(emitter, arguments);

        events.forEach(function(ev) {
            emitter.removeListener(ev, cb);
        });
    }

    events.forEach(function(ev) {
        emitter.on(ev, cb);
    });
}

var Uploader = function( filename, uuid ) {
    this.filename = filename;
    this.uuid     = uuid;

    this.id = gen_uuid.v4();

    this.fileid   = null;
    this.cookie   = null;

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

// Called when writing to persistent storage
Uploader.prototype.toJSON = function() {
    return JSON.stringify({
	id: this.id,
	filename: this.filename,
	uuid: this.uuid,
	fileid: this.fileid,
	cookie: this.cookie,
	cancel: this.cancel,
	cancelled: this.cancelled,
	pause: this.pause,
	paused: this.paused,
	done: this.done,
	started: this.started,
	offset: this.offset,
	error: this.error,
	retries: this.retries
    });
}

// Called when initializing from persistent storage
Uploader.prototype.initialize = function( data ) {
    this.id       = data.id;

    this.filename = data.filename;
    this.uuid     = data.uuid;

    this.fileid   = data.fileid;
    this.cookie   = data.cookie;

    this.cancel   = data.cancel;
    this.cancelled = data.cancelled;

    this.pause    = data.pause;
    this.paused   = data.paused;

    this.done     = data.done;
    this.started  = data.started;
    this.offset   = data.offset;
    this.length   = data.length;

    this.error    = data.error;
    this.retries  = data.retries;
}

// I am an event emitter
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
    // var dfd  = new Deferred();

    async.series({
	start: function( cb ) {
	    if ( self.started ) {
		// We are here because of a resume or a retry.  Do a HEAD to
		// get the server offset.
		request({
		    url: config.viblio_upload_endpoint + '/' + self.fileid,
		    method: 'HEAD',
		    headers: {
			'Cookie': self.cookie,
		    },
		    strictSSL: false
		}, function( err, res, body ) {
		    if ( err ) cb( err );
		    else if ( res.statusCode != 200 )
			cb( new Error( 'HEAD: ' + self.fileid + ': ' + res.statusCode ) );
		    else {
			self.offset = parseInt( res.headers.offset );
			self.pause = false;
			self.paused = false;
			self.error = null;
			cb();
		    }
		});
	    }
	    else {
		try {
		    var stat = fs.statSync( self.filename );
		    self.length = stat.size;
		}
		catch( e ) {
		    cb( e );
		};
		request({
		    url: config.viblio_upload_endpoint,
		    method: 'POST',
		    json: {
			uuid: self.uuid,
			file: { Path: self.filename }
		    },
		    headers: {
			'Final-Length': self.length
		    },
		    strictSSL: false
		}, function( err, res, body ) {
		    if ( err ) cb( err );
		    else if ( ! ( res.statusCode == 200 || res.statusCode == 201 ) )
			cb( new Error( 'POST: ' + self.filename + ': ' + res.statusCode ) );
		    else {
			var location = res.headers.location;
			if ( ! location ) {
			    cb( new Error( 'POST did not return a Location header' ) );
			}
			else {
			    var pathname = url.parse( location ).pathname;
			    self.fileid = path.basename( pathname );

			    if ( res.headers['set-cookie'] ) {
				res.headers['set-cookie'].forEach( function( c ) {
				    var cookies = cookie.parse( c );
				    if ( cookies && cookies.AWSELB )
					self.cookie = 'AWSELB='+cookies.AWSELB;
				});
			    }

			    self.started = true;
			    cb();
			}
		    }
		});
		    
	    }
	},
	patch: function( cb ) {
	    async.doWhilst( 
		function( wcb ) {
		    self._doChunk().then(
			function( res ) {
			    wcb();
			},
			function( err ) {
			    wcb( err );
			}
		    );
		},
		function() {
		    return( self.offset < self.length &&
			    ! (self.pause || self.cancel ) );
		},
		function( err ) {
		    cb( err );
		}
	    );
	}
    }, function( err, results ) {
	if ( err ) { self.error = err.message; self.emit( 'errored', err ); }
	else if ( self.pause ) self.emit( 'paused' );
	else if ( self.cancel ) self.emit( 'cancelled' );
	else {
	    self.done = true;
	    self.emit( 'done' );
	}
	doneCallback( err );
	//if ( err ) dfd.reject( err );
	//else dfd.resolve();
    });

    // return dfd.promise;
}

// Do one POST
Uploader.prototype._doChunk = function( doneCallback ) {
    var self = this;
    var dfd  = new Deferred();

    if ( ! self.fd ) {
	self.fd = fs.openSync( self.filename, 'r' );
	if ( ! self.fd )
	    return dfd.reject( new Error( 'Failed to open ' + self.filename + ' to read' ) );
    }
    var buffer = new Buffer( config.chunk_size );
    var bytes_read = fs.readSync( self.fd, buffer, 0, config.chunk_size, self.offset );
    request({
	url: config.viblio_upload_endpoint + '/' + self.fileid,
	method: 'PATCH',
	headers: {
	    'Content-Type': 'application/offset+octet-stream',
	    'Content-Length': bytes_read,
	    'Offset': self.offset,
	    'Cookie': self.cookie,
	},
	body: buffer,
	strictSSL: false
    }, function( err, res, body ) {
	if ( err ) dfd.reject( err );
	else if ( res.statusCode != 200 )
	    dfd.reject( new Error( 'PATCH: ' + self.fileid + ': ' + res.statusCode ) );
	else {
	    self.offset += bytes_read;
	    if ( self.offset >= self.length )
		fs.closeSync( self.fd );
	    self.emit( 'progress', self );
	    dfd.resolve();
	}
    });
    return dfd.promise;
}

// o.pause().then( function() { log.debug( 'paused' ); }
Uploader.prototype.pauseUpload = function() {
    var self = this;
    var dfd  = new Deferred();

    onMany( self, ['paused', 'done', 'cancelled', 'errored' ],
	    function( err ) {
		if ( err ) { self.error = error; dfd.reject( err ); }
		else dfd.resolve( self );
	    });

    self.pause = true;  // initiate the pause
    return dfd.promise;
}

// o.pause().then( function() { log.debug( 'paused' ); }
Uploader.prototype.cancelUpload = function() {
    var self = this;
    var dfd  = new Deferred();

    onMany( self, ['done', 'cancelled', 'errored' ],
	    function( err ) {
		if ( err ) { self.error = error; dfd.reject( err ); }
		else dfd.resolve( self );
	    });

    self.cancel = true;  // initiate the cancel
    return dfd.promise;
}

// Issue a DELETE to the server
Uploader.prototype.deleteUpload = function() {
    var self = this;
    var dfd = new Deferred();

    request({
	url: config.viblio_upload_endpoint + '/' + self.fileid,
	method: 'DELETE',
	headers: {
	    'Cookie': self.cookie,
	},
	strictSSL: false
    }, function( err, res, body ) {
	if ( err ) dfd.reject( err );
	else if ( res.statusCode != 200 )
	    dfd.reject( new Error( 'DELETE: ' + self.fileid + ': ' + res.statusCode ) );
	else {
	    dfd.resolve();
	}
    });
    return dfd.promise;
}

module.exports = Uploader;