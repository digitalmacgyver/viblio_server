var Uploader = require( '../lib/uploader' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var fs = require( 'fs' );
var config = require( '../lib/app-config' );
var events = require( 'events' );
var settings = require( '../lib/storage' )( 'settings' );
var privates = require( '../lib/storage' )( 'private' );

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
	}
	else {
	    self.emit( 'file:retry', f );
	    setTimeout( function() {
		self.q.push( f, function( err, results ) {
		    self.handler( f, err, results );
		});
	    }, 1000 * f.retries );
	}
    }
    else {
	self.log.debug( f.fileid + ' is finished.' );
	self.emit( 'file:done', f );
    }
};

Queuer.prototype.add = function( filename ) {
    var self = this;
    var dfd  = new Deferred();
    privates.get( 'uuid' ).then( function( uuid ) {
	var f = new Uploader( filename, uuid );
	self.q.push( f, function( err, results ) {
	    self.handler( f, err, results );
	});
	f.on( 'progress', function() {
	    self.emit( 'file:progress', f );
	});
	dfd.resolve();
    });
    return dfd.promise;
};

var queuer = new Queuer();
module.exports = queuer;

