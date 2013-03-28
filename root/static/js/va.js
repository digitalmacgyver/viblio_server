function json2string( json ) {
    return JSON.stringify( json );
}

var DialogManager = function() {
    this._active = '';
}

DialogManager.prototype.hide = function() {
    if ( this._active != '' ) {
        $(this._active).modal( 'hide' );
        this._active = '';
    }
}

DialogManager.prototype.error = function( msg ) {
    this.hide();
    $("#dialog-error .modal-body p").html( msg );
    this._active = '#dialog-error';
    $(this._active).modal( 'show' );
}

var dialogManager = new DialogManager();

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
