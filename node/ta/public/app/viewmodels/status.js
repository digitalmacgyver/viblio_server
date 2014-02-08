define([
        'durandal/app',
        'viewmodels/ta-header'],
function(app, taHeader) {
    return {
        taHeader: taHeader,
	logout: function() {
	    app.trigger( 'system:logout' );
	},
	close: function() {
	    window.close();
	}
    };
});