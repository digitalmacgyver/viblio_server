var config = require( '../lib/app-config' );
var pj = require( '../package.json' );
var os = require( 'os' );
var fs = require( 'fs' );
var path = require( 'path' );
var mkdirp = require( 'mkdirp' );

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
		path.join( module.exports.home(), 'Videos' )
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
		path.join( module.exports.home(), 'Videos' )
	    ];
	}
    },
    dirskips: function() {
	if ( os.platform() == 'linux' ) {
	    return null;
	}
	else if ( os.platform() == 'darwin' ) {
	    return 'Library';
	}
	else {
	    return null;
	}
    }
};

