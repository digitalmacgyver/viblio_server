define(['durandal/app'], function(app) {
    return {
	logout: function() {
	    app.trigger( 'system:logout' );
	}
    };
});
