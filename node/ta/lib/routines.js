var Scanner = require( '../lib/scan' );
var mq = require( '../lib/mq' );
var platform = require( '../lib/platform' );
var config = require ( '../lib/app-config' );
var settings = require( '../lib/storage' )( 'settings' );
var privates = require( '../lib/storage' )( 'private' );

function newUser() {
    var scanner = new Scanner();
    scanner.on( 'dir', function( dir ) {
	mq.send( 'scan:dir', { dir: dir } );
    });
    scanner.scanForDirs( platform.home() ).then(
	function( dirs ) {
	    mq.send( 'scan:dir:done', dirs );
	}
    );
}

function existingUser() {
}

module.exports.newUser = newUser;
module.exports.existingUser = existingUser;
