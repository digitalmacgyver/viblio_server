var express = require( 'express' );
var http = require( 'http' );
var path = require( 'path' );
var async = require( 'async' );
var platform = require( './lib/platform' );
var viblio = require( './lib/viblio' );
var privates = require( './lib/storage' )( 'private' );
var settings = require( './lib/storage' )( 'settings' );
var mq = require( './lib/mq' );
var routines = require( './lib/routines' );
var queuer = require( './lib/queuer' );
var fs = require( 'fs' );
var Scanner = require( './lib/scan' );
var pj = require( './package.json' );

// config
var config = require( './lib/app-config' );

// For testing, can override server endpoints on the
// command line.  Be sure to use https:// when connecting
// to a local server.
if ( process.argv[2] ) {
    config.viblio_server_endpoint = process.argv[2];
    config.viblio_upload_endpoint = process.argv[2] + '/files';
}

// Logging
var expressWinston = require('express-winston');
var winston = require( "winston" );

var app = express();
mq.init();

var logfile = path.join( platform.tmpdir(), pj.name + '.log' );

var log = new (winston.Logger)({
    transports: [
        new (winston.transports.Console)({ 
	    colorize: true, 
	    level: ((config.debug && 'debug')||'info') 
	}),
        new (winston.transports.File)({ 
	    json: false, 
	    level: ((config.debug && 'debug')||'info'), 
	    filename: logfile
	})
    ],
    exceptionHandlers: [
        new (winston.transports.Console)({ 
	    colorize: true, 
	    level: ((config.debug && 'debug')||'info') 
	}),
        new (winston.transports.File)({ 
	    json: false, 
	    level: ((config.debug && 'debug')||'info'), 
	    filename: logfile
	})
    ],
    exitOnError: false        // and don't exit when they occur
});

function logdump( o ) {
    log.debug( JSON.stringify( o, null, 2 ) );
}

queuer.setLogger( log );

app.configure(function() {
    app.set('port', config.port || process.env.PORT || 3000);
    app.engine('html', require('ejs').renderFile);
    app.set('view engine', 'html');

    app.use(express.favicon(__dirname + '/public/favicon.ico', 
			    { maxAge: 2592000000 }));

    if ( config.trace_server ) {
        app.use(expressWinston.logger({
            transports: [
                new winston.transports.Console({
                    json: false,
                    colorize: true
                }),
                new winston.transports.File({ 
                    filename: logfile,
                    json: false 
                })
            ]
        }));
    }

    app.use(express.bodyParser());

    // The express jsonp() call only looks at query[], not
    // at body[] for the callback name!  So posts that expect
    // jsonp don't work correctly!
    app.use( function( req, res, next ) {
        if ( req.method.toLowerCase() == 'post' ) {
            if ( req.body['callback'] ) {
                req.query['callback'] =
                    req.body['callback'];
            }
        }
        next();
    });

    app.use(app.router);

    app.use(express.static(__dirname + '/public'));

    if ( config.trace_http ) {
        app.use( function( req, res, next ) {
            log.debug( req.url );
            log.debug( 'HEADERS:' ); logdump( req.headers );
            log.debug( 'BODY:' );
            req.on( 'data', function( chunk ) {
                log.debug( '> ' + chunk );
            });
            next();
        });
    }
    
    app.use( function( req, res, next ) {
	if ( ! res.stash ) return next();
	var accept = req.headers.accept || '';
	if (~accept.indexOf('json')) {
            res.json(res.stash);
	}
	else if ( req.param('callback') ) {
            res.jsonp(res.stash);
	}
	else {
	    res.json( res.stash );
	}
    });

    // Page not found errors
    app.use(function(req, res, next) {
        log.error( "page not found: %s", req.url );
        res.send( 'Page not found', 404 );
    });

    // Server errors
    app.use(function(err, req, res, next) {
        log.error( "unhandled server error: status: %d: ",
                   err.status || 500, err.message );
        res.send( err.message, err.status || 500 );
    });
});

app.get( '/', function( req, res, next ) {
    res.render( 'index', {} );
});

app.post( '/ping', function( req, res, next ) {
    res.stash = {};
    next();
});

app.post( '/authping', function( req, res, next ) {
    viblio.api( '/services/user/me' ).then(
	function( data ) {
	    privates.get( 'version' ).then( function( version ) {
		if ( ! version ) {
		    version = '0.0.1';
		    privates.set( 'version', version );
		}
		data.version = version;
		res.stash = data; next();
	    });
	},
	function( err ) {
	    res.stash = err; next();
	}
    );
});

// Called from the web-app
app.post( '/authenticate', function( req, res, next ) {
    viblio.api( '/services/na/authenticate', req.body ).then(
	function( data ) {
	    if ( data && data.user ) {
		// New user detection...
		privates.get( 'newuser' ).then( function( val ) {
		    if ( val == null )
			data.user['newuser'] = 'true';
		    else
			data.user['newuser'] = val;
		    // Give it a second, then set the uuid.  This will kick off
		    // a new user routine, which will send messages to the gui.
		    setTimeout( function() {
			privates.set( 'uuid', data.user.uuid );
			privates.set( 'displayname', data.user.displayname );
		    }, 1000 );
		    privates.get( 'version' ).then( function( version ) {
			if ( ! version ) {
			    version = '0.0.1';
			    privates.set( 'version', version );
			}
			data.version = version;
			res.stash = data; next();
		    });
		});
	    }
	    else {
		res.stash = data; next();
	    }
	},
	function( err ) {
	    res.stash = err; next();
	}
    );
});

app.post( '/logout', function( req, res, next ) {
    viblio.api( '/services/na/logout' ).then( 
	function( data ) {
	    res.stash = data; next();
	},
	function( err ) {
	    res.stash = err; next();
	}
    );
});

app.post( '/stats', function( req, res, next ) {
    queuer.stats().then( function( stats ) {
	res.stash = stats; next();
    });
});

app.post( '/add_watchdir', function( req, res, next ) {
    var dir = req.param( 'dir' );
    fs.exists( dir, function( exists ) {
	if ( ! exists ) {
	    res.stash = { error: 1, message: 'Folder ' + dir + ' not found' };
	    next();
	}
	else {
	    routines.addWatchDir( dir ).then(
		function() {
		    res.stash = {}; next();
		},
		function(err) {
		    res.stash = {error:1, message: err.message}; next();
		}
	    );
	}
    });
});

app.post( '/remove_watchdir', function( req, res, next ) {
    var dir = req.param( 'dir' );
    routines.removeWatchDir( dir );
    res.stash = {}; next();
});

app.post( '/watchdirs', function( req, res, next ) {
    settings.getArray( 'watchdir' ).then( function( values ) {
	res.stash = values; next();
    });
});

app.post( '/default_watchdirs', function( req, res, next ) {
    var dirs = platform.defaultWatchDirs();
    var ret = [];
    dirs.forEach( function( dir ) {
	ret.push({ label: path.basename( dir ), path: dir });
    });
    res.stash = ret; next();
});

app.post( '/all_dirs', function( req, res, next ) {
    async.parallel({
	watchdirs: function( cb ) {
	    settings.getArray( 'watchdir' ).then( function( dirs ) {
		var ret = [];
		dirs.forEach( function( dir ) {
		    ret.push({ label: path.basename( dir ), path: dir });
		});
		cb( null, ret );
	    });
	},
	defaults: function( cb ) {
	    var dirs = platform.defaultWatchDirs();
	    var ret = [];
	    dirs.forEach( function( dir ) {
		ret.push({ label: path.basename( dir ), path: dir });
	    });
	    cb( null, ret );
	}
    }, function( err, results ) {
	res.stash = results; next();
    });
});

app.post( '/places', function( req, res, next ) {
    platform.places().then( function( dirs ) {
	res.stash = dirs; next();
    });
});

app.post( '/volumes', function( req, res, next ) {
    platform.volumes().then( function( dirs ) {
	res.stash = dirs; next();
    }, function( err ) {
	res.stash = { error: 1, message: err.message }; next();
    });
});

app.post( '/listing', function( req, res, next ) {
    var scanner = new Scanner();
    scanner.listing( req.param( 'dir' ) ).then( function( result ) {
	res.stash = result; next();
    });
});

app.post( '/scan', function( req, res, next ) {
    routines.scanAll();
    res.stash = {}; next();
});

app.get( '/miller', function( req, res, next ) {
    var scanner = new Scanner();
    var id = req.param( 'id' );

    if ( ! id ) {
	async.series([
	    function( cb ) {
		platform.places().then( function( dirs ) {
		    var ret = [{ category: 'Places' }];
		    dirs.forEach( function( dir ) {
			ret.push({ id: dir.path,
				   name: dir.label,
				   parent: true });
		    });
		    cb( null, ret );
		});
	    },
	    function( cb ) {
		platform.volumes().then( function( dirs ) {
		    var ret = [{ category: 'Volumes' }];
		    dirs.forEach( function( dir ) {
			ret.push({ id: dir.path,
				   name: dir.label,
				   parent: true });
		    });
		    cb( null, ret );
		});
	    }
	], function( err, results ) {
	    if ( err ) {
		res.json( err );
	    }
	    else {
		var ret = results[0];
		res.json( ret.concat( results[1] ) );
	    }
	});
    }
    else {
	async.series([
	    function( cb ) {
		fs.stat( id, function( err, stat ) {
		    if ( err ) cb( err );
		    else {
			if ( ! stat.isDirectory() )
			    cb( {} );
			else 
			    cb();
		    }
		});
	    },
	    function( cb ) {
		scanner.listing( id ).then( function( result ) {
		    var ret = [];
		    result.forEach( function( s ) {
			ret.push({ id: s.path,
				   name: s.file,
				   parent: s.isdir });
		    });
		    ret.sort( function( a, b ) {
			return ((a.name < b.name) ? -1 : ((a.name > b.name) ? 1 : 0));
		    });
		    cb( null, ret );
		});
	    },
	], function( err, results ) {
	    if ( err ) res.json( err );
	    else res.json( results[1] );
	});
    }
});

app.post( '/pause', function( req, res, next ) {
    var fid = req.param( 'fid' );
    log.debug( 'pausing: ', fid );
    if ( fid ) {
	queuer.pause( fid ).then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
    }
    else {
	queuer.pauseAll().then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
    }
});

app.post( '/resume', function( req, res, next ) {
    var fid = req.param( 'fid' );
    log.debug( 'resuming: ', fid );
    if ( fid ) {
	queuer.resume( fid ).then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
    }
    else {
	queuer.resumeAll().then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
    }
});

app.post( '/cancel', function( req, res, next ) {
    var fid = req.param( 'fid' );
    if ( fid ) {
	queuer.cancel( fid ).then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
    }
    else {
	queuer.cancelAll();
	res.stash = {}; next();
/*
	queuer.cancelAll().then(
	    function() {
		res.stash = {}; next();
	    },
	    function(err) {
		res.stash = { error: 1, message: err.message };
		next();
	    }
	);
*/
    }
});

var server = http.createServer(app);
server.listen(app.get('port'), function(){
    viblio.authenticate( false ).then(
	function() {
	    log.debug( 'Ready to Start!' );
	    privates.get( 'newuser' ).then( function( v ) {
		if ( v == null || v == 'true' ) {
		    privates.set( 'newuser', 'false' );
		    // NEW USER ROUTINE
		    routines.newUser();
		}
		else {
		    // EXISTING USER ROUTINE
		    routines.existingUser();
		}
	    });
	    // Kick off the auth keepalive and sw upgrade timers
	    viblio.fireTimers();
	},
	function( err ) {
	    log.error( 'Could not open the local browser: platform: %s, code: %s, detail: %s',
		       platform.platform(), err.code, err.message );
	}
    );
});
mq.attach( server );
