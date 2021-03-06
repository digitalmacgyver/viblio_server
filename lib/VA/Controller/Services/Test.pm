package VA::Controller::Services::Test;
use Moose;
use namespace::autoclean;
use JSON;
use Try::Tiny;
use DateTime;

BEGIN { extends 'VA::Controller::Services' }

# Just for testing ...
#
sub me :Local {
    my( $self, $c ) = @_;

    #$DB::single = 1;
    $c->log->info( 'This is a test' );
    if ( $c->{data} ) {
	$c->logdump( $c->{data} );
    }

    $self->status_ok( $c, $c->user->obj );
}

sub argtest :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
	( $c,
	  [ uid  => '-',
	    zoom => 80,
	    'x'  => '-',
	    'y'  => 90  ],
	  @_ );

    $self->status_ok( $c, { args => $args } );
}

sub mailchimp :Local {
    my( $self, $c ) = @_;
    
    # https://mandrillapp.com/api/docs/
    my $model = {
	subject => 'Testing Mailchimp',
	to => [{
	    email => $c->user->email,
	    name  => $c->user->displayname }],
	template => 'test-email.tt',
	stash => {
	}
    };
    $self->send_email( $c, $model );
    $self->status_ok( $c, {} );
}

sub template_test :Local {
    my( $self, $c ) = @_;
    my $to = $c->req->param( 'email' );
    my $template = $c->req->param( 'template' );
    my $force_staging = $c->req->param( 'force_staging' );

    unless( $to ) {
	$self->status_bad_request( $c, "missing 'email' param" );
    }
    unless( $template ) {
	$self->status_bad_request( $c, "missing 'template' param" );
    }

    if ( $force_staging ne 'false' ) {
	$c->{server_override} = 'http://staging.viblio.com/';
    }

    my $with_faces = $self->where_valid_mediafile();
    $with_faces->{'media_assets.asset_type'} = 'face';
    my $without_faces = $self->where_valid_mediafile();

    my @media = $c->user->media->search
	($with_faces,
	 {order_by => 'me.id desc', 
	  prefetch=>'media_assets',
	  });
    my $media;
    if ( $#media >= 0 ) {
	$media = $media[0];
    }
    else {
	@media = $c->user->media->search
	    ($without_faces,
	     {order_by => 'me.id desc'});
	if ( $#media >= 0 ) {
	    $media = $media[0];
	}
    }

    unless( $media ) {
	$self->status_bad_request( $c, "Could not obtain a media file" );
    }

    my $mf = VA::MediaFile->new->publish
	( $c, $media, 
	  { views => ['poster'], include_contact_info => 1, 
	    expires => (60*60*24*365) } );

    my @media_array = ( $mf );
    if ( $#media > 0 ) {
	push( @media_array, VA::MediaFile->new->publish
	      ( $c, $media[1], { views => ['poster'], include_contact_info => 1, expires => (60*60*24*365) } ) );
    }

    # Need some faces
    #
    my @feats = $c->model( 'RDS::MediaAssetFeature' )
	->search({ 'me.user_id' => $c->user->obj->id,
		   'contact.id' => { '!=', undef }, 
		   'me.feature_type'=>'face'}, 
                 {prefetch=>['contact','media_asset'], 
		  page=>1, rows=>4,
                  group_by=>['media_asset.media_id','contact.id'] });
    my @faces = ();
    foreach my $feat ( @feats ) {
        push( @faces, { uri => $feat->media_asset->uri,
                        name => $feat->contact->contact_name
              });
    }

    @feats = $c->model( 'RDS::MediaAssetFeature' )
	->search({ 'me.user_id' => $c->user->obj->id,
		   'contact.id' => { '!=', undef }, 
		   'contact.contact_name' => { '=', undef },
		   'me.feature_type'=>'face'}, 
                 {prefetch=>['contact','media_asset'], 
		  page=>1, rows=>4,
                  group_by=>['media_asset.media_id','contact.id'] });
    my @unnamed_faces = ();
    foreach my $feat ( @feats ) {
        push( @unnamed_faces, { uri => $feat->media_asset->uri,
              });
    }

    my $NOW    = DateTime->now;
    my $TARGET = DateTime->from_epoch( epoch => ($NOW->epoch - 60*60*24*7) );
    my $dtf    = $c->model( 'RDS' )->schema->storage->datetime_parser;
    my @tagged_faces = $c->user->contacts->search(
	{ updated_date => { '>', $dtf->format_datetime( $TARGET ) },
	  picture_uri  => { '!=', undef },
	  contact_name => { '!=', undef } });
    my @tf = map {{ uuid => $_->uuid, picture_uri => $_->picture_uri, contact_name => $_->contact_name }} @tagged_faces;

    my $headers = {
	subject => $c->loc( "This is a test" ),
	to => [{
	    email => $to,
	    name  => $c->user->displayname }],
	template => 'email/' . $template,
	stash => {
	    model => {
		user  => $c->user,
		media => \@media_array,
		faces => \@faces,
		unnamedfaces => \@unnamed_faces,
		tagged_faces => \@tf,
		vars => {
		    shareType => 'private',
		    user => $c->user->obj,
		    numVideosUploadedLastWeek => 10,
		    numVideosViewedLastWeek => 4,
		    totalVideosInAccount => $c->user->media->count,
		},
	    },
	    from => $c->user->obj,
	    commentText => "This is a new comment",
	    body => "This was text from textarea.",
	    url => sprintf( "%s#register?email=%s", $c->server,  $c->user->email ),
	    new_password => 'xxxyyyzzzfff',
	}
    };
    $self->send_email( $c, $headers );
    $self->status_ok( $c, {} );
}

sub i18n :Local {
    my( $self, $c ) = @_;
    my $name = $c->request->param('name') || $c->loc('Guest');
    # $c->response->content_type('text/plain; charset=utf-8');
    my $message = $c->loc( 'Welcome [_1]!', $name );
    $self->status_ok
	( $c, 
	  { translated => $message,
	    locale => $c->get_locale,
	    language => $c->language(),
	    languages => $c->languages(),
	    installed_languages => $c->installed_languages(),
	  } );
}

sub role_test :Local {
    my( $self, $c ) = @_;
    if ( $c->check_user_roles( 'tester' ) ) {
	$c->log->debug( "** IS A TESTER\n" );
    }
    else {
	$c->log->debug( "** DOES NOT APPEAR TO BE A TESTER\n" );
    }
    $self->status_ok( $c, {} );
}

sub new_video_test :Local {
    my( $self, $c ) = @_;

    my $with_faces = $self->where_valid_mediafile();
    $with_faces->{'media_assets.asset_type'} = 'face';
    my $without_faces = $self->where_valid_mediafile();

    my @media = $c->user->media->search
	($with_faces,
	 {order_by => 'me.id desc', 
	  prefetch=>'media_assets',
	  });
    my $uuid;
    if ( $#media >= 0 ) {
	$uuid = $media[0]->uuid;
    }
    else {
	my @media = $c->user->media->search
	    ($without_faces,
	     {order_by => 'me.id desc'});
	if ( $#media >= 0 ) {
	    $uuid = $media[0]->uuid;
	}
    }
    if ( $uuid ) {
	$c->req->params({ uid => $c->user->uuid,
			  mid => $uuid,
			  'site-token' => 'maryhadalittlelamb' });
	$c->forward( '/services/na/mediafile_create' );
    }
    else {
	$self->status_bad_request( $c, 'Could not find a media file with faces' );
    }
}


__PACKAGE__->meta->make_immutable;

1;
