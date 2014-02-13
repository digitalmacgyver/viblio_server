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
    
    getStats = function() {
        viblio.api( '/stats' ).then( function( data ) {
            console.log( data );
        });
    };
    
    return {
        taHeader: taHeader,
        folders: app.watchdirs,
        
	scan: function() {
	    app.showMessage( 'Whamo' );
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
