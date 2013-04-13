var express = require( 'express' );
var path = require( "path" );
var http = require( 'http' );
var faye = require('faye');

// Logging
var log = require( "winston" );
log.add( log.transports.File, { filename: '/tmp/mq.log', json: false } );

// in memory queue
var Queue = require( "./queue" );

// config
var kphyg = require( "konphyg" )( __dirname );
var config = kphyg( 'mq' );

// Queue of incoming user messages
var mQueue = new Queue();

var app = express();
var bayeux = new faye.NodeAdapter({
  mount:    '/faye',
  timeout:  45
});

app.configure(function() {
    app.set('port', process.env.PORT || 3002);
    app.use( express.logger( 'dev' ) );
    app.use(express.bodyParser());
    app.use(app.router);
});

app.configure('development', function( ){
    app.use(express.logger());
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function( ){
    app.use(express.logger());
    app.use(express.errorHandler());
});

// The app server sends this message
app.post( '/enqueue', function( req, res, next ) {
    // Enqueue a new item
    var uid = req.param( 'uid' );
    var msg = req.body;

    log.info( "enqueuing message for " + uid );

    mQueue.enqueue( uid, msg, function( err ) {
	if ( err ) {
	    return req.json({ error: true, message: err });
	}
	mQueue.count( uid, function( err, count ) {
	    if ( err ) {
		return req.json({ error: true, message: err });
	    }

	    // Notify any connected client
	    bayeux.getClient().publish( '/messages/' + uid,
					{ count: count } );
	    res.json({count: count});
	});
    });
});

// Upon noficiation, the client makes this call to
// obtain list of messages pending.
app.get( '/dequeue', function( req, res, next ) {
    var uid = req.param( 'uid' );
    log.info( "dequeue from " + uid );
    mQueue.messagesFor( uid, function( err, messages ) {
	if ( err ) {
	    return req.json({ error: true, message: err });
	}
	res.jsonp({messages: messages});
    });
});

var server = app.listen(app.get('port'));
bayeux.attach(server);

bayeux.bind( 'subscribe', function( clientID, channel ) {
    // When a client connects, obtain the uid from the channel name,
    // then notify them of any pending messages.
    var uid = path.basename( channel );
    log.info( "client " + uid + " has subscribed" );
    mQueue.count( uid, function( err, count ) {
	if ( err ) {
	    count = 0;
	}
	if ( count > 0 )
	    bayeux.getClient().publish( '/messages/' + uid,
					{ count: count } );
    });
});

log.info('Listening on port ' + app.get('port'));
