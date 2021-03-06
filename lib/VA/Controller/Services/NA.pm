package VA::Controller::Services::NA;

# These calls are not authenticated.

use Moose;
use namespace::autoclean;
use DateTime;
use Try::Tiny;

use VA::MediaFile;
use JSON;
use Email::Address;

use VA::MediaFile::US;
use MIME::Types;
use LWP;
use File::Basename;
use Net::GitHub::V3;

use Data::UUID;
use GeoData;

use WWW::Mixpanel;

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/na

All services under this path are non-authenticated.  

=cut

# Random invitation code
#
sub invite_code :Private {
    my ( $self, $len ) = @_;
    $len = 8 unless( $len );
    my $code = '';
    for( my $i=0; $i<$len; $i++ ) {
	$code .= substr("abcdefghjkmnpqrstvwxyz23456789",int(1+rand()*30),1);
    }
    return $code;
}

=head2 /services/na/authenticate

The main authentication endpoint.  Parameters are email, password and realm.  The
realm parameter selects the type of authentictor to use; currently 'facebook' or
'db' (for local database).  Other realms may be added in the future.

=head3 Response

If successful, the response will be

  { "user" : $user }

If unsuccessful, the response will be a JSON struct that looks something like:

  {
   "error" : 1,
   "message" : "Authentication Failure",
   "detail" : "No session or session expired.",
   "code" : 401
  }

=cut

sub authfailure_response :Private {
    my( $self, $c, $code ) = @_;
    my $hash = {
	"NOLOGIN_NOT_IN_BETA" => "Login failed: Not registered in the beta program.",
	"NOLOGIN_BLACKLISTED" => "Login failed: This account has been black listed.",
	"NOLOGIN_EMAIL_NOT_FOUND" => "Login failed: Email address is not registered.",
	"NOLOGIN_PASSWORD_MISMATCH" => "Login failed: Password does not match for email address.",
	"NOLOGIN_MISSING_EMAIL" => "Login failed: Missing email address.",
	"NOLOGIN_MISSING_PASSWORD" => "Login failed: Missing password.",
	"NOLOGIN_EMAIL_TAKEN" => "Login failed: Email address already taken.",
	"NOLOGIN_DB_FAILED" => "Login failed: Server could not create account.",
	"NOLOGIN_XCHECK" => "Login failed: If you created your account with Facebook, please log in with Facebook.",
	"NOLOGIN_OAUTH_FAILURE" => "Login failed: Authentication failure against social network.",
	"NOLOGIN_UNKNOWN" => "Login failed",
	"NOLOGIN_INVALID_EMAIL" => "Login failed: Invalid Email."
    };
    return $c->loc( $hash->{$code} );
}

sub authenticate :Local {
    my ( $self, $c ) = @_;

    my $no_password = $self->boolean( $c->req->param( 'no_password' ), 0 );
    my $try_photos = $self->boolean( $c->req->param( 'try_photos' ), 0 );

    # Get the username and password from form
    my $email = $self->sanitize( $c, $c->req->params->{email} );
    my $password = $c->req->params->{password};
    my $realm = $c->req->params->{realm} || 'facebook';

    my $creation_reason = $self->sanitize( $c, $c->req->params->{creation_reason} );

    # Different realms require different lookup and password values
    #
    my $creds = {};
    if ( $realm eq 'db' ) {
	if ( $c->config->{in_beta} ) {
	    unless( $c->model( 'RDS::EmailUser' )->find({email => $email, status => 'whitelist'}) ) {
		my $code = "NOLOGIN_NOT_IN_BETA";
		$self->status_unauthorized( $c, $self->authfailure_response( $c, $code ), $code );
	    }
	}

	if ( $c->model( 'RDS::EmailUser' )->find({email => $email, status => 'blacklist'}) ) {
	    my $code = "NOLOGIN_BLACKLISTED";
	    $self->status_unauthorized( $c, $self->authfailure_response( $c, $code ), $code );
	}
	$creds = {
	    email => $email,
	    password => $password,
	};

	# There is one case that causes perl exceptions; when someone created an account
	# via OAuth, but is now trying to authenticate with an email/password.  Since the
	# OAuth based account does not have a password, the password check in PassphraseColumn.pm
	# line 55 causes an exception trying to match() on an undefined value.
	my $xcheck = $c->model( 'RDS::User' )->find({ email => $email });
	if ( $xcheck && ! defined( $xcheck->password() ) ) {
	    my $code = "NOLOGIN_XCHECK";
	    $self->status_unauthorized( $c, $self->authfailure_response( $c, $code ), $code );
	}
    }
    elsif ( $realm =~ /facebook/ ) {
	$creds = {};
	# Turn on auto creation of Facebook accounts on login.
	$c->{no_autocreate} = 0;
    }
    elsif ( $realm =~ /community/ ) {
	$creds = $c->req->params;
    }
    elsif ( $realm =~ /viblio/ ) {
	$creds = $c->req->params;
    }
    
    if ( $c->authenticate( $creds, $realm ) ) {
	# The website's facebook login only ever calls: services/na/authenticate.
	if ( $realm =~ /facebook/ ) {
	    if ( exists( $c->stash->{new_user} ) and $c->stash->{new_user} ) {
		# In this case we have just authenticated a new facebook user.
		if ( !defined( $creation_reason ) ) {
		    $creation_reason = 'signup_facebook';
		    my $device_type = device_type( $c->req->browser );
		    if ( ( $device_type eq 'iphone' ) || ( $device_type eq 'ipad' ) ) {
			$creation_reason = 'iPhone';
		    }
		}
		$self->new_user_helper( $c, { realm => $realm, email => $c->user->email, no_password => 1, try_photos => $try_photos, creation_reason => $creation_reason } );
	    }
	}

	# If the user does not already have an access_token, generate
	# one now.  Normally this token is generated in new_user(),
	# but that functionality was added after many users already
	# existed, so this is a way to get access_tokens into the
	# system after-the-fact.
	#
	if ( ! $c->user->obj->access_token ) {
	    # Create an access token for use with the 'viblio' authenticator
	    $c->user->obj->access_token(
		lc( Data::UUID->new->create_from_name_str( 'com.viblio', $c->user->obj->email ) ) );
	    $c->user->obj->update;
	}

	if ( exists( $c->stash->{new_user} ) and $c->stash->{new_user} ) {
	    try {
		# Try to send Mixpanel a message about this user does
		# stuff from the iPhone app.  This isn't perfect - it also
		# sends events when the user does logins through a
		# browser, but it's better than the no information we get
		# now.
		my $device_type = device_type( $c->req->browser );
		if ( ( $device_type eq 'iphone' ) || ( $device_type eq 'ipad' ) ) {
		    my $mp = WWW::Mixpanel->new( $c->config->{mixpanel_token} );
		    $mp->people_set( $c->user->obj->uuid(), '$email' => $c->user->obj->email(), '$created' => $c->user->obj->created_date() );
		}
	    } catch {
		my $exception = $_;
		$c->log->error( 'Failed to send mixpanel event for login.  Error was $exception. User was: ' . $c->user->obj->uuid() );
	    };
	}

	$self->status_ok( $c, { user => $c->user->obj } );
    } 
    else {
	# Lets try to create a more meaningful error message
	#
	if ( $creds->{email} ) {
	    my $code = "NOLOGIN_UNKNOWN";

	    if ( $c->config->{in_beta} ) {
		unless( $c->model( 'RDS::EmailUser' )->find({email => $email, status => 'whitelist'}) ) {
		    $code = "NOLOGIN_NOT_IN_BETA";
		}
	    }

	    if ( $c->model( 'RDS::EmailUser' )->find({email => $email, status => 'blacklist'}) ) {
		$code = "NOLOGIN_BLACKLISTED";
	    }

	    my @hits = $c->model( 'RDS::User' )->search({ email => $email });
	    if ( $#hits == -1 ) {
		$code = "NOLOGIN_EMAIL_NOT_FOUND";
	    }
	    else {
		$code = "NOLOGIN_PASSWORD_MISMATCH";
	    }

	    $self->status_unauthorized
		( $c, $self->authfailure_response( $c, $code ), $code );
	}
	else {
	    # This was a social oauth login attempt.  The plugin will need to communicate back to
	    # us via $c.  I've made custom hacks to the oauth plugins to ensure this.
	    if ( $c->{authfail_code} ) {
		$self->status_unauthorized
		    ( $c, $self->authfailure_response( $c, $c->{authfail_code} ), 
		      $c->{authfail_code} );
	    }
	    else {
		# we just don't know
		$self->status_unauthorized
		    ( $c, $self->authfailure_response( $c, "NOLOGIN_UNKNOWN" ),
		      "NOLOGIN_UNKNOWN" );
	    }
	}
    }
}

=head2 /services/na/logout

Log out of the current session.  

=head3 Response

 {}

=cut

sub logout :Local {
    my( $self, $c ) = @_;
    $c->logout();
    $self->status_ok
	( $c, {} );
}

=head2 /services/na/i18n

Obtain information about the current localization environment; the user's current
language and the languages available.

=head3 Response

An example response:

  {
   "guessed_locale" : "en",
   "current_language" : [
      "en"
   ],
   "user_session_language" : null,
   "installed_languages" : {
      "en" : "English",
      "sv" : "Swedish"
   }
  }

=cut

sub i18n :Local {
    my( $self, $c ) = @_;

    $self->status_ok
	( $c, 
	  { guessed_locale => $c->get_locale,
	    user_session_language => $c->session ? $c->session->{locale} : undef,
	    current_language => $c->languages(),
	    installed_languages => $c->installed_languages(),
	  } );
}

sub device_type : Private {
    my $d = shift;
    return 'android' if ( $d->android );
    return 'audrey' if ( $d->audrey );
    return 'avantgo' if ( $d->avantgo );
    return 'blackberry' if ( $d->blackberry );
    return 'dsi' if ( $d->dsi );
    return 'iopener' if ( $d->iopener );
    return 'iphone' if ( $d->iphone );
    return 'ipod' if ( $d->ipod );
    return 'ipad' if ( $d->ipad );
    return 'kindle' if ( $d->kindle );
    return 'n3ds' if ( $d->n3ds );
    return 'palm' if ( $d->palm );
    return 'webos' if ( $d->webos );
    return 'wap' if ( $d->wap );
    return 'psp' if ( $d->psp );
    return 'ps3' if ( $d->ps3 );
    return undef;
}

=head2 /services/na/device_info

Return what we know about the connecting device.  Can pass in a user-agent, or it defaults 
to the user-agent header.

=head3 Response

Example response (depends on user-agent):

  {
   "gecko_version" : null,
   "is_pspgameos" : null,
   "public_version" : 4,
   "engine_version" : null,
   "public_major" : "4",
   "mobile" : 1,
   "browser_string" : "Safari",
   "device_name" : "Android",
   "device_type" : "android",
   "is_windows" : null,
   "engine_string" : "KHTML",
   "robot" : null,
   "country" : "US",
   "language" : "EN",
   "user_agent" : "Mozilla/5.0 (Linux; U; Android 3.1; en-us; GT-P7310 Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 XXX/534.13",
   "engine_major" : null,
   "os_string" : "Linux",
   "device" : "android",
   "is_mac" : null,
   "public_minor" : ".0",
   "engine_minor" : null,
   "is_os2" : null,
   "is_ps3gameos" : null,
   "is_vms" : null,
   "is_unix" : 1,
   "is_dotnet" : null
  }

=cut

# DEPRECATED
sub device_info :Local {
    my( $self, $c ) = @_;
    my $d = $c->req->browser;

    $self->status_bad_request( $c, "services/mediafiles/device_info is deprecated." );

    if ( $c->req->param( 'user_agent' ) ) {
	# can over ride, for fun
	$d->user_agent( $c->req->param( 'user_agent' ) );
    }

    $self->status_ok
	( $c, 
	  { user_agent => $d->user_agent,
	    country => $d->country,
	    language => $d->language,
	    device => $d->device,
	    device_name => $d->device_name,
	    public_version => $d->public_version,
	    public_major => $d->public_major,
	    public_minor => $d->public_minor,
	    engine_string => $d->engine_string,
	    engine_version => $d->engine_version,
	    engine_major => $d->engine_major,
	    engine_minor => $d->engine_minor,
	    is_windows => $d->windows ? 1 : undef,
	    is_mac => $d->mac ? 1 : undef,
	    is_dotnet => $d->dotnet ? 1 : undef,
	    is_os2 => $d->os2 ? 1 : undef,
	    is_unix => $d->unix ? 1 : undef,
	    is_vms => $d->vms ? 1 : undef,
	    is_ps3gameos => $d->ps3gameos ? 1 : undef,
	    is_pspgameos => $d->pspgameos ? 1 : undef,
	    os_string => $d->os_string,
	    browser_string => $d->browser_string,
	    gecko_version => $d->gecko_version,
	    robot => $d->robot ? 1 : undef,
	    mobile => $d->mobile ? 1 : undef,
	    device_type => device_type( $d ),
	  } );
}

=head2 /services/na/invite_request

This is the first step in the process of adding a new user to the local database.  This
is a request to join.  The input parameters are email, password and username.  The username
parameter is optional, and defaults to a system-generated default.  It is mapped to
'displayname' in the user record.

If the email is valid and the password non-null, a random code is generated and an email
sent to the email address given with the code.  A PendingUser record is created in the
database to hold the email, password and code information.

The user is not logged in.  They must receive the code and enter it back into the
system with the matching email and password using the /services/na/new_user endpoint
to gain access to the system.

=head3 Response

A successful response will be

  { "username": $username }

which will be the username passed in, or the system-generated one if a username
was not supplied.

=cut

# DEPRECATED
sub invite_request :Local {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	    password => undef,
	    username => undef,
	  ],
	  @_ );

    $self->status_bad_request( $c, "services/mediafile/invite_request is deprecated." );


    unless( $args->{email} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'email' ) );
    }

    unless( $args->{password} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'password' ) );
    }

    my $username = $self->auto_username
	( $c, $args->{email}, $args->{username} );

    unless( $self->is_email_valid( $args->{email} ) ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Email address \'[_1]\' appears to be invalid.", $args->{email} ) );
    }

    my $existing = $c->model( 'RDS::User' )->find
	({ email => $args->{email} });
    if ( $existing ) {
	$self->status_bad_request
	    ( $c, $c->loc( "A user with email=\'[_1]\' already exists.", $args->{email} ) );
    }

    $existing = $c->model( 'RDS::PendingUser' )->find
	({ email => $args->{email} });
    if ( $existing ) {
	# Allow someone to re-invite
	$existing->delete;
    }

    # Looks good so far.  Create an invitation code ...
    # 
    my $code;
    do {
	$code = $self->invite_code;
	$existing = $c->model( 'RDS::PendingUser' )->find({ code => $code });
    } while( $existing );

    my $user = $c->model( 'RDS::PendingUser' )->create
	({ email => $args->{email},
	   password => $args->{password},
	   username => $username,
	   code => $code,
	 });
    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc("Server Error: Failed to create pending user!") );
    }

    # Send the invite
    #
    $c->log->debug( 'Sending email to ' . $args->{email} );

    $c->stash->{no_wrapper} = 1;
    $c->stash->{email} =
    { to       => $args->{email},
      from     => $c->config->{viblio_return_email_address},
      subject  => $c->loc( "Invitation to join VIBLIO" ),
      template => 'email/invitation.tt'
    };
    $c->stash->{user} = $user;
    $c->forward( $c->view('Email::Template') );

    if ( scalar( @{ $c->error } ) ) {
	# Sending email failed!  
	# The error will get properly communicated in the end() method,
	# so we just need to clean up.
	$c->log->debug( "SENDMAIL PROBLEM" );
	$user->delete;
    }
    else {
	$self->status_ok( $c, { username => $username } );
    }
}



=head2 /services/na/new_user_no_password

Supports a new API to create a user account with just an email address.

=head3 Response

  { "user": $user }

=cut

sub new_user_no_password :Local {
    my $self = shift;
    my $c = shift;

    my $result = $self->_new_user_no_password( $c, @_ );
    if ( $result->{ok} ) {
	$self->status_ok( $c, $result->{response} );
    } else {
	$self->status_bad_request( $c, $result->{response}, $result->{detail} );
    }
}


sub _new_user_no_password :Private {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	    realm => 'db',
	    via => 'trayapp',
	    try_photos => 0,
	    creation_reason => undef
	  ],
	  @_ );

    if ( $self->is_email_valid( $args->{email} ) ) {
	my $username = ( $args->{email} =~ m/^(.*?)@/ )[0];
	my $password = $self->invite_code();

	return $self->_new_user( $c, $args->{email}, $password, $username, $username, $args->{realm}, $args->{via}, $password, $args->{try_photos}, $args->{creation_reason} );
    } else {
	my $code = "NOLOGIN_INVALID_EMAIL";
	return { 'ok' => 0,
		 'response' => $self->authfailure_response( $c, $code ),
		 'detail' => $code };
    }
}

=head2 /services/na/new_user

This is the companion endpoint to /services/na/invite_request.  Once the user
obtains a random invite code, this endpoint is called with email and password
used in invite_request, along with the code obtained from the email.  A username
parameter may also be passed, and if present, overrides the previous username
value in the PendingUser record.

If the email, password and code parameters match a PendingUser record, that
record becomes the basis for a User record and the user is logged into the system.
The caller may redirect into the application.

=head3 Response

  { "user": $user }

=cut

sub new_user :Local {
    my $self = shift;
    my $c = shift;
    my $result = $self->_new_user( $c, @_ );

    if ( $result->{ok} ) {
	$self->status_ok( $c, $result->{response} );
    } else {
	$self->status_bad_request( $c, $result->{response}, $result->{detail} );
    }
}

sub _new_user :Private {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	    password => undef,
	    username => undef,
	    displayname => undef,
	    realm => 'db',
	    via => 'trayapp',
	    no_password => 0,
	    try_photos => 0,
	    creation_reason => undef
	  ],
	  @_ );

    my $creds = {};
    my $dbuser;

    if ( $args->{realm} eq 'db' ) {
	unless( $args->{email} ) {
	    my $code = "NOLOGIN_MISSING_EMAIL";
	    return { 'ok' => 0,
		     'response' => $self->authfailure_response( $c, $code ),
		     'detail' => $code };
	}

	$args->{displayname} = $args->{username} unless( $args->{displayname} );
	$args->{displayname} = $self->displayname_from_email( $args->{email} ) unless( $args->{displayname} );
	$args->{displayname} = $args->{email} unless( $args->{displayname} );

	$args->{displayname} = $self->sanitize( $c, $args->{displayname} );

	unless( $args->{password} ) {
	    my $code = "NOLOGIN_MISSING_PASSWORD";
	    return { 'ok' => 0,
		     'response' => $self->authfailure_response( $c, $code ), 
		     'detail' => $code };
	}

	my @hits = $c->model( 'RDS::User' )->search({ email => $args->{email} });
	if ( $#hits >= 0 ) {
	    my $code = "NOLOGIN_EMAIL_TAKEN";
	    return { 'ok' => 0,
		     'response' => $self->authfailure_response( $c, $code ),
		     'detail' => $code  };
	}

	if ( $c->config->{in_beta} ) {
	    unless( $c->model( 'RDS::EmailUser' )->find({email => $args->{email}, status => 'whitelist'}) ) {
		my $code = "NOLOGIN_NOT_IN_BETA";
		return { 'ok' => 0,
			 'response' => $self->authfailure_response( $c, $code ), 
			 'detail' => $code };
	    }
	}

	if ( $c->model( 'RDS::EmailUser' )->find({email => $args->{email}, status => 'blacklist'}) ) {
	    my $code = "NOLOGIN_BLACKLISTED";
	    return { 'ok' => 0,
		     'response' => $self->authfailure_response( $c, $code ), 
		     'detail' => $code };
	}

	$dbuser = $c->model( 'RDS::User' )->create
	    ({ email => $args->{email},
	       password => $args->{password},
	       displayname => $args->{displayname},
	       accepted_terms => 1,
	     });

	unless( $dbuser ) {
	    $c->log->error( "new_user: Failed to create new user for $args->{email}" );
	    my $code = "NOLOGIN_DB_FAILED";
	    return { 'ok' => 0,
		     'response' => $self->authfailure_response( $c, $code ), 
		     'detail' => $code };
	}

	$creds = {
	    email => $dbuser->email,
	    password => $args->{password} 
	};
    }

    if ( $c->authenticate( $creds, $args->{realm} ) ) {
	$self->new_user_helper( $c, $args );
	return { 'ok' => 1,
		 'response' => { user => $c->user->obj } };
    }
    else {
	$dbuser->delete if ( $dbuser );
	$c->log->error( "new_user: Failed to create new user for $args->{email}" );
	my $code = "NOLOGIN_DB_FAILED";
	return { 'ok' => 0,
		 'response' => $self->authfailure_response( $c, $code ), 
		 'detail' => $code };
    }
}

sub new_user_helper :Private {
    my $self = shift;
    my $c    = shift;
    my $args = shift;

    my $user = $c->user->obj;
    $user->provider( ( $args->{realm} eq 'db' ? 'local' : $args->{realm}) ); $user->update;
    
    # Create a profile - note authentication may have already
    # created a profile if the user came in via facebook.
    if ( ! $user->profile ) {
	$user->create_profile();
    }
    
    # Create an access token for use with the 'viblio' authenticator
    $user->access_token(
	lc( Data::UUID->new->create_from_name_str( 'com.viblio', $user->email ) ) );
    $user->update;
    
    # There may be a "pending user" record corresponding to this email.
    # If there is, in media_shares table, replace all 'private' shares
    # with pending user id with this new user's id.
    my $pending_user = $c->model( 'RDS::User' )->find({ provider_id => 'pending', displayname => $args->{email} });
    if ( $pending_user ) {
	foreach my $share ( $c->model( 'RDS::MediaShare' )->search({ share_type => 'private', user_id => $pending_user->id }) ) {
	    $share->user_id( $user->id );
	    $share->update;
	}
	$pending_user->delete;
	$pending_user->update;
    }
    
    # Contact records consist of an email address and an optional pointer
    # to a real viblio user.  A person registering as the result of a email
    # share will be a contact, but the viblio user pointer is currently NULL.
    # Lets fix that now.
    #
    my $update_rs = $c->model( 'RDS::Contact' )->search({ contact_email => $user->email });
    $update_rs->update({ contact_viblio_id => $user->id });
    
    # Create some default albums for this account.
    try {
	my $new_user_albums = [ { name => 'Using VIBLIO', s3_key => 'media/default-images/DEFAULT-poster.png', mimetype => 'image/png' },
				{ name => 'Birthdays', s3_key => 'media/default-images/BIRTHDAY-poster.jpg' },
				{ name => 'Family', s3_key => 'media/default-images/FAMILY-poster.jpg' },
				{ name => 'Friends', s3_key => 'media/default-images/FRIENDS-poster.jpg' },
				{ name => 'Holidays', s3_key => 'media/default-images/HOLIDAY-poster.jpg' },
				{ name => 'Vacations', s3_key => 'media/default-images/VACATION-poster.jpg' }
	    ];

	my $ug = new Data::UUID;

	foreach my $new_user_album ( @$new_user_albums ) {
	    my $name = $new_user_album->{name};
	    my $s3_key = $new_user_album->{s3_key};
	    my $s3_bucket = 'viblio-external';
	    my $mimetype = 'image/jpeg';
	    if ( exists( $new_user_album->{mimetype} ) ) {
		$mimetype = $new_user_album->{mimetype};
	    }
	    my $uuid =  $ug->create();
	    VA::Controller::Services::Album->new()->create_album_helper( $c, $name, $ug->to_string( $uuid ), 1, { s3_bucket => $s3_bucket, s3_key => $s3_key, mimetype => $mimetype, width => 288, height => 216 } );
	}
    } catch {
	$c->log->error( "Failed to create welcome default albums, error was: $_" );
    };

    # Send a SQS message for this new account creation
    try {
	$c->log->debug( 'Sending SQS message for new account' );
	my $sqs = $c->model( 'SQS', $c->config->{sqs}->{new_account_creation} )
	    ->SendMessage( to_json({
		user_uuid => $user->uuid,
		action => 'welcome_video' }) );
    } catch {
	$c->log->error( "Failed to send welcome_video SQS message: $_" );
    };

    
=perl
	# And finally, send them a nice welcome email
	#
	$self->send_email( $c, {
	    subject => $c->loc( "VIBLIO Account Confirmation" ),
	    to => [{
		email => $user->email,
		name  => $user->displayname }],
	    template => 'email/03-accountConfirmation.tt',
	    stash => {
		url => $c->server . '#confirmed?uuid=' . $user->uuid,
	    }});
=cut

    my $template = 'email/04-07-accountCreated.tt';
    my $model = { user => $user };
    my $subject = 'Welcome to VIBLIO';

    if ( $args->{no_password} && $args->{try_photos} ) {
	$subject = 'The first step to easy photos!';
	$template = 'email/26-01-photoFinder.tt';

	if ( defined( $args->{no_password} ) && $args->{no_password} ) {
	    $user->metadata( $args->{no_password} );
	    $user->update();
	}
    } elsif ( $args->{no_password } ) {
	$template = 'email/04-08-no_pw_accountCreated.tt';
	$model->{password} = $args->{no_password};
	$model->{provider} = $user->{_column_data}->{provider};
    }

    # Send an instructional email too.
    $self->send_email( $c, {
	subject => $c->loc( $subject ),
	to => [{
	    email => $user->email,
	    name  => $user->displayname }],
	template => $template,
	stash => {
	    model => $model
	}});

    # Handle Mixpanel and email notifications for user creation.
    my $creation_reason = "iPhone";
    if ( defined( $args->{creation_reason} ) and $args->{creation_reason} ) {
	$creation_reason = $args->{creation_reason};
    }
    try {
	my $mp = WWW::Mixpanel->new( $c->config->{mixpanel_token} );
	$mp->people_set( $c->user->obj->uuid(), "creation_reason" => $creation_reason );
    } catch {
	my $exception = $_;
	$c->log->error( 'Failed to send mixpanel event for account creation.  Error was $exception. User was: ' . $c->user->obj->uuid() );
    };
    # Send a notification email.
    try {
	$self->send_email( $c, {
	    subject => "New user created via $creation_reason - " . $c->user->email(),
	    from => {
		email => 'notifications@viblio.com',
		name => 'VIBLIO'
	    },
		    to => [ { email => 'notifications@viblio.com' } ],
		    body => "New user created via $creation_reason - " . $c->user->email(),
		    stash => {
			from => 'notifications@viblio.com',
			model => {}
		}
			   } );
    } catch {
	$c->log->error( 'Failed to send account creation notification email.  Error was $exception. User was: ' . $c->user->obj->uuid() );

    };

}


=head2 /services/na/account_confirm

This endpoint sets the confirm bit in the passed in user's account, and
sends them another email welcoming them to viblio.

=cut

sub account_confirm :Local {
    my( $self, $c ) = @_;
    my $uuid = $c->req->param( 'uuid' );
    unless( $uuid ) {
	$self->status_bad_request( $c, $c->loc( 'Missing required parameter: [_1]', 'uuid' ) );
    }
    my $user = $c->model( 'RDS::User' )->find({uuid => $uuid});
    unless( $user ) {
	$c->log->error( "Account confirm: cannot find a record for $uuid" );
	$self->status_not_found( $c, $c->loc( 'Cannot find user for uuid: [_1]', $uuid ), $uuid );
    }
    $user->confirmed( 1 ); $user->update;

    my $headers = {
	subject => $c->loc( "Welcome to VIBLIO" ),
	to => [{
	    email => $user->email,
	    name  => $user->displayname }],
	template => 'email/03-accountConfirmation.tt',
	stash => {
	    to => $user,
	    url => $c->server,
	    model => {
		user => $user,
	    }
	}
    };
    $self->send_email( $c, $headers );
    $self->status_ok( $c, { user => $user } );
}

=head2 /services/na/forgot_password_request

If the user forgets their password, this endpoint can be called with a 'email'
parameter.  An email is sent to the email address given with a code.

=head3 Response

  { "user" : $user }

=cut

sub forgot_password_request :Local {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	  ],
	  @_ );

    unless( $args->{email} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "email" ) );
    }

    my $user = $c->model( 'RDS::User' )->find({ email => $args->{email} });

    # Design team wants to ignore this error and let the user think they
    # sent an email.  I guess when it does not arrive, they'll try again.
    unless( $user ) {
	$self->status_ok( $c, {} );
    }

    my $code = $self->invite_code();

=perl    
    Doing a simplified version of this now, by sending out a new password
    and resetting right here.

    my $rec = $c->model( 'RDS::PasswordReset' )
	->find_or_create({ email => $args->{email},
			   code  => $code });
    unless( $rec ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to create record: [_1]", 'RDS::PasswordReset' ) );
    }
=cut
    my $email= { 
	subject  => $c->loc( "Reset your password on VIBLIO" ),
	to => [{
	    email => $args->{email} }],
	template => 'email/18-forgotPassword.tt',
	stash => {
	    new_password => $code,
	    user => $user,
	}
    };
    $self->send_email( $c, $email );
    $user->password( $code );
    $user->update;
    $self->status_ok( $c, { user => $user } );
}

=head2 /services/na/new_password

Once the forgetting user receives a code in email, they can pass email, the new password and the
code to this endpoint.  If everything matches, the password will be changed and the user will be logged in.

=head3 Response

  { "user" : $user }

=cut

# DEPRECATED
sub new_password :Local {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	    password => undef,
	    code     => undef,
	  ],
	  @_ );

    $self->status_bad_request( $c, "services/na/new_password is deprecated." );

    unless( $args->{email} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "email" ) );
    }

    unless( $args->{password} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "password" ) );
    }

    unless( $args->{code} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "code" ) );
    }

    my $user = $c->model( 'RDS::User' )->find({ email => $args->{email} });
    unless( $user ) {
	$self->status_not_found
	    ( $c, $c->loc( "Cannot find user for [_1]", $args->{email} ), $args->{email} );
    }

    my $rec = $c->model( 'RDS::PasswordReset' )->find({ email => $args->{email} });
    unless( $rec ) {
	$self->status_not_found
	    ( $c, $c->loc( "Cannot find password reset record for [_1]", $args->{email} ), $args->{email} );
    }

    unless( $rec->code eq $args->{code} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Reset code does not match record." ) );
    }

    $user->password( $args->{password} ); 
    $user->update;

    if ($c->authenticate({ email    => $user->email,
			   password => $args->{password}  }, 'db' )) {
	$rec->delete;
	$self->status_ok( $c, { user => $c->user->obj } );
    }
    else {
	$self->status_forbidden
	    ( $c, $c->loc( "Unable to authenticate user with new password." ) );
    }
}

=head2 /services/na/workorder_processed

When a workorder is complete, this is the endpoint that should be called.  It is
meant to be called from the Amazon SNS bus.  

This is meant to be called as a POST with a workorder structure as JSON in the
request body.

This routine attempts to reconcile the incoming workorder changes with the
original, creating new media files and modifying existing media files as
indicated in the incoming workorder.

When it is done, it will call workorder_done() to send async notification to
the user that originally sent the workorder to be processed.

=cut

# DEPRECATED
sub workorder_processed :Local {
    my( $self, $c ) = @_;
    my $incoming = $c->{data};

    $self->status_bad_request( $c, "services/na/workorder_processed is deprecated." );

    if ( $incoming->{error} ) {
	$c->log->error( "The incoming workorder was marked errored" );
	$c->logdump( $incoming );

	$self->workorder_done( $c, undef, $incoming );
	$self->status_ok( $c, {} );
    }

    if ( ! $incoming->{wo} ) {
	$c->log->error( "No wo field found in WO" );
	$self->workorder_done( $c, undef, {
	    error => 1,
	    message => "No 'wo' field found in incoming!" } );
	$self->status_ok( $c, {} );
    }

    my $wo = $c->model( 'RDS::Workorder' )->find({ uuid => $incoming->{wo}->{uuid} });
    unless( $wo ) {
	$c->log->error( "Could not obtain db record for $incoming->{wo}->{uuid}" );
	$self->workorder_done( $c, undef, {
	    error => 1,
	    message => "Could not find wo id=" .  $incoming->{wo}->{uuid} } );
	$self->status_ok( $c, {} );
    }

    # The user is the user associated with the workorder.  Downstream
    # methods expect a $c->user, but this is not an authenticated
    # endpoint!  So ...
    $c->user( $wo->user );

    # Check the security token
    if ( ! $incoming->{wo}->{'site-token'} ) {
	$c->log->error( "Incoming wo is missing the site-token field." );
	$self->workorder_done( $c, $wo->user->uuid, {
	    error => 1,
	    message => "Missing authentication handshake parameters." } );
	$self->status_ok( $c, {} );
    }

    if ( $c->secure_token( $wo->user->uuid ) ne $incoming->{wo}->{'site-token'} ) {
	$c->log->error( "Incoming wo authentication failure." );
	$self->workorder_done( $c, $wo->user->uuid, {
	    error => 1,
	    message => "Authentication failure." } );
	$self->status_ok( $c, {} );
    }

    my $user_id = $wo->user_id;
    my $mediafiles = $wo->media->search({}, {prefetch => 'assets'}); # rs so its searchable
    my @infiles = @{$incoming->{media}};

    my $exception;
    my @to_delete = ();
    try {
        $c->model( 'DB' )->schema->txn_do( 
	    sub {
		foreach my $infile ( @infiles ) {
		    my $mediafile;
		    if ( ! $infile->{uuid} ) {
			# This is a new media file
			$mediafile = $c->model( 'RDS::Media' )->create({
			    user_id => $user_id,
			    filename => $infile->{filename} });
			$mediafile->add_to_workorders( $wo );
		    }
		    else {
			$mediafile = $mediafiles->find({ uuid => $infile->{id} });
		    }
		    
		    foreach my $key ( keys( %{$infile->{views}} ) ) {
			my $inview = $infile->{views}->{$key};
			my $view = $mediafile->asset( $key );
			if ( ! $view ) {
			    # This is a new view
			    $mediafile->create_related( 'assets', {
				location => $inview->{location},
				mimetype => $inview->{mimetype},
				uri => $inview->{uri},
				size => $inview->{size},
				asset_type => $key,
				filename => $inview->{filename} || $infile->{filename} });
			}
			else {
			    # existing view

			    if ( $key eq 'main' ) {
				my $location = $view->location;
				if ( $location ) {
				    push( @to_delete, VA::MediaFile->publish( $c, $mediafile ) );
				}
			    }

			    $view->location( $inview->{location} );
			    $view->uri( $inview->{uri} );
			    $view->size( $inview->{size} );
			    $view->mimetype( $inview->{mimetype} );
			    $view->filename( $inview->{filename} || $infile->{filename} );
			    $view->update;
			}
		    }

		    $mediafile->filename( $infile->{filename} );
		    $mediafile->media_type( $infile->{type} );
		    $mediafile->update;
		}

		# Update the workorder state
		$wo->state( 'WO_COMPLETE' );
		$wo->completed( DateTime->now );
		$wo->update;
	    });
    } catch {
	$exception = $_;
    };
    
    if ( $exception ) {
	$c->log->error( "Exception processing incoming wo: $exception" );
	$self->workorder_done( $c, $wo->user->uuid, {
	    error => 1,
	    message => 'Failed to process incoming workorder.' });
	$self->status_ok( $c, {} );
    }
    else {
	foreach my $mf ( @to_delete ) {
	    new VA::MediaFile->delete( $c, $mf );
	}
	$self->workorder_done( $c, $wo->user->uuid, $wo->TO_JSON );
	$self->status_ok( $c, {} );
    }
}

# DEPRECATED
sub workorder_done :Private {
    my( $self, $c, $uuid, $wo ) = @_;

    $self->status_bad_request( $c, "services/na/workorder_done is deprecated." );

    $c->log->debug( "WORKORDER DONE" );

    if ( $uuid ) {
	# Queue it up in the user message queue, or send a push notification.
	# We'd like to distinguish between iOS clients and web clients so
	# we only deliver the message once.  How?
	my $res = $c->model( 'MQ' )->post( '/enqueue', { uid => $uuid,
							 type => 'new_wo',
							 wo  => $wo } );
	if ( $res->code != 200 ) {
	    $c->log->error( "Failed to post wo to user message queue! Response code: " . $res->code );
	    $c->logdump( { uid => $uuid,
			   wo  => $wo } );
	}
    }
    else {
	# No one to send it to!
	$c->log->error( "WO: TOTAL FAILURE! No one to send the WO to." );
    }
}

# DEPRECATED
sub test_secure_token :Local {
    my( $self, $c, $uid, $mid, $site_token ) = @_;

    $self->status_bad_request( $c, "services/mediafile/test_secure_token is deprecated." );

    $uid = $c->req->param( 'uid' ) unless( $uid );
    $site_token = $c->req->param( 'site-token' ) unless( $site_token );
    if ( $c->secure_token( $uid ) ne $site_token ) {
	$c->log->error( "mediafile_create() authentication failure: calculated(" . $c->secure_token( $uid ) . ") does not match $site_token" );
	$self->status_forbidden( $c, 'mediafile_create() authentication failure.' );
    }
    $self->status_ok( $c, {} );
}

# This is the endpoint called by the video processor when a new
# video has been uploaded and processed.  We need to notify the 
# web gui and the tray app that this event has occurred.  
#
# This is a protected endpoint.
#
sub mediafile_create :Local {
    my( $self, $c, $uid, $mid, $site_token ) = @_;
    $uid = $c->req->param( 'uid' ) unless( $uid );
    $mid = $c->req->param( 'mid' ) unless( $mid );
    $site_token = $c->req->param( 'site-token' ) unless( $site_token );

    unless( $uid && $mid && $site_token ) {
	$self->status_bad_request( $c, 'Missing one or more of uid, mid, site-token params' );
    }

    unless( $site_token eq 'maryhadalittlelamb' ) {
	if ( $c->secure_token( $uid ) ne $site_token ) {
	    $c->log->error( "mediafile_create() authentication failure: calculated(" . $c->secure_token( $uid ) . ") does not match $site_token" );
	    $self->status_forbidden( $c, 'mediafile_create() authentication failure.' );
	}
    }

    my $user = $c->model( 'RDS::User' )->find({uuid=>$uid});
    if ( ! $user ) {
	$self->status_not_found( $c, 'Cannot find user for $uid', $uid );
    }

    my $mediafile = $user->media->find({ uuid => $mid });
    unless( $mediafile ) {
	$self->status_not_found( $c, 'Cannot find media for $mid', $mid );
    }

    ## Do the geo location stuff here, as the videos arrive
    my $lat = $mediafile->lat;
    my $lng = $mediafile->lng;
    if ( $lat && $lng && $lat != 0 && $lng != 0 ) {
	my $info = GeoData::get_data( $c, $lat, $lng );
	if ( $info->{city} && $info->{address} ) {
	    $mediafile->geo_address( $info->{address} );
	    $mediafile->geo_city( $info->{city} );
	    $mediafile->update;
	}
    }

    my $mf = VA::MediaFile->new->publish( $c, $mediafile, { include_contact_info => 1, expires => (60*60*24*365) } );

    ### FOR NOW, LIMIT ANY EMAILS TO THE FIRST FEW VIDEOS UPLOADED
    ### TO THE ACCOUNT
    my $rs = $user->media->search( $self->where_valid_mediafile( undef, undef, 1, 1 ) );
    if ( $rs->count == 5 ) {

	if ( $user->profile->setting( 'email_notifications' ) &&
	     $user->profile->setting( 'email_upload' ) ) {

	    # Send email notification
	    #
	    $c->log->debug( 'Sending email to ' . $user->email );

	    my $email = {
		subject    => $c->loc( "Your VIBLIO Video is Ready" ),
		to => [{
		    email => $user->email,
		    name  => $user->displayname }],
		template => 'email/05-youveGotVideos.tt',
		stash => {
		    user => $user,
		    media => $mf,
		    server => $c->server,
		    model => {
			media => [ $mf ],
		    }
		}
	    };
	    $self->send_email( $c, $email );
	}
    }

    # Send message queue notification
    #
    my $res = $c->model( 'MQ' )->post( '/enqueue', { uid => $uid,
						     type => 'new_video',
						     media  => $mf } );
    if ( $res->code != 200 ) {
	$c->log->error( "Failed to post wo to user message queue! Response code: " . $res->code );
    }

    # Mobile push notifications
    foreach my $dev ( $user->user_devices->all ) {
	$dev->badge_count( $dev->badge_count + 1 );
	my $options = {
	    network => $dev->network,
	    message => 'A new video is ready to share!',
	    badge => $dev->badge_count,
	    sound => 'default',
	    custom => {
		type => 'NEWVIDEO',
		uuid => $mediafile->uuid,
	    }
	};
	$self->push_notification( $c, $dev->device_id, $options );
	$dev->update;
    }

    $self->status_ok( $c, {} );
}


# This endpoint is called when we have created a Facebook resource on
# behalf of our user.
#
# This is a protected endpoint.
#
sub create_fb_album :Local {
    my( $self, $c, $uid, $mid, $site_token ) = @_;
    $uid = $c->req->param( 'uid' ) unless( $uid );
    $mid = $c->req->param( 'mid' ) unless( $mid );
    $site_token = $c->req->param( 'site-token' ) unless( $site_token );

    unless( $uid && $mid && $site_token ) {
	$self->status_bad_request( $c, 'Missing one or more of uid, mid, site-token params' );
    }

    unless( $site_token eq 'maryhadalittlelamb' ) {
	if ( $c->secure_token( $uid ) ne $site_token ) {
	    $c->log->error( "mediafile_create() authentication failure: calculated(" . $c->secure_token( $uid ) . ") does not match $site_token" );
	    $self->status_forbidden( $c, 'mediafile_create() authentication failure.' );
	}
    }

    my $user = $c->model( 'RDS::User' )->find({uuid=>$uid});
    if ( ! $user ) {
	$self->status_not_found( $c, 'Cannot find user for $uid', $uid );
    }

    my $mediafile = $user->media->find({ uuid => $mid });
    unless( $mediafile ) {
	$self->status_not_found( $c, 'Cannot find media for $mid', $mid );
    }
    my $asset = $mediafile->assets->first( { asset_type => 'fb_album' } );

    if ( $user->profile->setting( 'email_notifications' ) ) {
	# Send email notification
	#
	$c->log->debug( 'Sending email to ' . $user->email );
	my $email = {
	    subject    => $c->loc( "Your Facebook Photo Album is Ready" ),
	    to => [{
		email => $user->email,
		name  => $user->displayname }],
	    template => 'email/22-fbAlbumCreated.tt',
	    stash => {
		user => $user,
		server => $c->server,
		model => {
		    media => $mediafile,
		    media_asset => $asset
		}
	    }
	};
	$self->send_email( $c, $email );
    }

    # Send message queue notification
    #
    # DEBUG - IN THE FUTURE HAVE A SLIDE OUT OR SOMETHING FOR THIS!
    #my $res = $c->model( 'MQ' )->post( '/enqueue', { uid => $uid,
    #						     type => 'new_video',
    #						     media  => $mf } );
    #if ( $res->code != 200 ) {
    #	$c->log->error( "Failed to post wo to user message queue! Response code: " . $res->code );
    #}

    $self->status_ok( $c, {} );
}



=head2 /services/na/incoming_email

This is a "webhook" used my the Mailchip/Mandrill email delivery service to
deliver mail that was sent in response to a reply from an email we sent. See

  http://help.mandrill.com/categories/20102127-Inbound-Email-Processing

for details about inbound processing and the format of the incoming data.

We have (or might have) various email Reply-To's that we use for different
emails that go out.  

  reply@support.viblio.com

is used to send out general notifications that are not really meant to be
replied to, but handling them is better than bouncing back to the user!

  help@support.viblio.com
  feedback@support.viblio.com

This handler below is used to route reply, or help, or feedback to the 
appropriate destination; the database, the log, or even sending an email
to someone.

Although this endpoint is unauthenticated, it is protected by using Mandrill
webhook authentication (see http://help.mandrill.com/entries/23704122-Authenticating-webhook-requests).
This is meant to ensure that anything coming in this way is definitely from
Mailchimp/Mandrill.

=cut

sub incoming_email :Local {
    my( $self, $c ) = @_;

    unless( $c->model( 'Mandrill' )->authenticate( $c ) ) {
	$c->log->error( "mailchimp: authentication failure" );
	$self->status_ok( $c, {} );
    }

    my $content = $c->req->body_params->{'mandrill_events'};
    if ( $content ) {
	try {
	    my $json = from_json( $content );
	    my @messages = ();
	    if ( ref $json eq 'ARRAY' ) {
		@messages = @$json;
	    }
	    else {
		push( @messages, $json );
	    }
	    foreach my $message ( @messages ) {
		if ( $message->{msg} ) {
		    my $m = $message->{msg};
		    $c->log->debug( "mailchip: from:    $m->{from_email}" );
		    $c->log->debug( "mailchip: subject: $m->{subject}" );
		    $c->log->debug( "mailchip: message: \n$m->{text}" );

		    my @addrs = Email::Address->parse( ${$m->{to}}[0][0] );
		    if ( $#addrs >= 0 ) {
			my $name = $addrs[0]->name;
			$c->log->debug( "mailchimp: TO: $name" );
			#
			# $name tells us where this is directed.  It
			# might be 'reply' or 'help', or 'feedback' or
			# something like that.  From this tag we'd probably
			# want to route this message somewhere ... to the
			# database, log files, or maybe send some email.
			#

			# feedback will be stored as a github issue
			# on the viblio-server repo.
			try {
			    # Authenticate with an access token
			    my $gh = Net::GitHub::V3->new(
				access_token => $c->config->{github}->{access_token} );
			    my $issue = $gh->issue;
			    # Set the default repo to operate on
			    $issue->set_default_user_repo( 
				'viblio',
				$c->config->{github}->{repo} );
			    # Create the issue
			    my $i = $issue->create_issue({
				title => $m->{subject},
				body  => $m->{from_email} . "\n\n" . $m->{text},
				assignee => $c->config->{github}->{owner},
				labels => [ 'pending' ],
				milestone => 1 });
			}
			catch {
			    $c->log->error( "Incoming email from feeback, failure to save to github: $_" );
			};
		    }
		}
		else {
		    $c->log->error( "Mailchimp incoming email: No {msg}" );
		}
	    }
	} catch {
	    $c->log->error( "Mailchimp incoming email: $_" );
	};
    }
    else {
	$c->log->error( "Mailchimp incoming email: No body params" );
	$c->logdump( $c->req->body );
    }

    $self->status_ok( $c, {} );
}

=head2 /services/na/media_shared

This is the endpoint that is called when someone views a media file that has
been shared.

=cut

sub media_shared :Local {
    my $self = shift;
    my $c = shift;
    my $result = $self->_media_shared( $c, @_ );
    if ( $result->{ok} ) {
	$self->status_ok( $c, $result->{response} );
    } else {
	$self->status_bad_request( $c, $result->{response} );
    }
}

sub _media_shared :Private {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $preview = $c->req->param( 'preview' );

    # Is caller logged in?
    my $user = $c->user;
    
    if ( !defined( $user ) && exists( $c->stash->{user_obj} ) && defined( $c->stash->{user_obj} ) ) {
	# We are being called by an internal process, to act as if
	# this user has viewed the video in question.
	$user = $c->stash->{user_obj};
    }

    my $mediafile = $c->model( 'RDS::Media' )->find({ uuid => $mid }, {prefetch => 'user'});
    unless( $mediafile ) {
	return { 'ok' => 0,
		 'response' => $c->loc( "Cannot find media for uuid=[_1]", $mid ) };
    }

    # FOR TESTING
    if ( $c->req->param( 'share_type' ) && $c->req->param( 'secret' ) ) {
	if ( $c->req->param( 'secret' ) eq 'Viblio2013' ) {
	    my $mf = VA::MediaFile->new->publish( $c, $mediafile, { include_tags => 1 } );
	    return { 'ok' => 1,
		     'response' => { share_type => $c->req->param( 'share_type' ),
				    media => $mf, owner => $mediafile->user->TO_JSON } }; 
	}
	else {
	    return { 'ok' => 0,
		     'response' => $c->loc( 'Bad secret passed' ) };
	}
    }

    # If the user is logged in and its their video, show it
    if ( $user && $mediafile->user_id == $user->id ) {
	# They own it
	$c->log->debug( "SHARE: OWNED BY USER" );
	my $mf = VA::MediaFile->new->publish( $c, $mediafile, { include_tags => 1 } );
	return { 'ok' => 1,
		 'response' => { share_type => "owned_by_user", 
				 media => $mf, owner => $mediafile->user->TO_JSON } };
    }

    # If the user is logged in and they can see the video because
    # of a shared album membership, show it
    if ( $user && $user->can_view_video( $mediafile->uuid ) ) {
	# increment the view count
	$mediafile->view_count( $mediafile->view_count + 1 ) unless( $preview );
	$mediafile->update;
	my $mf = VA::MediaFile->new->publish( $c, $mediafile, { include_tags => 1 } );
	return { 'ok' => 1,
		 'response' => { share_type => 'private', 
				 media => $mf, 
				 owner => $mediafile->user->TO_JSON } };
    }

    # Gather all of the media_shares ...
    my @shares = $mediafile->media_shares;

    if ( $#shares == -1 ) {
	# Its private
	return { 'ok' => 0,
		 'response' => $c->loc( 'This mediafile is private.' ) };
    }

    my $is = {};
    $is->{$_->{_column_data}->{share_type}} = 1 foreach @shares;
    my $share_type;

    # possible values: private, hidden, public
    my $OK = 0;

    # A media file can have multiple shares.  If it has both hidden/public
    # and private, the hidden/public view will take precedence.  But if the
    # use is logged in, we can look a bit closer to see if this is a private
    # share specifically targeted to him, and show a private view.
    if ( $is->{private} && $user ) {
	my $share = $mediafile->media_shares->find({ 
	    share_type => 'private', 
	    user_id => $user->id });
	if ( $share ) {
	    $share->view_count( $share->view_count + 1 ) unless( $preview );
	    $share->update;
	    $share_type = "private";
	    $OK = 1;
	}
    }

    if ( $OK == 0 && ($is->{public} || $is->{hidden}) ) {
	my $found = 'public';
	if ( $is->{hidden} ) {
	    $found = 'hidden';
	}
	# In this case, we do not know how they got here.  If it has a hidden
	# share, then we care more about this method for tracking.  
	my $share = $mediafile->media_shares->search( { share_type => $found } )->first();
	if ( $share ) {
	    $share->view_count( $share->view_count + 1 ) unless( $preview );
	    $share->update;
	}

	# NEW CODE.  So that public/hidden shares visited by a logged in viblio
	# user will be remembered and shown on the user's SHARE page, add a hidden
	# share with this user's id
	if ( $user ) {
	    $mediafile->find_or_create_related( 'media_shares', { 
		user_id => $user->id,
		share_type => 'hidden',
		view_count => 0 });
	}

	$share_type = $found;
	$OK = 1;
    }
    elsif ( $OK == 0 && $is->{private} ) {
	$share_type = "private";
	if ( $user ) {
	    my $share = $mediafile->media_shares->find({ 
		share_type => 'private', 
		user_id => $user->id });
	    if ( $share ) {
		$share->view_count( $share->view_count + 1 ) unless( $preview );
		$share->update;
		$OK = 1;
	    }
	}
	else {
	    # This is a private share, but the user coming in is not
	    # authenticated.  Return an indication that this user needs
	    # to be prompted to either log in or create an account.
	    return { 'ok' => 1,
		     'response' => { auth_required => 1 } };
	}
    }

    if ( $OK ) {
	# increment the view count
	$mediafile->view_count( $mediafile->view_count + 1 ) unless( $preview );
	$mediafile->update;

	my $mf = VA::MediaFile->new->publish( $c, $mediafile, { include_tags => 1 } );
	return { 'ok' => 1,
		 'response' => { share_type => $share_type, media => $mf, owner => $mediafile->user->TO_JSON } };
    }
    else {
	return { 'ok' => 0,
		 'response' => $c->loc( "You are not authorized to view this media." ) };
    }
}

sub terms :Local {
    my( $self, $c ) = @_;
    $c->stash->{no_wrapper} = 1;
    my $terms = $c->view( 'HTML' )->render( $c, 'terms.tt' );
    $self->status_ok( $c, { terms => $terms } );
}

sub valid_email :Local {
    my( $self, $c ) = @_;
    my $email = $c->req->param( 'email' );
    my $valid = 0;
    my $why = 'No email address supplied';
    unless( $email ) {
	$self->status_ok( $c, { valid => $valid, why => $why } );
    }
    unless( $self->is_email_valid( $email ) ) {
	$self->status_ok( $c, { valid => $valid, why => 'malformed email address' } );
    }
    if ( $c->model( 'RDS::User' )->find({ email => $email }) ) {
	$self->status_ok( $c, { valid => $valid, why => 'email address taken' } );
    }
    $self->status_ok( $c, { valid => 1, why => '' } );
}

sub add_video_to_email :Local {
    my( $self, $c ) = @_;
    my $email = $c->req->param( 'email' );
    unless( $email ) {
	$self->status_bad_request( $c, $c->loc( "No email address specified." ) );
    }
    unless( $self->is_email_valid( $email ) ) {
	$self->status_bad_request( $c, $c->loc( "Malformed email address" ) );
    }

    my $mid = $c->req->param( 'mid' );
    my $mediafile = $c->model( 'RDS::Media' )->find({ uuid => $mid }, {prefetch => 'user'});
    unless( $mediafile ) {
	$self->status_not_found( $c, $c->loc( "Cannot find media for uuid=[_1]", $mid ), $mid );
    }

    my $user = $c->model( 'RDS::User' )->find( { email => $email } );

    my $result = {};

    unless ( $user ) {
	# It's a valid email, but no user of this email exists, create an account.
	my $response = $self->_new_user_no_password( $c, $email );
	if ( $response->{ok} ) {
	    $user = $response->{response}->{user};
	} else {
	    $self->status_bad_request( $c, $c->loc( $response->{response} ) );
	}
    }

    # Add this video to the user account, if permissible.
    $c->stash->{user_obj} = $user;
    my $share_response = $self->_media_shared( $c );
    unless ( $share_response->{ok} ) {
	$self->status_bad_request( $c, $c->loc( $share_response->{response } ) );
    }

    $self->status_ok( $c, $result );
}

sub find_share_info_for_album :Local {
    my( $self, $c ) = @_;
    my $email = $self->sanitize( $c, $c->req->param( 'email' ) );
    my $aid = $self->sanitize( $c, $c->req->param( 'aid' ) );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });

    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }

    my $com = $album->community;
    if ( $com ) {
	my $owner = $album->user();

	my $members = { $owner->email() => 1 };
	foreach my $member ( $com->members->contacts->all() ) {
	    $members->{$member->contact_email()} = 1;
	}
	unless ( exists( $members->{$email} ) ) {
	    $self->status_forbidden( $c, $c->loc( 'Email [_1] is not authorized to view album [_2]', $email, $aid ), $aid );
	}

	my $album_data = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );

	$self->status_ok( $c, { 'album' => $album_data, 'owner' => { 'displayname' => $owner->displayname(),
								     'uuid' => $owner->uuid() } } )
    } else {
	$self->status_forbidden( $c, $c->loc( 'Email [_1] is not authorized to view album [_2]', $email, $aid ), $aid );
    }
}

sub find_share_info_for_pending :Local {
    my( $self, $c ) = @_;

    my $email = $self->sanitize( $c, $c->req->param( 'email' ) );
    my $test  = $c->req->param( 'test' );

    # find pending user
    my @pending = $c->model( 'RDS::User' )->search({displayname => $email,
						    provider_id => 'pending' });
    if ( $#pending >= 0 ) {
	# May have been shared to more than once, just pick the first one.
	my $pending = $pending[0];

	# Now find share record for this pending user.
	my @shares = $c->model( 'RDS::MediaShare' )->search({share_type=>'private', user_id=>$pending->id});
	if ( $#shares >= 0 ) {
	    my $share = $shares[0];  # pick the first one
	    # Get the media file and the user who owns it
	    my $mediafile = $share->media;
	    my $owner = $mediafile->user;
	    $self->status_ok( $c, {
		media => VA::MediaFile->publish( $c, $mediafile, { views => ['poster'] } ),
		owner => $owner->TO_JSON });
	}
    }

    ## TEST ##
    if ( $test ) {
	$self->status_ok( $c, {
	    owner => $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' })->TO_JSON,
	    media => VA::MediaFile->publish( $c, $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' })->media->first ),
	});
    }

    $self->status_ok( $c, {} );
}

=head2 /services/na/download_trayapp

This will download the most current version of the tray app to the calling client.

=cut

# DEPRECATED
sub download_trayapp :Local {
    my( $self, $c ) = @_;

    $self->status_bad_request( $c, "services/na/download_trayapp is deprecated." );

    my $data = $c->model( 'RDS::AppConfig' )->
	find({ app => 'TrayAppDL', current => 1 });
    if ( $data ) {
	my $hash = $data->TO_JSON;
	if ( $hash->{config} ) {
	    my $json = from_json( $hash->{config} );
	    $hash->{config} = $json;

	    ## The uri in the config struct is of the form:
	    ## bucket/key
	    my $mimetype = MIME::Types->new()->mimeTypeOf( $hash->{config}->{uri} );
	    my $name = basename( $hash->{config}->{uri} );
	    my @parts = split( /\//, $hash->{config}->{uri} );
	    my $bucket = shift @parts;
	    my $key = join( '/', @parts );

	    $hash->{url} = 
		new VA::MediaFile::US()->uri2url( $c, $key, { use_s3 => 1, bucket => $bucket } );

	    my $len = $hash->{config}->{size};

	    $c->res->body( "Content-type: $mimetype\015\012\015\012" );
	    $c->res->headers->header( 'Content-Type' => $mimetype );
	    $c->res->headers->header( 'Content-Length' => $len );
	    $c->res->headers->header( 'Content-Disposition' => "attachment; filename=\"$name\"" );
	    $c->res->headers->header( 'filename' => "\"$name\"" );
	    $c->res->headers->header( 'Accept-Ranges' => 'none' );

	    $c->log->debug( 'download_trayapp: ' . $hash->{url} ); 
	    LWP::UserAgent->new()->get( $hash->{url},
					':content_cb' => sub {
					    my( $data, $res ) = @_;
					    if ( $res->is_error ) {
						$c->log->error( 'download_trayapp: ' . $res->content );
						return;
					    }
					    $c->response->write( $data );
					} );
	    $c->detach;
	}
	else {
	    $c->res->status( 404 );
	    $c->res->body( 'Not found' );
	    $c->detach;
	}
    }
    else {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }
}

# Uses View::Thumbnail to return profile photos.
#
sub avatar :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
	( $c,
	  [ uid  => undef,
	    zoom => undef,
	    'x'  => '-',
	    'y'  => 90  ],
	  @_ );
  
    my $uid  = $args->{uid};
    my $zoom = $args->{zoom};
    my $x    = $args->{x};
    my $y    = $args->{y};

    if ( $x && $x eq '-' ) {
	undef $x;
    }

    my $user;
    if ( $uid && $uid eq '-' && $c->user ) {
	$user = $c->user->obj;
    }
    elsif ( $uid ) {
	$user = $c->model( 'RDS::User' )->find({ uuid => $uid });
    }

    my $photo;
    if ( $user ) {
	$photo = $user->profile->image;
    }

    if ( $photo ) {
	$c->stash->{image} = $photo;
	$c->stash->{zoom} = $zoom if ( $zoom );
    }
    else {
	$c->stash->{image} = $c->model( 'File' )->slurp( "avatar.png" );
    }

    $c->stash->{y} = $y if ( $y );
    $c->stash->{x} = $x if ( $x );
    $c->stash->{current_view} = 'Thumbnail';
}

=head2 /services/na/media_comments

Unauthenticated endpoint to get comments associated with the media file
passed in as mid.  Needed for the web_player page.

Also pass back the owner information for this media file.  This is
also used on the web_player to show who created the mediafile.

=cut

sub media_comments :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }

    my $mf = $c->model( 'RDS::Media' )->find({ uuid => $mid }, { prefetch => 'user' });
    unless( $mf ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }
    my @comments = $mf->comments->search({},{prefetch=>'user', order_by=>'me.created_date desc'});
    my @data = ();
    foreach my $comment ( @comments ) {
	my $hash = $comment->TO_JSON;
	if ( $comment->user_id ) {
	    $hash->{who} = $comment->user->displayname;
	}
	push( @data, $hash );
    }
    $self->status_ok( $c, { comments => \@data, owner => $mf->user->TO_JSON } );
}

sub faces_in_mediafile :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $m = $c->model( 'RDS::Media' )->find({uuid=>$mid});
    unless( $m ) {
	$self->status_not_found
	    ( $c, 
	      $c->loc( 'Unable to find mediafile for [_1]', $mid ), $mid );
    }
    my $mf = VA::MediaFile->new->publish( $c, $m, { assets=>[],include_contact_info=>1} );
    $self->status_ok( $c, { faces => $mf->{views}->{face} } );
}

sub geo_loc :Local {
    my( $self, $c ) = @_;
    my $lat = $self->sanitize( $c, $c->req->param( 'lat' ) );
    my $lng = $self->sanitize( $c, $c->req->param( 'lng' ) );

    my $latlng = "$lat,$lng";
    my $keystr = '';
    if ( $c->config->{geodata}->{google}->{key} ) {
	$keystr = '&key=' + $c->config->{geodata}->{google}->{key};
    }
    my $res = $c->model( 'GoogleMap' )->get( "/maps/api/geocode/json?latlng=$latlng&sensor=true$keystr" );

    $self->status_ok( $c, $res->data->{results} );
}

=head2 /services/na/form_feedback

For sending feedback to viblio team.  The UI is responsible for
setting feedback_email to the correct email address that Mandrill
uses to route back to us, which we then file in our feedback system.

=cut

sub form_feedback :Local {
    my( $self, $c ) = @_;
    my $feedback = $self->sanitize( $c, $c->req->param( 'feedback' ) );
    my $feedback_email = $c->req->param( 'feedback_email' );
    my $feedback_location = $c->req->param( 'feedback_location' );

    my @addresses = Email::Address->parse( $feedback_email );
    if ( scalar( @addresses ) < 1 ) {
	# Silently fail.
	$self->status_ok( $c, {} );
    } elsif ( ( $addresses[0]->host() eq $c->config->{viblio_return_email_domain} )
	      or ( $self->is_email_valid( $feedback_email ) ) ) {
	
	$self->send_email( $c, {
	    subject => 'feedback on ' . $feedback_location,
	    from => {
		email => ( $c->user ? $c->user->obj->email : undef ),
		name  => ( $c->user ? $c->user->obj->displayname : 'Anonymous' ) },
	    to => [{ email => $feedback_email,
		     name  => 'Feedback' }],
	    template => 'email/feedback.tt',
	    stash => {
		feedback => $feedback,
		feedback_user => ( $c->user ? $c->user->obj->email : 'Anonymous' ),
		feedback_location => $feedback_location
	    } });
    } else {
	$c->log->error( "DIDN'T SEND FEEDBACK EMAIL, INVALID DESTINATION address '$feedback_email', FEEDBACK WAS: '$feedback' ON PAGE '$feedback_location'." );
    }
    # Send an OK even if we didn't send an email - we don't want the
    # UI to barf on users if there is some mess up.
    $self->status_ok( $c, {} );
}

# Sending email from the client using JSON in the body
#
sub emailer :Local {
    my( $self, $c ) = @_;
    if ( $c->{data} && $c->{data}->{subject} && $c->{data}->{to} ) {
	$self->send_email( $c, $c->{data} );
    }
    else {
	$self->status_bad_request( $c, $c->loc( 'Badly formed JSON body' ) );
    }
    $self->status_ok( $c, {} );
}

# Send a push notification to a user
sub send_push_notification :Local {
    my( $self, $c ) = @_;
    my $uid     = $c->req->param( 'uid' );
    my $network = $c->req->param( 'network' );
    my $message = $c->req->param( 'message' );
    my $badge   = $c->req->param( 'badge' );

    my $user = $c->model( 'RDS::User' )->find({ uuid => $uid });
    unless( $user ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find user for [_1]', $uid ), $uid );
    }

    unless( $network ) {
	$self->status_bad_request( $c, $c->loc( 'Missing network param: use APNS for Apple' ) );
    }

    my $options = { network => $network, sound => 'default' };
    if ( $message ) { $options->{message} = $message; }
    if ( $badge   ) { $options->{badge} = $badge; }

    $options->{custom} = { type => 'MESSAGE' };

    foreach my $dev ( $user->user_devices->all ) {
	$self->push_notification( $c, $dev->device_id, $options );
    }

    $self->status_ok( $c, {} );
}

__PACKAGE__->meta->make_immutable;

1;
