define(['durandal/app', 'knockout'], function( app, ko ) {
    var dirs = ko.observableArray([]);
    var dir_scan_done = ko.observable( false );
    app.on( 'mq:scan:dir', function( data ) {
	dirs.push( data.dir );
    });
    app.on( 'mq:scan:dir:done', function() {
	dir_scan_done( true );
    });
    return {
	dirs: dirs,
	dir_scan_done: dir_scan_done,
    };
});
