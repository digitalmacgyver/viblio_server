define([
        'durandal/app',
        'lib/viblio',
        'knockout',
        'viewmodels/ta-header',
        'viewmodels/folder',
        'viewmodels/miller'],
function(app,viblio,ko,taHeader,Folder,miller) {
    var folders = ko.observableArray();
    
    showMiller = function() {
        app.showDialog(miller);
    };
    
    return {
        taHeader: taHeader,
        folders: folders,
        
        activate: function() {
            viblio.api( '/places').then( function( data ) {
                console.log( data );
            });
            viblio.api( '/watchdirs').then( function( dirs ) {
                console.log( dirs );
                
                dirs.forEach(function( dir ){
                    var f = new Folder( dir );
                    folders.push( f );
                });
            });
            viblio.api( '/stats' ).then( function( data ) {
                console.log( data );
            });
        },
        
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
