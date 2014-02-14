define([
        'durandal/app',
        'lib/viblio',
        'knockout',
        'viewmodels/ta-header',
        'viewmodels/folder',
        'viewmodels/miller'],
function(app,viblio,ko,taHeader,Folder,miller) {
    var folders = ko.observableArray();
    var testDir = ko.observable();
    
    showMiller = function() {
        app.showDialog(miller);
    };
    
    return {
        taHeader: taHeader,
        folders: app.watchdirs,
        newuser: app.newUser,

	scan: function() {
	    viblio.api( '/scan' );
	},

	testfail: function() {
	    app.addFolder( '/home/ubuntu/TestVids/More', function( err ) {
		app.showMessage( err, 'Add Folder' );
	    });
	},
        
	testadd: function() {
	    app.addFolder( '/home/ubuntu/TestVids', function( err ) {
		app.showMessage( err, 'Add Folder' );
	    });
	},
        
	logout: function() {
	    app.trigger( 'system:logout' );
	},
	close: function() {
	    window.close();
	}
    };
});
