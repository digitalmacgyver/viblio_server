var graph = require('fbgraph');
var util  = require( 'util' );

var access_token = "CAAIC3LicUnYBAJZAbxA3FWYldOX4byCDZCuNbWSmq1JqK1X7YWuoVFlI9SG16BRfuJuFB73llIBSRzXQTw9IhYK9Vk7x1ZCKtiOxkXZCdR3qOioqkFshrOAWVTrcXA9xYcdr1xMiLaADLut3pytl0anZCVXrQkzoZD";

graph.setAccessToken(access_token);

var user_params = {
    fields: 'id,name,first_name,picture.type(normal),albums.limit(10).fields(photos.limit(10).fields(id,tags,from,source),type),photos.limit(10).fields(tags,from,updated_time,source)'
};

var friends_params = {
    fields: 'id,name,friends.fields(id,name,first_name,picture.type(normal),albums.limit(10).fields(type,photos.limit(10).fields(id,tags,source,from)),photos.limit(10).fields(tags,source,from))'
};

graph.get( 'me', friends_params, function( err, res ) {
    if ( err ) 
	console.log( err );
    else
	console.log( util.inspect( res, false, 10, false ) );

    var total = 0;
    console.log( 'You have ' + res.friends.data.length + ' friends:' );
    for( var i=0; i<res.friends.data.length; i++ ) {
	console.log( res.friends.data[i].name );
	if ( res.friends.data[i].albums ) {
	    var ptotal = 0;
	    for( var j=0; j<res.friends.data[i].albums.data.length; j++ )
		ptotal += res.friends.data[i].albums.data[j].photos.data.length;
	    console.log( '  and they have ' + res.friends.data[i].albums.data.length + ' albums with a total of ' + ptotal + ' photos.' );
	    total += ptotal;
	}
	if ( res.friends.data[i].photos ) {
	    console.log( '  and they have ' + res.friends.data[i].photos.data.length + ' photos.' );
	    total += res.friends.data[i].photos.data.length;
	}
    }
    console.log( 'So we\'re talking about ' + total + ' photos for processing.' );
});
