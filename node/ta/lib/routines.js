var Scanner = require( '../lib/scan' );
var mq = require( '../lib/mq' );
var platform = require( '../lib/platform' );
var config = require ( '../lib/app-config' );
var settings = require( '../lib/storage' )( 'settings' );
var privates = require( '../lib/storage' )( 'private' );
var async = require( 'async' );

function newUser() {
    var scanner = new Scanner( null, platform.dirskips() );
    scanner.on( 'dir', function( dir ) {
	mq.send( 'scan:dir', { dir: dir } );
    });

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
}

module.exports.newUser = newUser;
module.exports.existingUser = existingUser;
