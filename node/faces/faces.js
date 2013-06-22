var express   = require('express')
  , graph     = require('fbgraph')
  , ugen      = require( 'cuid' )
  , mkdirp    = require('mkdirp')
  , fs        = require('fs')
  , path      = require( 'path' )
  , url       = require("url")
  , app       = express();

// Logging
var log = require( "winston" );
log.add( log.transports.File, { filename: '/tmp/faces.log', json: false } );

// Configuration
var Config = require( "konphyg" )( __dirname );
var config = Config( "faces" );

app.configure('development', function(){
    log.info( 'DEVELOPMENT' );
    app.use(express.errorHandler({ dumpExceptions: true, showStack: true })); 
});

app.configure('production', function(){
    log.info( 'PRODUCTION' );
    app.use(express.errorHandler());
});

app.configure(function(){
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(app.router);
});

// Download a photo for processing.  The photo is downloaded
// asynchroniously in chunks.  The callback gets passed an error
// (null if no error) and the temp filename.  The callback should
// take care to remove temp files when no longer needed.
//
// This function should be used to download photos.  The callback
// can do things like pass the photo on to the recognizer, then
// perhaps manipulate the photo with imagemagik, and store it
// in the local database.
//
function download_photo( src, callback ) {
    var tmpdir = config.storage.tmpdir;
    if ( ! fs.existsSync( tmpdir ) ) 
	mkdirp.sync( tmpdir );
    var ofile = path.join( tmpdir, ugen() );
    ofile = ofile + path.extname( src );

    var http = require( 'http' );
    if ( url.parse( src ).protocol == 'https:' )
	http = require( 'https' );

    try {
	var target = fs.createWriteStream( ofile, { flags: 'a' } );
	var response = http.request(
	    { host: url.parse( src ).host,
	      path: url.parse( src ).path
	    }, function( response ) {
		response.on( 'data', function( chunk ) {
		    target.write( chunk, encoding='binary' );
		});
		response.on( 'end', function() {
		    callback( null, ofile );
		});
	    }).end();
    } catch( e ) {
	callback( e, ofile );
    }
}

// Collect Faces data on the passed in Facebook uid (user).  If the uuid argument is 
// not null, use this as the database key, else generate a new uuid and use that.
// For the primary user (the viblio user), the uuid will come from the cat server.
// For friends, the uuid can be fetched from the local database by Facebook uid if
// it exists, or created new.
//
function collect_info( uid, uuid ) {
    // Profile picture and full name and first name
    graph.fql( 'select name, first_name, pic_big from user where uid = ' + uid, function( err, res ) {
	if ( err ) {
	    console.log( 'ERROR: Collecting for ' + uid + ': ' + err.message );
	}
	else {
	    // We have user info in res.data[0].  
	    console.log( res.data[0].name );

	    if ( ! uuid ) uuid = ugen(); // generate a uuid if needed

	    // This is a test of the downloader.  It may or may not go here in the
	    // final product.
	    //
	    download_photo( res.data[0].pic_big, function( err, filename ) {
		if ( err ) {
		    log.error( "Failed to download user profile photo" );
		}
		else {
		    console.log( "SAVED " + filename );
		    // We have the profile photo.  Now we can pass it to the recognizer,
		    // monkey with the size (imagemagic), extract the face, store it
		    // in the local database, etc.
		}
	    });

	    // Try finding a user record in the local database by uid (Facebook user id).  If
	    // found, it already has a uuid (viblio user id) and data.  If not found, generate
	    // a uuid (unless the input param is already defined), and store uuid, uid and 
	    // the name and first_name.  Download the profile picture and process it to
	    // viblio specs, and store the raw picture data.  We'll want to pass the photo
	    // to the recognizer too, I'd guess.
	    //

	    // Now go find all other photos in which this user is tagged.
	    graph.fql( 'select object_id, xcoord, ycoord from photo_tag where subject = ' + uid, function( err, res ) {
		if ( err ) {
		    console.log( 'ERROR: TAGS for ' + uid + ': ' + err.message );
		}
		else {
		    // Foreach photo, we need to download it and what?, we know the center
		    // point of the user (xcoord and ycoord, percentages from top/left) in the
		    // image.  I guess we want to extract a thumbnail using this data to pass
		    // to the recognizer.  We'll want to store the thumbnail in a list associated
		    // with the user.

		    res.data.forEach( function( d ) {
			graph.fql( 'select src_big from photo where object_id = ' + d.object_id, function( err, photo ) {
			    if ( err ) {
				console.log( 'ERROR: TAGGED PHOTO for ' + uid + ': ' + err.message );
			    }
			    else {
				d.src = photo.data[0].src_big;
				// d now looks like:
				// { object_id: 56944189601,
				//   xcoord: 57.0957,
				//   ycoord: 50.989,
				//   src: 'https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-ash4/2078_56944189601_7726_n.jpg' }
				//
				console.log( d );
			    }
			}); 
		    });
		}
	    });
	}
    });
}

// This is the main entry point for Facebook synchronization, basically
// pulling profile pics and tagged photos to pass to the recognizer for
// the viblio user and all their friends.
//
app.get( '/fbsync', function( req, res, next ) {
    var uuid  = req.param('uuid');     // Cat user UUID
    var fbid  = req.param('fbid');     // Facebook uid
    var token = req.param('token');    // Facebook auth token

    try {
	graph.setAccessToken( token );
    } catch( e ) {
	return next( new Error( e.message ) );
    }

    // Do a simple access to make sure the token is ok
    graph.fql( 'select uid, pic_big from user where uid = me()', function( err, fb ) {
	if ( err ) {
	    console.log( err );
	    return next( new Error( err.message ) );
	}
	console.log( fb );

	if ( fb && fb.data && fb.data.length==1 && fb.data[0].uid==fbid ) {
	    // We're good to go
	    res.status( 200 ).send( {} );  // Detach here so we can go do real work.

	    // Collect the person information of the calling user; their profile photo and
	    // all of the photos this person is tagged in.
	    //
	    // Then do the same for each friend this person has.
	    //
	    collect_info( fbid, uuid );
	    graph.fql( 'select uid2 from friend where uid1 = me()', function( err, fdata ) {
		if ( err ) {
		    console.log( err.message );
		}
		else {
		    if ( fdata && fdata.data && fdata.data.length > 0 ) {
			fdata.data.forEach( function( d ) {
			    collect_info( d.uid2 );
			});
		    }
		}
	    });
	}
	else {
	    return next( new Error( 'Authentication failure' ) );
	}
    });
});

var port = process.env.PORT || 3033;
app.listen(port, function() {
    console.log("Faces server listening on port %d", port);
});
