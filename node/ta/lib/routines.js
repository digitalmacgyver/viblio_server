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
var chokidar = require( "chokidar" );

var watcher;

function newUser() {
    var scanner = new Scanner( null, platform.dirskips() );
    scanner.on( 'dir', function( dir ) {
	mq.send( 'scan:dir', { label: path.basename( dir ), path: dir } );
    });

    mq.send( 'scan:dir:start' );
    async.map( platform.defaultWatchDirs(), 
	       function( dir, cb ) {
		   scanner.scanForDirs( dir ).then(
		       function( dirs ) {
			   cb( null, dirs );
		       }
		   );
	       },
	       function( err, results ) {
		   mq.send( 'scan:dir:done', results );
	       }
	     );
}

function existingUser() {
    // Restore the queue from storage ...
    queuer.restore();
    addWatchDirs();
}

var watchTimers = {};
function addWatchDir( dir ) {
    var scanner = new Scanner( null, platform.dirskips() );
    var types = '(\.|\/)' + config.file_types + '$';
    var regexp = new RegExp( types, 'i' );

    if ( ! watcher ) { 
	watcher = chokidar.watch( dir, { ignored: /[\/\\]\./, persistent: true } );
	watcher.on( 'add', function( filename, stat ) {
	    if ( !stat.isDirectory() && filename.match( regexp ) ) {
		watchTimers[filename] = setTimeout( function() {
		    delete watchTimers[filename];
		    queuer.add( filename );
		}, 5000 );
	    }
	});
	watcher.on( 'change', function( filename, stat ) {
	    if ( !stat.isDirectory() && filename.match( regexp ) ) {
		if ( watchTimers[filename] ) clearTimeout( watchTimers[filename] );
		watchTimers[filename] = setTimeout( function() {
		    delete watchTimers[filename];
		    queuer.add( filename );
		}, 5000 );
	    }
	});
    }
    else {
	watcher.add( dir );
    }
}

function addWatchDirs() {
    // Get the watchdirs ... send all the files in each
    // to the queue (which will just drop those that have
    // already uploaded), then establish the watches
    settings.getArray( 'watchdir' ).then( function( dirs ) {
	dirs.forEach( function( dir ) {
	    addWatchDir( dir );
	});
    });
}

function resetWatchDirs() {
    if ( watcher ) watcher.close();
    watcher = null;
    addWatchDirs();
}

module.exports.newUser = newUser;
module.exports.existingUser = existingUser;
module.exports.addWatchDirs = addWatchDirs;
module.exports.addWatchDir = addWatchDir;
module.exports.resetWatchDirs = resetWatchDirs;
