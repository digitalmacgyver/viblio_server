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
    function basename( path ) { return path.replace( /.*\//, "" ).replace( /.*\\/, "" ); }
    function dirname( path ) { return path.match( /.*\// ); }
    app.addFolder = function( _dirname ) {
	var label = basename( _dirname );
	var path  = dirname(  _dirname );
	var folder = new Folder({ label: label, path: path });
	app.watchdirs.push( folder );
	app.watchHash[ label ] = folder;
	viblio.api( '/add_watchdir', { dir: dirname } );
    };
    app.removeFolder = function( folder ) {
	app.watchdirs.remove( folder );
	delete app.watchHash[ folder.name() ];
	viblio.api( '/remove_watchdir', { dir: folder.path() } );
    };

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