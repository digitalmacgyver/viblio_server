define(['durandal/app', 'lib/viblio', 'knockout', 'viewmodels/ta-header', 'viewmodels/folder', 'plugins/router', 'plugins/dialog'], function( app, viblio, ko, taHeader, Folder, router, dialog ) {

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
                                    console.log( id );
                                    viblio.api( '/add_watchdir', { dir: id } ).then( function( data ) {
                                        console.log(data);
                                    });
                                },
                        'Quickview': function(id) { alert('Quickview on node or leaf ' + id); }
                    }
                },
                'pane': {
                    'options': {
                        'Add':  function( id ) {
                                    console.log( id );
                                    viblio.api( '/add_watchdir', { dir: id } ).then( function( data ) {
                                        console.log(data);
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
