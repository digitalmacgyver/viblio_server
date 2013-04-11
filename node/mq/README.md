Faye-based Message Queue and Delivery

This message delivery server sits between a message producer and
message consumers.  A message producer posts JSON messages to 
'uid' keyed queues.  Message clients (web applications) use the
Faye javascript library to recieve dequeue notifications asynchroniously
and fetch messages from their queue.  It is expected that the client's
domain is coming from the message producer (the application server),
so the client's interaction with this message queue server is cross
domain, which Faye supports.

A simple client looks like this:

<html>
  <body>
    <!-- html body code -->

    <script src="http://code.jquery.com/jquery-1.9.1.min.js"></script>
    <script src="http://code.jquery.com/jquery-migrate-1.1.1.min.js"></script>
    <!-- Fetch the faye.js from this mq server! -->
    <script src="http://mq:3000/faye.js"></script>
    // Create the Faye client object for communication.  Note that
    // we are specifying a cross domain full url path.
    var client = new Faye.Client('http://mq:3000/faye', {
	timeout: 120 });

    // The message exchange is done using globally unique 'uid' keys
    var uid = '15';
    
    // Subscribe to my message queue with a callback that gets called
    // when new messages are available.  If I just got online and messages
    // have previously been sent for me, this callback will fire right 
    // away and I can go get those messages.
    client.subscribe( '/messages/' + uid, function( json ) {
	// json.count is the number of messages on the queue for me
	console.log( "I have " + json.count + " messages waiting for me." );
	// go and get them
	$.ajax({
	    url: 'http://mq:3000/dequeue',
	    data: { uid: uid },  // pass my uid
	    dataType: 'jsonp',   // cross domain call
	    success: function( json ) {
		// json.messages is an array of messages.  The
		// number should match the json.count received
		// previously.  Each item in the array is an object:
		// { uid: $uid, message: $message }
		// where $message is in whatever format the enqueuer
		// posted (you guys must agree on a message format!)
		var messages = json.messages;
                console.log( "=> received " + messages.length + " messages" );
                console.log( JSON.stringify( messages ) );
	    }
	});
    });
    <script>
    </script>
  </body>
</html>

To enqueue a message for a client, do a POST to /enqueue with the body
of the message formatted as JSON, including the uid key that specifies
the proper queue; something like:

{ "uid": 15, "text": "This is a message", "id": 1 }

When a client calls /dequeue, his messages are removed from the mq queues
upon delivery.  

IMPORTANT!!

This implementation uses in-process data structures to store messages and
Faye state.  If this process goes away, so does all of the data, probably 
not what you want in production.  The file "queue.js" should be changed to
use a persistent storage mechansim, and Faye should also use persistent
storage for state.  See http://faye.jcoglan.com/node/engines.html.
