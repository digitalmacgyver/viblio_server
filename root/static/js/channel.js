/* Script for the Channel Page */
$(document).ready( function() {
    initialize();
});

function media_edit(event) {
    var $this = $(event.target);
    var container = $this.parents( 'div[class^="media-search-result"]' );

    var label = $this.html();
    if ( label == 'Edit' ) {
	$this.html( 'Done' );
	container.find( ".mplay-icon" ).hide();
	container.find( ".media-file").on( 'click', media_selected );
	container.find( ".btn-group" ).css( 'visibility', 'visible' );
    }
    else {
	$this.html( 'Edit' );
	container.find( ".btn-group" ).css( 'visibility', 'hidden' );
	container.find( ".mplay-icon" ).show();
	container.find( ".media-file").removeClass( 'selected' );
	container.find( ".media-file").off( 'click', media_selected );
    }
}

function show_metadata(event) {
    var $this = $(event.target);
    var container = $this.parents( 'div[class^="media-search-result"]' );
    $("#metadata").empty();
    container.find( ".selected" ).each( function() {
	var mid = $(this).attr( 'id' ).replace( 'mid-','' );
	$.getJSON( '/services/mediafile/get_metadata',
		   { mid: mid },
		   function( json ) {
		       var el = $(ich.md({uuid: mid}));
		       $("#metadata").append( el );
		       el.find( '.metadata-data' ).jsonEditor( json );
		   });
    });
}

function media_selected() {
    $(this).toggleClass( 'selected' );
}

function build_media_gully( title, json, simulate, editable ) {
    var el = $( ich.scrollable({ title: title, media: json.media }) );
    $("#list-of-scrollables").append( el );
    el.find(".media-search-area").smoothDivScroll({
	manualContinuousScrolling: false,
	mousewheelScrolling: "horizontal",
	touchScrolling: true
    });
    el.find(".fancybox").fancybox({
	tpl: {
	    // wrap template with custom inner DIV: the empty player container
	    wrap: '<div class="fancybox-wrap" tabIndex="-1">' +
		'<div class="fancybox-skin">' +
		'<div class="fancybox-outer">' +
		'<div id="player">' + // player container replaces fancybox-inner
		'</div></div></div></div>' 
	},
	beforeShow: function () {
	    var uri = $(this.element).data( 'uri' );
	    $("#player").flowplayer( "/static/flowplayer/flowplayer-3.2.16.swf", {
		clip: {
		    url: 'mp4:amazons3/viblio-mediafiles/' + uri,
		    ipadUrl: encodeURIComponent($(this.element).data( 'url' )),
		    // URL for sharing on FB, etc.
		    pageUrl: site_server + '/shared/flowplayer/' + $(this.element).data( 'uuid' ),
		    //scaling: 'fit',
		    ratio: 9/16,
		    //splash: true,
		    provider: 'rtmp'
		},
		plugins: {
		    rtmp: {
			url: '/static/flowplayer/flowplayer.rtmp-3.2.12.swf',
			netConnectionUrl: 'rtmp://ec2-54-214-160-185.us-west-2.compute.amazonaws.com/vods3'
		    },
		    viral: {
			url: '/static/flowplayer/flowplayer.viralvideos-3.2.13.swf',
			share: { 
			    description: 'Video highlight by Viblio',
			    facebook: true,
			    twitter: true,
			    myspace: false,
			    livespaces: true,
			    digg: false,
			    orkut: false,
			    stumbleupon: false,
			    bebo: false
			},
			embed: false,
			email: false
		    }
		},
		canvas: {
		    backgroundColor:'#254558',
		    backgroundGradient: [0.1, 0]
		}
	    }).flowplayer().ipad({simulateiDevice: simulate});
	},
	beforeClose: function () {
	    // important! unload the player
	    var fp = flowplayer(); 
	    fp.unload();
	}
    });
}

function initialize() {
    /* Do a number of media queries and display them using smoothdivscrolls */
    var video = document.createElement("video"),
    idevice = /ip(hone|ad|od)/i.test(navigator.userAgent),
    noflash = flashembed.getVersion()[0] === 0,
    simulate = !idevice && noflash &&
        !!(video.canPlayType('video/mp4; codecs="avc1.42E01E, mp4a.40.2"').replace(/no/, ''));

    // Use a queue pattern to serialize the requests, do we can
    // display them in a predictable order.
    //
    var queue = [];
    queue.push({
	url: '/services/user/media',
	data: { from: 's3' },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message );
            }
            else {
		build_media_gully( 'Recommended by your friends', json, simulate );
	    }
	}
    });
    queue.push({
	url: '/services/user/media',
	data: { from: 's3' },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message );
            }
            else {
		build_media_gully( 'Top Hits', json, simulate );
	    }
	}
    });
    queue.push({
	url: '/services/user/media',
	data: { from: 's3' },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message );
            }
            else {
		build_media_gully( 'Featuring people you know', json, simulate );
	    }
	}
    });
    queue.push({
	url: '/services/user/media',
	data: { from: 's3' },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message );
            }
            else {
		build_media_gully( 'This year in review', json, simulate );
	    }
	}
    });
    queue.push({
	url: '/services/user/media',
	data: { from: 's3' },
	dataType: 'json',
	success: function( json ) {
	    if ( json.error ) {
		dialogManager.error( json.message );
            }
            else {
		build_media_gully( 'Watch List', json, simulate, false );
	    }
	}
    });

    var run = function() {
	var options = queue.shift();
	if ( options ) 
	    $.ajax( options ).success( run );
    };

    run();

}
