package VA::Controller::Services::NA;

# These calls are not authenticated.

use Moose;
use namespace::autoclean;
use DateTime;
use Try::Tiny;

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
	$code .= substr("ABCDEFGHJKMNPQRSTVWXYZ23456789",int(1+rand()*30),1);
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

sub authenticate :Local {
    my ( $self, $c ) = @_;

    # Get the username and password from form
    my $username = $c->req->params->{email};
    my $password = $c->req->params->{password};
    my $realm = $c->req->params->{realm} || 'facebook';

    # Different realms require different lookup and password values
    #
    my $creds = {};
    if ( $realm eq 'db' ) {
	$creds = {
	    provider => 'local',
	    email => $username,
	    password => $password,
	};
    }
    elsif ( $realm =~ /facebook/ ) {
	$creds = {};
    }

    if ( $c->authenticate( $creds, $realm ) ) {
	$self->status_ok( $c, { user => $c->user->obj } );
	return;
    } else {
	$self->status_unauthorized
	    ( $c,
	      $c->loc( "Login failed" ) );
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

sub device_info :Local {
    my( $self, $c ) = @_;
    my $d = $c->req->browser;

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

    my $existing = $c->model( 'DB::User' )->find
	({ email => $args->{email} });
    if ( $existing ) {
	$self->status_bad_request
	    ( $c, $c->loc( "A user with email=\'[_1]\' already exists.", $args->{email} ) );
    }

    $existing = $c->model( 'DB::PendingUser' )->find
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
	$existing = $c->model( 'DB::PendingUser' )->find({ code => $code });
    } while( $existing );

    my $user = $c->model( 'DB::PendingUser' )->create
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
    $c->stash->{no_wrapper} = 1;
    $c->stash->{email} =
    { to       => $args->{email},
      from     => $c->config->{viblio_return_email_address},
      subject  => $c->loc( "Invitation to join Viblio" ),
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
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ email    => undef,
	    password => undef,
	    username => undef,
	    code     => undef,
	  ],
	  @_ );

    unless( $args->{email} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'email' ) );
    }

    unless( $args->{password} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'password' ) );
    }

    unless( $args->{code} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'code' ) );
    }

    my $username = $self->auto_username
	( $c, $args->{email}, $args->{username} );

    my $pending = $c->model( 'DB::PendingUser' )
	->find({ code => $args->{code} });
    unless( $pending ) {
	$self->status_bad_request
	    ( $c, $c->loc( "No matching pending user for email/code." ) );
    }
    unless( $pending->email eq $args->{email} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Email does not match for given code." ) );
    }

    my $user = $c->model( 'DB::User' )->create
	({ email => $pending->email,
	   password => $pending->password,
	   displayname => $pending->username || $username,
	   provider => 'local',
	 });

    if ($c->authenticate({ email    => $user->email,
			   password => $args->{password}  }, 'db' )) {
	$pending->delete;
	$self->status_ok( $c, { user => $c->user->obj } );
    }
    else {
	$user->delete;
	$self->status_bad_request
	    ( $c, $c->loc( "Unable to create new user." ) );
    }
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

    my $user = $c->model( 'DB::User' )->find({ email => $args->{email} });
    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Cannot find user for [_1]", $args->{email} ) );
    }

    my $code = $self->invite_code;

    my $rec = $c->model( 'DB::PasswordReset' )
	->find_or_create({ email => $args->{email},
			   code  => $code });
    unless( $rec ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to create record: [_1]", 'DB::PasswordReset' ) );
    }
    
    $c->stash->{no_wrapper} = 1;
    $c->stash->{email} =
    { to       => $args->{email},
      from     => $c->config->{viblio_return_email_address},
      subject  => $c->loc( "Reset your password on Viblio" ),
      template => 'email/reset-password.tt'
    };
    $c->stash->{user} = $user;
    $c->stash->{rec}  = $rec;
    $c->forward( $c->view('Email::Template') );

    if ( scalar( @{ $c->error } ) ) {
	# Sending email failed!  
	# The error will get properly communicated in the end() method,
	# so we just need to clean up.
	$rec->delete;
    }
    else {
	$self->status_ok( $c, { user => $user } );
    }
}

=head2 /services/na/new_password

Once the forgetting user receives a code in email, they can pass email, the new password and the
code to this endpoint.  If everything matches, the password will be changed and the user will be logged in.

=head3 Response

  { "user" : $user }

=cut

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

    my $user = $c->model( 'DB::User' )->find({ email => $args->{email} });
    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Cannot find user for [_1]", $args->{email} ) );
    }

    my $rec = $c->model( 'DB::PasswordReset' )->find({ email => $args->{email} });
    unless( $rec ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Cannot find password reset record for [_1]", $args->{email} ) );
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
	$self->status_bad_request
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

sub workorder_processed :Local {
    my( $self, $c ) = @_;
    my $incoming = $c->{data};

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

    my $wo = $c->model( 'DB::Workorder' )->find( $incoming->{wo}->{id} );
    unless( $wo ) {
	$c->log->error( "Could not obtain db record for $incoming->{wo}->{id}" );
	$self->workorder_done( $c, undef, {
	    error => 1,
	    message => "Could not find wo id=" .  $incoming->{wo}->{id} } );
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
    my $mediafiles = $wo->mediafiles->search({}, {prefetch => 'views'}); # rs so its searchable
    my @infiles = @{$incoming->{media}};

    my $exception;
    my @to_delete = ();
    try {
        $c->model( 'DB' )->schema->txn_do( 
	    sub {
		foreach my $infile ( @infiles ) {
		    my $mediafile;
		    if ( ! $infile->{id} ) {
			# This is a new media file
			$mediafile = $c->model( 'DB::Mediafile' )->create({
			    user_id => $user_id,
			    filename => $infile->{filename} });
			$mediafile->add_to_workorders( $wo );
		    }
		    else {
			$mediafile = $mediafiles->find( $infile->{id} );
		    }
		    
		    foreach my $key ( keys( %{$infile->{views}} ) ) {
			my $inview = $infile->{views}->{$key};
			my $view = $mediafile->view( $key );
			if ( ! $view ) {
			    # This is a new view
			    $mediafile->create_related( 'views', {
				location => $inview->{location},
				mimetype => $inview->{mimetype},
				uri => $inview->{uri},
				size => $inview->{size},
				type => $key,
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
		    $mediafile->type( $infile->{type} );
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

sub workorder_done :Private {
    my( $self, $c, $uuid, $wo ) = @_;
    $c->log->debug( "WORKORDER DONE" );

    if ( $uuid ) {
	# Queue it up in the user message queue, or send a push notification.
	# We'd like to distinguish between iOS clients and web clients so
	# we only deliver the message once.  How?
	my $res = $c->model( 'MQ' )->post( '/enqueue', { uid => $uuid,
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

__PACKAGE__->meta->make_immutable;

1;
