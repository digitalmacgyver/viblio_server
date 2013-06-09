/*
 * jQuery File Upload Plugin JS Example 8.0
 * https://github.com/blueimp/jQuery-File-Upload
 *
 * Copyright 2010, Sebastian Tschan
 * https://blueimp.net
 *
 * Licensed under the MIT license:
 * http://www.opensource.org/licenses/MIT
 */

/*jslint nomen: true, unparam: true, regexp: true */
/*global $, window, document */

function jfu_init( server ) {
    // Initialize the jQuery File Upload widget:
    $('#fileupload').fileupload({
        // Uncomment the following to send cross-domain cookies:
        //xhrFields: {withCredentials: true},
        url: server,
	maxFileSize: 4294967296,
        acceptFileTypes: /(\.|\/)(flv|mp4|m4v|m3u8|ts|3gp|mov|avi|wmv)$/i,
	add_media_file: function( file, callback ) {
	    console.log( JSON.stringify( file ) );
	    // send file to Cat, get result with nginx creds,
	    // pass back to ui for render
	    var woid = $("#fileupload").data( 'woid' );
	    file.workorder_id = woid;
	    file.location = 'jfs';
	    $.getJSON( '/services/mediafile/create', file, function( json ) {
		$(".process-available").show();
		var media = json.media;
		var file = {
		    delete_type: 'GET',
		    delete_url: '/services/mediafile/delete?id=' + media.id,
		    url: media.views.main.url,
		    type: media.views.main.mimetype,
		    size: media.views.main.size,
		    name: media.filename
		};
		if ( media.views.thumbnail ) 
		    file.thumbnail_url = media.views.thumbnail.url;
		callback( file );
	    });
	}
    });

    // Enable iframe cross-domain access via redirect option:
    $('#fileupload').fileupload(
        'option',
        'redirect',
        window.location.href.replace(
            /\/[^\/]*$/,
            '/static/jfu/cors/result.html?%s'
        )
    );

    if (window.location.hostname === 'blueimp.github.com' ||
            window.location.hostname === 'blueimp.github.io') {
        // Demo settings:
        $('#fileupload').fileupload('option', {
            url: '//jquery-file-upload.appspot.com/',
            disableImageResize: false,
            maxFileSize: 5000000,
            acceptFileTypes: /(\.|\/)(gif|jpe?g|png)$/i
        });
        // Upload server status check for browsers with CORS support:
        if ($.support.cors) {
            $.ajax({
                url: '//jquery-file-upload.appspot.com/',
                type: 'HEAD'
            }).fail(function () {
                $('<span class="alert alert-error"/>')
                    .text('Upload server currently unavailable - ' +
                            new Date())
                    .appendTo('#fileupload');
            });
        }
    } else {
        // Load existing files:
        $('#fileupload').addClass('fileupload-processing');
	$.ajax({
	    url: '/services/wo/find_or_create',
	    data: { state: 'WO_PENDING' },
	    dataType: 'json',
	    context: $('#fileupload')[0]
	}).always( function() {
	    $(this).removeClass('fileupload-processing');
	}).done( function( result ) {
	    var files = [];
	    if ( result.media.length ) {
		$(".process-available").show();

		for ( var i=0; i<result.media.length; i++ ) {
		    var media = result.media[i];
		    var file = {
			delete_type: 'GET',
			delete_url: '/services/mediafile/delete?id=' + media.id,
			url: media.views.main.url,
			type: media.views.main.mimetype,
			size: media.views.main.size,
			name: media.filename
		    };
		    if ( media.views.thumbnail ) 
			file.thumbnail_url = media.views.thumbnail.url;
		    files.push( file );
		}
	    }
	    $("#fileupload").data( 'woid', result.wo.id );
	    $("#fileupload").fileupload('option', 'done').call( $("#fileupload"), null, {result: { files: files }});
	});
	
	/**
        $.ajax({
            url: $('#fileupload').fileupload('option', 'url'),
	    data: {
		uid: 'xxxx'
	    },
            dataType: 'json',
            context: $('#fileupload')[0]
        }).always(function (result) {
            $(this).removeClass('fileupload-processing');
        }).done(function (result) {
            $(this).fileupload('option', 'done')
                .call(this, null, {result: result});
	    if ( result.files.length )
		$(".process-available").show();
        });
	**/
	// Fetch user's pending workorder and display it, or 
	// create a new empty workorder and display it.
	//
	/**
	var result = {
	    files: [
		{ name: 'this is a filename.mp4',
		  size: 1024,
		  type: 'image/jpg',
		  delete_type: 'GET',
		  delete_url: 'http://delete_url',
		  thumbnail_url: 'http://thumbnail_url',
		  url: 'http://source_url'
		}
	    ]
	};
	$("#fileupload").fileupload('option', 'done')
	    .call( $("#fileupload"), null, {result: result});
	if ( result.files.length )
	    $(".process-available").show();
	**/
    }

    // When a file is removed, check to see if there are any pending
    // upload left.  If not, hide the WO submit
    $("#fileupload").bind( "fileuploaddestroyed", function(e, data) {
	console.log( "File Removed" );
	var count = $('table[role="presentation"] tr').length;
	if ( count == 0 )
	    $(".process-available").hide();
    });

    // Here is how we attach uid for file uniqueness to send to
    // modified node server
    //
    $.getJSON( '/services/user/me', function( data ) {
	$("#fileupload").fileupload( 'option', 'formData', {
	    uid: data.user.uuid
	});
    });
}

$(function () {
    $.ajax({
        url: '/services/mediafile/url_for',
	data: { location: 'jfs', path: '/' },
        dataType: 'json',
        success: function( json ) {
            if ( ! json.error ) {
		jfu_init( json.url );
            }
        }
    });

    $(window).on('beforeunload ',function() {
	if ( $('table[role="presentation"] tr').length )
	    return "Would you like to submit your uploaded files for processing now?  You can leave and come back later too, if you wish.";
    });

    // Submit the WO for processing
    $(".process-available").click( function() {
	console.log( 'processing' );
	var woid = $("#fileupload").data( 'woid' );
	$.ajax({
            url: "/services/wo/bom",
            data: { id: woid },
            dataType: 'json',
            success: function( json ) {
                dialogManager.confirm( ich.wo_bom( json ),function() {
                    $.ajax({
                        url: "/services/wo/submit",
                        data: { id: woid },
                        dataType: 'json',
                        success: function(json) {
                            if ( json.error ) {
                                dialogManager.error( json.message, json.detail );
                            }
                            else {
                                // redirect back home.
				$('table[role="presentation"]').empty();
                                window.location = "/";
                            }
                        }
                    });
                });
            }
	});
    });
});
