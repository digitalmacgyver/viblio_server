package VA::Controller::Services::User;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use MIME::Base64;
use Imager;
use Try::Tiny;
use JSON;

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/user/*

Services related to the logged in user or to user management in general.

=head2 /services/user/me

Get the database record for the logged in user.  A user record is returned:

  { "user": $user }

=head3 Example Response

  {
     "user": {
        "active" => "2013-03-23 23:38:13",
        "accepted_terms" => undef,
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
    my $hash = { user => $c->user->obj };
    $self->status_ok( $c, $hash );
}

=head2 /services/user/profile

Retrieve logged in user profile.  Returns profile fields
and account link information.

=head3 Example Response

{
   "profile" : {
      "uuid" : "BADCB4A6-9412-11E2-ADDF-209629C23E77",
      "email" : "aqpeeb@gmail.com",
      "fields" : [
         {
            "value" : "True",
            "name" : "email_notifications",
            "public" : "1"
         },
         {
            "value" : "True",
            "name" : "email_comment",
            "public" : "1"
         },
         {
            "value" : "True",
            "name" : "email_upload",
            "public" : "1"
         },
         {
            "value" : "True",
            "name" : "email_face",
            "public" : "1"
         },
         {
            "value" : "True",
            "name" : "email_viblio",
            "public" : "1"
         }
      ],
      "links" : [
         {
            "link" : "https://www.facebook.com/andrew.peebles.9843",
            "provider" : "facebook"
         }
      ]
   }
}

=cut

sub profile :Local {
    my( $self, $c ) = @_;
    my @fields = $c->user->obj->profile->fields;
    my @links = $c->user->obj->links;
    my @link_data = ();
    foreach my $link ( @links ) {
	push( @link_data, { provider => $link->provider,
			    link => $link->data->{link} } );
    }
    my $data = {
	uid => $c->user->obj->uuid,
	email => $c->user->obj->email,
	displayname => $c->user->obj->displayname,
	fields => \@fields,
	links => \@link_data,
    };
    $self->status_ok( $c, { profile => $data } );
}

sub change_profile :Local {
    my( $self, $c ) = @_;
    my $profile = $c->user->obj->profile;
    unless( $profile ) {
	$c->log->error( "change_profile(): Unable to obtain a profile for user: " . $c->user->obj->uuid );
	$self->status_bad_request
	    ( $c, 
	      $c->loc( "Unable to obtain your profile!" ) );
    }
    foreach my $name ( keys( $c->req->params ) ) {
	next if ( $name eq '_' );
	my $field = $profile->fields->find({ name => $name });
	if ( $field ) {
	    $field->value( $c->req->param( $name ) );
	    $field->update;
	}
	else {
	    $c->log->error( "change_profile(): unable to find field named " . $name );
	}
    }
    $c->forward( '/services/user/profile' );
}

=head2 /services/user/change_email_or_displayname

Pass in one or both of 'email', 'displayname' to change these
values for the logged in user.  Presently 'email' does not
do anything, as changing the primary user key is frought with
danger.

Returns the user struct. { user: {userinfo} }

=cut

sub change_email_or_displayname :Local {
    my( $self, $c ) = @_;
    my $email = $c->req->param( 'email' );
    my $displayname = $c->req->param( 'displayname' );
    if ( $email ) {
	# $c->user->obj->email( $email );
	# DO NOT ALLOW THIS AT THIS TIME ... changing the user's email address has
	# large ramifications.
    }
    if ( $displayname ) {
	$c->user->obj->displayname( $displayname );
    }
    $c->user->obj->update;
    $self->status_ok($c, { user => $c->user->obj->TO_JSON });
}

sub link_facebook_account :Local {
    my( $self, $c, $token ) = @_;
    $token = $c->req->param( 'access_token' ) unless( $token );
    unless( $token ) {
	$c->log->error( "Missing token param for link_facebook_account()" );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    my $fb = $c->model( 'Facebook', $token );
    unless( $fb ) {
	$c->log->error( "Failed to link FB account: token was: " + $token );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    my $fb_user = $fb->fetch( 'me' );
    unless( $fb_user ) {
	$c->log->error( "Facebook fetch(me) failed during FB link" );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    unless( $fb_user->{id} ) {
	$c->log->error( "Facebook user id missing during link" );
	$c->logdump( $fb_user );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    $c->user->obj->update_or_create_related
	( 'links', {
	    provider => 'facebook',
	  });
    my $link = $c->user->obj->links->find({provider => 'facebook'});
    $link->data({
	link => $fb_user->{link},
	access_token => $token,
	id => $fb_user->{id} });
    $link->update; 
    $c->session->{fb_token} = $token;
    
    # Send a facebook link message to the Amazon SQS queue
    try {
	my $sqs_response = $c->model( 'SQS', $c->config->{sqs}->{facebook_link} )
	    ->SendMessage( to_json({
		user_uuid => $c->user->obj->uuid,
		fb_access_token => $token,
		action => 'link',
		facebook_id => $fb_user->{id} }) );
	# No doc exists on the response!
    } catch {
	$c->log->error( "facebook link failed: $_" );
    };

    $self->status_ok( $c, { user => $fb_user } );
}

sub unlink_facebook_account :Local {
    my( $self, $c ) = @_;
    my $link = $c->user->obj->links->find({provider => 'facebook'});
    if ( $link ) {
	# DO SQS CALL !??!?!?!?!
	if ( $c->session->{fb_token} ) {
	    delete $c->session->{fb_token};
	}
	$c->user->obj->delete_related
	    ( 'links', {
		provider => 'facebook',
	      });
    }
    $self->status_ok( $c, {} );
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

    my $user = $c->model( 'RDS::User' )->find({username=>$params->{username}});
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

    $user = $c->model( 'RDS::User' )->new( $params );
    unless( $user ) {
	$self->status_bad_request
	    ( $c,
	      $c->loc( "Failed to create username=\'[_1]\'", $params->{username} ) );
    }

    my @problems = ();
    if ( $roles ) {
	foreach my $role ( @$roles ) {
	    my $r = $c->model( 'RDS::Role' )->find({role=>$role});
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
    $uid = $c->user->obj->uuid unless( $uid );

    # Have to be an admin to change someone else's photo
    #
    unless( $c->check_user_roles( 'admin' ) ) {
	unless( $c->user->obj->uuid eq $uid ) {
	    $self->status_forbidden
		( $c,
		  $c->loc("Only users with 'admin' role can change someone else's photo." ) );
	}
    }

    # uid might be an id or a username
    #
    my $user;
    if ( $c->user->obj->uuid eq $uid ) {
	$user = $c->user->obj;
    }
    else {
	$user = $c->model( 'RDS::User' )->find({ uuid => $uid });
    }

    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc("User for uuid=[_1] not found!", $uid ) );
    }

    my $profile = $user->profile;
    unless( $profile ) {
	$self->status_bad_request
	    ( $c, $c->loc("[_1] does not have a profile", $user->email) );
    }

    my $upload = $c->req->upload( 'upload' );
    my $photo;
    if ( $upload ) {

	# The incoming image is very likely too big to store, since
	# we will never display it bigger that 128x128, so we'll process it
	# here on upload.
	my $image = Imager->new();
	$image->read( data => $upload->slurp ) or
	    $c->log->error( "Failed to create Imager object: " . $image->errstr );
	if ( $image->getheight > 128 ) {
	    $c->log->debug( "The profile image height is greater that 128, so scale." );
	    my $source_aspect = $image->getwidth / $image->getheight;
	    my $y = 128;
	    my $x = $y * $source_aspect;
	    
	    $image = $image->scale(
		xpixels => $x,
		ypixels => $y,
		type => 'min',
		qtype => 'mixing' );
	}

	$profile->image_mimetype( $upload->type );
	my $data;
	(my $file_type = $upload->type) =~ s!^image/!!;
	$image->write( data => \$data, type => $file_type );
	$profile->image( $data );
	$profile->image_size( length( $data ) );
	$profile->update;
    }
    elsif ( $c->req->param( 'upload' ) ) {
	my $mimetype = $c->req->param( 'mimetype' ) || 'image/jpeg';
	my $data = decode_base64( $c->req->param( 'upload' ) );
	my $sz = length( $data );

	$profile->mimetype( $mimetype );
	$profile->image( $data );
	$profile->size( $sz );
	$profile->update;
    }
    else {
	$self->status_bad_request( $c, $c->loc("Missing upload field") );
    }
    $self->status_ok( $c, {} );
}

# Leaving this in just for code example, if I need to do this
# in the future.
#
sub original :Local {
    my( $self, $c ) = @_;
    my $photo = $c->user->obj->profile->image;

    unless( $photo ) {
	$self->status_bad_request( $c, $c->loc("no photo available") );
    }

    my $type = $c->user->obj->profile->image_mimetype;
    my $len  = $c->user->obj->profile->image_size;

    $c->res->body( "Content-type: $type\015\012\015\012" );

    $c->response->headers->header( 'Content-Type' => $type );
    $c->response->headers->header( 'Content-Length' => $len );

    $c->response->write( $photo );
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
	#my @colors = ('red', 'green', 'yellow', 'purple' );
	#my $color  = $colors[ int( rand( 3 ) ) ];
	#$c->stash->{image} = $c->model( 'File' )->slurp( "nopic-" . $color . "-90.png" );
	$c->stash->{image} = $c->model( 'File' )->slurp( "avatar.png" );
    }

    $c->stash->{y} = $y if ( $y );
    $c->stash->{x} = $x if ( $x );
    $c->stash->{current_view} = 'Thumbnail';
}

=head2 /services/user/accept_terms

Called with no arguments, sets the date in the user's record when they accepted
the terms of use document.  

=head3 Response

  { "accepted": $date }

=cut

sub accept_terms :Local {
    my( $self, $c ) = @_;

    $c->user->obj->accepted_terms( 1 );
    $c->user->obj->update;
    $self->status_ok( $c, {} );
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

sub change_password :Local {
    my( $self, $c, $password ) = @_;
    $password = $c->req->param( 'password' ) unless( $password );
       
    $c->user->obj->password( $password ); 
    $c->user->obj->update;

    if ($c->authenticate({ email    => $c->user->obj->email,
			   password => $password }, 'db' )) {
	$self->status_ok( $c, { user => $c->user->obj } );
    }
    else {
	$self->status_bad_request
	    ( $c, $c->loc( "Unable to authenticate user with new password." ) );
    }
}

sub tell_a_friend :Local {
    my( $self, $c ) = @_;
    my @list = $c->req->param( 'list[]' );
    my $message = $c->req->param( 'message' );

    my $user = $c->user->obj;

    # We don't want to return any errors from this routine
    unless( ($#list >= 0) && $message ) {
	$self->status_ok( $c, {} );
    }

    my @clean = $self->expand_email_list( $c, \@list, [ $c->user->email ] );

    foreach my $recip ( @clean ) {
	$self->send_email( $c, {
	    subject    => $c->loc( "Invitation to join Viblio" ),
	    to => [{
		email => $recip}],
	    template => 'email/referAFriend.tt',
	    stash => {
		from => $user,
		message => $message,
	    } });
    }

    $self->status_ok( $c, {} );
}

__PACKAGE__->meta->make_immutable;

1;
