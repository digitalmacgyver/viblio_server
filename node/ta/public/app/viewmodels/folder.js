define([
        'durandal/app',
        'lib/viblio',
        'knockout'],
function(app,viblio,ko) {
    var Folder = function( data, options ) {
        var self = this;
        
        self.name = ko.observable(data.label);
        self.path = ko.observable( data.path );
	self.watched = ko.observable( false );
	self.files = ko.observableArray([]);

        self.selected = ko.observable( false );

        self.numVids = ko.computed( function() {
	    return self.files().length;
	});

        self.shouldSync = ko.computed(function(){
            if( self.selected() ) {
                return true;
            } else {
                return false;
            }
        });

	app.on( 'mq:file', function( data ) {
	    if ( data.topdir == self.name() ) {
		// its mine
		if ( self.files.indexOf( data.file ) != -1 )
		    // haven't already seen it
		    self.files.push( data.file );
	    }
	});
        
        self.navigate = function() {
            var args = {
                path: self.path()
            };
            console.log( typeof args.path );
            viblio.api( '/listing', args.path ).then( function( data ) {
                console.log(data);
            });
        };
        
    };
    
    return Folder;
});