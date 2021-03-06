define([
        'durandal/app',
        'lib/viblio',
        'knockout'],
function(app,viblio,ko) {
    var Folder = function( data, options ) {
        var self = this;
        
        self.label = ko.observable(data.label);
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
	    if ( data.topdir == self.path() ) {
		// its mine
		if ( self.files.indexOf( data.file ) == -1 )
		    // haven't already seen it
		    self.files.push( data.file );
	    }
	});

	self.sync = function() {
	    app.addFolder( self.path() );
	};

	self.remove = function() {
	    app.removeFolder( self );
	};
        
    };
    
    return Folder;
});