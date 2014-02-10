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
		path.join( module.exports.home(), 'SkyDrive' ),
	    ];
	}
    },
    dirskips: function() {
	if ( os.platform() == 'linux' ) {
	    return '\\\/\\\.';
	}
	else if ( os.platform() == 'darwin' ) {
	    return '(Library|Macintosh HD|\\\/\\\.)';
	}
	else {
	    return null;
	}
    },
    skipdirs: function() {
	if ( os.platform() == 'linux' ) {
	    return [
		'/bin',
		'/etc',
		'/usr',
		'/sbin',
		'/var',
		'/dev',
		'/proc',
		'/sys',
		'/lib',
		'/boot',
		'/run',
		'/selinux',
		'/lost+found',
		'/cdrom',
		'/root',
	    ];
	}
	else if ( os.platform() == 'darwin' ) {
	    return [
		'/Applications',
		'/Developer',
		'/Library',
		'/Network',
		'/System',
		'/bin',
		'/etc',
		'/usr',
		'/sbin',
		'/var',
		'/dev',
		'/proc',
		'/sys',
		'/lib',
		'/boot',
		'/run',
		'/private',
		'/cores',
		'/net',
	    ];
	}
	else {
	    return [
		process.env['windir'],
		process.env['ProgramData'],
		process.env['ProgramFiles'],
		process.env['ProgramFiles(x86)'],
		process.env['SystemRoot'],
	    ];
	}
    },
    is_dir_ok: function( dir ) {
	for( var i=0; i<module.exports.skipdirs().length; i++ )
	    if ( dir.indexOf( module.exports.skipdirs()[i] ) == 0 ) return false;
	var home = path.dirname( module.exports.home() );
	if ( dir != home &&
	     dir.indexOf( home ) == 0 &&
	     dir.indexOf( module.exports.home() ) == -1 ) return false;
	return true;
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
		{ label: 'SkyDrive', path: path.join( home, 'SkyDrive' ) },
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
    },
    volumes: function() {
	var dfd = new Deferred();
	if ( os.platform() == 'linux' ) {
	    async.map( ['/mnt', '/media'],
		       function( root, cb ) {
			   fs.readdir( root, function( err, files ) {
			       if ( err ) {
				   cb( err );
			       }
			       else {
				   var result = [];
				   files.forEach( function( file ) {
				       result.push({ label: file, path: path.join(root,file) });
				   });
				   cb( null, result );
			       }
			   });
		       },
		       function( err, results ) {
			   if ( err ) {
			       dfd.reject( err );
			   }
			   else {
			       var result = results[0];
			       dfd.resolve( result.concat( results[1] ) );
			   }
		       }
		     );
	}
	else if ( os.platform() == 'darwin' ) {
	    fs.readdir( '/Volumes', function( err, files ) {
		if ( err ) return dfd.reject( err );
		var result = [];
		files.forEach( function( file ) {
		    if ( ! ( file.match( /^\./ ) ||
			     file.match( /^Macintosh HD/ ) ) ) {
			result.push({ label: file, path: '/Volumes/'+file });
		    }
		});
		dfd.resolve( result );
	    });
	}
	else {
	    var parts = [];
	    var spawn = require('child_process').spawn,
	    list  = spawn('cmd');

	    list.stdout.on('data', function (data) {
		data = data.toString('utf8');
		if ( data.match(/^Name/) ) return;
		data = data.replace(/[\n\r]/g,'');
		data = data.replace(/\s+$/, '');
		if ( data.match(/^$/) ) return;
		parts.push(data);
	    });

	    list.on('exit', function (code) {
		if ( parts.length >= 3 ) {
		    parts.shift(); // remove initial command prompt
		    parts.pop(); // remove final command prompt
		    var result = [];
		    parts.forEach( function( part ) {
			result.push({ label: part, path: part+path.sep });
		    });
		    dfd.resolve( result );
		}
		else {
		    dfd.reject( new Error( 'Could not find volumes' ) );
		}
	    });

	    list.stdin.write('wmic logicaldisk get name\n');
	    list.stdin.end();
	}
	return dfd.promise;
    }
};

