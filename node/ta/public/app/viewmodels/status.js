define([
        'durandal/app',
        'viewmodels/ta-header',
        'knockout'],
function(app, taHeader, ko) {
    var dirs = ko.observableArray([{'name': 'Desktop'}, {'name': 'Shared'}, {'name': 'iPhoto'}, {'name': 'Movies'}]);
    
    dirs().forEach(function( d ){
        d.selected = ko.observable(false);
        console.log(d);
    });
    
    return {
        taHeader: taHeader,
        dirs: dirs,
        
	logout: function() {
	    app.trigger( 'system:logout' );
	},
	close: function() {
	    window.close();
	}
    };
});
