package VA::Controller::Services::Faces;
use Moose;

use VA::MediaFile;
use Data::Page;
use JSON;
use Try::Tiny;

use Storable qw/ dclone /;

use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

# Short cut for notifying the backend recognition system of face
# recognition events.
#
sub notify_recognition :Private {
    my( $self, $c, $message ) = @_;
    try {
	my $response = $c->model( 'SQS', $c->config->{sqs}->{recognition} )
	    ->SendMessage( to_json( $message ) );
    } catch {
	$c->log->error( 'Failed to send RECOGNITION message: ' + to_json( $message ) + ': ' + $_ );
    };
}

=head1 /services/faces/*

Services related to getting and manipulating face data

=head2 /services/faces/media_face_appears_in

Return the list of published media files visible to the logged in user
that the passed in face appears in.

=cut

sub media_face_appears_in :Local {
    my $self = shift; 
    my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 20,
	  asset_id => undef,
	  contact_uuid => undef,
	  'views[]' => ['poster'],
	  include_contact_info => 0,
	  include_images => 0,
	  include_tags => 0,
	  only_visible => 1,
	  only_videos => 1,
	  'status[]' => [],
	  'tags[]' => [],
	  'media_uuids[]' => [],
	  no_dates => 0
        ],
        @_ );

    # DEBUG
    #$DB::single = 1;

    if ( $args->{include_images} ) {
	push( @{$args->{'views[]'}}, 'image' );
    }

    my $rows = $args->{rows};
    my $page = $args->{page};

    my $user = $c->user->obj;

    my $asset_id = $args->{asset_id};
    my $contact_id = undef;

    if ( $args->{contact_uuid} ) {
	my $contact = $c->model( 'RDS::Contact' )->find( { uuid => $args->{contact_uuid} } );
	if ( $contact ) {
	    $contact_id = $contact->id();
	}
    }

    # If this is an unidentified face, then only asset_id will be
    # defined.  If it is an identifed face, then contact_id will be defined as well.
    #
    if ( ! defined( $contact_id ) ) {
	# This face is unidentifed, and so belongs to exactly one video, the
	# one in which it was detected.
	my @media_uuid = $c->model( 'RDS::MediaAsset' )->search( { 'me.uuid' => $asset_id }, { prefetch => 'media' } )->all();
	unless( scalar( @media_uuid ) ) {
	    $self->status_not_found( $c, 
				     $c->loc( 'Unable to find asset for [_1]', $asset_id ), $asset_id );
	}
	my ( $videos, $pager ) = $c->user->visible_media( {
	    'media_uuids[]' => [ $media_uuid[0]->media->uuid() ],
	    include_contact_info => $args->{include_contact_info},
	    include_images => $args->{include_images},
	    include_tags => $args->{include_tags},
	    only_visible => $args->{only_visible},
	    only_videos => $args->{only_videos},
	    'views[]' => $args->{'views[]'},
	    'tags[]' => $args->{'tags[]'},
	    rows => $rows,
	    page => $page,
	    no_dates => $args->{no_dates} } );

	unless( scalar( @$videos ) == 1 ) {
	    $self->status_forbidden( $c, $c->loc( 'You do not have permission to access the video for asset [_1]', $asset_id ), $asset_id );
	}

	my $tags_params = {
	    page => undef,
	    rows => undef,
	    include_contact_info => 0,
	    include_images => 0,
	    include_tags => 1,
	    only_visible => 1,
	    only_videos => 1,
	    'views[]' => ['main'],
	    'media_uuids[]' => [ $media_uuid[0]->media->uuid() ] };
	my $all_tags = $c->user->get_tags( $tags_params );
    
	my $no_date_return = 0;
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
    
	my $mediafile = VA::MediaFile->new->publish( $c, $videos->[0], { $args->{'views[]'} } );

	if ( $videos->[0]->user_id != $c->user->id() ) {
	    $mediafile->{is_shared} = 1;
	} else {
	    $mediafile->{is_shared} = 0;
	}

	$self->status_ok( $c, { 
	    media => [ $mediafile ], 
	    all_tags => $all_tags,
	    no_date_return => $no_date_return,
	    page => $self->pagerToJson( $pager ) } );
    } else {
	# We had performance problems in this query, so try a
	# different approach where we get the media_uuids only first.
	#
	# This is facilitated by the understanding that a given
	# contact only appears in videos owned by one user.

	# DEBUG
	#$DB::single = 1;

	# First get all videos that contact is in:
	my ( $contact_videos, $contact_pager ) = $c->user->visible_media( {
	    'contact_uuids[]' => [ $args->{contact_uuid} ],
	    only_visible => $args->{only_visible},
	    only_videos => $args->{only_videos} } );
	
	# Limit this to the optional list of requested media_uuids
	# that have the desired contact.
	my $media_uuids = $args->{'media_uuids[]'};
	my $relevant_media = [];
	my $relevant_media_ids = [];
	if ( scalar( @$media_uuids ) ) {
	    my $requested_media = {};
	    for my $media_uuid ( @$media_uuids ) {
		$requested_media->{$media_uuid} = 1;
	    }
	    
	    for my $video ( @$contact_videos ) {
		if ( exists( $requested_media->{$video->uuid()} ) ) {
		    push ( @$relevant_media, $video->uuid() );
		    push ( @$relevant_media_ids, $video->id() );
		}
	    }
	} else {
	    # In this case all videos with the contact are relevant.
	    for my $video ( @$contact_videos ) {
		push ( @$relevant_media, $video->uuid() );
		push ( @$relevant_media_ids, $video->id() );
	    }
	}
	$media_uuids = $relevant_media;

	# Now do the searches based only on these media_uuids.
	
	# This is an identified face and may appear in multiple media files.
	my ( $videos, $pager ) = $c->user->visible_media( {
	    # We handled this above.
	    #'contact_uuids[]' => [ $args->{contact_uuid} ],
	    include_contact_info => $args->{include_contact_info},
	    include_images => $args->{include_images},
	    include_tags => $args->{include_tags},
	    only_visible => $args->{only_visible},
	    only_videos => $args->{only_videos},
	    'views[]' => $args->{'views[]'},
	    'tags[]' => $args->{'tags[]'},
	    'media_uuids[]' => $media_uuids,
	    rows => $rows,
	    page => $page,
	    no_dates => $args->{no_dates} } );

	unless( scalar( @$videos ) > 0 ) {
	    $self->status_forbidden( $c, $c->loc( 'You do not have permission to access any videos for contact [_1]', $args->{contact_uuid} ), $args->{contact_uuid} );
	}

	my $tags_params = {
	    # We handled this above.
	    #'contact_uuids[]' => [ $args->{contact_uuid} ],
	    page => undef,
	    rows => undef,
	    include_contact_info => 0,
	    include_images => 0,
	    include_tags => 1,
	    only_visible => 1,
	    only_videos => 1,
	    'views[]' => ['main'],
	    'media_uuids[]' => $media_uuids };
	my $all_tags = $c->user->get_tags( $tags_params );
    
	my $no_date_return = 0;
	if ( exists( $all_tags->{'No Dates'} ) ) {
	    $no_date_return = 1;
	}
    
	my $face_tag_params = dclone( $tags_params );
	$face_tag_params->{include_contact_info} = 1;

	# 10 seconds.
	my $face_tags = $c->user->get_face_tags_for_media_id( $relevant_media_ids );

	for my $face_tag ( keys( %$face_tags ) ) {
	    if ( exists( $all_tags->{$face_tags->{$face_tag}->{contact_name}} ) ) {
		$all_tags->{$face_tags->{$face_tag}->{contact_name}} += $face_tags->{$face_tag}->{face_count};
	    } else {
		$all_tags->{$face_tags->{$face_tag}->{contact_name}} = $face_tags->{$face_tag}->{face_count};
	    }
	}
    
	my ( $media_tags, $media_contact_features ) = $self->get_tags( $c, $videos );

	my $media = $self->publish_mediafiles( $c, $videos, { 
	    views => $args->{'views[]'}, 
	    include_contact_info => $args->{include_contact_info}, 
	    include_images => $args->{include_images}, 
	    include_tags => $args->{include_tags},
	    media_tags => $media_tags,
	    media_contact_features => $media_contact_features } );

	$self->status_ok( $c, { media => $media,
				all_tags => $all_tags,
				no_date_return => $no_date_return,
				pager => $self->pagerToJson( $pager ) } );
    }
}

# DEPRECATED
#
=head2 /services/faces/contact_mediafiles_count

Return the total number of mediafiles that this contact uniquely appears in.

=cut

sub contact_mediafile_count :Local {
    my( $self, $c ) = @_;

    $self->status_bad_request( $c, "services/faces/contact_mediafile_count is deprecated." );

    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }
    
    my $cid = $c->req->param( 'cid' );
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});

    unless( $contact ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find contact for [_1]', $cid ), $cid );
    }

    my $where = { contact_id => $contact->id, 
		  feature_type => 'face',
		  'me.user_id' => $c->user->id };

    if ( $only_videos ) {
	$where->{'media.media_type'} = 'original';
    }
    if ( $only_visible ) {
	$where->{'media.status'} = [ 'visible', 'complete' ];
    }
    if ( scalar( @status_filters ) ) {
	$where->{'media.status'} = \@status_filters;
    }

    my $count =  $c->model( 'RDS::MediaAssetFeature' )->search(
	$where,
	{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } )->count;
    $self->status_ok( $c, { count => $count } );
}

=head2 /services/faces/contacts

Return all contacts for logged in user that appear in a video visible
by the user.

Here a contact is defined to be:
    * Someone who shows up in a video
    * Who has been named

Return value is a hash with one key: "faces", whose value is an array
reference to hashes of:

contact JSON structures, agumented with:
* A URL to the picture_uri of the person in a field called url
* appears_in - the number of movies this contact appears in
* asset_id - the UUID of the media asset associated with this face -
  this is used for unidentified faces to locate the videos they appear
  in.

DEPRECATED: Also the three contacts that appear in the most videos
used to return 'star_power' = star1,2 or 3, however this doesn't do
that any longer.

=cut

sub contacts :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ 
	  page => undef,
          rows => 10,
        ],
        @_ );
    
    # DEBUG
    #$DB::single = 1;

    my $user = $c->user->obj;

    my $face_tags = $c->user->get_face_tags( { include_contact_info => 1 } );

    my @result = ();
    for my $face_uuid ( keys( %$face_tags ) ) {
	my $face = $face_tags->{$face_uuid};
	push( @result, { url => undef,
			 appears_in => $face->{face_count},
			 asset_id => $face->{asset_uuid},
			 contact_name => $face->{contact_name},
			 uuid => $face->{contact_uuid},
			 asset_location => $face->{asset_location} } );

	if ( defined( $face->{picture_uri} ) ) {
	    my $klass = $c->config->{mediafile}->{$face->{asset_location}};
	    my $fp = new $klass;
	    my $url = $fp->uri2url( $c, $face->{picture_uri} );
	    $result[-1]->{url} = $url;
	} else {
	    $result[-1]->{url} = '/css/images/avatar-nobd.png';
	    $result[-1]->{nopic} = 1;  # in case UI needs to know
	}
    }

    # Because of the nature of this query, I could not use the native DBIX pager,
    # and therefore I need to implement that functionality myself, including the
    # sort.
    #
    my @sorted = sort { $b->{appears_in} <=> $a->{appears_in} } @result;
    
    # DEBUG - DEPRECATED - REMOVE IF COMMENTING THIS DOESN'T CAUSE PROBLEMS
    #$sorted[0]->{star_power} = 'star1' if ( $#sorted >=0 );
    #$sorted[1]->{star_power} = 'star2' if ( $#sorted >=1 );
    #$sorted[2]->{star_power} = 'star3' if ( $#sorted >=2 );
    
    if ( $args->{page} ) {
	my $pager = Data::Page->new( $#sorted + 1, $args->{rows}, $args->{page} );
	my @slice = ();
	if ( $#sorted >= 0 ) {
	    @slice = @sorted[ $pager->first - 1 .. $pager->last - 1 ];
	}
	
	$self->status_ok( $c, { faces => \@slice, 
				pager => $self->pagerToJson( $pager ) });
    } else {
	$self->status_ok( $c, { faces => \@sorted } );
    }
}

#
# Like contacts above, but list all contacts in videos, even if no name and
# no picture.  This is used on the people page to get all known and unknown
# people in videos.
#
sub contacts_present_in_videos :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 10,
        ],
        @_ );

    my $user = $c->user->obj;

    # Find all contacts for a user that appear in at least one video.
    my $search = {
	'me.user_id' => $user->id,
	contact_id => {'!=',undef},
	# Screen out FB faces.
	'me.feature_type' => 'face'
    };
    my $where = {
	select   => ['contact_id', 'media_asset_id'],
	prefetch => ['contact', 'media_asset'],
	group_by => ['contact_id'],
	order_by => 'media_asset.created_date desc'
    };
    my @feats = $c->model( 'RDS::MediaAssetFeature' )->search( $search, $where );

    my @id_data = ();
    my @unknown_data = ();
    foreach my $feat ( @feats ) {

	my $contact = $feat->contact;
	my $asset   = $feat->media_asset;
	my $hash    = $contact->TO_JSON;

	if ( $contact->picture_uri ) {
	    my $klass = $c->config->{mediafile}->{$asset->location};
	    my $fp = new $klass;
	    my $url = $fp->uri2url( $c, $contact->picture_uri );
	    $hash->{url} = $url;
	}
	else {
	    $hash->{url} = '/css/images/avatar-nobd.png';
	    $hash->{nopic} = 1;  # in case UI needs to know
	}
	$hash->{asset_id} = $asset->uuid;

	if ( defined( $contact->contact_name() ) ) {
	    push( @id_data, $hash );
	} else {
	    push( @unknown_data, $hash );
	}
    }

    my @sorted = @unknown_data;
    @id_data = sort { uc( $a->{'contact_name'} ) cmp uc( $b->{'contact_name'} ) } @id_data;

    if ( $args->{page} ) {
	my $pager = Data::Page->new( $#sorted + 1, $args->{rows}, $args->{page} );
	my @slice = ();
	if ( $#sorted >= 0 ) {
	    @slice = @sorted[ $pager->first - 1 .. $pager->last - 1 ];
	}
	
	my @result = ( @id_data, @slice );

	$self->status_ok( $c, { faces => \@result, 
				pager => $self->pagerToJson( $pager ) });
    } else {
	my @result = ( @id_data, @sorted );
	$self->status_ok( $c, { faces => \@result } );
    }
}

=head2 /services/faces/faces_in_mediafile, /services/na/faces_in_mediafile

For a passed in mediafile (uuid), return all the faces, known and unknown,
present in that video.  Returns something that looks like:

  {
   "faces" : [
      {
         "appears_in" : 1,
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/91d90a85-0786-43b6-acef-928799e27507%2Fface-ecf16301-7d86-452c-b05c-43fa0f73af9e.jpg?Signature=ONC91C9PhUqW%2BzJcB0qRlszky1A%3D&Expires=1379278215&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
         "contact" : {
            "provider" : null,
            "contact_name" : "Nikola Tesla",
            "provider_id" : null,
            "created_date" : "2013-09-07 18:54:05",
            "uuid" : null,
            "intellivision_id" : null,
            "contact_viblio_id" : null,
            "picture_uri" : null,
            "contact_email" : "viblio.smtesting+nikola@gmail.com",
            "id" : "257",
            "updated_date" : null
         }
      },
      {
         "appears_in" : 1,
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/91d90a85-0786-43b6-acef-928799e27507%2Fface-3819b4fe-f297-4a52-93d6-4872dcbb0db6.jpg?Signature=b7qJcOXdb%2Bh63%2Fn3EHStC3asbHc%3D&Expires=1379278215&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA"
      },
   ]
  }

In the example above, the first record is a known face, and thus contains a "contact"
record.  The second face is present but unknown.

=cut

sub faces_in_mediafile :Local {
    my( $self, $c ) = @_;
    #
    # Delegate to an unauthenticated version of this routine, needed by
    # the web player page.
    #
    $c->forward( '/services/na/faces_in_mediafile' );
}

# DEPRECATED

=head2 /services/faces/contact

Return the contact information for the passed in contact uuid

=cut

sub contact :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );

    $self->status_bad_request( $c, "services/faces/contact is deprecated." );

    unless( $cid ) {
	$self->status_bad_request
	    ( $c, $c->loc( 'Missing required param: [_1]', 'cid' ) );
    }
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
    unless( $contact ) {
	$contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
    }
    unless( $contact ) {
	$self->status_not_found
	    ( $c, $c->loc( 'Cannot find contact for [_1]', $cid ), $cid );
    }

    my $klass = $c->config->{mediafile}->{'us'};
    my $fp = new $klass;
    my $url = $contact->picture_uri ? $fp->uri2url( $c, $contact->picture_uri ) : 
	'css/images/avatar-nobd.png';

    my $hash = $contact->TO_JSON;
    $hash->{url} = $url;

    $self->status_ok( $c, { contact => $hash } );
}


=head2 /services/faces/all_contacts

Returns list of contacts that match the regular expression passed
in as 'term'.

=cut

sub all_contacts :Local {
    my( $self, $c ) = @_;
    my $q = $c->req->param( 'term' );
    my $editable = $c->req->param( 'editable' );

    my $where = {};
    if ( $q ) {
	$where = { contact_name => { '!=', undef }, 'LOWER(contact_name)' => { 'like', '%'.lc($q).'%' } };
    }
    elsif ( $editable ) {
	$where = { contact_name => { '!=', undef } };
    }

    my @contacts = $c->user->contacts->search($where,{order_by => 'contact_name'});

    my @data = ();
    foreach my $contact ( @contacts ) {
	my $hash = $contact->TO_JSON;
	if ( $contact->picture_uri ) {
	    $hash->{url} = new VA::MediaFile::US()->uri2url( $c, $contact->picture_uri );
	}
	#else {
	#    DO NOT PUT A PLACE HOLDER PIC HERE.  The GUI will look to see it this is
	#    null to determine how to render.
	#}
	$hash->{uuid} = $hash->{id} unless( $hash->{uuid} );
	push( @data, $hash );
    }

    if ( $q ) {
	my @ret = ();
	my $i=1;
	foreach my $con ( @data ) {
	    push( @ret, { value => $i++, text => $con->{contact_name}, 
			  label => $con->{contact_name}, cid => $con->{uuid}, url => $con->{url} });
	}
	$self->status_ok( $c, \@ret );
    }
    elsif ( $editable ) {
	my @ret = map { $_->{contact_name} } @data;
	$self->status_ok( $c, \@ret );
    }
    else {
	$self->status_ok( $c, { contacts => \@data } );
    }
}

=head2 /services/faces/photos_of

Return all the known photos of a contact uuid

=cut
sub photos_of :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
    unless( $contact ) {
	$contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
    }
    unless( $contact ) {
	$self->status_ok( $c, {} );
    }

=perl
    # THIS WAS HERE TO DEBUG, NEEDED BEFORE I CAN AGGRAGATE FACES
    my @features = $c->model( 'RDS::Contact' )->search({contact_name => undef, user_id => $c->user->id});
    my @data = ();
    foreach my $feat ( @features ) {
	my $url = new VA::MediaFile::US()->uri2url( $c, $feat->picture_uri );
	push( @data, { url => $url, id => $feat->id } );
    }
    $self->status_ok( $c, \@data );
=cut

    # Explicitly consider features of any type, face or fb_face.
    my @features = $c->model( 'RDS::MediaAssetFeature' )->
	search({ contact_id => $contact->id,
		 'media_asset.uri' => { '!=' => undef },
		 'me.user_id' => $c->user->id },
	       { prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] });
    my @data = ();
    foreach my $feat ( @features ) {
	my $url = new VA::MediaFile::US()->uri2url( $c, $feat->media_asset->uri );
	push( @data, { url => $url, uri => $feat->media_asset->uri, id => $feat->id } );
    }
    $self->status_ok( $c, \@data );
}

sub contact_emails :Local {
    my( $self, $c ) = @_;
    my $q = $c->req->param( "q" );

    my $where = { -or => [
		       'LOWER(contact_name)' => { 'like', '%'.lc($q).'%' },
		       'LOWER(contact_email)' => { 'like', '%'.lc($q).'%' },
		      ] };
    my @contacts = $c->user->contacts_and_groups->search($where);

    if ( $#contacts == -1 ) {
	my $email = $self->is_email_valid( $q );
	if ( $email ) {
	    $self->status_ok( $c, [{ id => $email->format, name => $email->format }] );
	}
    }
    my @data = map { {id => $_->contact_email, name => $_->contact_name} } @contacts;
    $self->status_ok( $c, \@data );
}

sub change_contact :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ uuid => undef,
	  new_uri => undef,
	  contact_name => undef,
	  contact_email => undef
	], @_ );

    my $contact = $c->user->contacts->find({ uuid => $args->{uuid} });

    unless( $contact ) {
	$self->status_not_found($c, $c->loc("Cannot find contact for [_1]", $args->{uuid} ), $args->{uuid} );
    }

    $contact->contact_name( $args->{contact_name} );

    if ( $args->{contact_email} ) {
	$contact->contact_email( $args->{contact_email} );
    }
    if ( $args->{new_uri} ) {
	$contact->picture_uri( $args->{new_uri} );
    }
    $contact->update;

    $self->status_ok( $c, { contact => $contact->TO_JSON } );
}

=head2 /services/faces/tag

Tag a contact

=cut

sub tag :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ uuid => undef,
	  cid => undef,
	  new_uri => undef,
	  contact_name => undef
	], @_ );

    my $contact = $c->user->contacts->find({ uuid => $args->{uuid} });

    unless( $contact ) {
	$self->status_not_found($c, $c->loc("Cannot find contact for [_1]", $args->{uuid} ), $args->{uuid} );
    }

    if ( ! $args->{cid} ) {
	# Just giving this unknown person a name
	$contact->contact_name( $args->{contact_name} );
	if ( $args->{new_uri} ) {
	    $contact->picture_uri( $args->{new_uri} );
	}
	$contact->update;
	$self->status_ok( $c, { contact => $contact->TO_JSON } );
    }
    else {
	# We are identifying this previously unknown person
	# to be the same person as contact_id 'cid'.  For now
	# I think this means finding all media asset features
	# containing $contact->id and changing it to $identified->id
	#
	my $identified = $c->user->contacts->find({ uuid => $args->{cid} });
	unless( $identified ) {
	    $identified = $c->user->contacts->find({ id => $args->{cid} });
	}
	unless( $identified ) {
	    $self->status_not_found($c, $c->loc("Cannot find contact for [_1]", $args->{cid} ), $args->{cid} );
	}

	my @fids = ();
	# Explicitly consider any type of face, fb_face or regular.
	foreach my $feat ( $c->model( 'RDS::MediaAssetFeature' )->search({ contact_id => $contact->id }) ) {
	    push( @fids, $feat->id );
	    $feat->contact_id( $identified->id );
	    $feat->update;
	}

	# Send the information to the recognition system
	$self->notify_recognition( $c, {
	  action => 'move_faces',
	  user_id => $c->user->obj->id,
	  old_contact => $contact->id,
	  new_contact => $identified->id,
	  delete_old_contact => 1,
	  media_asset_feature_ids => \@fids });

	# Then delete the unknown contact
	$contact->delete; $contact->update;

	$self->status_ok( $c, { contact => $identified->TO_JSON } );
    }
}

sub avatar_for_name :Local {
    my( $self, $c ) = @_;
    my $contact_name = $c->req->param( 'contact_name' );

    my @contacts = $c->user->contacts->search({ contact_name => $contact_name });
    if ( $#contacts >= 0 ) {
	my $contact = $contacts[0];

	my $url;
	if ( $contact->picture_uri ) {
	    my $klass = $c->config->{mediafile}->{'us'};
	    my $fp = new $klass;
	    $url = $fp->uri2url( $c, $contact->picture_uri );
	}
	else {
	    $url = '/css/images/avatar.png';
	}
        my $provider = 'user-supplied';
        if ( $contact && $contact->{_column_data}->{provider} ) {
            $provider = $contact->{_column_data}->{provider};
        }
        $self->status_ok( $c, { url => $url, provider => $provider  } );
    }
    else {
	$self->status_ok( $c, {} );
    }
}

sub contact_for_name :Local {
    my( $self, $c ) = @_;
    my $contact_name = $c->req->param( 'contact_name' );
    my @contacts = $c->user->contacts->search({ contact_name => $contact_name });
    if ( $#contacts >= 0 ) {
	my $contact = $contacts[0];

	my $url;
	if ( $contact->picture_uri ) {
	    my $klass = $c->config->{mediafile}->{'us'};
	    my $fp = new $klass;
	    $url = $fp->uri2url( $c, $contact->picture_uri );
	}
	else {
	    $url = '/css/images/nopic-green-36.png';
	}
	my $data = $contact->TO_JSON;
	$data->{url} = $url;
	$self->status_ok( $c, { contact => $data } );
    }
    else {
	$self->status_ok( $c, {} );
    }
}

sub delete_contact :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my $contact = $c->user->contacts->find({ uuid => $cid });
    unless( $contact ) {
	$self->status_not_found($c, $c->loc('Unable to find contact for [_1]', $cid ), $cid );
    }
    # Both fb_face and regular face.
    my @feats = $c->model( 'RDS::MediaAssetFeature' )->search({ contact_id => $contact->id });
    my @fids  = map { $_->id } @feats;

    $self->notify_recognition( $c, {
	action => 'delete_contact',
	user_id => $c->user->obj->id,
	contact_id => $contact->id,
	media_asset_feature_ids => \@fids });

    if ( $contact->contact_name ) {
	# This is a known contact
	#$contact->picture_uri( undef ); 
	#$contact->contact_name( undef ); 
	#$contact->contact_email( undef ); 
	#$contact->update;
	#foreach my $feat ( @feats ) {
	#    $feat->delete; $feat->update;
	#}

	# Why would we delete as above?  We should delete the contact,
	# but we also want to delete the stuff in S3.
	my @assets = ();
	foreach my $feat ( @feats ) {
	    my $asset = $feat->media_asset();
	    push( @assets, $asset );
	}	
	# Handles deletion from S3 of the assets, and from the
	# database for both assets and features.
	my @asset_uuids = map { $_->uuid() } @assets;
	VA::Controller::Services::Mediafile->new()->delete_assets( $c, \@asset_uuids );

	$contact->delete; $contact->update;
    }
    else {
	# This is an unknown contact
	$contact->delete; $contact->update;
    }

    $self->status_ok( $c, {} );
}

sub remove_false_positives :Local {
    my( $self, $c ) = @_;

    my @ids = $c->req->param( 'ids[]' );
    my $feature;

    my $new_pic_uri;
    my $main_contact;

    my @ret = ();

    foreach my $id ( @ids ) {
	# Any type of face here.
	$feature = $c->model( 'RDS::MediaAssetFeature' )->find({id => $id, user_id => $c->user->obj->id});
	unless( $feature ) {
	    $c->log->error( 'remove false positives: cannot find ' + $id + ' in media asset features' );
	    next;
	}
	my $asset = $feature->media_asset;
	my $contact = $c->user->obj->create_related( 'contacts', {
	    picture_uri => $asset->uri });

	push( @ret, {
	    id     => $id,
	    c_id   => $contact->id,
	    c_uuid => $contact->uuid } );

	$self->notify_recognition( $c, {
	    action => 'move_faces',
	    user_id => $c->user->obj->id,
	    old_contact => $feature->contact_id,
	    new_contact => $contact->id,
	    media_asset_feature_ids => [ $feature->id ] });

	# If the picture of the face being removed is the one being used by
	# this contact, then we have to change the contact picture if possible.
	if ( $feature->contact->picture_uri eq $asset->uri ) {
	    $main_contact = $feature->contact;
	    my @features = $c->model( 'RDS::MediaAssetFeature' )->
		search({ contact_id => $main_contact->id,
			 feature_type => [ 'face', 'fb_face' ],
			 'me.user_id' => $c->user->id },
		       { prefetch => 'media_asset' });
	    my $found = 0;
	    foreach my $f ( @features ) {
		if ( $f->media_asset->uri ne $asset->uri ) {
		    $main_contact->picture_uri( $f->media_asset->uri ); $main_contact->update;
		    $new_pic_uri = $f->media_asset->uri;
		    $found = 1;
		    last;
		}
	    }
	    unless( $found ) {
		$main_contact->picture_uri( undef ); $main_contact->update;
	    }
	}
	$feature->contact_id( $contact->id ); $feature->update();
    }

    my $url;
    if ( $new_pic_uri ) {
	my $klass = $c->config->{mediafile}->{'us'};
	my $fp = new $klass;
	$url = $fp->uri2url( $c, $new_pic_uri );
    }
    if ( $main_contact ) {
	my $data = $main_contact->TO_JSON;
	$data->{url} = $url;
	$self->status_ok( $c, { contact => $data, newids => \@ret } );
    }
    else {
	$self->status_ok( $c, { newids => \@ret } );
    }
}

=head2 /services/faces/remove_from_video

Remove a face from a single video.

=cut

sub remove_from_video :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my $mid = $c->req->param( 'mid' );
    my $contact = $c->user->contacts->find({ uuid => $cid });
    unless( $contact ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find contact for [_1]', $cid ), $cid );
    }
    my $mediafile = $c->user->media->find({ uuid => $mid });
    unless( $mediafile ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find media file for [_1]', $mid ), $mid );
    }

    # Is this the only occurence, fb_face or otherwise, of this person?
    my @feats = $c->model( 'RDS::MediaAssetFeature' )
	->search(
	{ contact_id => $contact->id, 'me.user_id' => $c->user->obj->id},
	{ prefetch => { 'media_asset' => 'media' } } );
    my @fids  = map { $_->id } @feats;
    my @mfeats = ();
    my @others = ();
    foreach my $feat ( @feats ) {
	if ( $feat->media_asset->media->id != $mediafile->id ) {
	    push( @others, $feat->media_asset->media );
	}
	else {
	    push( @mfeats, $feat );
	}
    }

    if ( $#others >= 0 ) {
	# Face is in other videos besides this one
	my @mfids = map { $_->id } @mfeats;
	$self->notify_recognition( $c, {
	    action => 'delete_faces_for_contact',
	    user_id => $c->user->obj->id,
	    contact_id => $contact->id,
	    media_asset_feature_ids => \@mfids });
	foreach my $feat ( @mfeats ) {
	    $feat->delete; $feat->update;
	}
	# Change the contact picture to another in a different video
	$contact->picture_uri( $others[0]->media_assets->first({ asset_type => 'face' })->uri );
    }
    else {
	# Face is only in this video
	$self->notify_recognition( $c, {
	    action => 'delete_contact',
	    user_id => $c->user->obj->id,
	    contact_id => $contact->id,
	    media_asset_feature_ids => \@fids });
	
	if ( $contact->contact_name ) {
	    # This is a known contact
	    #$contact->picture_uri( undef ); $contact->update;
	    #foreach my $feat ( @feats ) {
	    #	$feat->delete; $feat->update;
	    #}

	    my @assets = ();
	    foreach my $feat ( @feats ) {
		my $asset = $feat->media_asset();
		push( @assets, $asset );
	    }	
	    # Handles deletion from S3 of the assets, and from the
	    # database for both assets and features.
	    my @asset_uuids = map { $_->uuid() } @assets;
	    VA::Controller::Services::Mediafile->new()->delete_assets( $c, \@asset_uuids );
	}
	else {
	    # This is an unknown contact
	    $contact->delete; $contact->update;
	}
    }
    $self->status_ok( $c, {} );
}

=head2 /services/faces/add_contact_to_media_file

Pass in mid for mediafile, and either contact_name to do a lookup or cid to find a contact.  Add
that contact as someone who is in the media file (video).

=cut

sub add_contact_to_mediafile :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $cid = $c->req->param( 'cid' );
    my $contact_name = $self->sanitize( $c, $c->req->param( 'contact_name' ) );

    my $media = $c->user->media->find({ uuid => $mid });
    unless( $media ) {
	$self->status_not_found( $c, $c->loc( "Cannot find mediafile for [_1]", $mid ), $mid );
    }

    my $contact;
    if ( $cid ) {
	$contact = $c->user->contacts->find({ uuid => $cid });
    }
    elsif ( $contact_name ) {
	$contact = $c->user->contacts->find({ contact_name => $contact_name });
	if ( ! $contact ) {
	    # NEW!! A brand new face/contact can be created out of thin air here.
	    $contact = $c->user->obj->create_related( 'contacts', {
		contact_name => $contact_name });
	}
    }
    unless( $contact ) {
	if ( $cid ) {
	    $self->status_not_found( $c, $c->loc( "Cannot find contact for [_1]", $cid ), $cid );
	}
	else {
	    $self->status_bad_request( $c, $c->loc( "Cannot find/create contact for [_1]", $contact_name ) );
	}
    }
    
    # Have to create a media_asset with a media_asset_feature and attach it to the mediafile.
    #
    my $asset = $media->create_related( 'media_assets', {
	user_id => $c->user->obj->id,
	asset_type => 'face',
	mimetype => 'image/jpg',
	uri => $contact->picture_uri,
	location => 'us',
	bytes => 0,
	view_count => 0 });

    unless( $asset ) {
	$self->status_bad_request( $c, $c->loc( "Unable to create a new asset to add face to mediafile" ) );
    }

    my $feature = $asset->create_related( 'media_asset_features', {
	media_id => $media->id,
	user_id => $c->user->obj->id,
	feature_type => 'face',
	coordinates => '{}',
	contact_id => $contact->id });

    unless( $feature ) {
	$self->status_bad_request( $c, $c->loc( "Unable to create a new asset feature to add face to mediafile" ) );
    }

    my $data = $contact->TO_JSON;
    if ( $data->{picture_uri} ) {
	$data->{picture_url} = VA::MediaFile::US->new->uri2url( $c, $data->{picture_uri} );
    }

    $self->status_ok( $c, { contact => $data } );
}

# DEPRECATED
#
# Return unnamed contacts that have a photo
#
sub unnamed :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 10000]
      );

    $self->status_bad_request( $c, "services/faces/unnamed is deprecated." );

    my $rs = $c->user->contacts->search(
	{ contact_name => undef,
	  picture_uri => { '!=', undef } },
	{ page => $args->{page}, rows => $args->{rows} } );

    my @data = ();
    foreach my $contact ( $rs->all ) {
	my $hash = $contact->TO_JSON;
	$hash->{url} = VA::MediaFile::US->new->uri2url( $c, $contact->picture_uri );
	push( @data, $hash );
    }

    $self->status_ok( $c, {
	faces => \@data,
	pager => $self->pagerToJson( $rs->pager ) });
}

__PACKAGE__->meta->make_immutable;
1;
