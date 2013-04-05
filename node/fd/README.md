#File Downloader

`fd` is a server designed to download multiple files in parallel from 
supplied urls.  It supports asynchronyous progress queries and the
ability to abort downloads in progress.  `fd` can respond in JSON or JSONP.

`fd` implements three service endpoints; "download", "progress" and "abort".
All three require an "id" parameter that uniquely identifies a particular
download.  (The download endpoint also requires a "url", the url of the
file to download and a "filename" to indicate where to store the downloaded
file).  These ids should be unique enough not to collide during parallel
downloads.

There is also a "remove" endpoint that takes a filename (same filename
passed to a download in the past) and will remove that file from the
host file system.

## Persistence and Scaling Considerations

Being a NodeJS application, `fd` can handle any number of parallel download,
progress and about requests, but there may come a point where a single `fd`
process is not enough to handle the load.  `fd` uses "memcached" to persist
the progress information, so that a download request to one process can still
get its progress information from a different process, so long as those
processes have a connection to a common memcached.  However, it is not 
possible to be as flexible with aborts.  An abort **must** be executed
on the same process that initiated the associated download.  So, if you want
to reliably handle aborts, you must stick to a single `fd` process.  If you
employ multiple processes (behind a reverse proxy load balancer for example),
then you may still make abort requests, but the request might fail.  (you 
might be able to mitigate this with process affinity with the load balancer).

So, you can implement a cluster of `fd` servers behind a reverse proxy like
nginx.  You can configure `fd`'s use of memcached to use a cluster of
memcached servers, on the same or remote machines.  For a sample nginx
configuration, see http://www.geektantra.com/2011/06/using-nginx-as-a-load-balancer/.  
For information on memcached configuration, see https://github.com/3rd-Eden/node-memcached.

## Configuration

The configuration file for `fd` is "fd.json".  `fd` uses "konphyg" to read it, so
it is possible to have development and production varients.  The "memcached"
entry is passed to the memcached constructor.

The "storage" entry is used to construct pathnames on the host system for
storing the downloaded files.

## Endpoints

### GET /download?id=$id&url=$url&filename=$filename

``` js
{
  "id": $id,
  "expected": 704833536,
  "received": 704833536,
  "done": true,
  "errored": false,
  "aborted": false
}
```

**id** is the id you passed in.  **expected** and **received** are the byte counts.
It is possible for **expected** to be equal to -1, if the file being downloaded
did not include a Content-Length header.  **done** will be true when the download
is complete.  

If you are employing a /progress loop, then the last call to /progress, when
**done** is true will contain accurate values for **errored** and **aborted**.
If you are not employing a /progress loop, then you should call /progress
upon receiving the response to /download.  That will give you accurate
**errored** and **aborted** values, as well as cleaning up bits on the
server.

### GET /progress?id=$id

``` js
{
  "id": $id,
  "expected": 704833536,
  "received": 109969408,
  "done": false,
  "errored": false,
  "aborted": false
}
```

**id** is the id you passed in.  **expected** and **received** are the byte counts.
It is possible for **expected** to be equal to -1, if the file being downloaded
did not include a Content-Length header.  **done** will be true when the download
is complete.  You must check **errored** and **aborted** to determine if the
download was successful.  **aborted** will be true if the download was aborted
due to a call to the **/abort** endpoint.

### GET /abort?id=$id

``` js
{
  "error": false
}
```

If **error** is false, then the abort was successful.  Your original /download
will return, and your next /progress call will contain **done**=true and 
**aborted**=true.

### GET /remove?filename=$filename

``` js
{
  "error": false
}
```

## Errors

Any of the endpoints can return

``` js
{
  "error": true,
  "message": "An error message"
}
```

This condition should always be checked before assuming any other content
in the response.

## Example Usage
  
In this example, assume that **files** is an array of objects that look like

``` js
{
  "id": "some-generated-unique-id",
  "url": "some-external-url-for-the-download",
  "filename": "a-file-name-for-storage"
}
```

Then javascript running in the client browser might look like this:

``` js
files.forEach( function( f ) {
    // fire the download
    $.ajax({
	url: "/download",
	data: f,
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		alert( json.message );
	    }
	    // Let the progress checkers
	    // handle the final condition
	    // of each download.
	}
    });
    // prepare a progress bar
    progress.prepare( f );
    // fire a periodic progress monitor
    var tmr = setInterval( function() {
	$.ajax({
	    url: '/progress',
	    data: { id: f.id },
	    dataType: 'json',
	    success: function( json ) {
		if ( json.error ) {
		    alert( json.message );
		    progress.remove( f );
		    tmr.clearInterval();
		}
		else if ( ! done ) {
		    progress.update( f, expected, received );
		}
		else {
		    if ( errored || aborted ) {
			alert( "download was cancelled" );
		    }
		    progress.remove( f );
		    tmr.clearInterval();
		}
	    }
	});
    }, 1000 ); // every second
});
```
