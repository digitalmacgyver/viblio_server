define(['plugins/router', 
	'durandal/app', 
	'durandal/system', 
	'viewmodels/folder',
	'lib/viblio', 
	'knockout'], 
function (router, app, system, Folder, viblio, ko) {

    router.on('router:navigation:complete').then(function(instance, instruction, router) {
        if (app.title) {
            document.title = instruction.config.title + " | " + app.title;
        } else {
            document.title = instruction.config.title;
        }
    });

    router.guardRoute = function( instance, instruction ) {
	if ( instruction.config.auth ) {
	    return system.defer( function( dfd ) {
		viblio.auth_ping().then(
		    function( data ) {
			if ( instruction.config.route != 'login' )
                            viblio.setLastAttempt( null );
                        viblio.setUser( data.user );
                        dfd.resolve({});
		    },
		    function( err ) {
			if ( instruction.config.route != 'login' )
                            viblio.setLastAttempt( instruction.config.route );
                        dfd.resolve('login');
		    }
		);
	    }).promise();
	}
	else {
	    if ( instruction.config.route != 'login' && instruction.config.route != 'signup' )
                viblio.setLastAttempt( null );
	    if ( instruction.config.route == '' && 
                 ( viblio.getUser() && viblio.getUser().uuid ) ) {
                return('status');
            }
	    return({});
	}
    };

    app.on( 'system:logout', function() {
	viblio.api( '/logout' ).always( function() {
	    viblio.setUser(null);
	    viblio.setLastAttempt( null );
	    router.navigate( 'login' );
	});
    });

    app.on( 'system:close', function() {
	viblio.setLastAttempt( null );
	window.close();
    });

    // ========================================================================
    // 
    // Here's what's going on.  We maintain an observable list of the user's
    // watchdirs hanging off of app.  Any view that displays watchdirs does
    // it will app.watchdirs().  These are Folder models.  These folder models
    // are watching for mq:file events which come from the server whenever
    // content is found or added to these watchdirs.  They will update their
    // state (and therefore the UI) when these events occur.  Since every view
    // is rendering app.watchdirs() array, every view gets automatically updated.
    //
    // We also add a couple of methods to app; app.addFolder( path ) and 
    // app.removeFolder( folder ), which view models should call to add or
    // remove watchdirs.  
    //
    app.watchdirs = ko.observableArray([]);
    app.watchHash = {};
    function getFolders() {
	viblio.api( '/all_dirs' ).then( function( data ) {
	    var dirs = data.watchdirs;
	    var watched = true;
	    if ( data.watchdirs.length == 0 ) {
		dirs = data.defaults;
		watched = false;
	    }
	    dirs.forEach( function( dir ) {
		var folder = new Folder( dir );
		folder.watched( watched );
		app.watchdirs.push( folder );
		app.watchHash[ dir.label ] = folder;
	    });
	});
    }
    app.on( 'mq:subscribed', function() {
	viblio.api( '/scan' );
    });
    function _basename( path ) { return path.replace(/.*\//, "").replace( /.*\\/, "" ); }
    function _dirname( path ) { 
	var isWin = path.indexOf('\\');
	var bn = _basename( path );
	var regexp = new RegExp( bn+'$' );
	var dn = path.replace( regexp, '' ).replace(/\/$/, '').replace(/\\$/,'');
	if ( dn == "" ) {
	    if ( isWin == -1 ) {
		return "/";
	    }
	    else {
		return "\\";
	    }
	}
	else {
	    return dn;
	}
    }
    app.addFolder = function( i_dirname, err_callback ) {
	var label = _basename( i_dirname );
	var path  = _dirname(  i_dirname );

	if ( app.watchHash[label] ) {
	    // Probably turning a default watch into a real watch
	    app.watchHash[label].watched( true );
	    viblio.api( '/add_watchdir', { dir: i_dirname } );
	}
	else {
	    var folder = new Folder({ label: label, path: i_dirname });
	    folder.watched( true );
	    app.watchdirs.push( folder );
	    app.watchHash[ label ] = folder;
	    viblio.api( '/add_watchdir', { dir: i_dirname } ).then( 
		function( data ) {
		    // success
		},
		function( data ) {
		    if ( data.error ) {
			if ( err_callback )
			    err_callback( data.message );
			delete app.watchHash[ folder.name() ];
			setTimeout( function() {
			    app.watchdirs.remove( folder );
			},0 );
		    }
		}
	    );
	}
    };
    app.removeFolder = function( folder ) {
	app.watchdirs.remove( folder );
	delete app.watchHash[ folder.name() ];
	viblio.api( '/remove_watchdir', { dir: folder.path() } );
    };
    //
    // ========================================================================

    return {
        router: router,
        activate: function () {
            router.map([
                { auth: true,  route: '', title:'Status', moduleId: 'viewmodels/status', nav: false },
                { auth: true,  route: 'status',   title:'Status', moduleId: 'viewmodels/status', nav: false },
                { auth: true,  route: 'walkthru', title:'Walkthru', moduleId: 'viewmodels/walkthru', nav: false },
                { auth: false, route: 'login',  moduleId: 'viewmodels/login',  nav: false },
                { auth: false, route: 'signup', moduleId: 'viewmodels/signup', nav: false },
            ]).buildNavigationModel();
            
	    getFolders();

            return router.activate();
        }
    };
});