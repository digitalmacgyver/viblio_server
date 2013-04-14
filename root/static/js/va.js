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
	$("#dialog-confirm div button.btn-primary").off( "click", this._confirm_cb );
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
