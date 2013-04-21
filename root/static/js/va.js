// filepicker.io key
var picker_key = "AUBFLi68nRXe7sDddBPBVz";

// utiltiy
function json2string( json ) {
    return JSON.stringify( json );
}

// In Bootstrap, you cannot ever have more than one dialog on the screen.
// This DialogManager manages this for you, making sure to hide the
// previous if a new one is being posted.
//
var DialogManager = function() {
    this._active = '';
}

DialogManager.prototype.hide = function() {
    if ( this._active != '' ) {
        $(this._active).modal( 'hide' );
        this._active = '';
    }
}

DialogManager.prototype.error = function( msg, detail ) {
    this.hide();
    if ( detail ) {
	msg = msg + "<br/>" + detail;
    }
    $("#dialog-error .modal-body p").html( msg );
    this._active = '#dialog-error';
    $(this._active).modal( 'show' );
}

DialogManager.prototype.info = function( msg ) {
    this.hide();
    $("#dialog-info .modal-body p").html( msg );
    this._active = '#dialog-info';
    $(this._active).modal( 'show' );
}

DialogManager.prototype.confirm = function( msg, callback ) {
    this.hide();
    $("#dialog-confirm .modal-body p").html( msg );

    if ( this._confirm_cb ) {
	$("#dialog-confirm div button.btn-primary").off( "click", this._confirm_cb );
    }
    this._confirm_cb = callback;
    $("#dialog-confirm div button.btn-primary").on( "click", this._confirm_cb );

    this._active = '#dialog-confirm';
    $(this._active).modal( 'show' );
}

DialogManager.prototype.custom = function( el, callback ) {
    this.hide();

    if ( this._confirm_cb ) {
	$(el + " div button.btn-primary").off( "click", this._confirm_cb );
    }
    this._confirm_cb = callback;
    $(el + " div button.btn-primary").on( "click", this._confirm_cb );

    this._active = el;
    $(this._active).modal( 'show' );
}

var dialogManager = new DialogManager();

// Common ajax error hanadler
//
$(document).ajaxError(function( event, jqXHR, settings, exception ) {
    var requesting_url = settings.url;
    if (jqXHR.status === 0) {
        // This is another way that we know the user has logged out of the system.
        dialogManager.error( "STATUS=0, Re-Authenticate?" );
    } else if (jqXHR.status == 404) {
        dialogManager.error('Requested page not found. [404]<br>URL: '+requesting_url);
    } else if (jqXHR.status == 500) {
        dialogManager.error('Internal Server Error [500].\n' + jqXHR.responseText);
    } else if (exception === 'parsererror') {
        dialogManager.error('Requested JSON parse failed.\n' + jqXHR.responseText);
    } else if (exception === 'timeout') {
        dialogManager.error('Time out error.');
    } else if (exception === 'abort') {
        dialogManager.error('Ajax request aborted.');
    } else {
        dialogManager.error('Uncaught Error.\n' + jqXHR.responseText);
    }
});

// Pages that want to see the async message dialog must
// call this function on page load.
//   init_message_queue( "[% c.message_server %]" );
//
var mq;
function init_message_queue( server, callback ) {
    try {
	// Instanciate the message queue
	mq = new Faye.Client( server + "/faye", {
	    timeout: 120 });

	// Get myself so I know my uuid, which I can then use to
	// subscribe to messages
	//
	$.ajax({
	    url: '/services/user/me',
	    dataType: 'json',
	    success: function(json) {
		var uuid = json.user.uuid;
		mq.subscribe( '/messages/' + uuid, function( msg ) {
		    console.log( 'I have ' + msg.count + ' messages waiting' );
		    // go get them
		    $.ajax({
			url: server + "/dequeue",
			data: { uid: uuid },
			dataType: 'jsonp',
			success: function( data ) {
			    // data.messages is an array of messages.  The
			    // number should match the data.count received
			    // previously.  Each item in the array is an object:
			    // { uid: $uid, message: $message }
			    // where $message is in whatever format the enqueuer
			    // posted (you guys must agree on a message format!)
			    if ( callback ) {
				callback( data );
			    }
			    else {
				var messages = data.messages;
				console.log( "=> received " + messages.length + " messages" );
				console.log( JSON.stringify( messages ) );
				default_process_mq( data );
			    }
			}
		    });
		});
	    }
	});
    } catch( e ) {
	console.log( "Failed to connect to message queue server." );
    }
}

var lfhon = 0;
function local_file_upload_handler( server ) {
    // This is the local file media add form submission
    var handler = function(evt) {
        evt.preventDefault();
        $("#lfmessage").hide();
        $("#localfileprogress").show();
        var formData = new FormData();
        var file = document.getElementById('upload').files[0];
        formData.append('upload', file);

        var xhr = new XMLHttpRequest();
        xhr.open( 'post', server + '/upload', true );

        xhr.upload.onprogress = function(e) {
            if (e.lengthComputable) {
                var percentage = (e.loaded / e.total) * 100;
                $("#localfileprogress .bar").css( 'width', percentage + '%' );
            }
        };

        xhr.onerror = function(e) {
            $("#lfmessage").html( "ERROR" );
            $("#lfmessage").show();
        };

        xhr.onload = function(e) {
            if ( this.status == 200 ) {
                // this.response
                var res = JSON.parse( this.response );
                console.log( JSON.stringify( res ) );
                $("#dialog-localfile").data( 'file', res );
            }
        };

        xhr.send( formData );

    };
    if ( lfhon == 0 ) {
	$("#localfileformsubmit").on( 'click', handler );
	lfhon = 1;
    }
}

// The default handler for an arriving message.  Assumes this is
// an arriving workorder.
//
function default_process_mq( data ) {
    var m = data.messages[0];

    if ( m.wo.error ) {
	dialogManager.error( "We are sorry, but your project encountered errors during processing." );
	return;
    }

    // get the highlight reel
    $.ajax({
	url: '/services/wo/highlight',
	data: { id: m.wo.id },
	dataType: 'json',
	success: function( json ) {
	    var view = json.media;
	    $("#dialog-wo .completed-project-title").html( m.wo.name );
	    $("#dialog-wo .completed-project-tn").empty().append( ich.media_file( view ) );
	    $("#dialog-wo .completed-project-tn .html5lightbox").html5lightbox();
	    $("#dialog-wo .completed-project-tn a").on( 'click', function() {
		dialogManager.hide();
	    });
	    dialogManager.custom( "#dialog-wo", function(){} );
	}
    });
}

$(document).ready( function() {
    filepicker.setKey( picker_key );
});

