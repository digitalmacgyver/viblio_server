// Media list management common routines
//

// Delete a media file from the servers, then from the gui
//
function delete_media( id ) {
    $.ajax({
	url: "/services/mediafile/delete",
	data: { id: id },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message, json.detail );
	    }
	    else {
		$("#mid-"+id).remove();
	    }
	}
    });
}

// Display the delete buttons on the media file thumbnails
//
function media_edit() {
    $("#media-list .dbtn").toggle('slide', {direction: 'right'}, 300);
}

// Add filepicker.io media to the list
//
function add_filepicker_media( wid, callback ) {
    filepicker.pickMultiple ( 
	{ 
          extensions: ['3g2','3gp','3gp2','3gpp','3gpp2','aac','ac3',
	  	       'eac3','ec3','f4a','f4b','f4v','flv','highwinds',
		       'm4a','m4b','m4r','m4v','mkv','mov','mp3',
		       'mp4','oga','ogg','ogv','ogx','ts','webm','wma',
		       'wmv','png','jpg','gif',
		       '3G2','3GP','3GP2','3GPP','3GPP2','AAC','AC3',
		       'EAC3','EC3','F4A','F4B','F4V','FLV','HIGHWINDS',
		       'M4A','M4B','M4R','M4V','MKV','MOV','MP3',
		       'MP4','OGA','OGG','OGV','OGX','TS','WEBM','WMA',
		       'WMV','PNG','JPG','GIF']
        },
        function( fpfiles ) {
	    var num = fpfiles.length;
            for( var i=0; i<fpfiles.length; i++ ) {
                var url = fpfiles[i].url;
		fpfiles[i]['location'] = 'fp';
		if ( wid ) 
		    fpfiles[i]['workorder_id'] = wid;
                $.ajax({
                    url: "/services/mediafile/create",
                    method: "POST",
                    dataType: "json",
                    data: fpfiles[i],
                    success: function( json ) {
			if ( json.error ) {
			    dialogManager.error( json.message );
			}
			if ( --num == 0 ) {
			    callback();
			}
                    },
                    error: function() {
                        dialogManager.error( "failed to store " + url );
			if ( --num == 0 ) {
			    callback();
			}
                    }
                });
            }
        },
        function( err ) {
	    if ( err && err.code && err.code == 101 ) {
		// User closed dialog without picking anything.  No problem.
	    }
	    else {
		dialogManager.error( json2string( err ) );
	    }
        }
    );
    return;
}

// Add locallaly picked media to the list
//
function add_local_media( wid, callback ) {
    $("#localfileprogress").hide();
    $("#lfmessage").hide();

    dialogManager.custom( '#dialog-localfile', function() {
	var file = $("#dialog-localfile").data( 'file' );

        if ( file ) {

	    var data = {
		location: 'fs',
		filename: file.name,
		url: file.path,
		mimetype: file.mimetype,
		size: file.size
	    };
	    if ( wid ) 
		data['workorder_id'] = wid;

            $.ajax({
                url: "/services/mediafile/create",
                method: "POST",
                dataType: "json",
                data: data,
                success: function( json ) {
                    if ( json.error ) {
                        dialogManager.error( json.message );
                    }
		    callback();
                },
                error: function() {
                    dialogManager.error( "failed to store " + url );
		    callback();
                }
            });
        }
    });
}

function list_media( wid, play, callback ) {
    var url = '/services/user/media';
    var data = {};
    var from = 's3';

    if ( wid ) {
	url = '/services/wo/bom';
	data = { id: wid };
	from = 'anywhere';
    }

    $.ajax({
        url: url,
	data: data,
        dataType: 'json',
        success: function( json ) {
            if ( json.error ) {
                dialogManager.error( json.message );
            }
            else {
                $("#media-list").empty();
                for( var i=0; i<json.media.length; i++ ) {
		    if ( from == 'anywhere' || json.media[i].views.main.location == from ) {
			// Use a client-side template to create a media-object
			if ( json.media[i].views.main.mimetype.indexOf('audio') == 0 ) {
                            $("#media-list").append( ich.media_file_audio(json.media[i]) );
			}
			else {
                            $("#media-list").append( ich.media_file(json.media[i]) );
			    if ( play ) {
				$("#media-list #mid-"+json.media[i].id).find( 'a' ).data( 'media', json.media[i] ).click( function() {
				    var media = $(this).data( 'media' );
				    play( media );
				});
			    }
			    else {
				$("#media-list #mid-"+json.media[i].id).find( '.mplay-icon' ).remove();
			    }
			}
		    }
                }
		// apply the clear so the grid wraps the content
		$( '<br style="clear: left;" />' ).appendTo( '#media-list' );
		callback();
            }
        }
    });
}
