var platform = require( '../lib/platform' );
var config = require( '../lib/app-config' );
var LocalStorage = require( 'node-localstorage' ).LocalStorage;
var path = require( 'path' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var events = require( 'events' );

var Storage = function( primary_key ) {
    this.storage = new LocalStorage( path.join( platform.appdata(), 
						config.name + '.als' ) );
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
    dfd.resolve( this.storage.getItem( this.mkkey( key ) ) );
    return dfd.promise;
}

Storage.prototype.set = function( key, val ) {
    var dfd = new Deferred();
    this.emit( 'set', key, val );
    dfd.resolve( this.storage.setItem( this.mkkey( key ), val ) );
    return dfd.promise;
}

Storage.prototype.del = function( key ) {
    var dfd = new Deferred();
    this.emit( 'del', key );
    dfd.resolve( this.storage.removeItem( this.mkkey( key ) ) );
    return dfd.promise;
}

Storage.prototype.add = function( key, item ) {
    // add item to array
    var dfd = new Deferred();
    var json = this.storage.getItem( this.mkkey( key ) );
    if ( ! json ) json = '[]';
    var a = JSON.parse( json );
    a.push( item );
    this.emit( 'add', item );
    dfd.resolve(
	this.storage.setItem( this.mkkey( key ), JSON.stringify( a ) )
    );
    return dfd.promise;
}

Storage.prototype.rem = function( key, item ) {
    // remove item from array
    var dfd = new Deferred();
    var json = this.storage.getItem( this.mkkey( key ) );
    if ( ! json ) json = '[]';
    var a = JSON.parse( json );
    var b = [];
    a.forEach( function( i ) {
	if ( i !== item ) b.push( i );
    });
    this.emit( 'rem', item );
    if ( b.length == 0 )
	dfd.resolve( this.storage.removeItem( this.mkkey( key ) ) );
    else
	dfd.resolve(
	    this.storage.setItem( this.mkkey( key ), JSON.stringify( b ) )
	);
    return dfd.promise;
}

Storage.prototype.getArray = function( key ) {
    // return array
    var dfd = new Deferred();
    var json = this.storage.getItem( this.mkkey( key ) );
    if ( ! json ) json = '[]';
    var a = JSON.parse( json );
    dfd.resolve( a );
    return dfd.promise;
}

Storage.prototype.json = function() {
    // return all settings as a object
    var dfd = new Deferred();
    var obj = {};
    for( var i=0; i< this.storage.length; i++ ) {
	var key = this.storage.key(i);
	var regexp = new RegExp( '^' + this.pkey + ':(.+)' );
	var m   = key.match( regexp );
	if ( m && m[1] ) {
	    var sval = this.storage.getItem( key );
	    var val;
	    try {
		val = JSON.parse( sval );
	    }
	    catch(e) {
		val = sval;
	    }
	    obj[m[1]] = val;
	}
    }
    dfd.resolve( obj );
    return dfd.promise;
}

Storage.prototype.clear = function() {
    var dfd = new Deferred();
    dfd.resolve( this.storage.clear() );
    return dfd.promise;
}

var factory = {};
module.exports = function( pkey ) {
    if ( ! factory[pkey] )
	factory[pkey] = new Storage( pkey );
    return factory[pkey];
};
