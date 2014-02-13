define([
        'durandal/app',
        'lib/viblio',
        'knockout',
        'viewmodels/ta-header',
        'viewmodels/folder'],
function(app,viblio,ko,taHeader,Folder) {
    var folders = ko.observableArray();
    
    return {
        taHeader: taHeader,
        folders: app.watchdirs,
        
        compositionComplete: function() {
	    /**
            $("#columns").hColumns({
                nodeSource: function(node_id, callback) {
                }
            });
	    **/
        },

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
