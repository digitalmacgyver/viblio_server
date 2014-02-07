define(['durandal/app', 'lib/viblio', 'knockout'], function( app, viblio, ko ) {
    var view;

    var dirs = ko.observableArray([]);
    var dir_scan_done = ko.observable( true );

    var found = {};

    var watchdirs = ko.observableArray([]);
    var otherdirs = ko.observableArray([]);
    var alldirs   = ko.observableArray([]);
    var suggesteddirs = ko.observableArray([]);

    var places = ko.observableArray([]);

    return {
	dirs: dirs,
	dir_scan_done: dir_scan_done,

	watchdirs: watchdirs,
	otherdirs: otherdirs,
	alldirs: alldirs,
	suggesteddirs: suggesteddirs,
	places: places,

	activate: function() {
	    dirs.removeAll();
	    found = {};
	    app.on( 'mq:scan:dir', function( data ) {
		dirs.push( data.path );
		found[ data.path ] = data.label;
	    });
	    app.on( 'mq:scan:dir:start', function() {
		dir_scan_done( false );
	    });
	    app.on( 'mq:scan:dir:done', function() {
		dir_scan_done( true );
		viblio.api( '/default_watchdirs' ).then( function( dirs ) {
		    dirs.forEach( function( dir ) {
			watchdirs.push({ label: dir.label, path: dir.path, found: (found[dir.path]?true:false) });
			if ( found[dir.path] )
			    alldirs.push({ label: dir.label, path: dir.path, found: true });
			else 
			    suggesteddirs.push({ label: dir.label, path: dir.path, found: false });
			delete found[ dir.path ];
		    });
		    for( var key in found ) {
			alldirs.push({ label: found[key], path: key, found: true });
			otherdirs.push({ label: found[key], path: key, found: true });
		    }
		});
		viblio.api( '/places' ).then( function( dirs ) {
		    dirs.forEach( function( dir ) {
			places.push({ label: dir.label, path: dir.path, found: false });
		    });
		});
	    });
	},

	compositionComplete: function( _view ) {
	    view = _view;
	}

    };
});
