package VA::Controller::Services::User;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use MIME::Base64;

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/user/*

Services related to the logged in user or to user management in general.

=head2 /services/user/me

Get the database record for the logged in user.  A user record is returned:

  { "user": $user }

=head3 Example Response

  {
     "user": {
        "provider" => "facebook",
        "active" => "2013-03-23 23:38:13",
        "accepted_terms" => undef,
        "provider_id" => "100005451434129",
        "uuid" => "BADCB4A6-9412-11E2-ADDF-209629C23E77",
        "username" => "andrew.peebles.9843",
        "email" => undef,
        "id" => "5",
        "displayname" => "Andrew Peebles"
     }
  }

=cut

sub me :Local {
    my( $self, $c ) = @_;
    $self->status_ok( $c, { user => $c->user->obj } );
}

=head2 /services/user/add_user

Add a new local user.  Only dbadmins can do this.

=head3 Parameters

Takes 'username', 'password', 'fullname' and optionally one or more roles in the form
of

  role=r1&role=&r2(...)

=head3 Response

Returns the new user record:

  { "user": $user }

=cut 

#
# /add_user?username=xx&password=yy&fullname=zz&email=ee&role=r1&role=&r2
#
sub add_user :Local {
    my( $self, $c ) = @_;
    unless( $c->check_user_roles( 'admin' ) ) {
	$self->status_forbidden
	    ( $c,
	      $c->loc("Only users with 'admin' role can add new users.") );
    }
    my $params = $c->req->params;
    # $c->logdump( $params );

    foreach my $arg ( qw/username password fullname email/ ) {
	if ( ! defined( $params->{$arg} ) ) {
	    $self->status_bad_request
		( $c,
		  $c->loc("Missing required \'[_1]\' parameter.", $arg ) );
	}
    }

    # Default provider to local
    if ( ! $params->{provider} ) {
	$params->{provider} = 'local';
    }

    my $user = $c->model( 'DB::User' )->find({username=>$params->{username}});
    if ( $user ) {
	$self->status_bad_request
	    ( $c, 
	      $c->loc("User with username=\'[_1]\' already exists", $params->{username} ) );
    }

    my $roles;
    if ( defined( $params->{role} ) ) {
	if ( ref $params->{role} eq 'ARRAY' ) {
	    $roles = $params->{role};
	}
	else {
	    push( @$roles, $params->{role} );
	}
	delete $params->{role};  # so we can use $params to create the user
    }

    $user = $c->model( 'DB::User' )->new( $params );
    unless( $user ) {
	$self->status_bad_request
	    ( $c,
	      $c->loc( "Failed to create username=\'[_1]\'", $params->{username} ) );
    }

    my @problems = ();
    if ( $roles ) {
	foreach my $role ( @$roles ) {
	    my $r = $c->model( 'DB::Role' )->find({role=>$role});
	    if ( $r ) {
		$user->add_to_roles( $r );
	    }
	    else {
		push( @problems, $c->loc( "role \'[_1]\' not found", $role ) );
	    }
	}
    }

    if ( $#problems >= 0 ) {
	$self->status_bad_request
	    ( $c, 
	      join( ', ', @problems ) );
    }
    else {
	# commit new user into database.
	$user->update;
	$self->status_ok( $c, { user => $user } );
    }
}

# Leave this in for now, in case we want to support profile photos.
#
sub add_or_replace_profile_photo :Local {
    my( $self, $c, $uid ) = @_;
    $uid = $c->req->param( 'uid' ) unless( $uid );
    $uid = $c->user->obj->id unless( $uid );

    # Have to be an admin to change someone else's photo
    #
    unless( $c->check_user_roles( 'admin' ) ) {
	unless( $c->user->obj->id == $uid || $c->user->obj->username eq $uid ) {
	    $self->status_forbidden
		( $c,
		  $c->loc("Only users with 'admin' role can change someone else's photo." ) );
	}
    }

    # uid might be an id or a username
    #
    my $user;
    if ( $c->user->obj->id == $uid || $c->user->obj->username eq $uid ) {
	$user = $c->user->obj;
    }
    else {
	my $rs = $c->model( 'DB::User' )
	    ->search({id => $uid}, {username=>$uid});
	$user = $rs->first if ( $rs );
    }

    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc("User for uid=[_1] not found!", $uid ) );
    }

    my $profile = $user->profile;
    unless( $profile ) {
	$self->status_bad_request
	    ( $c, $c->loc("[_1] does not have a profile", $user->email) );
    }

    my $upload = $c->req->upload( 'upload' );
    my $photo;
    if ( $upload ) {
	$photo = $profile->photo;
	if ( $photo ) {
	    $photo->mimetype( $upload->type );
	    $photo->filename( $upload->basename );
	    $photo->image( $upload->slurp );
	    $photo->size( $upload->size );
	    $photo->update;
	}
	else {
	    $photo = $c->model( 'DB::Photo' )->create
		({ id => $profile->id,
		   mimetype => $upload->type,
		   filename => $upload->basename,
		   size => $upload->size,
		   image => $upload->slurp });
	    $profile->photo( $photo );
	    $profile->update;
	}
    }
    elsif ( $c->req->param( 'upload' ) ) {
	my $mimetype = $c->req->param( 'mimetype' ) || 'image/jpeg';
	my $filename = $c->req->param( 'filename' ) || 'uploaded';
	my $data = decode_base64( $c->req->param( 'upload' ) );
	my $sz = length( $data );
	$photo = $profile->photo;
	if ( $photo ) {
	    $photo->mimetype( $mimetype );
	    $photo->filename( $filename );
	    $photo->image( $data );
	    $photo->size( $sz );
	    $photo->update;
	}
	else {
	    $photo = $c->model( 'DB::Photo' )->create
		({ id => $profile->id,
		   mimetype => $mimetype,
		   filename => $filename,
		   size => $sz,
		   image => $data });
	    $profile->photo( $photo );
	    $profile->update;
	}
    }
    else {
	$self->status_bad_request( $c, $c->loc("Missing upload field") );
    }
    $self->status_ok( $c, { id => $photo->id } );
}

# Leaving this in just for code example, if I need to do this
# in the future.
#
sub original :Local {
    my( $self, $c ) = @_;
    my $photo = $c->user->profile->photo;

    unless( $photo ) {
	$self->status_bad_request( $c, $c->loc("no photo available") );
    }

    my $type = $photo->mimetype;
    my $len  = $photo->size;

    $c->res->body( "Content-type: $type\015\012\015\012" );

    $c->response->headers->header( 'Content-Type' => $type );
    $c->response->headers->header( 'Content-Length' => $len );

    $c->response->write( $photo->image );
}

# Uses View::Thumbnail to return profile photos.
#
sub avatar :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
	( $c,
	  [ uid  => '-',
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
    if ( $uid && $uid eq '-' ) {
	$user = $c->user->obj;
    }
    elsif ( $uid ) {
	$user = $c->model( 'DB::User' )->find( $uid );
    }

    my $photo;
    if ( $user ) {
	$photo = $user->profile->photo;
    }

    if ( $photo ) {
	$c->stash->{image} = $photo->image;
	$c->stash->{zoom} = $zoom if ( $zoom );
    }
    else {
	my @colors = ('red', 'green', 'yellow', 'purple' );
	my $color  = $colors[ int( rand( 3 ) ) ];
	$c->stash->{image} = $c->model( 'File' )->slurp( "nopic-" . $color . "-90.png" );
    }

    $c->stash->{y} = $y if ( $y );
    $c->stash->{x} = $x if ( $x );
    $c->stash->{current_view} = 'Thumbnail';
}

=head2 /services/user/username

User wants to change their nickname (username)

If called with no argument; if existing username, return it.  If no existing username, generate one based on email name

If called with username= argument; If its equal to existing username, return it, else generate one based on argument.

If a username already exists, one is generated by post-fixing 123
and seeing if that exists.  If so, then 1 is added (124) and so
on until a unique username is generated.

=head3 Response

  { "username": $username }

=cut

sub username :Local {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ username    => undef,
	  ],
	  @_ );
    
    if ( !defined( $args->{username} ) ) {
	if ( $c->user->username ) {
	    # return existing username
	    $self->status_ok( $c, { username => $c->user->username } );
	}
	else {
	    # generate a random one
	    my $un = $self->auto_username( $c->user->email );
	    $c->user->username( $un ); $c->user->update;
	    $c->persist_user;
	    $self->status_ok( $c, { username => $un } );
	}
    }
    else {
	if ( $c->user->username eq $args->{username} ) {
	    # they already have it, return existing username
	    $self->status_ok( $c, { username => $c->user->username } );
	}
	else {
	    my $un = $self->auto_username
		( $c, $c->user->email, $args->{username} );
	    $c->user->username( $un ); $c->user->update;
	    $c->persist_user;
	    $self->status_ok( $c, { username => $un } );
	}
    }
}

=head2 /services/user/accept_terms

Called with no arguments, sets the date in the user's record when they accepted
the terms of use document.  

=head3 Response

  { "accepted": $date }

=cut

sub accept_terms :Local {
    my( $self, $c ) = @_;

    $c->user->accepted_terms( DateTime->now );
    $c->user->update;
    $c->persist_user;
    $self->status_ok( $c, { accepted => sprintf( "%s", $c->user->accepted_terms) } );
}

=head2 /services/user/media

Return the list of media files belonging to this user.  This call forwards to
/services/mediafile/list; See the documentation for that call.

=cut

sub media :Local {
    my $self = shift; my $c = shift;
    $c->forward( '/services/mediafile/list' );
}

=head2 /services/user/workorders

Return the list of workorders belonging to the logged in user.  This call forwards to
/services/wo/list; See the documentation for that call.

=cut

sub workorders :Local {
    my $self = shift; my $c = shift;
    $c->forward( '/services/wo/list' );
}

=head2 /services/user/auth_token

Obtain a token that can be used to access the public apis on the file
server and message queue services.  The services may accept the token
in different ways.  This endpoint generates a token based on the logged
in user's uuid and a secret password that is known by viblio servers.
When the token and the user's uuid are passed to a secured api, a new
token can be generated with the uuid and shared secret, then compared
with the tramsmitted token.

=head3 Response

  { "uuid": $uuid, "token": $token }

=cut

sub auth_token :Local {
    my( $self, $c ) = @_;
    my $uuid = $c->user->obj->uuid;
    my $token = $c->secure_token( $uuid );
    $self->status_ok( $c, { uuid => $uuid, token => $token } );
}

__PACKAGE__->meta->make_immutable;

1;
