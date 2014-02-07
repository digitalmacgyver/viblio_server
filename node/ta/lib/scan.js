var path = require( 'path' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var fs = require( 'fs' );
var events = require( 'events' );
var config = require( '../lib/app-config' );

// Usage:
//
// var Scanner = require( './lib/scan' );
// var scanner = new Scanner();
//
// scanner.scanForFiles( '/home/peebles/Videos' ).then( function( files ) {
//   // files[] is list of files
// });
//
// OR you can use events if you want the info as it comes:
//
// scanner.on( 'file', function( filename ) {
// });
// scanner.scanForFiles( '/home/peebles/Videos' );
//
var Scanner = function( types, skips ) {
    types = types || '(\.|\/)' + config.file_types + '$';
    this.regexp = new RegExp( types, 'i' );
    if ( skips ) this.skips = new RegExp( skips );
}

// I am an event emitter
Scanner.super_ = events.EventEmitter;
Scanner.prototype = Object.create(events.EventEmitter.prototype, {
    constructor: {
        value: Scanner,
        enumerable: false
    }
});

// Similar to scanForFiles() except this one returns the list of
// directories that contain at least one file that matches the
// regexp.  If such a file is found, the search is done down
// that branch.
Scanner.prototype.scanForDirs = function( topdir, concurrency ) {
    var self = this;
    var dfd  = new Deferred();
    concurrency = concurrency || 1;
    self.dirs = [];
    var q = async.queue( function( dir, done ) {
	fs.readdir( dir, function( err, files ) {
	    if ( err ) done( err );
	    else {
		async.map( files, function( f, mcb ) {
		    fs.stat( path.join( dir, f ), function( err, res ) {
			mcb( null, res );
		    });
		}, function( err, stats ) {
		    if ( err ) {
			return done( err );
		    }
		    var found = false;
		    var todo  = [];
		    for( var i=0; ( i<files.length && ! found ); i++ ) {
			try {
			    var f = files[i];
			    var stat = stats[i];
			    if ( ! stat.isDirectory() ) {
				if ( f.match( self.regexp ) ) {
				    self.emit( 'dir', dir );
				    self.dirs.push( dir );
				    found = true;
				}
			    }
			    else {
				// remember subdirs if we don't find any files
				if ( ! ( self.skips && dir.match( self.skips ) ) ) 
				    todo.push( path.join( dir, f ) ); 
			    }
			} catch(e) {
			    // ignore errors
			};
		    }
		    if ( ! found ) {
			async.nextTick( function() {
			    todo.forEach( function( pathname ) {
				q.push( pathname );
			    });
			    done();
			});
		    }
		    else {
			done();
		    }
		});
	    }
	});
    }, concurrency );
    q.push( topdir );
    q.drain = function() {
	dfd.resolve( self.dirs );
    }
    return dfd.promise;
}

// Recursively scans the file system for files that match
// the file type regexp passed into the contructor.  Returns
// a promise.  The resolution function will return the list
// of matching files (full paths starting with topdir).
Scanner.prototype.scanForFiles = function( topdir, concurrency ) {
    var self = this;
    var dfd  = new Deferred();
    concurrency = concurrency || 1;
    self.files = [];
    var q = async.queue( function( dir, done ) {
	fs.readdir( dir, function( err, files ) {
	    if ( err ) done( err );
	    else {
		async.map( files, function( f, mcb ) {
		    fs.stat( path.join( dir, f ), function( err, res ) {
			mcb( null, res );
		    });
		}, function( err, stats ) {
		    if ( err ) {
			return done( err );
		    }
		    var todo = [];
		    for( var i=0; i<files.length; i++ ) {
			try {
			    var f = files[i];
			    var stat = stats[i];
			    if ( stat.isDirectory() ) {
				if ( ! ( self.skips && dir.match( self.skips ) ) ) 
				    todo.push( path.join( dir, f ) );
			    }
			    else if ( f.match( self.regexp ) ) {
				self.emit( 'file', path.join( dir, f ) );
				self.files.push( path.join( dir, f ) );
			    }
			} catch(e) {
			    // ignore errors
			};
		    }
		    async.nextTick( function() {
			todo.forEach( function( pathname ) {
				q.push( pathname );
			});
			done();
		    });
		});
	    }	 
	});
    }, concurrency );
    q.push( topdir );
    q.drain = function() {
	dfd.resolve( self.files );
    }
    return dfd.promise;
}

Scanner.prototype.listing = function( dir ) {
    var self = this;
    var dfd  = new Deferred();
    fs.readdir( dir, function( err, files ) {
	if ( err ) return dfd.reject( err );
	async.map( files, 
		   function( file, cb ) {
		       fs.stat( path.join( dir, file ), function( err, s ) {
			   cb( null, s );
		       });
		   },
		   function( err, stats ) {
		       if ( err ) return dfd.reject( err );
		       var result = [];
		       for( var i=0; i<files.length; i++ )
			   result.push({ file: files[i],
					 path: path.join( dir, files[i] ),
					 isdir: ( stats[i] ? stats[i].isDirectory() : false ),
					 size:  ( stats[i] ? stats[i].size : 0 ) });
		       dfd.resolve( result );
		   });
    });
    return dfd.promise;
}

module.exports = Scanner;
