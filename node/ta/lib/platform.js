var config = require( '../lib/app-config' );
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
			     '.' + config.name );
	}
	else if ( os.platform() == 'darwin' ) {
	    dir = path.join( module.exports.home(),
			     'Library', 'Preferences',
			     config.name );
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
    }
};

