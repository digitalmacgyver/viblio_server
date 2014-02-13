var Scanner = require( '../lib/scan' );
var mq = require( '../lib/mq' );
var platform = require( '../lib/platform' );
var config = require ( '../lib/app-config' );
var settings = require( '../lib/storage' )( 'settings' );
var privates = require( '../lib/storage' )( 'private' );
var async = require( 'async' );
var queuer = require( '../lib/queuer' );
var fs = require( 'fs' );
var path = require( 'path' );
var watcher = require( '../lib/watcher' );
var Deferred = require( 'promised-io/promise').Deferred;

var uploads = {};
watcher.on( 'change', function( filename, stat, prev, topdir ) {
    var scanner = new Scanner( null, platform.dirskips() );
    var types = '(\.|\/)' + config.file_types + '$';
    var regexp = new RegExp( types, 'i' );

    if ( ! filename.match( regexp ) ) return;

    // send it to the UI
    mq.send( 'file', { topdir: topdir, file: filename });

    // This is a "bounce" detector.  Filesystem watchers
    // can fire multiple times during an "add".  If we detect
    // that, then cancel the currently uploading version
    // of the file.
    if ( uploads[filename] ) {
	queuer.cancel( uploads[filename].id ).then( function() {
	    queuer.add( filename );
	});
    }
    else {
	queuer.add( filename );
    }
});

queuer.on( 'file:add', function( f ) {
    uploads[ f.filename ] = f;
});

queuer.on( 'file:done', function( f ) {
    if ( uploads[ f.filename ] ) 
	delete uploads[ f.filename ];
});

queuer.on( 'file:failed', function( f ) {
    if ( uploads[ f.filename ] ) 
	delete uploads[ f.filename ];
});

queuer.on( 'file:cancelled', function( f ) {
    if ( uploads[ f.filename ] ) 
	delete uploads[ f.filename ];
});

function uploadFiles( dirs ) {
    var dfd = new Deferred();
    var scanner = new Scanner( null, platform.dirskips() );

    scanner.on( 'file', function( s ) {
	mq.send( 'file', s );
	queuer.add( s.file );
    });

    async.map( dirs, 
	       function( dir, cb ) {
		   scanner.scanForFiles( dir ).then( 
		       function( files ) {
			   cb( null, files );
		       },
		       function( err ) {
			   cb( err );
		       }
		   );
	       },
	       function(err, result ) {
		   if ( err ) dfd.reject( err );
		   else dfd.resolve( result );
	       }
	     );
    return dfd.promise;
}

function newUser() {
    /*

      THE UI DOES A MANUAL SCAN NOW AFTER LOGIN!!!

    var scanner = new Scanner( null, platform.dirskips() );
    scanner.on( 'file', function( s ) {
	mq.send( 'scan:file', s );
	mq.send( 'file', s );
    });

    mq.send( 'scan:files:start' );
    async.map( platform.defaultWatchDirs(), 
	       function( dir, cb ) {
		   scanner.scanForFiles( dir ).then(
		       function( files ) {
			   cb( null, files );
		       }
		   );
	       },
	       function( err, results ) {
		   mq.send( 'scan:files:done', results );
	       }
	     );
    */
}

function existingUser() {
    // Restore the queue from storage ...
    queuer.restore();
    addWatchDirs();
}

function scanAll() {
    var scanner = new Scanner( null, platform.dirskips() );
    scanner.on( 'file', function( s ) {
	mq.send( 'scan:file', s );
	mq.send( 'file', s );
    });
    mq.send( 'scan:files:start' );

    settings.getArray( 'watchdir' ).then( function( dirs ) {
	if ( dirs.length == 0 ) {
	    dirs = platform.defaultWatchDirs()
	}
	async.map( dirs, 
		   function( dir, cb ) {
		       scanner.scanForFiles( dir ).then(
			   function( files ) {
			       cb( null, files );
			   }
		       );
		   },
		   function( err, results ) {
		       mq.send( 'scan:files:done', results );
		   }
		 );
    });
}

var watchTimers = {};
function addWatchDir( dir, illdoit ) {
    var dfd = new Deferred();
    var types = '(\.|\/)' + config.file_types + '$';
    var regexp = new RegExp( types, 'i' );

    watcher.add( dir ).then( function( info ) {
	var dir = info.dir;
	var matches = info.matches;
	if ( dir ) {
	    // add dir, remove matches, scandir and add files found,
	    // minus matches.
	    settings.add( 'watchdir', dir ).then( function() {
		async.map( matches, function( match, cb ) {
		    settings.rem( 'watchdir', match ).then( function() {
			cb();
		    })
		}, function(err) {
		    if ( ! illdoit ) {
			uploadFiles( [dir] ).then( function() {
			    dfd.resolve();
			});
		    }
		    else {
			dfd.resolve();
		    }
		});
	    });
	}
	else {
	    dfd.reject( new Error( "Folder's parent already being watched" ) );
	}
    });

    return dfd.promise;
}

function addWatchDirs() {
    var dfd = new Deferred();
    // Get the watchdirs ... send all the files in each
    // to the queue (which will just drop those that have
    // already uploaded), then establish the watches
    settings.getArray( 'watchdir' ).then( function( dirs ) {
	settings.del( 'watchdir' ).then( function() {
	    async.mapSeries( dirs,
			     function( dir, cb ) {
				 addWatchDir( dir, true ).then( function() {
				     cb();
				 });
			     },
			     function() {
				 settings.getArray( 'watchdir' ).then( function( dirs ) {
				     uploadFiles( dirs ).then( function() {
					 dfd.resolve();
				     });
				 });
			     });
	});
    });
    return dfd.promise;
}

function removeWatchDir( dir ) {
    settings.rem( 'watchdir', dir );
    watcher.remove( dir );
}

module.exports.newUser = newUser;
module.exports.existingUser = existingUser;
module.exports.addWatchDirs = addWatchDirs;
module.exports.addWatchDir = addWatchDir;
module.exports.removeWatchDir = removeWatchDir;
module.exports.scanAll = scanAll;
