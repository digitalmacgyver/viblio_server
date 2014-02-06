var path = require( 'path' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;
var fs = require( 'fs' );
var events = require( 'events' );

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
var Scanner = function( types ) {
    types = types || 
	'(\.|\/)(3gp|avi|flv|m4v|mp4|mts|mov|mpeg|mpg|ogg|swf|mwv)$';
    this.regexp = new RegExp( types, 'i' );
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

module.exports = Scanner;
