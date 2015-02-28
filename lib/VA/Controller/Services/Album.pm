package VA::Controller::Services::Album;
use Moose;
use namespace::autoclean;
use JSON::XS ();
use URI::Escape;

use Data::Page;
use Try::Tiny;

use Storable qw/ dclone /;

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
	    $urls->{ $to->{email} } = sprintf( "%s#register?email=%s&url=%s",
					       $c->server,
					       uri_escape( $to->{email} ),
					       uri_escape( '#home?aid=' . $album->uuid ) );


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

# DEPRECATED
sub list :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    $self->status_bad_request( $c, "services/album/list is deprecated." );

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

# DEPRECATED
#
# Return a list of album titles for the albums the user owns
sub album_names_no_shared :Local {
    my( $self, $c ) = @_;
    
    $self->status_bad_request( $c, "services/album/album_names_no_shared is deprecated." );

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
    my @albums = ();
    
    my $seen_owners = {};

    foreach my $community ( @communities ) {
	my $owner_id = $community->user_id();
	my $owner_uuid = undef;
	if ( exists( $seen_owners->{ $owner_id } ) ) {
	    $owner_uuid = $seen_owners->{ $owner_id };
	} else {
	    $owner_uuid = $community->user->uuid();
	    $seen_owners->{ $owner_id } = $owner_uuid;
	}
	push( @albums, { title => $community->album->title(),
			 uuid => $community->album->uuid(),
			 is_shared => 1,
			 owner_uuid => $owner_uuid } );
    }

    foreach my $album ( $c->user->albums->all ) {
	my $owner_id = $album->user_id();
	my $owner_uuid = undef;
	if ( exists( $seen_owners->{ $owner_id } ) ) {
	    $owner_uuid = $seen_owners->{ $owner_id };
	} else {
	    $owner_uuid = $album->user->uuid();
	    $seen_owners->{ $owner_id } = $owner_uuid;
	}
	push( @albums, { title => $album->title(), uuid => $album->uuid(), is_shared => 0, owner_uuid => $owner_uuid } );
    }

    my @n = sort { $a->{title} cmp $b->{title} } @albums;

    $self->status_ok( $c, { albums => \@n } );
}

sub create_album_helper :Private {
    my ( $self, $c, $name, $aid, $is_viblio_created, $set_album_cover ) = @_;

    my $where = {
	user_id => $c->user->id(),
	is_album => 1,
	media_type => 'original',
    };
    if ( $name ) {
	$where->{title} = $name;
    }

    my @albums = $c->model( 'RDS::Media' )->search( $where )->all();

    if ( scalar( @albums ) > 0 ) {
	# At least one album of this name already exists, change the
	# name of the desired created album.
	if ( my $count = ( $name =~ m/\(\d+\)$/ ) ) {
	    my $new_count = $count + 1;
	    $name =~ s/\($count\)$/\($new_count\)/;
	} else {
	    $name = "$name (1)";
	}
	
	$where->{title} = "$name";
    }

    if ( $aid ) {
	$where->{uuid} = $aid;
    }

    my $album = $c->user->find_or_create_related( 'media', $where );

    if ( $is_viblio_created ) {
	$album->is_viblio_created( 1 );
    }

    unless ( $album->recording_date && $album->recording_date->epoch != 0 ) {
	$album->recording_date( DateTime->now );
    }

    $album->title( $name );
    $album->update;

    # Set the poster of the new album to a canned image
    if ( defined( $set_album_cover ) ) {
	try {
	    my $s3_bucket = $set_album_cover->{s3_bucket};
	    my $s3_key = $set_album_cover->{s3_key};
	    my $width = $set_album_cover->{width};
	    my $height = $set_album_cover->{height};
	    my $mimetype = $set_album_cover->{mimetype};
	    my $bucket = $c->model( 'S3' )->bucket( name => $s3_bucket );
	    my $poster_image = $bucket->object( key => $s3_key );
	    $c->stash->{data} = $poster_image->get();
	    my $poster = VA::MediaFile::US->create( $c, { album => $album, width => $width, height => $height, mimetype => $mimetype, assettype => 'poster' } );
	} catch {
	    # Oh well...
	    $c->log->error( "Failed to set default poster image: $_" );
	}
    }

    return $album;
}

# Delegate the actual work to a subroutine, call the subroutine from
# elsewhere, leave status and such in tact here.
sub create :Local {
    my( $self, $c ) = @_;
    my $name = $c->req->param( 'name' ) || 'unnamed';
    my $aid = $c->req->param( 'aid' );
    my $initial_mid = $c->req->param( 'initial_mid' );

    my @list = $c->req->param( 'list[]' );

    my $album = $self->create_album_helper( $c, $name, $aid );

    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Failed to create a new album' ) );
    }

    if ( $#list >= 0 ) {
	$initial_mid = shift @list unless ( $initial_mid );
    }

    if ( $initial_mid ) {
	my $media = $c->user->videos->find( { uuid => $initial_mid } );
	unless( $media ) {
	    $self->status_not_found( $c, $c->loc( 'Bad initial media uuid' ), $initial_mid );
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
	try {
	    my $bucket = $c->model( 'S3' )->bucket( name => 'viblio-external' );
	    my $poster_image = $bucket->object( key => 'media/default-images/DEFAULT-poster.png' );
	    $c->stash->{data} = $poster_image->get();
	    my $poster = VA::MediaFile::US->create( $c, { album => $album, width => 288, height => 216, mimetype => 'image/png', assettype => 'poster' } );
	} catch {
	    # Oh well...
	    $c->log->error( "Failed to set default poster image: $_" );
	}
    }

    foreach my $vid ( @list ) {
	my $media = $c->user->videos->find({ uuid => $vid });
	unless( $media ) {
	    $self->status_not_found( $c, $c->loc( 'Bad media uuid' ), $vid );
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

=head2

services/album/get - Return a list of media in the requested album,
with posters, if the user has permission to view.

Inputs:
* aid - The uuid of the album
* include_contact_info - Defaults to 0, if true includes face info in the response
* include_tags - Defaults to 0
* include_images - Defaults to 0
* only_visible - Defaults to 1
* only_videos - Defaults to 1

=cut

sub get :Local {
    my $self = shift;
    my $c = shift;
    my $args = $self->parse_args
	( $c,
	  [ aid => undef,
	    page => 1,
	    rows => 100000,
	    include_contact_info => 0,
	    include_tags => 0,
	    include_images => 0,
	    only_visible => 1,
	    only_videos => 1,
	    'tags[]' => [],
	    no_dates => 0,
	    'media_uuids[]' => []
	  ],
	  @_ );

    my $aid = $args->{aid};
    my $page = $args->{page};
    my $rows = $args->{rows};
    my $tags = $args->{'tags[]'};

    my $include_contact_info = $args->{include_contact_info};
    my $include_tags = $args->{include_tags};
    my $include_images = $args->{include_images};
    my $only_visible = $args->{only_visible};
    my $only_videos = $args->{only_videos};
    my $no_dates = $args->{no_dates};
    my $media_uuids = $args->{'media_uuids[]'};

    #$DB::single = 1;

    # If we've been asked to filter by tags we may as well include
    # tags.
    if ( scalar( @$tags ) ) {
	$include_tags = 1;
    }

    my $params = {
	views => ['poster'],
	include_contact_info => $include_contact_info,
	include_tags => $include_tags,
    };
    
    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }

    # DEBUG - Make sure if I ask for an album I can't see I get
    # nothing.  Should I get an error instead?

    my $album_owner_uuid = $c->user->uuid;

    my $poster_params = { views => ['poster'] };
    if ( $album_owner_uuid ) {
	$poster_params->{owner_uuid} = $album_owner_uuid;
    }
    my $hash = VA::MediaFile->new->publish( $c, $album, $poster_params );
    $hash->{is_shared} = ( $album->community ? 1 : 0 );

    my $all_tags = {};
    my $no_date_return = 0;

    if ( $include_tags ) {
	my $tags_params = {
	    page => undef,
	    rows => undef,
	    include_contact_info => 0,
	    include_images => 0,
	    include_tags => 1,
	    only_visible => 1,
	    only_videos => 1,
	    'views[]' => ['main'],
	    'album_uuids[]' => [ $aid ] };
	$all_tags = $c->user->get_tags( $tags_params );
	
	if ( exists( $all_tags->{'No Dates'} ) ) {
	    $no_date_return = 1;
	}
    
	my $face_tag_params = dclone( $tags_params );
	$face_tag_params->{include_contact_info} = 1;
	my $face_tags = $c->user->get_face_tags( $face_tag_params );
	for my $face_tag ( keys( %$face_tags ) ) {
	    if ( exists( $all_tags->{$face_tags->{$face_tag}->{contact_name}} ) ) {
		$all_tags->{$face_tags->{$face_tag}->{contact_name}} += $face_tags->{$face_tag}->{face_count};
	    } else {
		$all_tags->{$face_tags->{$face_tag}->{contact_name}} = $face_tags->{$face_tag}->{face_count};
	    }
	}
    }

    my ( $videos, $pager ) = $c->user->visible_media( {
	page => $page,
	rows => $rows,
	include_contact_info => $include_contact_info,
	include_image => $include_images,
	include_tags => $include_tags,
	'album_uuids[]' => [ $aid ],
	no_dates => $no_dates,
	'tags[]' => $tags,
	only_videos => $only_videos,
	only_visible => $only_visible,
	'media_uuids[]' => $media_uuids } );

    my ( $media_tags, $media_contact_features ) = $self->get_tags( $c, $videos );

    my $m = undef;
    if ( $include_tags ) {
	$m = ( $self->publish_mediafiles( $c, $videos, { include_owner_json => 1,
							 include_contact_info => $include_contact_info,
							 include_tags => $include_tags,
							 include_images => $include_images,
							 media_tags => $media_tags,
							 media_contact_features => $media_contact_features } ) );
    } else {
	$m = ( $self->publish_mediafiles( $c, $videos, { include_owner_json => 1,
							 include_contact_info => $include_contact_info,
							 include_tags => $include_tags,
							 include_images => $include_images } ) );
    }

    $hash->{media} = $m;
    $hash->{owner} = $album->user->TO_JSON; 

    $self->status_ok( $c, { album => $hash, 
			    pager => $self->pagerToJson( $pager ), 
			    all_tags => $all_tags, 
			    no_date_return => $no_date_return } );
}

sub add_media :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $mid = $c->req->param( 'mid' );
    my @list = $c->req->param( 'list[]' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }

    my $media;
    my $template;
    my $subject;

    $template = 'email/20-newVideoAddedToAlbum.tt';
    $subject = $c->loc( '[_1] added a new video to [_2]', $c->user->displayname, $album->title );

    if ( $mid ) {
	$media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
	unless( $media ) {
	    $self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
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
		$self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
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
	# Send them to the message queue and send email
	foreach my $to ( @to ) {
	    if ( $to->{user} ) {

		my $model = {
		    user => $c->user->obj->TO_JSON,
		    album => VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } ),
		    video => VA::MediaFile->new->publish( $c, $media, { views => ['poster'] } ),
		    #url => sprintf( "%s#web_player?mid=%s", $c->server, $media->uuid ),
		    url => sprintf( "%s#register?email=%s&url=%s",
				    $c->server,
				    uri_escape( $to->{email} ),
				    uri_escape( '#home?aid=' . $album->uuid ) ),
		    num => ( $#list + 1 ),
		};

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
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    } elsif ( $album->user_id() != $c->user->id() ) {
	$self->status_forbidden( $c, $c->loc( 'Cannot remove items from album you do not own [_1]', $aid ), $aid );
    }
    unless( $media ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
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
    my $title = $self->sanitize( $c, $c->req->param( 'title' ) );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    } elsif ( $album->user_id() != $c->user->id() ) {
	$self->status_forbidden( $c, $c->loc( 'You do not have permission to edit [_1]', $aid ), $aid );
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
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
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

# DEPRECATED
#
# List albums shared to me
sub list_shared :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    $self->status_bad_request( $c, "services/album/list_shared is deprecated." );

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

# DEPRECATED
#
# This lists all albums, owned by the user and shared to the user.
sub list_all :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    $self->status_bad_request( $c, "services/album/list_all is deprecated." );

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

# DEPRECATED

# Similar to list_shared() but organized by sharer.  No paging because of this.
# This returns something very similar to all_shared() for videos.
sub list_shared_by_sharer :Local {
    my( $self, $c ) = @_;
    
    $self->status_bad_request( $c, "serices/album/list_shared_by_sharer is deprecated." );

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

# DEPRECATED
#
# If the user has permission to see the passed in mid by virtue of
# it being shred to him, then return the published content.
sub get_shared_video :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
 
    $self->status_bad_request( $c, "services/album/get_shared_video is deprecated." );
   
    my @result = $c->user->obj->visible_media( { 'media_uuids[]' => [ $mid ] } );

    if ( scalar( @result ) ) {
	my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
	$self->status_ok( $c, { media => VA::MediaFile->new->publish( $c, $media, { views => ['poster'] } ) } );
    }
    else {
	$self->status_forbidden( 
	    $c, $c->loc( 'User is not allowed to access this video' ), $mid ); 
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
	$self->status_not_found(
	    $c, $c->loc( 'Could not find this album' ), $aid );
    }

    # If this album is already shared, then do not create another one!
    # Although technically possible to have multiple communities
    # pointing to a single album, this makes the GUI very problematic!
    # So, if the album is already shared, then merge the new list of
    # members into the existing list of members.
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

#DEPRECATED
sub add_members_to_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my @members = $c->req->param( 'members[]' );

    $self->status_bad_request( $c, "services/album/add_members_to_shared is deprecated." );

    my @clean = $self->expand_email_list( $c, \@members, [ $c->user->email ] );
    my $members = \@clean;
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find this album' ), $aid );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find community container for album' ), $aid );
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
	$self->status_not_found(
	    $c, $c->loc( 'Could not find this album' ), $aid );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find community container for album' ), $aid );
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
	$self->status_not_found(
	    $c, $c->loc( 'Could not find this album' ), $aid );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find community container for album' ), $aid );
    }
    $community->members->remove_contacts( $c->user->obj->email );
    $self->status_ok( $c, {} );        
}

sub delete_shared_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not delete this album' ), $aid );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find community container for album' ), $aid );
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
	$self->status_not_found(
	    $c, $c->loc( 'Could not find shared with info for this album' ), $aid );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_not_found(
	    $c, $c->loc( 'Could not find community container for album' ), $aid);
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

# DEPRECATED
# 
# Create an album of faces for the input contact_id.
sub create_face_album :Local {
    my( $self, $c ) = @_;
    my $title = $self->sanitize( $c, $c->req->param( 'title' ) );
    my $contact_uuid = $c->req->param( 'contact_id' );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );

    $self->status_bad_request( $c, "services/album/create_face_album is deprecated." );


    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $contact_uuid });
    unless( $contact ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find contact' ), $contact_uuid );
    }

    unless( $title ) {
	$title = $contact->contact_name;
    }

    my $where = { 
	contact_id => $contact->id, 
	'me.user_id' => $c->user->id, 
	feature_type => 'face' 
    };

    if ( $only_videos ) {
	$where->{'media.media_type'} = 'original';
    }

    my $rs = $c->model( 'RDS::MediaAssetFeature' )
	->search(
	$where,
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

# DEPRECATED
#
# Search by title or description
sub search_by_title_or_description :Local {
    my( $self, $c ) = @_;
    my $q = $self->sanitize( $c, $c->req->param( 'q' ) );
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 10000;

    $self->status_bad_request( $c, "services/album/search_by_title_or_description is deprecated." );


    my $rs = $c->user->albums->search(
	{ -or => [ 'LOWER(title)' => { 'like', '%'.lc($q).'%' },
		   'LOWER(description)' => { 'like', '%'.lc($q).'%' } ] },
	{ order_by => 'recording_date desc',
	  page => $page, rows => $rows } );
    
    my $data = $self->publish_mediafiles( $c, [ $rs->all() ], { include_tags => 1 } );
    $self->status_ok( $c, { media => $data, pager => $self->pagerToJson( $rs->pager ) } );
}

# Handle the banner photo per album.
#
sub add_or_replace_banner_photo :Local {
    my( $self, $c ) = @_;

    my $user = $c->user->obj;
    unless( $user ) {
	$self->status_not_found( $c, $c->loc("User for not found!" ) );
    }

    my $aid = $c->req->param( 'aid' );
    my $album = $c->model( 'RDS::Media' )->find( { uuid => $aid, user_id => $user->id() } );
    unless( $album ) {
	my $album = $c->model( 'RDS::Media' )->find( { uuid => $aid } );
	if ( $album ) {
	    $self->status_forbidden(
		$c, $c->loc( 'This user does not own the album.' ), $aid );
	} else {
	    $self->status_not_found(
		$c, $c->loc( 'Could not find album.' ), $aid );
	}
    }

    if ( $c->req->param( 'delete' ) ) {
	# Delete the banner for this album.
	my @album_banners = $c->model( 'RDS::MediaAsset' )->search( { media_id => $album->id(), asset_type => 'banner' } )->all();
	foreach my $album_banner ( @album_banners ) {
	    VA::MediaFile::US->delete_asset( $c, $album_banner );
	    $album_banner->delete();
	}
	$self->status_ok( $c, {} );
    }

    my $result = {};

    my $upload = $c->req->upload( 'upload' );
    my $photo;
    if ( $upload ) {
	my $image = Imager->new();
	$image->read( data => $upload->slurp ) or
	    $c->log->error( "Failed to create Imager object: " . $image->errstr );

	if ( !( $upload->type =~ m/^image/ ) ) {
	    $self->status_bad_request(
		$c, $c->loc( "Upload must have mime type starting with image/." ) );
	}

	my $mimetype = $upload->type;
	my $data;
	(my $file_type = $upload->type) =~ s!^image/!!;
	$image->write( data => \$data, type => $file_type );
	my $width = $image->getwidth();
	my $height = $image->getheight();

	# We store the original upload data, we just put it in Imager
	#to get the mime type and size.
	$c->stash->{data} = $data;
	$c->stash->{data} = $upload->slurp();

	my @album_banners = $c->model( 'RDS::MediaAsset' )->search( { media_id => $album->id(), asset_type => 'banner' } )->all();
	if ( scalar( @album_banners ) == 1 ) {
	    VA::MediaFile::US->delete_asset( $c, $album_banners[0] );
	    $album_banners[0]->delete();
	}

	my $mediafile = VA::MediaFile::US->create( $c, { album => $album, width => $width, height => $height, mimetype => $mimetype } );
	unless ( $mediafile ) {
	    $self->status_bad_request( $c, $c->loc("Failed to create mediafile.") );
	}
	$result = $self->publish_mediafiles( $c, [ $mediafile ], { views => [ 'banner' ], only_videos => 0, only_visible => 0 } );
    } else {
	$self->status_bad_request( $c, $c->loc("Missing upload field") );
    }
    $self->status_ok( $c, $result );
}

__PACKAGE__->meta->make_immutable;

1;

