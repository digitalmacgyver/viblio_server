package VA::Controller::Services::NA;

# These calls are not authenticated.

use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

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
	$c->logdump( { user => $c->user->obj->TO_JSON } );
	$self->status_ok( $c, { user => $c->user->obj } );
	return;
    } else {
	$self->status_unauthorized
	    ( $c,
	      $c->loc( "Login failed" ) );
    }
}

sub logout :Local {
    my( $self, $c ) = @_;
    $c->logout();
    $self->status_ok
	( $c, {} );
}

# Return information on installed languages, the default
# language guessed from the browser, and the user's current
# language.
#
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

# Return what we know about the connecting device.  Can pass
# in a user-agent, or it defaults to the user-agent header.
#
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

# New user registration.  
#
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
	   username => $pending->username || $username,
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
	$self->status_ok( $c, { email => $args->{email} } );
    }
}

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

# For the test app, which cannot handle cookies for authenticated downloads, provile
# a hook here that can do unauthenticated downloads.
#
sub download :Local {
    my( $self, $c, $uid, $id ) = @_;
    $uid = $c->req->param( 'uid' ) unless( $uid );
    $id  = $c->req->param( 'id' ) unless( $id );
    $id  = $c->req->param( 'uuid' ) unless( $id );

    unless( $uid && $id ) {
	my $err = $c->loc( "Missing input params: need userid and media id" );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $user = $c->model( 'DB::User' )->find($uid);
    unless( $user ) {
	my $err = $c->loc( "Cannot find user for uid [_1]", $uid );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $mediafile = $user->mediafiles->find({ id => $id });
    # try uuid if not found
    unless( $mediafile ) {
	$mediafile = $user->mediafiles->find({ uuid => $id });
    }

    # Not found should return a real html-based 404
    #
    if ( ! $mediafile ||
	 ! -f $mediafile->path ) {
	my $err = $c->loc( "No media file found at id/uuid [_1]", $id );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $type = $mediafile->mimetype;
    my $len  = $mediafile->size;

    $c->res->body( "Content-type: $type\015\012\015\012" );

    $c->res->headers->header( 'Content-Type' => $type );
    $c->res->headers->header( 'Content-Length' => $len );

    my $f = new FileHandle $mediafile->path;
    unless( $f ) {
	my $err = $c->loc( "No media file found at id/uuid [_1]", $id );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $blk_size = 1024 * 4;
    my $data;
    my $sz = $f->read( $data, $blk_size );
    while( $sz > 0 ) {
        $c->res->write( $data );
        $sz = $f->read( $data, $blk_size );
    }

    $f->close();
}

__PACKAGE__->meta->make_immutable;

1;
