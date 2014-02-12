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
        
	logout: function() {
	    app.trigger( 'system:logout' );
	},
	close: function() {
	    window.close();
	}
    };
});
