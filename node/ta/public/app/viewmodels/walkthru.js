define(['durandal/app', 'lib/viblio', 'knockout', 'viewmodels/ta-header', 'viewmodels/folder', 'plugins/router'], function( app, viblio, ko, taHeader, Folder, router ) {
    var view;

    var dirs = ko.observableArray([]);
    var dir_scan_done = ko.observable( true );

    var found = {};

    var watchdirs = ko.observableArray([]);
    var otherdirs = ko.observableArray([]);
    var alldirs   = ko.observableArray([]);
    var suggesteddirs = ko.observableArray([]);

    var places = ko.observableArray([]);
    var volumes = ko.observableArray([]);
    
    confirm = function() {
        alldirs().forEach( function( dir ) {
            console.log( dir );
            if( dir.shouldSync() ) {
                var args = {
                    dir: dir.path()
                };
                console.log('this dir was selected: ' + dir.label() );
                console.log( args );
                viblio.api( '/add_watchdir', args ).then( function( data ) {
                    console.log('Dir added');
                    console.log(data);
                });
            }
        });
        //router.navigate('#status');
    };
    
    return {
        taHeader: taHeader,
	dirs: dirs,
	dir_scan_done: dir_scan_done,

	watchdirs: watchdirs,
	otherdirs: otherdirs,
	alldirs: alldirs,
	suggesteddirs: suggesteddirs,
	places: places,
	volumes: volumes,
        
	activate: function() {
	    dirs.removeAll();
	    found = {};
	    app.on( 'mq:scan:file', function( data ) {
		dirs.push( data.file );
		if ( ! found[ data.topdir ] )
		    found[ data.topdir ] = 1;
		else
		    found[ data.topdir ] += 1;
	    });
	    app.on( 'mq:scan:files:start', function() {
		dir_scan_done( false );
	    });
	    app.on( 'mq:scan:files:done', function() {
		dir_scan_done( true );
		viblio.api( '/default_watchdirs' ).then( function( dirs ) {
		    dirs.forEach( function( dir ) {
                        
                        var f = new Folder( { label: dir.label, path: dir.path, found: found[dir.path] } );
                        watchdirs.push( f );
                        
			//watchdirs.push({ label: dir.label, path: dir.path, found: found[dir.path] });
			if ( found[dir.path] )
                            alldirs.push( f );
			    //alldirs.push({ label: dir.label, path: dir.path, found: found[dir.path] });
			else
                            suggesteddirs.push( f );
			    //suggesteddirs.push({ label: dir.label, path: dir.path, found: 0 });
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
		viblio.api( '/volumes' ).then( function( dirs ) {
		    dirs.forEach( function( dir ) {
			volumes.push({ label: dir.label, path: dir.path, found: false });
		    });
		});
	    });
	},

	compositionComplete: function( _view ) {
	    view = _view;
	    $(view).find('.miller-demo').miller({
		url: function( id ) {
		    if ( id ) 
			return '/miller?id=' + encodeURIComponent( id );
		    else 
			return '/miller';
		},
		'toolbar': {
		    'options': {
			'Select': function(id) { alert('Select node or leaf ' + id); },
			'Quickview': function(id) { alert('Quickview on node or leaf ' + id); }
		    }
		},
		'pane': {
		    'options': {
			'Add': function(id) { alert('Add to leaf ' + id); },
			'Update': function(id) { alert('Update leaf ' + id); },
			'Delete': function(id) { alert('Delete leaf ' + id); }
		    }
		}
	    });
	}

    };
});
