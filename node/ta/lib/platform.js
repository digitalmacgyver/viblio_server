var config = require( '../lib/app-config' );
var pj = require( '../package.json' );
var os = require( 'os' );
var fs = require( 'fs' );
var path = require( 'path' );
var mkdirp = require( 'mkdirp' );
var async = require( 'async' );
var Deferred = require( 'promised-io/promise').Deferred;

module.exports = {
    // User's HOME
    home: function() {
	return process.env.HOME || 
	    process.env.USERPROFILE ||
	    process.env.HOMEPATH;
    },
    // Where to store local-data
    appdata: function() {
	var dir;
	if ( os.platform() == 'linux' ) {
	    dir = path.join( module.exports.home(),
			     '.' + pj.name );
	}
	else if ( os.platform() == 'darwin' ) {
	    dir = path.join( module.exports.home(),
			     'Library', 'Preferences',
			     pj.name );
	}
	else {
	    dir = process.env.LOCALAPPDATA ||
		process.env.APPDATA;
	}
	if ( ! fs.existsSync( dir ) ) {
	    mkdirp.sync( dir );
	}
	return dir;
    },
    // TMPDIR
    tmpdir: function() {
	return os.tmpDir();
    },
    // A string representing this OS
    platform: function() {
	return [os.platform(), os.type(),
		os.arch(), os.release()].join(':');
    },
    // Default watch dirs
    defaultWatchDirs: function() {
	if ( os.platform() == 'linux' ) {
	    return [
		path.join( module.exports.home(), 'Documents' ),
		path.join( module.exports.home(), 'Downloads' ),
		path.join( module.exports.home(), 'Videos' ),
		path.join( module.exports.home(), 'Desktop' ),
		path.join( module.exports.home(), 'Pictures' ),
	    ];
	}
	else if ( os.platform() == 'darwin' ) {
	    return [
		path.join( module.exports.home(), 'Documents' ),
		path.join( module.exports.home(), 'Downloads' ),
		path.join( module.exports.home(), 'Movies' ),
		path.join( module.exports.home(), 'Desktop' ),
		path.join( module.exports.home(), 'Pictures' ),
	    ];
	}
	else {
	    return [
		path.join( module.exports.home(), 'Documents' ),
		path.join( module.exports.home(), 'Downloads' ),
		path.join( module.exports.home(), 'Videos' ),
		path.join( module.exports.home(), 'Desktop' ),
		path.join( module.exports.home(), 'Pictures' ),
	    ];
	}
    },
    dirskips: function() {
	if ( os.platform() == 'linux' ) {
	    return '\\\/\\\.';
	}
	else if ( os.platform() == 'darwin' ) {
	    return 'Library';
	}
	else {
	    return null;
	}
    },
    places: function() {
	var dfd = new Deferred();
	var home = module.exports.home();
	if ( os.platform() == 'linux' ) {
	    var possibles = [
		{ label: 'Home Folder', path: home  },
		{ label: 'Desktop', path: path.join( home, 'Desktop' ) },
		{ label: 'Documents', path: path.join( home, 'Documents' ) },
		{ label: 'Pictures', path: path.join( home, 'Pictures' ) },
		{ label: 'Videos', path: path.join( home, 'Videos' ) },
		{ label: 'Downloads', path: path.join( home, 'Downloads' ) },
		{ label: 'tmp', path: module.exports.tmpdir() },
		{ label: 'Computer', path: '/' }
	    ];
	    var result = [];
	    async.map( possibles,
		       function( p, cb ) {
			   fs.exists( p.path, function( exists ) {
			       if ( exists ) result.push( p );
			       cb();
			   });
		       },
		       function( err ) {
			   if ( err ) dfd.reject( err );
			   else dfd.resolve( result );
		       }
		     );
	}
	else if ( os.platform() == 'darwin' ) {
	    var possibles = [
		{ label: 'Home Folder', path: home  },
		{ label: 'Desktop', path: path.join( home, 'Desktop' ) },
		{ label: 'Documents', path: path.join( home, 'Documents' ) },
		{ label: 'Pictures', path: path.join( home, 'Pictures' ) },
		{ label: 'Videos', path: path.join( home, 'Videos' ) },
		{ label: 'Movies', path: path.join( home, 'Movies' ) },
		{ label: 'Downloads', path: path.join( home, 'Downloads' ) },
		{ label: 'tmp', path: module.exports.tmpdir() },
		{ label: 'Computer', path: '/' }
	    ];
	    var result = [];
	    async.map( possibles,
		       function( p, cb ) {
			   fs.exists( p.path, function( exists ) {
			       if ( exists ) result.push( p );
			       cb();
			   });
		       },
		       function( err ) {
			   if ( err ) dfd.reject( err );
			   else dfd.resolve( result );
		       }
		     );
	}
	else {
	    var possibles = [
		{ label: 'Home Folder', path: home  },
		{ label: 'Desktop', path: path.join( home, 'Desktop' ) },
		{ label: 'Documents', path: path.join( home, 'Documents' ) },
		{ label: 'Pictures', path: path.join( home, 'Pictures' ) },
		{ label: 'Videos', path: path.join( home, 'Videos' ) },
		{ label: 'Downloads', path: path.join( home, 'Downloads' ) },
		{ label: 'Computer', path: 'C:' + path.sep }
	    ];
	    var result = [];
	    async.map( possibles,
		       function( p, cb ) {
			   fs.exists( p.path, function( exists ) {
			       if ( exists ) result.push( p );
			       cb();
			   });
		       },
		       function( err ) {
			   if ( err ) dfd.reject( err );
			   else dfd.resolve( result );
		       }
		     );
	}
	return dfd.promise;
    }
};

