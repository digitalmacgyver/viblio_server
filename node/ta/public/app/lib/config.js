define( function() {
    var site = {
	'viblio.com': {
	    facebook: '613586332021367',
	},
	'staging.viblio.com': {
	    facebook: '153462094815829',
	},
	'192.168.1.35': {
	    facebook: '566096966734454',
	},
    };

    function service( host, svc ) {
	var the_host = host;
	if ( ! site[the_host] ) the_host = 'staging.viblio.com';
	var the_svc = svc;
	if ( ! site[the_host][the_svc] ) the_host = 'staging.viblio.com';
	return site[the_host][the_svc];
    }

    var myLocation = '//' + window.location.hostname;
    if ( window.location.port )
	myLocation += ':' + window.location.port;

    return {
	// Facebook params.
	facebook_appid: function() {
	    return service( window.location.hostname, 'facebook' );
	},
	facebook_channel: function() {
	    return myLocation + '/Content/channel.html';
	},
	facebook_ask_features: function() {
	    return 'email,user_photos,user_videos,read_friendlists,friends_photos,friends_videos';
	}
    };
});
