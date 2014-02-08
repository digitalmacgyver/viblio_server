define([
        'durandal/app',
        'lib/viblio',
        'knockout'],
function(app,viblio,ko) {
    var Folder = function( data, options ) {
        var self = this;
        
        self.name = ko.observable(data.label);
        self.path = ko.observable( data.path );
        self.selected = ko.observable( false );
        self.numVids = ko.observable( 50 );
        self.shouldSync = ko.computed(function(){
            if( self.selected() ) {
                return true;
            } else {
                return false;
            }
        });
        
        self.navigate = function() {
            var args = {
                dir: self.path()
            };
            console.log( typeof args.path );
            viblio.api( '/listing', args ).then( function( data ) {
                console.log(data);
            });
        };
        
    };
    
    return Folder;
});