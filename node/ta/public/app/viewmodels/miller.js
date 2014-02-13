define(['durandal/app', 
	'lib/viblio', 
	'knockout', 
	'viewmodels/ta-header', 
	'viewmodels/folder', 
	'plugins/router', 
	'plugins/dialog'], 
function( app, viblio, ko, taHeader, Folder, router, dialog ) {

    return {
        
        closeModal: function() {
            dialog.close(this);
        },
        
        compositionComplete: function( _view ) {
            var view = _view;
            $(view).find('.miller-test').miller({
                url: function( id ) {
                    if ( id ) 
                        return '/miller?id=' + encodeURIComponent( id );
                    else 
                        return '/miller';
                },
                'toolbar': {
                    'options': {
                        'Select': function( id ) {
			    app.addFolder( id, function( err ) {
                                console.log(err);
                            });
                        },
                        'Quickview': function(id) { alert('Quickview on node or leaf ' + id); }
                    }
                },
                'pane': {
                    'options': {
                        'Add':  function( id ) {
			    app.addFolder( id, function( err ) {
                                console.log(err);
                            });
                        },
                        'Update': function(id) { alert('Update leaf ' + id); },
                        'Delete': function(id) { alert('Delete leaf ' + id); }
                    }
                }
            });
        }
    };
    
});
