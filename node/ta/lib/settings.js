var platform = require( '../lib/platform' );
var config = require( '../package.json' );
var LocalStorage = require( 'node-localstorage' ).LocalStorage;
var path = require( 'path' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;

// Usage:
//
// settings = require( './lib/settings' )( 'settings' );
// private  = require( './lib/settings' )( 'private' );
//
// settings.add( 'general', 'setting' );
// private.add( 'uuid', user_uuid );
//
module.exports = function( primary_key ) {
    var storage = new LocalStorage( path.join( platform.appdata(), 
					       config.name + '.als' ) );
    var pkey = 'settings';
    if ( primary_key ) pkey = primary_key;

    function mkkey( key ) {
	return [ pkey, key ].join( ':' );
    }

    return {
	get: function( key ) {
	    var dfd = new Deferred();
	    dfd.resolve( storage.getItem( mkkey( key ) ) );
	    return dfd.promise;
	},
	set: function( key, val ) {
	    var dfd = new Deferred();
	    dfd.resolve( storage.setItem( mkkey( key ), val ) );
	    return dfd.promise;
	}, 
	del: function( key ) {
	    var dfd = new Deferred();
	    dfd.resolve( storage.removeItem( mkkey( key ) ) );
	    return dfd.promise;
	},
	add: function( key, item ) {
	    // add item to array
	    var dfd = new Deferred();
	    var json = storage.getItem( mkkey( key ) );
	    if ( ! json ) json = '[]';
	    var a = JSON.parse( json );
	    a.push( item );
	    dfd.resolve(
		storage.setItem( mkkey( key ), JSON.stringify( a ) )
	    );
	    return dfd.promise;
	},
	rem: function( key, item ) {
	    // remove item from array
	    var dfd = new Deferred();
	    var json = storage.getItem( mkkey( key ) );
	    if ( ! json ) json = '[]';
	    var a = JSON.parse( json );
	    var b = [];
	    a.forEach( function( i ) {
		if ( i !== item ) b.push( i );
	    });
	    if ( b.length == 0 )
		dfd.resolve( storage.removeItem( mkkey( key ) ) );
	    else
		dfd.resolve(
		    storage.setItem( mkkey( key ), JSON.stringify( b ) )
		);
	    return dfd.promise;
	},
	getArray: function( key ) {
	    // return array
	    var dfd = new Deferred();
	    var json = storage.getItem( mkkey( key ) );
	    if ( ! json ) json = '[]';
	    var a = JSON.parse( json );
	    dfd.resolve( a );
	    return dfd.promise;
	},
	json: function() {
	    // return all settings as a object
	    var dfd = new Deferred();
	    var obj = {};
	    for( var i=0; i< storage.length; i++ ) {
		var key = storage.key(i);
		var regexp = new RegExp( '^' + pkey + ':(.+)' );
		var m   = key.match( regexp );
		if ( m && m[1] ) {
		    var sval = storage.getItem( key );
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
    };
};

