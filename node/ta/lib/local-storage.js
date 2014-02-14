/*
  node-localStorage was used initially, but that code is full of Sync calls.  This
  is a rewrite with everything being async.  I also attempt to cache the state in
  memory to minimize startup cost.
*/
fs = require( 'fs' );
path = require( 'path' );
async = require( 'async' );

var cacheHash = {};
var cacheArray = [];
var location;
var _length = 0;
var _inited = false;

module.exports = {

    // Initialize the location of the database
    init: function( root ) {
	if ( ! fs.existsSync( root ) ) {
	    fs.mkdirSync( root );
	}
	location = root;
    },

    // Read the existing database into memory
    _readdb: function(callback) {
	fs.readdir( location, function( err, files ) {
	    if ( err ) return callback( err );
	    cacheHash = {};
	    cacheArray = [];
	    async.map( files,
		       function( file, cb ) {
			   fs.readFile( path.join( location, file ), 'utf8', function( err, value ) {
			       if ( err ) return cb(err);
			       var key = decodeURIComponent( file );
			       cacheHash[key] = value;
			       cacheArray.push( key );
			       cb();
			   });
		       },
		       function( err, results ) {
			   _length = cacheArray.length;
			   _inited = true;
			   callback();
		       }
		     );
	});
    },

    length: function(callback) {
	if ( ! _inited ) {
	    // Need to read the entire database to get an accurate length
	    this._readdb(function(err) {
		if (callback) callback(err,_length);
	    });
	}
	else {
	    if (callback) callback(null,_length);
	}
    },

    setItem: function( key, value, callback ) {
	var filename = path.join( location, encodeURIComponent(key) );
	fs.writeFile( filename, value, { encoding: 'utf8' }, function(err) {
	    // cache it
	    if ( ! cacheHash[key] ) {
		cacheHash[key] = value;
		cacheArray.push( key );
		_length = cacheArray.length;
	    }
	    if (callback) callback(err);
	});
    },

    getItem: function( key, callback ) {
	var filename = path.join( location, encodeURIComponent(key) );
	if ( cacheHash[key] ) {
	    // read from cache
	    if (callback) callback( null, cacheHash[key] );
	}
	else {
	    fs.readFile( filename, 'utf8', function( err, value ) {
		if ( err ) callback( null, null );
		else {
		    if ( value ) {
			cacheHash[key] = value;
			cacheArray.push( key );
			_length = cacheArray.length;
		    }
		    if (callback) callback( null, value );
		}
	    });
	}
    },

    removeItem: function( key, callback ) {
	var filename = path.join( location, encodeURIComponent(key) );
	fs.unlink( filename, function(err) {
	    if ( cacheHash[key] )
		delete cacheHash[key];
	    var idx = cacheArray.indexOf( key );
	    if ( idx != -1 )
		cacheArray.splice( idx, 1 );
	    _length = cacheArray.length;
	    if (callback) callback(err);
	});
    },

    clear: function( callback ) {
	var self = this;
	// To clear, we need to read the database if it has not already been read
	async.series([
	    function(scb) {
		if ( _inited ) 
		    scb();
		else
		    self._readdb( function( err ) {
			scb( err );
		    })
	    },
	    function(scb) {
		var deleted = {};
		async.map( cacheArray,
			   function( key, cb ) {
			       var filename = path.join( location, 
							 encodeURIComponent(key) );
			       fs.unlink( filename, function(err) {
				   delete cacheHash[key];
				   deleted[key]=true;
				   cb(err);
			       });
			   },
			   function( err, results ) {
			       var newArray = [];
			       cacheArray.forEach( function( key ) {
				   if ( ! deleted[key] )
				       newArray.push( key );
			       });
			       cacheArray = newArray;
			       _length = cacheArray.length;
			       scb(err);
			   }
			 );
	    }
	], function( err ) {
	    if (callback) callback(err);
	});
    },

    key: function( n, callback ) {
	if ( ! _inited ) {
	    // Read the database into memory if we don't already have it.
	    this._readdb(function(err) {
		if (callback) callback( err, cacheArray[n] );
	    });
	}
	else {
	    if (callback) callback( null, cacheArray[n]  );
	}
    }

};

    