define([
    'plugins/router', 
    'durandal/app', 
    'durandal/system', 
    'lib/viblio',
    'lib/config',
    'knockout', 
    'facebook'], 
function( router, app, system, viblio, config, ko ) {
    var email = ko.observable();
    var email_entry_error = ko.observable( false );

    var password = ko.observable();
    var password_entry_error = ko.observable( false );

    fb_appid   = config.facebook_appid();
    fb_channel = config.facebook_channel();

    FB.init({
	appId: fb_appid,
	channelUrl: fb_channel,
	status: true,
	cookie: true,
	xfbml: true
    });

    function loginSuccessful( user ) {
	// Save the logged in user info to the viblio object,
	// which serves as a global exchange
	//
	viblio.setUser( user );
	
	// either go to the personal channel page, or
	// do a pass thru to the page the user was
	// trying to get to.
	if ( viblio.user().newuser == 'true' )
	    router.navigate( 'walkthru' );
	else
	    router.navigate( viblio.getLastAttempt() || 'status' );
    };

    function handleLoginFailure( json ) {
	var code = json.detail;
	var msg  = json.message;

	if ( code == "NOLOGIN_NOT_IN_BETA" ) {
	    msg  = "We are currently in an ivitation-only beta testing phase.  ";
	    msg += "If you would like to request participation in this beta testing program, ";
	    msg += "please enter your email below and click the reserver button.";
	}
	else if ( code == "NOLOGIN_BLACKLISTED" ) {
	    msg  = "We are very sorry but this email address is currently being blocked ";
	    msg += "from normal access.  If you feel this block should be removed, please ";
	    msg += "send email to <a href=\"mailto:xxx\">xxx</a>.";
	}
	else if ( code == "NOLOGIN_EMAIL_NOT_FOUND" ) {
	    msg  = "We do not have an account set up for " + email() + ".  If this is your ";
	    msg += "first time creating a Viblio account, start by downloading the ";
	    msg += '<a href="/#getApp?from=login">VIBLIO APP</a>.  ';
	    msg += "Otherwise, please re-enter the correct account information.";
	}
	else if ( code == "NOLOGIN_PASSWORD_MISMATCH" ) {
	    msg  = "The password you entered does not match the password we have on record for ";
	    msg += "this account.  Please try again, or click on the forgot password link.";
	}
	else if ( code == "NOLOGIN_NOEMAIL" ) {
	    msg  = "Please enter a valid email address to log in.";
	}
	else if ( code == "NOLOGIN_CANCEL" ) {
	    return;
	}
	else if ( !defined( code ) || code.match( /NOLOGIN_/g ) ) {
	    // msg is set to message coming back from server
	}
	else {
	    msg  = "We are very sorry, but something strange happened.  Please try ";
	    msg += "logging in again.";
	}
	return app.showMessage( msg, "Authentication Failure" );
    };

    function nativeAuthenticate() {
	if ( ! email() ) {
	    handleLoginFailure({ detail: "NOLOGIN_NOEMAIL" });
	    return;
	}
	if ( ! password() ) {
            if( $('.password').val() ) {
                password( $('.password').val() );
            } else {
                handleLoginFailure({ detail: "NOLOGIN_PASSWORD_MISMATCH" });
                return;
            }
	}

	viblio.api( '/authenticate',
		    { email: email(),
		      password: password(),
		      realm: 'db' }
		  ).then( 
		      function( json ) {
			  loginSuccessful( json.user );
		      },
		      function( err ) {
			  handleLoginFailure( err );
		      }
		  );
    };

    function facebookAuthenticate() {
	if ( ! fb_appid )
	    app.showMessage( 'In development, Facebook login will not work.' );

	FB.login(function(response) {
            if (response.authResponse) {
		viblio.api( '/authenticate',
			    { realm: 'facebook',
                              access_token: response.authResponse.accessToken }
			  ).then( 
			      function( json ) {
				  loginSuccessful( json.user );
			      },
			      function( err ) {
				  handleLoginFailure( err );
			      }
			  );
	    }
	},{scope: config.facebook_ask_features()});
    };


    return {
	email: email,
	email_entry_error: email_entry_error,

	password: password,
	password_entry_error: password_entry_error,

	nativeAuthenticate: nativeAuthenticate,
	facebookAuthenticate: facebookAuthenticate,

    };
});
