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
    
    getWatchdirs = function() {
        console.log( testDir() );
        viblio.api( '/watchdirs', testDir() ).then( function( data ) {
            console.log( data );
        });
    };
    
    getDefaultWatchdirs = function() {
        viblio.api( '/default_watchdirs' ).then( function( data ) {
            console.log( data );
            testDir( data[0] );
        });
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
