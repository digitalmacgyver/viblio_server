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
        folders: folders,
        
        activate: function() {
            viblio.api( '/places').then( function( data ) {
                console.log( data );
            });
            viblio.api( '/default_watchdirs').then( function( dirs ) {
                console.log( dirs );
                
                dirs.forEach(function( dir ){
                    var f = new Folder( dir );
                    folders.push( f );
                });
            });
        },
        
        compositionComplete: function() {
            $("#columns").hColumns({
                nodeSource: function(node_id, callback) {
                }
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
