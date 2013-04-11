redis = require("redis")
client = redis.createClient( 6379, "10.100.10.26" )
util = require( "util" )
p = console.log
client.on("error", function (err) {
    console.log("Error " + err);
});
cb = function( e, r ) {
    if ( e ) p("error: " + util.inspect( e ));
    else p("result: " + util.inspect(r));
};

msg1 = { wo: 3, name: "foobar" }
msg2 = { wo: 4, name: "barp" }

client.rpush(1, JSON.stringify(msg1), cb )
client.rpush(1, JSON.stringify(msg2), cb )
client.lrange(1,0,-1, function( err, range ) {
    for( var i=0; i<range.length; i++ ) {
	var o = JSON.parse( range[i] );
	p( util.inspect( o ) );
    }
})

client.llen( 1, function( err, count ) {
    p( "count is " + count );
})

client.del(1)

client.llen( 1, function( err, count ) {
    p( "count is " + count );
})
