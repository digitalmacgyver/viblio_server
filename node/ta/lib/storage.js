var platform = require( '../lib/platform' );
var config = require( '../lib/app-config' );
var pj = require( '../package.json' );
var mkdirp = require( 'mkdirp' );
var local_storage = require( '../lib/local-storage' );
var path = require( 'path' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var events = require( 'events' );

function debug() {
    if ( false )
	console.log.apply( null, arguments );
}

var Storage = function( primary_key ) {
    var loc = path.join( platform.appdata(), pj.name )
    mkdirp.sync( loc );
    this.storage = local_storage;
    this.storage.init( loc );
    this.pkey = primary_key || 'settings';
}

// I am an event emitter
Storage.super_ = events.EventEmitter;
Storage.prototype = Object.create(events.EventEmitter.prototype, {
    constructor: {
        value: Storage,
        enumerable: false
    }
});

Storage.prototype.mkkey = function ( key ) {
    return [ this.pkey, key ].join( ':' );
}

Storage.prototype.get = function( key ) {
    var dfd = new Deferred();
    this.storage.getItem( this.mkkey( key ), function( err, val ) {
	if ( err ) debug( err.message );
	dfd.resolve( val );
    });
    return dfd.promise;
}

Storage.prototype.set = function( key, val ) {
    var dfd = new Deferred();
    this.emit( 'set:'+key, val );
    this.storage.setItem( this.mkkey( key ), val, function( err ) {
	if ( err ) debug( err.message );
	dfd.resolve();
    });
    return dfd.promise;
}

Storage.prototype.del = function( key ) {
    var dfd = new Deferred();
    this.emit( 'del:'+key );
    this.storage.removeItem( this.mkkey( key ), function(err) {
	if ( err ) debug( err.message );
	dfd.resolve();
    });
    return dfd.promise;
}

Storage.prototype.add = function( key, item ) {
    // add item to array
    var dfd = new Deferred();
    this.storage.getItem( this.mkkey( key ), function( err, json ) {
	if ( ! json ) json = '[]';
	var a = JSON.parse( json );
	a.push( item );
	this.emit( 'add:'+key, item );
	this.storage.setItem( this.mkkey( key ), JSON.stringify( a ), function(err) {
	    if ( err ) debug( err.message );
	    dfd.resolve();
	});
    });
    return dfd.promise;
}

Storage.prototype.rem = function( key, item ) {
    // remove item from array
    var dfd = new Deferred();
    this.storage.getItem( this.mkkey( key ), function( err, json ) {
	if ( ! json ) json = '[]';
	var a = JSON.parse( json );
	var b = [];
	a.forEach( function( i ) {
	    if ( i !== item ) b.push( i );
	});
	this.emit( 'rem:'+key, item );
	if ( b.length == 0 )
	    this.storage.removeItem( this.mkkey( key ), function(err) {
		if ( err ) debug( err.message );
		dfd.resolve();
	    });
	else
	    this.storage.setItem( this.mkkey( key ), JSON.stringify( b ), function(err) {
		if ( err ) debug( err.message );
		dfd.resolve();
	    });
    });
    return dfd.promise;
}

Storage.prototype.getArray = function( key ) {
    // return array
    var dfd = new Deferred();
    this.storage.getItem( this.mkkey( key ), function( err, json ) {
	if ( err ) debug( err.message );
	if ( ! json ) json = '[]';
	var a = JSON.parse( json );
	dfd.resolve( a );
    });
    return dfd.promise;
}

Storage.prototype.json = function() {
    // return all settings as a object
    var self = this;
    var dfd = new Deferred();
    var obj = {};
    var regexp = new RegExp( '^' + self.pkey + ':(.+)' );
    self.storage.length( function( err, len ) {
	var i=0;
	async.whilst( 
	    function() { return( i < len ); },
	    function( cb ) {
		self.storage.key( i, function( err, key ) {
		    i+=1;
		    var m   = key.match( regexp );
		    if ( m && m[1] ) {
			self.storage.getItem( key, function( err, sval ) {
			    var val;
			    try {
				val = JSON.parse( sval );
			    }
			    catch(e) {
				val = sval;
			    }
			    obj[m[1]] = val;
			    cb();
			});
		    }
		    else {
			cb();
		    }
		});
	    },
	    function(err) {
		if ( err ) debug( err.message );
		dfd.resolve( obj );
	    }
	);
    });
    return dfd.promise;
}

Storage.prototype.clear = function() {
    var self = this;
    var dfd = new Deferred();
    var regexp = new RegExp( '^' + self.pkey );

    var found;
    async.doWhilst(
	function( cb ) {
	    found = false;
	    self.storage.length( function( err, len ) {
		if ( len == 0 ) return cb();
		var i=0;
		async.whilst(
		    function() { return( found==false && i < len ); },
		    function( xcb ) {
			self.storage.key( i, function( err, key ) {
			    if ( err ) debug( err.message );
			    i += 1;
			    if ( key.match( regexp ) ) {
				found = true;
				self.storage.removeItem( key, function( err ) {
				    xcb();
				});
			    }
			    else {
				xcb();
			    }
			});
		    },
		    function(err) {
			cb(err);
		    }
		);
	    });
	},
	function() { return found==true; },
	function( err ) {
	    dfd.resolve()
	}
    );


    return dfd.promise;
}

Storage.prototype.clearAll = function() {
    var dfd = new Deferred();
    this.storage.clear( function(err) {
	if ( err ) debug( err.message );
	dfd.resolve();
    });
    return dfd.promise;
}

Storage.prototype.values = function( rx ) {
    var self = this;
    var dfd = new Deferred();
    var regexp = new RegExp( '^' + this.pkey + ':' + rx + ':(.+)' );
    var result = [];

    self.storage.length( function( err, len ) {
	var i=0;
	async.whilst( 
	    function() { return( i < len ); },
	    function( cb ) {
		self.storage.key( i, function( err, key ) {
		    i += 1;
		    if ( key.match( regexp ) ) {
			var m   = key.match( regexp );
			if ( m && m[1] ) {
			    self.storage.getItem( key, function( err, sval ) {
				result.push( sval );
				cb();
			    });
			}
			else {
			    cb();
			}
		    }
		    else {
			cb();
		    }
		});
	    },
	    function( err ) {
		if ( err ) debug( err.message );
		dfd.resolve( result );
	    }
	);
    });

    return dfd.promise;
}
    

var factory = {};
module.exports = function( pkey ) {
    if ( ! factory[pkey] ) {
	factory[pkey] = new Storage( pkey );
    }
    return factory[pkey];
};
