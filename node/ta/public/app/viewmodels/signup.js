define([
        'durandal/app',
        'lib/viblio',
        'lib/config',
        'knockout'], 
function(app, viblio, config, ko) {
    
    var fname = ko.observable();
    var fname_entry_error = ko.observable( false );
    var lname = ko.observable();
    var lname_entry_error = ko.observable( false );
    var email = ko.observable();
    var email_entry_error = ko.observable( false );
    var pword1 = ko.observable('');
    var pword1_entry_error = ko.observable( false );
    var pword2 = ko.observable('');
    var pword2_entry_error = ko.observable( false );
    
    fb_appid   = config.facebook_appid();
    fb_channel = config.facebook_channel();

    FB.init({
	appId: fb_appid,
	channelUrl: fb_channel,
	status: true,
	cookie: true,
	xfbml: true
    });
    
    var validPassword = ko.computed(function(){
        if ( pword1().length >= 6 ) {
            return true;
        } else {
            return false;
        }
    });

    var passwordsMatch = ko.computed(function(){
        if ( pword1() === pword2() ) {
            return true;
        } else {
            return false;
        }
    });
    
    var enableSubmit = ko.computed(function(){
        if ( validPassword() && passwordsMatch() ) {
            return true;
        } else {
            return false;
        }
    });
    
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
    
    function signup() {
       app.showMessage('submit functionality needed');
    };
    
    return {
        fname: fname,
        fname_entry_error: fname_entry_error,
        lname: lname,
        lname_entry_error: lname_entry_error,
        email: email,
        email_entry_error: email_entry_error,
        pword1: pword1,
        pword1_entry_error: pword1_entry_error,
        pword2: pword2,
        pword2_entry_error: pword2_entry_error,
        validPassword: validPassword,
        passwordsMatch: passwordsMatch,
        enableSubmit: enableSubmit,
        
        facebookAuthenticate: facebookAuthenticate,
        signup: signup
    };
});
