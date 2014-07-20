package VA::Controller::Services::Album;
use Moose;
use namespace::autoclean;
use JSON::XS ();
use URI::Escape;

BEGIN { extends 'VA::Controller::Services' }

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

sub send_event_to_members :Private {
    my( $self, $c, $members, $type, $event, $data ) = @_;
    foreach my $member ( @$members ) {
	if ( $member->contact_viblio ) {
	    $c->model( 'MQ' )->post( '/enqueue', {
		uid => $member->contact_viblio->uuid,
		type => $type,
		send_event => $event,
		data => $data } );
	}
    }
}

sub notify :Private {
    my( $self, $c, $album, $_to ) = @_;

    # Prepare message model
    my $model = {
	user => $c->user->obj->TO_JSON,
	album => VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } ),
    };
    my $urls = {};
    # Send them to the message queue
    foreach my $to ( @$_to ) {
	if ( $to->{user} ) {
	    $c->model( 'MQ' )->post( '/enqueue', {
		uid => $to->{user}->uuid,
		type => 'new_shared_album',
		send_event => {
		    event => 'album:new_shared_album',
		    data  => { aid => $album->uuid }
		},
		data => $model } );

	    # This is the url in the email for an existing user
	    $urls->{ $to->{email} } = sprintf( "%s#home?aid=%s", $c->server, $album->uuid );

	    # remove user element, so we can use to for sending emails
	    delete $to->{user};
	}
	else {
	    # This user does not yet exist.  Like a private-share video, create
	    # a pending user and add them to the white list.  Add a share record
	    # so we can deal with it when the user registers.
	    #
	    my $pending_user = $c->model( 'RDS::User' )->find_or_create({
		displayname => $to->{email},
		provider_id => 'pending' });
	    unless( $pending_user ) {
		$self->status_bad_request
		    ( $c, $c->loc( "Failed to create a pending user for for [_1]", $to->{email} ) );
	    }
	    my $share = $album->find_or_create_related( 'media_shares', { 
		share_type => 'private',
		user_id => $pending_user->id });
	    unless( $share ) {
		$self->status_bad_request
		    ( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $album->uuid ) );
	    }
	    if ( $c->config->{in_beta} ) {
		my $wl = $c->model( 'RDS::EmailUser' )->find_or_create({
		    email => $to->{email},
		    status => 'whitelist' });
		unless( $wl ) {
		    $c->log->error( "Failed to add $to->{email} to whitelist for album share." );
		}
	    }
	    $urls->{ $to->{email} } = sprintf( "%s#register?email=%s&url=%s",
					       $c->server,
					       uri_escape( $to->{email} ),
					       uri_escape( '#home?aid=' . $album->uuid ) );
	}
    }
    # Send the email.  
    foreach my $to ( @$_to ) {
	$model->{url} = $urls->{$to->{email}};
	$self->send_email( $c, {
	    subject => $c->loc( '[_1] has invited you to a video album', $c->user->displayname ),
	    to => [ $to ],
	    template => 'email/19-albumSharedToYou.tt',
	    stash => $model } );
    }

}

sub list :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    my $rs = $c->user->albums->search({},{ page => $page, rows => $rows });
    my @albums = $rs->all;
    my $pager = $rs->pager;

    my @data = ();
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	$a->{is_shared} = ( $album->community ? 1 : 0 );
	push( @data, $a );
    }

    $self->status_ok( $c, { albums => \@data, pager => $self->pagerToJson( $pager ) } );
}

# Return a list of album titles for the albums the user owns
sub album_names_no_shared :Local {
    my( $self, $c ) = @_;
    my @a = $c->user->albums->search({},{order_by=>'title'});
    my @n = sort map { {title => $_->title(), uuid => $_->uuid()} } @a;
    $self->status_ok( $c, { albums => \@n } );
}

# Return a list of album titles for the albums the user owns and have
# been shared to the user.
sub album_names :Local {
    my( $self, $c ) = @_;

    my $rs = $c->model( 'RDS::ContactGroup' )->search
        ({'contact.contact_email'=>$c->user->email},
         { prefetch=>['contact',{'cgroup'=>'community'}]});

    my @communities = map { $_->cgroup->community } $rs->all;
    my @albums = map { {title => $_->album->title(), uuid => $_->album->uuid(), is_shared => 1} } @communities;

    foreach my $album ( $c->user->albums->all ) {
	push( @albums, { title => $album->title(), uuid => $album->uuid(), is_shared => 0 } );
    }

    my @n = sort { $a->{title} cmp $b->{title} } @albums;

    $self->status_ok( $c, { albums => \@n } );
}

sub create :Local {
    my( $self, $c ) = @_;
    my $name = $c->req->param( 'name' ) || 'unnamed';
    my $aid = $c->req->param( 'aid' );
    my $initial_mid = $c->req->param( 'initial_mid' );
    my @list = $c->req->param( 'list[]' );

    my $where = {
	is_album => 1,
	media_type => 'original',
    };
    if ( $aid ) {
	$where->{uuid} = $aid;
    }
    else {
	$where->{title} = $name;
    }
    my $album = $c->user->find_or_create_related( 'media', $where );

    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Failed to create a new album' ) );
    }

    unless ( $album->recording_date && $album->recording_date->epoch != 0 ) {
	$album->recording_date( DateTime->now );
	$album->update;
    }

    if ( $#list >= 0 ) {
	$initial_mid = shift @list unless ( $initial_mid );
    }

    if ( $initial_mid ) {
	my $media = $c->user->videos->find({ uuid => $initial_mid });
	unless( $media ) {
	    $self->status_bad_request( $c, $c->loc( 'Bad initial media uuid' ) );
	}
	my $rel = $c->model( 'RDS::MediaAlbum' )->find_or_create({ album_id => $album->id, media_id => $media->id });
	unless( $rel ) {
	    $self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between new album and initial media' ) );
	}
	# Set the poster of the new album to the poster of the video file just added
	my $has_a_poster = $album->find_related( 'media_assets', { asset_type => 'poster' } );
	if ( ! $has_a_poster ) {
	    my $poster = $media->assets->find({ asset_type => 'poster' });
	    $album->find_or_create_related( 'media_assets', {
		user_id => $c->user->obj->id,
		asset_type => 'poster',
		mimetype => $poster->mimetype,
		uri => $poster->uri,
		location => $poster->location,
		bytes => $poster->bytes,
		width => $poster->width,
		height => $poster->height,
		provider => $poster->provider,
		provider_id => $poster->provider_id });
	}
    }
    else {
	# Set the poster of the new album to a canned image
    }

    foreach my $vid ( @list ) {
	my $media = $c->user->videos->find({ uuid => $vid });
	unless( $media ) {
	    $self->status_bad_request( $c, $c->loc( 'Bad media uuid' ) );
	}
	my $rel = $c->model( 'RDS::MediaAlbum' )->find_or_create({ album_id => $album->id, media_id => $media->id });
	unless( $rel ) {
	    $self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between new album and media' ) );
	}
    }

    my $hash = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
    $hash->{owner} = $album->user->TO_JSON;

    $self->status_ok( $c, { album => $hash } );
}

sub get :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );

    my $include_contact_info = $c->req->param( 'include_contact_info' );
    $include_contact_info = 0 unless( $include_contact_info );
    my $include_tags = $c->req->param( 'include_tags' );
    $include_tags = 0 unless( $include_tags );

    my $params = {
	views => ['poster'],
	include_contact_info => $include_contact_info,
	include_tags => $include_tags,
    };

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    my $album_owner_uuid = undef;

    # Is this album viewable by the user?
    if ( $album->user_id != $c->user->id ) {
	# check shared albums
	my $rs = $c->model( 'RDS::ContactGroup' )->search
	    ({'contact.contact_email'=>$c->user->email},
	     { prefetch=>['contact',{'cgroup'=>'community'}]});
	my @communities = map { $_->cgroup->community } $rs->all;
	my @albums = map { $_->album } @communities;
	my $found = 0;
	foreach my $sa ( @albums ) {
	    if ( $sa->id == $album->id ) {
		$found = 1;
	    }
	}
	if ( ! $found ) {
	    $self->status_bad_request( $c, $c->loc( 'You do not have permission to view this album.' ) );
	}
    } else {
	$album_owner_uuid = $c->user->uuid;
    }

    my $poster_params = { views => ['poster'] };
    if ( $album_owner_uuid ) {
	$poster_params->{owner_uuid} = $album_owner_uuid;
    }
    my $hash = VA::MediaFile->new->publish( $c, $album, $poster_params );
    $hash->{is_shared} = ( $album->community ? 1 : 0 );

    # We want to avoid doing 1 DB query per media, so we compute some
    # stuff here and pass it down.  The callees check for the computed
    # data and use it, or generate it if needed.
    #
    # First off we want the set of unique tags for each media if
    # necessary.
    #
    # Media tags maps media.id to an hash ref keyed with tags for that
    # media.
    my $media_tags_by_owner_id = {};
   
    # Get all the feature information per owner.
    my $contact_features_by_owner_id = {};

    # Get all asset information per owner.
    my $assets_by_owner_id = {};

    my $owner_json_by_id = {};

    # Build up a data structure of media_owner UUIDs so we only do one
    # query per owner UUID in the album.
    my $media_owners = {};
    my @m = ();
    foreach my $med ( $album->media->search({},{order_by => 'recording_date desc'}) ) {
	my $owner_id = $med->user_id;
	unless ( exists( $media_owners->{$owner_id} ) ) {
	    $media_owners->{$owner_id} = $med->user->uuid;
	}
	$params->{owner_uuid} = $media_owners->{$owner_id};

	unless ( exists( $owner_json_by_id->{$owner_id} ) ) {
	    $owner_json_by_id->{$owner_id} = $med->user->TO_JSON();
	}

	unless ( exists( $assets_by_owner_id->{$owner_id} ) ) {
	    my @user_assets = $c->model( 'RDS::MediaAsset' )->search(
		{ 'me.user_id' => $owner_id } )->all();
	    foreach my $ua ( @user_assets ) {
		if ( exists( $assets_by_owner_id->{$owner_id}->{$ua->media_id} ) ) {
		    push( @{$assets_by_owner_id->{$owner_id}->{$ua->media_id}}, $ua );
		} else {
		    $assets_by_owner_id->{$owner_id}->{$ua->media_id} = [ $ua ];
		}
	    }
	    if ( exists( $assets_by_owner_id->{$owner_id}->{$med->id} ) ) {
		$params->{assets} = $assets_by_owner_id->{$owner_id}->{$med->id};
	    }
	}

	if ( $include_tags ) {
	    unless ( exists( $media_tags_by_owner_id->{$owner_id} ) ) {
		# Get all tags for the user.
		my $media_tags = {};
		my @mafs = $c->model( 'RDS::MediaAssetFeature' )->search(
		    { 'me.user_id' => $owner_id,
		      -or => [ 'me.feature_type' => 'activity',
			       -and => [ 'me.feature_type' => 'face',
					 'me.contact_id' => { '!=', undef } ] ] } )->all();
		foreach my $m ( @mafs ) {
		    my $tag = undef;
		    if ( $m->{_column_data}->{feature_type} eq 'face' ) {
			$tag = 'people';
		    } else {
			$tag = $m->coordinates;
		    }
		    if ( defined( $tag ) ) {
			$media_tags->{$m->media_id}->{$tag} = 1;
		    }
		    $media_tags_by_owner_id->{$owner_id}->{$m->media_id} = $media_tags;
		}
	    } 
	    if ( exists( $media_tags_by_owner_id->{$owner_id}->{$med->id} ) ) {
		$params->{media_tags} = $media_tags_by_owner_id->{$owner_id}->{$med->id};
	    } else {
		$params->{media_tags} = {};
	    }
	}

	if ( $include_contact_info ) {
	    unless ( exists( $contact_features_by_owner_id->{$owner_id} ) ) {
		my @feats = $c->model( 'RDS::MediaAssetFeature' )
		    ->search({'me.user_id' => $owner_id,
			      'contact.id' => { '!=', undef },
			      'me.feature_type'=>'face'},
			     {prefetch=>['contact','media_asset'],
			      group_by=>['contact.id']
			     });
		foreach my $feat ( @feats ) {
		    if ( exists( $contact_features_by_owner_id->{$owner_id}->{$feat->media_id} ) ) {
			push( @{$contact_features_by_owner_id->{$owner_id}->{$feat->media_id}},  $feat );
		    } else {
			$contact_features_by_owner_id->{$owner_id}->{$feat->media_id} = [ $feat ];
		    }
		}
	    }
	    if ( exists( $contact_features_by_owner_id->{$owner_id}->{$med->id} ) ) {
		$params->{features} = $contact_features_by_owner_id->{$owner_id};
	    } else {
		$params->{features} = { $med->id => [] };
	    }
	}

	my $data = VA::MediaFile->new->publish( 
	    $c, $med, 
	    $params );
	$data->{owner} = $owner_json_by_id->{$owner_id};
	push( @m, $data );
    } 
	
    $hash->{media} = \@m;
    $hash->{owner} = $album->user->TO_JSON; 

    $self->status_ok( $c, { album => $hash } );
}

sub add_media :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $mid = $c->req->param( 'mid' );
    my @list = $c->req->param( 'list[]' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    my $media;
    my $template;
    my $subject;

    $template = 'email/20-newVideoAddedToAlbum.tt';
    $subject = $c->loc( '[_1] added a new video to [_2]', $c->user->displayname, $album->title );

    if ( $mid ) {
	$media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
	unless( $media ) {
	    $self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
	}

	my $rel = $c->model( 'RDS::MediaAlbum' )->find_or_create({ album_id => $album->id, media_id => $media->id });
	unless( $rel ) {
	    $self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between album and media' ) );
	}
    }
    elsif ( $#list >= 0 ) {
	foreach $mid ( @list ) {
	    $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
	    unless( $media ) {
		$self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
	    }

	    my $rel = $c->model( 'RDS::MediaAlbum' )->find_or_create({ album_id => $album->id, media_id => $media->id });
	    unless( $rel ) {
		$self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between album and media' ) );
	    }
	}
	if ( $#list > 0 ) {
	    $template = 'email/20-newVideosAddedToAlbum.tt';
	    $subject = $c->loc( '[_1] added some new videos to [_2]', $c->user->displayname, $album->title );
	}
    }
    else {
	$self->status_bad_request( $c, $c->loc( 'No media files specified to add!' ) );
    }

    # If this is a shared album, we have some notifications to send!
    #
    my $com = $album->community;
    if ( $com ) {
	my @to = map {{
	    email => $_->contact_email,
	    name  => $_->contact_name,
	    user  => $_->contact_viblio }} $com->members->contacts;
	# Add the owner of this album
	push( @to, {
	    email => $album->user->email,
	    name  => $album->user->displayname,
	    user  => $album->user });
	# Now remove the initiating user
	#$c->log->debug( $encoder->encode( \@to ) );
	my $index = -1;
	for( my $i=0; $i<=$#to; $i++ ) {
	    $index = $i if ( $to[$i]->{email} eq $c->user->email );
	}
	splice( @to, $index, 1 ) if ( $index >= 0 );
	#$c->log->debug( 'index=' . $index );
	#$c->log->debug( $encoder->encode( \@to ) );
	# Prepare message model
	my $model = {
	    user => $c->user->obj->TO_JSON,
	    album => VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } ),
	    video => VA::MediaFile->new->publish( $c, $media, { views => ['poster'] } ),
	    url => sprintf( "%s#web_player?mid=%s", $c->server, $media->uuid ),
	    num => ( $#list + 1 ),
	};
	# Send them to the message queue and send email
	foreach my $to ( @to ) {
	    if ( $to->{user} ) {
		$c->model( 'MQ' )->post( '/enqueue', {
		    uid => $to->{user}->uuid,
		    type => 'new_album_video',
		    send_event => {
			event => 'album:new_shared_album_video',
			data  => { aid => $album->uuid, mid => $media->uuid }
		    },
		    data => $model } );
		# remove user element, so we can use to for sending emails
		delete $to->{user};

		$self->send_email( $c, {
		    subject => $subject,
		    to => [ $to ],
		    template => $template,
		    stash => $model } );
	    }
	}
    }

    $self->status_ok( $c, {} );
}

sub remove_media :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $mid = $c->req->param( 'mid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
    }

    my $com = $album->community;
    if ( $com ) {
	$self->send_event_to_members(
	    $c, [ $com->members->contacts->all ],
	    'delete_shared_album_video',
	    { event => 'album:delete_shared_album_video', data => {
		aid => $album->uuid, mid => $media->uuid } } );
    }

    my $rel = $c->model( 'RDS::MediaAlbum' )->find({ album_id => $album->id, media_id => $media->id });
    unless( $rel ) {
	$self->status_bad_request( $c, $c->loc( 'Unable to find relationship between album and media' ) );
    }
    $rel->delete; $rel->update;

    $self->status_ok( $c, {} );
}

sub change_title :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $title = $c->req->param( 'title' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    $album->title( $title );
    $album->update;

    $self->status_ok( $c, {} );
}

sub delete_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    my $community = $album->community;
    if ( $community ) {
	# Send an event to users in case they are viewing this share
	$self->send_event_to_members(
	    $c, [ $community->members->contacts->all ],
	    'delete_shared_album',
	    { event => 'album:delete_shared_album', data => { aid => $album->uuid } } );
	$community->members->delete;
	$community->delete;
    }

    my $rs = $c->model( 'RDS::MediaAlbum' )->search({ album_id => $album->id });
    $rs->delete if ( $rs );
    $album->delete;

    $self->status_ok( $c, {} );
}

# List albums shared to me
sub list_shared :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    # Following copied from User::is_community_member_of() to enable paging
    # my @albums = map { $_->album } $c->user->is_community_member_of();

    my $rs = $c->model( 'RDS::ContactGroup' )->search
	({'contact.contact_email'=>$c->user->email},
	 { page => $page, rows => $rows,
	   prefetch=>['contact',{'cgroup'=>'community'}]});

    my @communities = map { $_->cgroup->community } $rs->all;
    my @albums = map { $_->album } @communities;

    my @data = ();
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	$a->{is_shared} = 1;
	push( @data, $a );
    }

    $self->status_ok( $c, { albums => \@data, pager => $self->pagerToJson( $rs->pager ) } );
}

# This lists all albums, owned by the user and shared to the user.
sub list_all :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    my $rs = $c->model( 'RDS::ContactGroup' )->search
	({'contact.contact_email'=>$c->user->email},
	 { page => $page, rows => $rows,
	   prefetch=>['contact',{'cgroup'=>'community'}]});

    my @communities = map { $_->cgroup->community } $rs->all;
    my @albums = map { $_->album } @communities;

    my @data = ();
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	$a->{shared_to_me} = 1;
	push( @data, $a );
    }

    @albums = $c->user->albums->all;
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	$a->{is_shared} = ( $album->community ? 1 : 0 );
	push( @data, $a );
    }

    # resort based on title
    my @sorted = sort { $a->{title} cmp $b->{title} } @data;
    my $pager = Data::Page->new( $#sorted + 1, $rows, $page );
    my @slice = ();
    if ( $#sorted >= 0 ) {
	@slice = @sorted[ $pager->first - 1 .. $pager->last - 1 ];
    }
    $self->status_ok( $c, { albums => \@slice, 
			    pager  => $self->pagerToJson( $pager ) });
}

# Similar to list_shared() but organized by sharer.  No paging because of this.
# This returns something very similar to all_shared() for videos.
sub list_shared_by_sharer :Local {
    my( $self, $c ) = @_;
    my @albums = map { $_->album } $c->user->is_community_member_of();
    my @data = ();
    my $users = {};
    foreach my $album ( @albums ) {
	my $owner = $album->user->displayname;
	if ( ! defined( $users->{ $owner } ) ) {
            $users->{ $owner } = [];
        }
        push( @{$users->{ $owner }}, $album );
    }
    my @sorted_user_keys = sort{ lc( $a ) cmp lc( $b ) } keys( %$users );
    foreach my $key ( @sorted_user_keys ) {
        my @as = ();
	foreach my $album ( sort{ $b->created_date->epoch <=> $a->created_date->epoch } @{$users->{ $key }} ) {
	    my $a = VA::MediaFile->publish( $c, $album, { views => ['poster' ] } );
	    my @m = ();
	    push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos->search({},{rows=>4}) );
	    $a->{media} = \@m;
	    $a->{is_shared} = 1;
	    push( @as, $a );
	}
	push( @data, {
	    owner => $users->{ $key }[0]->user->TO_JSON,
            albums => \@as });
    }
    $self->status_ok( $c, { shared => \@data } );
}

# If the user has permission to see the passed in mid by virtue of
# it being shred to him, then return the published content.
sub get_shared_video :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    if ( $c->user->obj->can_view_video( $mid ) ) {
	my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
	$self->status_ok( $c, { media => VA::MediaFile->new->publish( $c, $media, { views => ['poster'] } ) } );
    }
    else {
	$self->status_bad_request( 
	    $c, $c->loc( 'User is not allowed to access this video' ) ); 
    }
}

sub share_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my @members = $c->req->param( 'members[]' );
    my @clean = $self->expand_email_list( $c, \@members, [ $c->user->email ] );
    my $members = \@clean;
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find this album' ) );
    }

    # If this album is already shared, then do not create another one!
    # Although technically possible to have multiple communities pointing to
    # a single album, this makes the GUI very problematic!!  So, if the album is
    # already shared, then merge the new list of members into the existing
    # list of members.
    #
    my $com = $album->community;
    my @to = ();
    if ( $com ) {
	# Already exists
	my @old_members = $com->members->contacts;
	$com->members->add_contacts( $members );
	my $hash = {};
	$hash->{ $_->contact_email } = $_ foreach( $com->members->contacts );
	foreach my $member ( @old_members ) {
	    if ( $hash->{ $member->contact_email } ) {
		delete $hash->{ $member->contact_email } 
	    }
	}
	foreach my $email ( keys %$hash ) {
	    push( @to, {
		email => $hash->{$email}->contact_email,
		name  => $hash->{$email}->contact_name,
		user  => $hash->{$email}->contact_viblio });
	}
    }
    else {
	# Create a new shared album
	$com = $c->user->create_shared_album( $album, $members );
	if ( $com ) {
	    @to = map {{
		email => $_->contact_email,
		name  => $_->contact_name,
		user  => $_->contact_viblio }} $com->members->contacts;
	}
    }
    unless( $com ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not share this album' ) );
    }

    # We have some notifications to send!
    #
    $self->notify( $c, $album, \@to );
    $self->status_ok( $c, {} );    
}

sub add_members_to_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my @members = $c->req->param( 'members[]' );
    my @clean = $self->expand_email_list( $c, \@members, [ $c->user->email ] );
    my $members = \@clean;
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }

    # Have to determine the new people actually added, so we can notify them
    #
    my @old_members = $community->members->contacts;
    $community->members->add_contacts( $members );
    my $hash = {};
    $hash->{ $_->contact_email } = $_ foreach( $community->members->contacts );
    foreach my $member ( @old_members ) {
	if ( $hash->{ $member->contact_email } ) {
	    delete $hash->{ $member->contact_email } 
	}
    }
    my @to = ();
    foreach my $email ( keys %$hash ) {
	push( @to, {
	    email => $hash->{$email}->contact_email,
	    name  => $hash->{$email}->contact_name,
	    user  => $hash->{$email}->contact_viblio });
    }

    $self->notify( $c, $album, \@to );
    $self->status_ok( $c, {} );        
}

sub remove_members_from_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my @members = $c->req->param( 'members[]' );
    my @clean = $self->expand_email_list( $c, \@members, [ $c->user->email ] );
    my $members = \@clean;
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }
    my @removed = $community->members->contacts->search({
	contact_email => { -in => $members } });
    $self->send_event_to_members(
	$c, \@removed,
	'delete_shared_album',
	{ event => 'album:delete_shared_album', data => { aid => $album->uuid } } );
    
    $community->members->remove_contacts( $members );
    $self->status_ok( $c, {} );        
}

# Anyone shoud be able to remove themselves from a shared album membership
sub remove_me_from_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }
    $community->members->remove_contacts( $c->user->obj->email );
    $self->status_ok( $c, {} );        
}

sub delete_shared_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not delete this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }
    # Send an event to users in case they are viewing this share
    $self->send_event_to_members(
	$c, [ $community->members->contacts->all ],
	'delete_shared_album',
	{ event => 'album:delete_shared_album', data => { aid => $album->uuid } } );

    $community->members->delete;
    $community->delete;
    $self->status_ok( $c, {} );
}

# List the people that the shared album is shared with.  Returns:
# { displayname: "nice string to display",
#   members: [ array-of-contacts ]
# }
#
sub shared_with :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find shared with info for this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }
    my @members = $community->members->contacts;
    my $displayname = $c->loc( 'Shared with no one' );

    my $count = $#members + 1;
    if ( $count == 1 ) {
	$displayname = $members[0]->contact_name;
    }
    elsif ( $count == 2 ) {
	$displayname = sprintf( 
	    "%s and %s",
	    $members[0]->contact_name,
	    $members[1]->contact_name );
    }
    elsif ( $count > 2 ) {
	my $rem = $count - 2;
	$displayname = sprintf(
	    "%s, %s and %d other%s",
	    $members[0]->contact_name,
	    $members[1]->contact_name,
	    $rem, ( $rem > 1 ? 's' : '' ));
    }
    
    my @data = map { $_->TO_JSON } @members;
    $self->status_ok( $c, { displayname => $displayname, members => \@data } );
}

sub create_face_album :Local {
    my( $self, $c ) = @_;
    my $title = $c->req->param( 'title' );
    my $contact_uuid = $c->req->param( 'contact_id' );

    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $contact_uuid });
    unless( $contact ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find contact' ) );
    }

    unless( $title ) {
	$title = $contact->contact_name;
    }

    my $rs = $c->model( 'RDS::MediaAssetFeature' )
	->search(
	{ contact_id => $contact->id, 'me.user_id' => $c->user->id },
	{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );

    my @mediafiles = map { $_->media_asset->media } $rs->all;

    my $album = $c->user->create_related( 'media', {
	is_album => 1,
	recording_date => DateTime->now,
	media_type => 'original',
	title => $title });

    unless( $album ) {
	$c->status_bad_request( $c, $c->loc( 'Unable to create album' ) );
    }

    # Add all the media
    foreach my $media ( @mediafiles ) {
	my $rel = $c->model( 'RDS::MediaAlbum' )->create({ album_id => $album->id, media_id => $media->id });
	unless( $rel ) {
	    $self->status_bad_request( 
		$c, $c->loc( 'Unable to establish relationship between new album and media' ) );
	}
    }

    # The poster for this album is obtained from the first mediafile
    my $media = $mediafiles[0];
    my $poster = $media->assets->find({ asset_type => 'poster' });
    $album->create_related( 'media_assets', {
	user_id => $c->user->obj->id,
	asset_type => 'poster',
	mimetype => $poster->mimetype,
	uri => $poster->uri,
	location => $poster->location,
	bytes => $poster->bytes,
	width => $poster->width,
	height => $poster->height,
	provider => $poster->provider,
	provider_id => $poster->provider_id });


    my $hash = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
    $hash->{owner} = $album->user->TO_JSON;
    $self->status_ok( $c, { album => $hash } );
}

# Search by title or description
sub search_by_title_or_description :Local {
    my( $self, $c ) = @_;
    my $q = $c->req->param( 'q' );
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 10000;
    my $rs = $c->user->albums->search(
	{ -or => [ 'LOWER(title)' => { 'like', '%'.lc($q).'%' },
		   'LOWER(description)' => { 'like', '%'.lc($q).'%' } ] },
	{ order_by => 'recording_date desc',
	  page => $page, rows => $rows } );
    my @data = map { VA::MediaFile->publish( $c, $_, { views => ['poster' ], include_tags => 1 } ) } $rs->all;
    $self->status_ok( $c, { media => \@data, pager => $self->pagerToJson( $rs->pager ) } );
}


__PACKAGE__->meta->make_immutable;

1;

