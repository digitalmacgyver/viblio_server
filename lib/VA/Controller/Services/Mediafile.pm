package VA::Controller::Services::Mediafile;
use Moose;
use namespace::autoclean;

use JSON;
use URI::Escape;
use DateTime;
use DateTime::Format::Flexible;
use CGI;
use HTTP::Tiny;
use POSIX 'strftime';

use Data::UUID;
use Geo::Distance;

BEGIN { extends 'VA::Controller::Services' }

=head1 Mediafile

Documentation for the mediafile structure is large enough to be
contained in another document.

=head2 Example Mediafile

An example mediafile looks like:

  {
    "filename" : "Video Mar 26, 2 59 53 PM.mov",
    "type" : "original",
    "user_id" : "1",
    "id" : "12",
    "uuid" : "7A5E0BB6-A851-11E2-B9F2-F0608BC6C0B6"
    "views" : {
       "thumbnail" : {
          "location" : "s3",
          "mediafile_id" : "12",
          "uuid" : "8612D28E-A851-11E2-9412-F0608BC6C0B6",
          "size" : "12915",
          "uri" : "7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video Mar 26, 2 59 53 PM_thumbnail.png",
          "filename" : "Video Mar 26, 2 59 53 PM_thumbnail.png",
          "url" : "http://viblio-mediafilesfilesfiles.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM_thumbnail.png?Signature=zhODpgAovbcu2gVUI4hmspz2P2g%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
          "id" : "35",
          "type" : "thumbnail",
          "mimetype" : "application/png"
       },
       "poster" : {
          "location" : "s3",
          "mediafile_id" : "12",
          "uuid" : "864C5716-A851-11E2-AADB-F0608BC6C0B6",
          "size" : "97158",
          "uri" : "7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video Mar 26, 2 59 53 PM_poster.png",
          "filename" : "Video Mar 26, 2 59 53 PM_poster.png",
          "url" : "http://viblio-mediafilesfilesfiles.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM_poster.png?Signature=8wPQjM49kHEtTodERkdJ1aoDVZo%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
          "id" : "36",
          "type" : "poster",
          "mimetype" : "application/png"
       },
       "main" : {
          "location" : "s3",
          "mediafile_id" : "12",
          "uuid" : "7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6",
          "size" : "5742173",
          "uri" : "7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video Mar 26, 2 59 53 PM.mov",
          "filename" : "Video Mar 26, 2 59 53 PM.mov",
          "url" : "http://viblio-mediafilesfilesfiles.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM.mov?Signature=AZZKBuGNzpCphOojFKm%2FieBmN4M%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
          "id" : "34",
          "type" : "main",
          "mimetype" : "video/quicktime"
       }
    }
  }

=head2 /services/mediafile/create

Create a new mediafile.  The actual real file should have been uploaded to some storage location
already.  

=head3 Parameters

=over

=item filename

A file name for this media file.  Should be a basename, not a path.  

=item mimetype

The mimetype for this media file, something like "video/mp4".

=item size

Size in bytes of this media file.  

=item uri

The "uri" for this media file.  This is not usually a full URL, but rather some sort of
tag passed back from the permanent storage server that holds the actual file.  Media file
views have "url" fields that are typically automatically derived from this uri field in
some way.

=item location

The location where this media file is physically stored.  Currently one of "fp" (filepicker.io),
"s3" (amazon S3 bucket) or "fs" (viblio local storage).  A client will know what to pass for
location, as it has already uploaded the physical media file to the storage server before calling
this endpoint.

=back

=head3 Response

  { "media": $mediafile }

The "url" fields of the media file views will be valid urls, suitable for display in a client 
media player or image or video tag.

=cut

# DEPRECATED
sub create :Local {
    my( $self, $c, $wid ) = @_;
    $wid = $c->req->param( 'workorder_id' ) unless( $wid );
    $wid = 0 unless( $wid );

    $self->status_bad_request( $c, "services/mediafile/create is deprecated." );


    my $location = $c->req->param( 'location' );
    unless( $location ) {
	$self->status_bad_request(
	    $c, $c->loc( "Cannot determine location of this media file" ));
    }
    my $fp = new VA::MediaFile;

    $c->req->params->{user_id} = $c->user->obj->id;
    my $mediafile = $fp->create( $c, $c->req->params );

    unless( $mediafile ) {
	$self->status_bad_request( 
	    $c, $c->loc( "Cannot create media file." ) );
    }

    if ( $wid ) {
	my $wo = $c->model( 'RDS::Workorder' )->find( $wid );
	unless( $wo ) {
	    $self->status_bad_request(
		$c, $c->loc( "Cannot find workorder to attach media file." ));
	}
	$mediafile->add_to_workorders( $wo );
    }

    $self->status_ok( $c, { media => $fp->publish( $c, $mediafile ) } );
}

=head2 /services/mediafile/url_for

Get a full base url to the server used to store media files at the
passed in location.  This is needed for servers that are protected
with server-side generated credentials.  

=head3 Parameters

Requires a 'location', something like "s3" or "fs".  Takes an
optional 'path' which defaults to "/".  

=head3 Response

  { "url": url }

=cut

sub url_for :Local {
    my( $self, $c, $location, $path ) = @_;
    $location = $c->req->param( 'location' ) unless( $location );
    $path = $c->req->param( 'path' ) unless( $path );
    $path = '/' unless( $path );
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
	$self->status_bad_request( 
	    $c, $c->loc( "Cannot determine type of this media file" ));
    }
    my $fp = new $klass;
    $self->status_ok( $c, { url => $c->localhost( $fp->uri2url( $c, $path ) ) } );
}

=head2 /services/mediafile/delete

Delete a mediafile.  Deletes the file in permanent storage as well.

=head3 Parameters

Mediafile id or uuid

=head3 Response

  {}

=cut

sub delete :Local {
    my( $self, $c, $id ) = @_;
    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );

    my $mf = $c->user->media->find( { uuid => $id }, 
				    { prefetch => 'assets' } );

    unless( $mf ) {
	$self->status_not_found(
	    $c, $c->loc( "Cannot find media file to delete." ), $id );
    }

    my $location = $mf->asset( 'main' )->location;
    unless( $location ) {
	$self->status_bad_request(
	    $c, $c->loc( "Cannot determine location of this media file" ));
    }
    my $fp = new VA::MediaFile;
    my $res = $fp->delete( $c, $mf );
    unless( $res ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to delete this media file from storage." ) );
    }

    # Deal with faces.  
    #
    # foreach face in this video:
    #   if unidentified 
    #     if only in this video
    #       delete the contact
    #   else if identified
    #     if only in this video
    #       unset picture_uri
    #     else
    #       set picture_uri to some other video
    #

    # This array will contain the list of contact uuids that fall
    # into the "identified, only in this video" case.  This will
    # be returned to the UI, so any contacts visible on the screen
    # can be removed if the video file they are in is removed.
    my @contacts_in_video = ();

    # Leverage the publish routine to obtain faces for
    # this mediafile.
    my $mediafile = VA::MediaFile->new->publish( $c, $mf, { assets => [], include_contact_info => 1 } );
    my @faces = @{$mediafile->{views}->{face}};

    # Generic resultset for finding other mediafiles (other than this one)
    #
    # Explicitly consider fb_face and face features here.
    my $rs = $c->model( 'RDS::MediaAssetFeature' )->search({
	'media.id' => { '!=', $mf->id } }, {
	    prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );

    foreach my $face ( @faces ) {
	#$c->log->debug( "Face: name: " . $face->{contact}->{contact_name} . ", uuid: " . $face->{contact}->{uuid} );
	if ( ! $face->{contact}->{contact_name} ) {
	    # unidentified
	    #$c->log->debug( "  unidentified" );
	    # Other mediafiles with this contact
	    my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	    #$c->log->debug( "  -> in $count other videos" );
	    if ( $count == 0 ) {
		# No others, so delete the contact
		my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		if ( $contact ) {
		    #$c->log->debug( "  -> DELETE " . $face->{contact}->{uuid} );
		    $contact->delete; $contact->update;
		}
	    }
	}
	else {
	    # identified
	    #$c->log->debug( "  identified" );
	    # Other mediafiles with this contact
	    my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	    #$c->log->debug( "  -> in $count other videos" );
	    if ( $count == 0 ) {
		# In no other videos.  Unset the picture_uri if it points
		# to this video
		my $cnt = $c->model( 'RDS::MediaAsset' )->search({
		    media_id => $mf->id,
		    uri => $face->{contact}->{picture_uri} })->count;
		if ( $cnt == 0 ) {
		    # There is a picture_uri, but it does not point to any
		    # of this mediafile's assets, so leave it alone.  It
		    # could be a contact with a pic, but not in any video
		    # like a FB contact
		    #$c->log->debug( "  -> PRESERVE picture_uri" );
		}
		else {
		    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		    if ( $contact ) {
			# There is a picture_uri, and it points to an asset about to be
			# deleted, and there are no other videos to which to point to,
			# so unset the picture_uri.
			#$c->log->debug( "  -> UNSET picture_uri " . $face->{contact}->{uuid} );
			$contact->picture_uri( undef ); $contact->update;

			push( @contacts_in_video, $contact->uuid ); # will be returned from this call
		    }
		}
	    }
	    else {
		# This person is in other videos.  If the picture_uri points to
		# one of the assets in this video, then must point it to one of
		# the assets in one of the other videos.
		my $cnt = $c->model( 'RDS::MediaAsset' )->search({
		    media_id => $mf->id,
		    uri => $face->{contact}->{picture_uri} })->count;
		if ( $cnt == 0 ) {
		    # There is a picture_uri, but it does not point to any
		    # of this mediafile's assets, so leave it alone.
		    #$c->log->debug( "  -> PRESERVE picture_uri" );
		}
		else {
		    # The picture_uri needs to be changed.
		    #$c->log->debug( "  -> SWITCH picture_uri" );
		    my @others = $rs->search({'me.contact_id' => $face->{contact}->{id}});
		    if ( $#others >= 0 ) {
			my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
			if ( $contact ) {
			    $c->log->debug( "  -> commit" );
			    $contact->picture_uri( $others[0]->media_asset->uri );
			    $contact->update;
			}
		    }
		}
	    }
	}
    }

    # Finally, delete record from the database
    $mf->delete;
    $self->status_ok( $c, { contacts => \@contacts_in_video } );
}


=head2 /services/mediafile/delete_asset

Delete assets related to a mediafile.  Deletes the asset in permanent
storage as well, and any related features.

Note: This method doesn't do anything fancy about remapping face URIs,
if faces are deleted using this API the caller must ensure all
contacts have valid URIs as part of the operation.

=head3 Parameters

assets[] - A list of assets. Any assets not belonging to the user are ignored.

=head3 Response

  {}

=cut

sub delete_assets :Local {
    my $self = shift;
    my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [
	  'assets[]' => []
        ],
        @_ );

    my @assets_to_delete = $c->model( 'RDS::MediaAsset' )->search( {
	'me.uuid' => { -in => $args->{ 'assets[]' } },
	'me.user_id' => $c->user->id() } )->all();

    unless( scalar( @assets_to_delete ) ) {
	$self->status_bad_request( $c, $c->loc( "No media_assets to delete found." ) )
    }

    for my $asset_to_delete ( @assets_to_delete ) {

	my $location = $asset_to_delete->location();

	unless( $location ) {
	    $self->status_bad_request( $c, $c->loc( "Cannot determine location of this asset." ) );
	}

	my $klass = $c->config->{mediafile}->{$location};
	unless ( $klass ) {
	    $self->status_bad_request( $c, $c->loc( "Cannot determine type of this asset." ) );
	}
	if ( $klass ne 'VA::MediaFile::US' ) {
	    $self->status_bad_request( $c, $c->loc( "Delete not implemented for resources of type: $klass" ) );
	}
	my $fp = new $klass;
	# If we have an error on a particular asset, we just continue on to the rest of them.
	$fp->delete_asset( $c, $asset_to_delete );

	# Finally, delete record from the database - doing so will
	# also take out any features associated with that asset
	# automatically.
	$asset_to_delete->delete;
    }
    $self->status_ok( $c, { } );
}

=head2 /services/mediafile/list

Return a list of media files belonging to the logged in user.  Supports
optional paging.  With no parameters, returns all media files owned by
the user.  With paging parameters, returns paged results and a pager.

=head3 Parameters

=over

=item type (optional)

Specifies the type of media files to return.  If not specified, returns
all types.

=item page (optional)

The page number to fetch items from.  The number of items per page
is specified by the 'rows' parameter.

=item rows (optional, defaults to 10)

Ignored unless 'page' is specified.  Specifies number of items per page.
This number of items (or less) will be delivered back to the client.

=back

=head3 Example Response

Without paging:

  { "media" : [ $list-of-mediafiles ] }

With paging:

  {
     "media" : [ [ $list-of-mediafiles ],
     "pager" : {
        "entries_per_page" : "3",
        "total_entries" : "12",
        "current_page" : "1",
        "entries_on_this_page" : 3,
        "first_page" : 1,
        "last_page" : 4,
        "next_page" : 2,
        "previous_page" : null,
        "first" : 1,
        "last" : 3
     }
  }

=cut
sub list :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 10000,
	  include_contact_info => 0,
	  include_tags => 1,
	  include_shared => 0,
	  'views[]' => ['poster', 'main'],
	  include_images => 0,
	  only_visible => 1,
	  only_videos => 1,
	  'status[]' => []
        ],
        @_ );

    my $params = {
	include_contact_info => $args->{include_contact_info},
	include_tags => $args->{include_tags},
	include_shared => $args->{include_shared},
	views => $args->{'views[]'},
	include_images => $args->{include_images}
    };

    if ( $params->{include_images} ) {
	push( @{$params->{views}}, 'image' );
    }

    my $where = {};
    if ( $args->{only_visible} ) {
	$where->{'status'} = [ 'visible', 'complete' ];
    }
    if ( scalar( @{$args->{'status[]'}} ) ) {
	$where->{'status'} = $args->{'status[]'};
    }
    if ( $args->{only_videos} ) {
	$where->{'me.media_type'} = 'original';
    }

    my $rs = $c->user->videos->search(
	$where,
	{ prefetch => 'assets',
	  page => $args->{page}, rows => $args->{rows},
	  order_by => { -desc => 'me.id' } } );

    if ( $args->{include_images} ) {
	push( @{$params->{'views'}}, 'image' );
    }

    my $media = $self->publish_mediafiles( $c, [$rs->all], $params );

    $self->status_ok(
	$c,
	{ media => $media,
	  pager => $self->pagerToJson( $rs->pager ),
	} );
}

# DEPRECATED
sub popular :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 10000,
	  'views[]' => undef,
	  only_visible => 1,
	  only_videos => 1,
	  'status[]' => [],
        ],
        @_ );

    $self->status_bad_request( $c, "services/mediafile/popular is deprecated." );

    my $where = $self->where_valid_mediafile( undef, undef, $args->{only_visible}, $args->{only_videos}, $args->{'status[]'} );
    $where->{ 'me.view_count' } = { '!=', 0 };
    my $rs = $c->user->media->search( $where, 
				      { prefetch => 'assets',
					page => $args->{page},
					rows => $args->{rows},
					order_by => { -desc => 'me.view_count' } });

    my $media = $self->publish_mediafiles( $c, [$rs->all], { views => $args->{'views[]'} } );

    my $pager = $self->pagerToJson( $rs->pager );
    $self->status_ok( $c, { media => $media, pager => $pager } );
}

=head2 /services/mediafile/get

Get the information for a single mediafile (mid=uuid).  If include_contact_info=1,
then also return media.views.faces, an array of the contacts present in this
media file.  If views=aa,bb then include only the views specified in the result.
Specifying views can cause a significant speedup.

=cut

sub get :Local {
    my( $self, $c, $mid, $include_contact_info ) = @_;
    $mid = $c->req->param( 'mid' ) unless( $mid );
    $include_contact_info = $c->req->param( 'include_contact_info' ) unless( $include_contact_info );
    $include_contact_info = 0 unless( $include_contact_info );

    my $include_shared = $c->req->param( 'include_shared' ) || 0;
    my $include_tags = $c->req->param( 'include_tags' ) || 1;

    my $params = {
	include_contact_info => $include_contact_info,
	include_shared => $include_shared,
	include_tags => $include_tags,
    };
    if ( $c->req->param( 'views[]' ) ) {
	my @views = $c->req->param( 'views[]' );
	$params->{views} = \@views;
    }

    my $mf = $c->user->media->find({uuid=>$mid},{prefetch=>['assets','user']});

    unless( $mf ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }

    my $view = VA::MediaFile->new->publish( $c, $mf, $params );
    $self->status_ok( $c, { media => $view, owner => $mf->user->TO_JSON } );
}

# DEPRECATED
sub get_metadata :Local {
    my( $self, $c, $mid ) = @_;
    $mid = $c->req->param( 'mid' ) unless( $mid );

    $self->status_bad_request( $c, "services/medafile/get_metadata is deprecated." );

    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }

    my $mf = $c->user->media->find({uuid=>$mid});

    unless( $mf ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }

    my $hash = VA::MediaFile->new->metadata( $c, $mf );
    if ( $hash ) {
	$self->status_ok( $c, $hash );
    }
    else {
	$self->status_bad_request( $c, $c->loc( 'Failed to obtain metadata' ) );
    }
}

sub set_title_description :Local {
    my( $self, $c) = @_;
    my $mid = $c->req->param( 'mid' );
    my $title = $self->sanitize( $c, $c->req->param( 'title' ) );
    my $description = $self->sanitize( $c, $c->req->param( 'description' ) );
    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }
    my $mf = $c->user->media->find({uuid=>$mid});
    unless( $mf ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }
    $mf->title( $title ) if ( $title );
    $mf->description( $description ) if ( $description );
    $mf->update;
    $self->status_ok( $c, { title => $mf->title, description => $mf->description } );
}

sub comments :Local {
    my( $self, $c ) = @_;
    $c->forward( '/services/na/media_comments' );
}

sub add_comment :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $txt = $c->req->param( 'txt' );
    if ( !defined( $txt ) || $txt eq '' ) {
	# noop
	$self->status_ok( $c, { comment => {} } );
    }
    # comments need to be sanitized before being written to any database!
    $txt = $self->sanitize( $c, $txt );
    if ( !defined( $txt ) || $txt eq '' ) {
	# noop
	$self->status_ok( $c, { comment => {} } );
    }
    # This version of add comment is being called by the logged in user...
    my $who = $c->user->displayname;

    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }
    my $mf = $c->model( 'RDS::Media' )->find({uuid=>$mid});
    unless( $mf ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }

    my $comment = $mf->create_related( 'comments', {
	user_id => $c->user->id,
	comment => $txt });

    unless( $comment ) {
	$self->status_bad_request(
	    $c, $c->loc( "Failed to add this comment to the database." ) );
    }	

    # Refetch, to get a valid create_date
    my $id = $comment->id;
    undef $comment;
    $comment = $c->model( 'RDS::MediaComment' )->find({id=>$id});

    my $hash = $comment->TO_JSON;
    $hash->{who} = $comment->user->displayname;

    ### MONA WANTS TO TURN THIS OFF BECAUSE SHE IS WORRIED ABOUT SPAMMING
    ### And now she wants it back on
    ### $self->status_ok( $c, { comment => $hash } );

    #################################################################################

    # Send emails and notifications (but not to myself!)

    # Who should get email/notifications?  The owner of the video being commented on,
    # and everybody who has been shared this video.  The logged in user
    # making the comment should never get an email.

    my $published_mf = VA::MediaFile->new->publish( $c, $mf, { views => ['poster', 'main'] } );
    if ( $c->user->id != $mf->user->id ) {
	my $res = $c->model( 'MQ' )->post( '/enqueue', 
					   { uid => $mf->user->uuid,
					     type => 'new_comment',
					     user => $c->user->obj->TO_JSON,
					     media  => $published_mf } );

	if ( $mf->user->profile->setting( 'email_notifications' ) &&
	     $mf->user->profile->setting( 'email_comment' ) ) {
	    $self->send_email( $c, {
		subject => $c->loc( 'Someone has commented on one of your videos.' ),
		to => [{ email => $mf->user->email,
			 name  => $mf->user->displayname }],
		template => 'email/16-commentsOnYourVid.tt',
		stash => {
		    from => $c->user->obj,
		    commentText => $comment->comment,
		    model => {
			media => [ $published_mf ] 
		    }
		} });
	}
    }

    # Now see if the mediafile has private shares, and send notifications to those
    # people
    #
    my @shares = $mf->media_shares->search({ share_type => 'private', user_id => { '!=', undef }});
    foreach my $share ( @shares ) {
	next if ( $share->user->id == $c->user->id );
	next unless( $share->user->email );
	my $res = $c->model( 'MQ' )->post( '/enqueue', 
					   { uid => $share->user->uuid,
					     type => 'new_comment',
					     user => $c->user->obj->TO_JSON,
					     media  => $published_mf } );
    }

    $self->status_ok( $c, { comment => $hash } );
}

=head2 /services/mediafile/add_share

Called to share a video with someone or someones.  Requires a mid media uuid.  The
list parameter is optional.  If not present, this share is 'public', a post to a
social networking site.  If the list is present, its assumed to be a clean, sanitized
comma delimited list of email addresses.  If an email address belongs to a viblio user,
a private share is created, otherwise a hidden share.  Email is sent to each address
on the list.  The url to the video is different depending on private or hidden.

If a list is passed, every email address on that list is added to the user's
contact list unless it is already present.

=cut

sub add_share :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my @list = $c->req->param( 'list[]' );
    my $subject = $self->sanitize( $c, $c->req->param( 'subject' ) );
    # Can't sanitize this, it comes with a HREF link in it.
    my $body = $c->req->param( 'body' );
    my $title = $self->sanitize( $c, $c->req->param( 'title' ) );
    my $embed = $self->boolean( $c->req->param( 'embed' ), 0 );
    my $disposition = $c->req->param( 'private' );
    $disposition = 'private' unless( $disposition );

    my $embed_url = undef;

    my $media = $c->user->media->find({ uuid => $mid });
    unless( $media ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ), $mid );
    }
    if ( $title ) {
	$media->title( $title );
	$media->update;
    }
    
    if ( $#list >=0 ) {
	my $addrs = {};
	my @clean = $self->expand_email_list( $c, \@list, [ $c->user->email ] );
	foreach my $email ( @clean ) {
	    my $share;
	    my $recip = $c->model( 'RDS::User' )->find({ email => $email });
	    if ( $disposition eq 'private' ) {
		# This is a private share to another viblio user
		if ( $recip ) {
		    # The target user already exists
		    $share = $media->find_or_create_related( 'media_shares', { 
			user_id => $recip->id,
			share_type => 'private' } );
		    unless( $share ) {
			$self->status_bad_request
			    ( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
		    }
		    $addrs->{$email}->{url} = $c->server . '#web_player?mid=' . $media->uuid;
		    $addrs->{$email}->{type} = 'private';
		}
		else {
		    # 1.  Create a "pending user" as a placeholder for this future user
		    # 2.  Create the share pointing to this pending user
		    # 3.  If we're in beta, auto-whitelist this future user (they will
		    #     get a welcome email upon actual registration)
		    #
		    # During registration, the share will be looked up by pending user
		    # and replaced with actual user, and pending user will be deleted.
		    my $pending_user = $c->model( 'RDS::User' )->find_or_create({
			displayname => $email,
			provider_id => 'pending' });
		    unless( $pending_user ) {
			$self->status_bad_request
			    ( $c, $c->loc( "Failed to create a pending user for for [_1]", $email ) );
		    }
		    $share = $media->find_or_create_related( 'media_shares', { 
			share_type => 'private',
			user_id => $pending_user->id });
		    unless( $share ) {
			$self->status_bad_request
			    ( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
		    }
		    if ( $c->config->{in_beta} ) {
			my $wl = $c->model( 'RDS::EmailUser' )->find_or_create({
			    email => $email,
			    status => 'whitelist' });
			unless( $wl ) {
			    $c->log->error( "Failed to add $email to whitelist for private share." );
			}
		    }
		    my $url = $c->server . '#register?email=' .
			uri_escape( $email ) . '&url=' .
			uri_escape( '#web_player?mid=' . $media->uuid );
		    $addrs->{$email}->{url} = $url;
		    $addrs->{$email}->{type} = 'private';
 		}

		# Add to user's contact list
		# my $contact = $c->user->obj->find_or_create_related( 'contacts', { contact_email => $email, contact_name => $email } );
		my $contact = $c->user->create_contact( $email );
		unless( $contact ) {
		    $c->log->error( "Failed to create a contact out of a shared email address!" );
		}
	    }
	    else {
		# This is a hidden share, emailed to someone but technically viewable
		# by anyone with the link
		$share = $media->find_or_create_related( 'media_shares', { share_type => 'hidden' } );
		unless( $share ) {
		    $self->status_bad_request
			( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
		}
		$addrs->{$email}->{url} = $c->server . '#web_player?mid=' . $media->uuid;
		$addrs->{$email}->{type} = 'unlisted';
	    }
	}
	# If we're here, then everything is ok so far and we can send emails
	foreach my $addr ( keys %$addrs ) {
	    my $email = {
		subject => $subject || $c->loc( "[_1] has shared a video with you", $c->user->obj->displayname ),
		to => [{
		    email => $addr }],
		template => 'email/06-videosSharedWithYou.tt',
		stash => {
		    body => $body,
		    from => $c->user->obj,
		    url => $addrs->{$addr}->{url},
		    model => {
			media => [ VA::MediaFile->new->publish( $c, $media, { expires => (60*60*24*365) } ) ],
			vars => {
			    shareType => $addrs->{$addr}->{type},
			}
		    }
		}
	    };
	    $self->send_email( $c, $email );
	}
    }
    elsif ( $disposition eq 'potential' ) {
	# This is a potential share.  A potential share is created in any context
	# where we don't otherwise know that the share will ever actually be used.
	# Currently this is the case for cut-n-paste or copy-to-clipboard link
	# displayed in the shareVidModal in the web gui.  We don't know if the user
	# will actually c-n-p or c-t-c, and if they do, we don't know if they 
	# actually utilize the information.  So we create a potential share, which
	# will turn into a "hidden" share if anyone ever comes into viblio via the
	# special link we will specify.
	#
	my $share = $media->create_related( 'media_shares', { share_type => 'potential' } );
	unless( $share ) {
	    $self->status_bad_request
		( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
	}
	my $url = $c->server . 's/ps/' . $share->uuid;
	$self->status_ok( $c, { url => $url } );
    }
    else {
	my $share = $media->find_or_create_related( 'media_shares', { share_type => 'public' } );
	unless( $share ) {
	    $self->status_bad_request
		( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
	}
	if ( $embed ) {
	    $embed_url = $c->server . 's/e/' . $share->uuid;
	}
    }

    if ( $embed and defined( $embed_url ) and length( $embed_url ) ) {
	$self->status_ok( $c, { embed_url => $embed_url } );
    } else {
	$self->status_ok( $c, {} );
    }
}

=head2 /services/mediafile/count

Simply return the total number of mediafiles owned by the logged in user.

=cut

sub count :Local {
    my( $self, $c ) = @_;
    my $uid = $c->req->param( 'uid' );
    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my $count = 0;

    my $where = $self->where_valid_mediafile( undef, undef, $only_visible, $only_videos, \@status_filters );

    if ( $uid ) {
	my $user = $c->model( 'RDS::User' )->find({uuid => $uid });
	if ( $user ) {
	    $count = $user->media->count($where);
	}
    }
    else {
	$count = $c->user->media->count($where);
    }
    $self->status_ok( $c, { count => $count } );
}

=head2 /services/mediafile/all_shared

Return a struct that contains all media shared to this user.  The return is an
array of structs that look like:

  { 
    owner: {
      * user record, person who shared this media
    },
    media: [
      * array of media files shared by owner
    ]
  }

If cid is passed in, it is interpreted as a contact_uuid, and will filter
the results so that only media containing this contact are returned.

=cut

sub all_shared :Local {
    my( $self, $c ) = @_;
    my $user = $c->user->obj;
    my $cid  = $c->req->param( 'cid' );

    my @media = ();
    if ( $cid ) {
	my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $cid });
	if ( $contact ) {
	    my @shares = $user->media_shares->search({'media.is_album' => 0},{prefetch=>{ media => 'user'}} );
	    my @media_ids = map { $_->media->id } @shares;
	    my @feats = $c->model( 'RDS::MediaAssetFeature' )
		->search({ 'me.contact_id' => $contact->id,
			   'me.feature_type' => 'face',
			   'media.id' => { '-in', \@media_ids } },
			 { prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] });
	    @media = map { $_->media_asset->media } @feats;
	}
    }
    else {
	#my @shares = $user->media_shares->search( {'media.is_album' => 0},{prefetch=>{ media => 'user'}} );
	#@media = map { $_->media } @shares;
	@media = $user->visible_media();
    }
    
    # partition this into an array of users, each with an array of videos they've
    # shared with you.

    my $users = {};
    foreach my $media ( @media ) {
	my $owner = $media->user->displayname;
	next if $media->user->id() == $user->id();
	if ( ! defined( $users->{ $owner } ) ) {
	    $users->{ $owner } = [];
	}
	push( @{$users->{ $owner }}, $media );
    }
    my @sorted_user_keys = sort{ lc( $a ) cmp lc( $b ) } keys( %$users );
    my @data = ();
    foreach my $key ( @sorted_user_keys ) {
	my @media = map { VA::MediaFile->publish( $c, $_, { views => ['poster', 'main' ] } ) } sort{ $b->created_date->epoch <=> $a->created_date->epoch } @{$users->{ $key }};

	# iOS app wants to sort based on shared on date ...
	my @mids = map { $_->id } sort{ $b->created_date->epoch <=> $a->created_date->epoch } @{$users->{ $key }};

	for( my $i=0; $i<=$#media; $i++ ) {
	    #    my $share = $c->model( 'RDS::MediaShare' )->find({ media_id => $mids[$i],
	    #						       user_id  => $c->user->obj->id });
	    #    # force the date to be formatted like other dates
	    #    my $s = { %{$share->{_column_data}} };
	    #    $media[$i]->{shared_date} = $s->{created_date};
	    $media[$i]->{shared_date} = $media[$i]->{created_date};
	}

	push( @data, {
	    owner => $users->{ $key }[0]->user->TO_JSON,
	    media => \@media
	      });
    }
    
    $self->status_ok( $c, { shared => \@data } );
}

# services/media/list_status
#
# Return an very simple structure listing the status of videos owned
# by this user.
#
# The interpretation of the status are:
# pending - The video has been fully uploaded, but processing has not yet begin
# visible - The video may be viewed, but further processing is ongoing
# complete - The video has completed all processing
# failed - There was a problem processing the video, it can not be viewed
#
# { stats : { pending : 1, visible : 19, complete : 119, failed : 0 },
#   details : [ { uuid : the uuid of the video, status : pending }, { uuid : uuid-sdf-23, status : complete }, ...
sub list_status :Local {
    my ( $self, $c ) = @_;
    my @media = $c->model( 'RDS::Media' )->search( 
	{ 'me.user_id' => $c->user->id,
	  'me.is_album' => 0,
	  'me.media_type' => 'original' } )->all();

    my $valid_status = { 
	pending  => 1,
	visible  => 1,
	complete => 1,
	failed   => 1
    };

    my $result = { 
	stats => { 
	    pending  => 0,
	    visible  => 0,
	    complete => 0,
	    failed   => 0
	},
		details => [] 
    };

    foreach my $m ( @media ) {
	if ( exists( $valid_status->{$m->status} ) ) {
	    $result->{stats}->{$m->status}++;
	    push( @{$result->{details}}, { uuid => $m->uuid, status => $m->status } );
	} else {
	    $c->log->warning( "Error, invalid status of: ", $m->status, " for media: ", $m->id, "\n" );
	}
    }
    $self->status_ok( $c, $result );
}

## List all videos, owned by and shared to the user
sub list_all :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;
    my $include_images = $self->boolean( $c->req->param( 'include_images' ), 0 );
    my $include_contact_info = $self->boolean( $c->req->param( 'include_contact_info' ), 0 );
    my $include_tags = $self->boolean( $c->req->param( 'include_tags' ), 1 );
    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }
    my $no_dates = $self->boolean( $c->req->param( 'no_dates' ), 0 );

    my $views = ['poster', 'main'];
    if ( $include_images ) {
	push( @$views, 'image' );
    }

    #$c->log->error( "Before visible_media: ", time() );
    
    my @videos = $c->user->visible_media( {
	include_contact_info => $include_contact_info,
	include_images => $include_images,
	include_tags => $include_tags,
	only_visible => $only_visible,
	only_videos => $only_videos,
	'status[]' => \@status_filters,
	'views[]' => $views } );

    #$c->log->error( "After visible_media: ", time() );
	   
    my ( $media_tags, $media_contact_features, $all_tags, $no_date_return ) = $self->get_tags( $c, \@videos );
 
    my $shared_uuids = {};
    for my $video ( @videos ) {
	if ( $video->user_id() != $c->user->id() ) {
	    $shared_uuids->{$video->uuid} = 1;
	}
    }
    
    my $pager = Data::Page->new( $#videos + 1, $rows, $page );
    my @slice = ();
    if ( $#videos >= 0 ) {
        @slice = @videos[ $pager->first - 1 .. $pager->last - 1 ];
    }

    #$c->log->error( "Before publish_mediafiles: ", time() );

    my $data = $self->publish_mediafiles( $c, \@slice, { 
	views                  => $views, 
	include_tags           => $include_tags, 
	include_shared         => 1, 
	include_owner_json     => 1, 
	include_images         => $include_images, 
	include_contact_info   => $include_contact_info,
	media_tags             => $media_tags,
	media_contact_features => $media_contact_features } );

    #$c->log->error( "After publish_mediafiles: ", time() );

    $self->status_ok( $c, { albums => $data,
                            pager  => $self->pagerToJson( $pager ),
			    all_tags => $all_tags,
			    no_date_return => $no_date_return } );
}

=head2 /services/mediafile/delete_share

Delete a private share

=cut

sub delete_share :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    unless( $mid ) {
	$self->status_bad_request( $c, $c->loc( 'Missing param [_1]', 'mid' ) );
    }
    my $user = $c->user->obj;
    my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
    unless( $media ) {
	$self->status_ok( $c, { deleted => [] } );
    }
    my @shares = $media->media_shares->search({ user_id => $user->id });
    my @deleted = ();
    foreach my $share ( @shares ) {
	push( @deleted, $share->media->uuid );
	$share->delete; $share->update;
    }
    $self->status_ok( $c, { deleted => \@deleted } );
}

=head2 /services/mediafile/cf

Return the S3 and cloudfront urls for a video

=cut

sub cf :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    
    my $user = $c->user();
    my $mediafile = $c->model( 'RDS::Media' )->find({ uuid => $mid }, {prefetch => 'user'});
    unless( $mediafile ) {
	$self->status_not_found( $c, $c->loc( "Cannot find media for uuid=[_1]", $mid ), $mid );
    }
    
    my $owns_video = 0;

    # If the user is logged in and its their video, show it
    if ( $user && $mediafile->user_id == $user->id ) {
	$owns_video = 1;
    }

    my @result = $c->user->obj->visible_media( { 'media_uuids[]' => [ $mid ] } );

    if ( $owns_video || scalar( @result ) ) {
	my $rs = $c->model( 'RDS::MediaAsset' )->search(
	    { 'media.uuid' => $mid,
	      'me.asset_type' => 'main' }, { prefetch => 'media' } );
	my $asset = $rs->first;
	unless( $asset ) {
	    $self->status_not_found( $c, $c->loc( 'Cannot find main asset for media [_1]', $mid ), $mid );
	}
	$self->status_ok( $c, { 
	    url    => VA::MediaFile::US->new->uri2url( $c, $asset->uri ),
	    cf_url => $c->cf_sign( $asset->uri, { stream => 1 } ) } );
    } else {
	$self->status_forbidden( $c, $c->loc( 'Not authorized to views this video.' ), $mid );
    }
}

=head2 /services/mediafile/related

Input parameters:
* only_videos=1 - whether media_type is 'original' only or all types
* only_visible=1 - whether status is restricted to ['visible', 'complete'] or not
* status[]=['a','b','c'] - overrides the status setting of only_visible
* media[]=[uuid1,uuid2,...] a list of related media

Return list of mediafiles related to the passed in mediafile, as
determined by:

1. If media[] is included, we return just the list of those items
which the user can see.

2. If this media is in any albums, return a list of videos that the
user can see in those albums, sorted by descending recording_date,
created_date.

3. Otherwise, if there are any faces in this video, return a list of
videos the user can see which also have those faces in them, sorted by
descending recording_date, created_date.

4. Otherwise, return the empty list.

=cut

sub related :Local {
    my( $self, $c ) = @_;

    my $mid = $c->req->param( 'mid' );
    my $page = $c->req->param( 'page' );
    my $rows = $c->req->param( 'rows' ) || 10;

    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @related_media = $c->req->param( 'media[]' );
    if ( scalar( @related_media ) == 1 && !defined( $related_media[0] ) ) {
	@related_media = ();
    }

    unless( $mid ) {
	$self->status_bad_request( $c, $c->loc( 'Missing param [_1]', 'mid' ) );
    }
    my $user = $c->user->obj;

    # The passed in uuid might be from a shared video
    #
    my $where = undef;

    if ( $only_visible ) {
	$where = { 'me.uuid' => $mid,
		   'me.is_album' => 0,
		   status => [ 'visible', 'complete'],
		   -or => ['me.user_id' => $user->id, 
			   'media_shares.user_id' => $user->id],
	};
    } else {
	$where = { 'me.uuid' => $mid,
		   'me.is_album' => 0,
		   -and => [ -or => ['me.user_id' => $user->id, 
				     'media_shares.user_id' => $user->id] ] };
    }
    if ( scalar( @status_filters ) ) {
	$where->{status} = \@status_filters;
    }
    if ( $only_videos ) {
	$where->{'me.media_type'} = 'original';
    }

    my $media = $c->model( 'RDS::Media' )->find( $where, {prefetch=>'media_shares'} );

    unless( $media ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find mediafile for [_1]', $mid ), $mid );
    }

    # Array of media objects to publish and return.
    my @media_results = ();

    if ( scalar( @related_media ) ) {
	# If we were provided a list of related media, just return the
	# ones the current user can see.
	
	@media_results = $user->visible_media( { 
	    'media_uuids[]' => \@related_media, 
	    only_visible => $only_visible, 
	    'status[]' => \@status_filters, 
	    only_videos => $only_videos } );
    } else {

	# First determine if this media is in any albums that this
	# user can view, if so then return those.
	#
	# If not, then determine if there are any faces in this video,
	# and if there are return other videos whose people appear in.
	my $seen = {};
	$seen->{ $media->uuid } = $media; # DO NOT SHOW MYSELF IN RELATED

	$where = { 'media.user_id' => $user->id(),
		   'media.id' => $media->id() };
	if ( $only_visible ) {
	    $where->{ 'media.status' } = [ 'visible', 'complete' ];
	}
	if ( scalar( @status_filters ) ) {
	    $where->{ 'media.status' } = \@status_filters;
	}
	if ( $only_videos ) {
	    $where->{ 'media.media_type' } = 'original';
	}

	my @owned_albums = $c->model( 'RDS::MediaAlbum' )->search(
	    $where,
	    { prefetch => [ 'media', { 'album_media' => 'media' } ] } )->all();

	foreach my $owned_album ( @owned_albums ) {
	    foreach my $album_contents ( $owned_album->album_media() ) {
		foreach my $owned_media ( $album_contents->media() ) {
		    unless ( exists( $seen->{ $owned_media->uuid() } ) ) {
			push( @media_results, $owned_media );
			$seen->{ $owned_media->uuid() } = $owned_media;
		    }
		}
	    }
	}

	my @user_community_list = $user->is_community_member_of();
	my @media_community_list = $media->is_community_member_of();
	
	my $user_communities = {};
	foreach my $user_community ( @user_community_list ) {
	    $user_communities->{ $user_community->uuid } = $user_community;
	}
	foreach my $media_community ( @media_community_list ) {
	    if ( exists( $user_communities->{ $media_community->uuid() } ) ) {
		#$DB::single = 1;
		foreach my $album_contents ( $media_community->album->media_albums_medias->related_resultset( 'album_media' )->all() ) {
		    foreach my $community_media ( $album_contents->related_resultset( 'media' )->all() ) {
			unless ( exists( $seen->{ $community_media->uuid() } ) ) {
			    push( @media_results, $community_media );
			    $seen->{ $community_media->uuid() } = $community_media;
			}
		    }
		}
	    }
	}
	
	if ( !scalar( @media_results ) ) {
	    # We didn't find anything in related albums, try to find
	    # related faces.

	    # Hash of media uuid's already added to results (to prevent dups in results)
	    my $seen = {};
	    $seen->{ $media->uuid } = $media; # DO NOT SHOW MYSELF IN RELATED

	    # First of all, find all known faces in the passed in mediafile
	    #
	    my @face_features = $c->model( 'RDS::MediaAssetFeature' )
		->search({ 'me.media_id' => $media->id,
			   'me.feature_type' => 'face',
			   'contact.contact_name' => { '!=', undef } },
			 { prefetch=>['contact','media_asset'], group_by=>['contact.id'] });
	    
	    if ( $#face_features >= 0 ) {
		# There are faces.  Lets find all other videos in our list that contain at
		# least one of these faces, ordered by most recently recorded.
		#
		my @contact_ids = map { $_->contact->id } @face_features;
		my @visible_media = $user->visible_media( { 
		    only_visible => $only_visible, 
		    'status[]' => \@status_filters, 
		    only_videos => $only_videos } );

		my @media_ids   = map { $_->id } @visible_media;
		
		# $c->log->error( $_->contact->contact_name, "\n" ) foreach @face_features;
		
		my @feats = $c->model( 'RDS::MediaAssetFeature' )
		    ->search({ 'contact.id' => { -in => \@contact_ids },
			       'me.feature_type' => 'face',
			       'me.media_id' => { -in => \@media_ids },
			     },
			     { prefetch => [ 'contact', { 'media_asset' => 'media' } ], group_by => ['media.id'] });
		
		# Unfortunately we are storing poster assets in the results array, so we have to do
		# poster fetches
		foreach my $feat ( @feats ) {
		    unless( $seen->{ $feat->media_asset->media->uuid } ) {
			# $c->log->error( $feat->media_asset->media->title );
			push( @media_results, $feat->media_asset->media );
			$seen->{ $feat->media_asset->media->uuid } = $feat->media_asset->media;
		    }
		}
	    }
	}
    }

    # Sort the result set by descending recorded date, then created date.
    @media_results = sort {  my $rdate_cmp = ( $b->recording_date->epoch() <=> $a->recording_date->epoch() );
			     if ( $rdate_cmp ) {
				 return $rdate_cmp;
			     } else {
				 return $b->created_date->epoch() <=> $a->created_date->epoch();
			     }
    } @media_results;

    # If we had media results, add ourself to the front of the list.
    if ( scalar( @media_results ) ) {
	unshift( @media_results, $media );
    }

    # Prepare and return results
    #
    my @data  = ();
    my $pager = {};
    if ( $page ) {
	my $data_pager = Data::Page->new( $#media_results + 1, $rows, $page );
	if ( $#media_results >= 0 ) {
	    @data = @media_results[ $data_pager->first - 1 .. $data_pager->last - 1 ];
	}
	$pager = $self->pagerToJson( $data_pager );
    }
    else {
	@data = @media_results;
    }

    my $media_hash = $self->publish_mediafiles( $c, \@media_results, { include_tags=>1, include_shared=>1, 'views' => [ 'poster', 'main' ] } );

    $self->status_ok( $c, { media => $media_hash, pager => $pager } );
}

sub change_recording_date :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $dstring = $self->sanitize( $c, $c->req->param( 'date' ) );
    my $media = $c->user->media->find({uuid => $mid });
    unless( $media ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
    }

    my $new_date = DateTime::Format::Flexible->parse_datetime( $dstring );
    my $date_string = $new_date->month_name . ' ' . $new_date->year();

    my $old_date = $media->recording_date();

    if ( $old_date == DateTime->from_epoch( epoch => 0 ) ) {
	# We are updating from the default, add a new tag.
	$media->asset( 'main' )->create_related( 'media_asset_features', { feature_type => 'activity',
									   coordinates => $date_string } );
    } else {
	# We are updating from a prior date, update existing or add
	# new tag if none.
	my $old_date_string = $old_date->month_name . ' ' . $old_date->year();
	my $old_tag = $media->asset( 'main' )->search_related( 'media_asset_features', { coordinates => $old_date_string } )->single();
	if ( defined( $old_tag ) ) {
	    $old_tag->coordinates( $date_string );
	    $old_tag->update();
	} else {
	    $media->asset( 'main' )->create_related( 'media_asset_features', { feature_type => 'activity',
									       coordinates => $date_string } );
	}
    }

    $media->recording_date( DateTime::Format::Flexible->parse_datetime( $dstring ) );
    $media->update;
    $self->status_ok( $c, [ $media->tags() ] )
}

# DEPRECATED
sub get_animated_gif :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );

    $self->status_bad_request( $c, "services/mediafile/get_animated_gif is deprecated." );

    my $asset = $c->model( 'RDS::MediaAsset' )->search(
	{ 'media.uuid' => $mid,
	  'me.asset_type' => 'poster_animated' },
	{ prefetch => 'media' } );
    if ( $asset ) {
	my $gif = $asset->first;
	if ( $gif ) {
	    $self->status_ok( $c, { url => VA::MediaFile::US->new->uri2url( $c, $gif->uri ) } );
	}
    }
    $self->status_ok($c,{});
}

# DEPRECATED
# Pass in a MD5 checksum, see if a mediafile exists with that hash
sub media_exists :Local {
    my( $self, $c ) = @_;
    my $hash = $c->req->param( 'hash' );

    $self->status_bad_request( $c, "services/mediafile/media_exists is deprecated." );

    my $count = $c->user->media->count({
	unique_hash => $hash });
    $self->status_ok( $c, { count => $count } );
}

# see if a particular mediafile has ever been shared
sub has_been_shared :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my @shared = $c->model( 'RDS::MediaShare' )->search(
	{ 'media.uuid' => $mid },
	{ prefetch => 'media' });
    $self->status_ok( $c, { count => ( $#shared + 1 ) } );
}

# Search by title or description OR TAG
# Returns media owned by and shared to user that matches the
# search criterion.
sub search_by_title_or_description :Local {
    my( $self, $c ) = @_;
    my $q = $self->sanitize( $c, $c->req->param( 'q' ) );
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 10000;

    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );

    my $include_contact_info = $self->boolean( $c->req->param( 'include_contact_info' ), 1 );
    my $include_images = $c->req->param( 'include_images' ) || 0;
    my $include_tags = $self->boolean( $c->req->param( 'include_tags' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my $views = ['poster', 'main'];
    if ( $include_images )  {
	push( @{$views}, 'image' );
    }

    my @videos = $c->user->visible_media( {
	include_contact_info => $include_contact_info,
	include_image => $include_images,
	include_tags => $include_tags,
	search_string => $q,
	only_videos => $only_videos,
	only_visible => $only_visible,
	'status[]' => \@status_filters,
	'views[]' => $views } );

    # DEBUG - can we actually have dupes now that we refactored here?
    # We will have dups.  De-dup, then page.
    my $seen = {};
    my @tmp = ();
    for my $media ( @videos ) {
	if ( !exists( $seen->{$media->id()} ) ) {
	    $seen->{$media->id()} = 1;
	    push( @tmp, $media );
	}
    }
    @videos = @tmp;

    my ( $media_tags, $media_contact_features, $all_tags, $no_date_return ) = $self->get_tags( $c, \@videos );

    my $pager = Data::Page->new( $#videos + 1, $rows, $page );
    my @slice = ();
    if ( $#videos >= 0 ) { 
	@slice = @videos[ $pager->first - 1 .. $pager->last - 1 ]; 
    }

    #$DB::single = 1;

    my $data = $self->publish_mediafiles( $c, \@slice, { 
	views => $views, 
	include_tags => $include_tags, 
	include_shared => 1, 
	include_contact_info => $include_contact_info, 
	include_owner_json => 1, 
	include_images => $include_images,
	media_tags => $media_tags,
	media_contact_features => $media_contact_features } );

    $self->status_ok( $c, { media => $data, 
			    pager => $self->pagerToJson( $pager ),
			    all_tags => $all_tags,
			    no_date_return => $no_date_return } );
}

# DEPRECATED
#
# IN ALBUM : Search by title or description OR TAG
# Returns media owned by and shared to user that matches the
# search criterion.
sub search_by_title_or_description_in_album :Local {
    my( $self, $c ) = @_;

    $self->status_bad_request( $c, "services/mediafile/search_by_title_or_description_in_album is deprecated." );

    my $q = $self->sanitize( $c, $c->req->param( 'q' ) );
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 10000;
    my $aid = $c->req->param( 'aid' );
    my $include_contact_info = $self->boolean( $c->req->param( 'include_contact_info' ), 1 );
    my $include_images = $c->req->param( 'include_images' ) || 0;
    my $include_tags = $self->boolean( $c->req->param( 'include_tags' ), 1 );
    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for "[_1]"', $aid ), $aid );
    }

    my @mids = map { $_->id } $album->videos;

    # Videos owned or shared to user where title or description match
    my $where = undef;

    if ( $only_visible ) {
	$where = { 'me.status' => [ 'visible', 'complete' ],
		   -and => [
		       'me.is_album' => 0,
		       'me.id' => { -in => \@mids },
		       -or => [ 'LOWER(me.title)' => { 'like', '%'.lc($q).'%' },
				'LOWER(me.description)' => { 'like', '%'.lc($q).'%' } ] ] };
    } else {
	$where = { -and => [
			'me.is_album' => 0,
			'me.id' => { -in => \@mids },
			-or => [ 'LOWER(me.title)' => { 'like', '%'.lc($q).'%' },
				 'LOWER(me.description)' => { 'like', '%'.lc($q).'%' } ] ] };
    }
    if ( scalar( @status_filters ) ) {
	$where->{'status'} = \@status_filters;
    }
    if ( $only_videos ) {
	$where->{'me.media_type'} = 'original';
    }
    my @tord = $c->model( 'RDS::Media' )->search( $where );
    
    # Videos owned or shared to user which are tagged with the expression
    my @features = $c->model( 'RDS::MediaAssetFeature' )->search(
	{ 'media.id' => { -in => \@mids },
	  'LOWER(me.coordinates)' => { 'like', '%'.lc($q).'%' } },
	{ prefetch => { 'media_asset' => 'media' } });

    # Videos owned or shared to user which have the passed in person's name
    # associated with them
    my @faces = $c->model( 'RDS::MediaAssetFeature' )->search(
	{ feature_type => 'face',
	  'media.id' => { -in => \@mids },
	  'LOWER(contact.contact_name)' => { 'like', '%'.lc($q).'%' } },
	{ prefetch => [ 'contact', { 'media_asset' => 'media' } ] });

    # We will have dups.  De-dup, then page.
    my $seen = {};
    my @tagged = ();

    foreach my $a ( @tord ) {
	my $media = $a;
	if ( ! $seen->{$media->id} ) {
	    $seen->{$media->id} = 1;
	    push( @tagged, $media );
	}
    }

    foreach my $a ( @features ) {
	my $media = $a->media_asset->media;
	if ( ! $seen->{$media->id} ) {
	    $seen->{$media->id} = 1;
	    push( @tagged, $media );
	}
    }

    foreach my $a ( @faces ) {
	my $media = $a->media_asset->media;
	if ( ! $seen->{$media->id} ) {
	    $seen->{$media->id} = 1;
	    push( @tagged, $media );
	}
    }

    my @media = sort { $b->recording_date <=> $a->recording_date } ( @tagged );

    my $pager = Data::Page->new( $#media + 1, $rows, $page );
    my @sliced = ();
    if ( $#media >= 0 ) { 
	@sliced = @media[ $pager->first - 1 .. $pager->last - 1 ]; 
    }

    my $views = ['poster', 'main'];
    if ( $include_images )  {
	push( @{$views}, 'image' );
    }

    my $data = $self->publish_mediafiles( $c, \@sliced, { views => $views, include_tags => $include_tags, include_shared => 1, include_contact_info => $include_contact_info, include_images => $include_images } );

    foreach my $d ( @$data ) {
	if ( $d->{owner_uuid} ne $c->user->uuid ) {
	    # This must be shared because the album is shared
	    $d->{is_shared} = ( $album->community ? 1 : 0 );
	    $d->{owner}     = $album->user->TO_JSON;
	} else {
	    $d->{is_shared} = 0;
	}
    }

    $self->status_ok( $c, { media => $data, pager => $self->pagerToJson( $pager ) } );
}

# Return all the unique cities that the videos a user can see occur
# in.
sub cities :Local {
    my( $self, $c ) = @_;
    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my @videos = $c->user->visible_media( {
	only_visible => $only_visible,
	only_videos => $only_videos,
	'status[]' => \@status_filters,
	where => { 'me.geo_city' => { '!=' => undef } } } );

    my $unique_cities = {};
    for my $city ( @videos ) {
	$unique_cities->{$city->geo_city()} = 1;
    }
    my @cities = sort( keys( %$unique_cities ) );
    $self->status_ok( $c, { cities => \@cities } );
}

# Return all videos taken in the passed in city
sub taken_in_city :Local {
    my( $self, $c ) = @_;
    my $q = $self->sanitize( $c, $c->req->param( 'q' ) );
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 10000;
    my $include_contact_info = $c->req->param( 'include_contact_info' ) || 0;
    my $include_images = $c->req->param( 'include_images' ) || 0;
    my $include_tags = $self->boolean( $c->req->param( 'include_tags' ), 1 );
    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );
    my $only_videos = $self->boolean( $c->req->param( 'only_videos' ), 1 );
    my @status_filters = $c->req->param( 'status[]' );
    if ( scalar( @status_filters ) == 1 && !defined( $status_filters[0] ) ) {
	@status_filters = ();
    }

    my $where = { 'me.geo_city' => $q };

    my @videos = $c->user->visible_media( {
	include_contact_info => $include_contact_info,
	include_image => $include_images,
	include_tags => $include_tags,
	only_visible => $only_visible,
	only_videos => $only_videos,
	'status[]' => \@status_filters,
	where => $where } );

    my ( $media_tags, $media_contact_features, $all_tags, $no_date_return ) = $self->get_tags( $c, \@videos );

    my $pager = Data::Page->new( $#videos + 1, $rows, $page );
    my @slice = ();
    if ( $#videos >= 0 ) {
        @slice = @videos[ $pager->first - 1 .. $pager->last - 1 ];
    }

    my $views = ['poster', 'main'];
    if ( $include_images ) {
	push( @$views, 'image' );
    }

    my $data = $self->publish_mediafiles( $c, \@videos, { 
	views => $views, 
	include_tags => $include_tags, 
	include_contact_info => $include_contact_info, 
	include_images => $include_images,
	media_tags => $media_tags,
	media_contact_features => $media_contact_features } );

    $self->status_ok( $c, { media => $data, 
			    pager => $self->pagerToJson( $pager ),
			    all_tags => $all_tags,
			    no_date_return => $no_date_return } );
}

# Return a list of all videos whose created_date (not recording_date)
# is within 7 days of the most recent video visible in the account.
#
sub recently_uploaded :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ days => 7,
	  page => 1,
          rows => 10000,
	  include_contact_info => 0,
	  include_tags => 1,
	  include_images => 0,
	  only_visible => 1,
	  only_videos => 1,
	  'status[]' => []
        ],
        @_ );

    my $days = $args->{days};
    my $page = $args->{page};
    my $rows = $args->{rows};
    my $include_contact_info = $args->{include_contact_info};
    my $include_images = $args->{include_images};
    my $include_tags = $args->{include_tags};
    my $only_visible = $args->{only_visible};
    my $only_videos = $args->{only_videos};
    my $status = $args->{'status[]'};

    my $views = ['poster', 'main'];
    if ( $include_images ) {
	push( @$views, 'image' );
    }

    if ( $days < 0 ) {
	$self->status_bad_request( $c, $c->loc( 'Days argument: [_1] must be >= 0.', $days ) );
    }

    # This one is a bit unusual in that we return our results in
    # descending order of creation date, as opposed to recording_date,
    # creation_date like most other endpoints.
    my @videos = sort( { $b->created_date->epoch() <=> $a->created_date->epoch() }
		       $c->user->visible_media( {
			   include_contact_info => $include_contact_info,
			   include_image => $include_images,
			   include_tags => $include_tags,
			   recent_created_days => $days,
			   only_videos => $only_videos,
			   only_visible => $only_visible,
			   'status[]' => $status,
			   'views[]' => $views } ) );
	
    my ( $media_tags, $media_contact_features, $all_tags, $no_date_return ) = $self->get_tags( $c, \@videos );

    my $pager = Data::Page->new( $#videos + 1, $rows, $page );
    my @slice = ();
    if ( $#videos >= 0 ) {
        @slice = @videos[ $pager->first - 1 .. $pager->last - 1 ];
    }
    
    my $data = $self->publish_mediafiles( $c, \@slice, 
					  { views => $views, 
					    include_tags => $include_tags, 
					    include_contact_info => $include_contact_info, 
					    include_images => $include_images,
					    media_tags => $media_tags,
					    media_contact_features => $media_contact_features,
					    include_owner_json => 1 } );
    
    $self->status_ok( $c, { media => $data, 
			    pager => $self->pagerToJson( $pager ),
			    all_tags => $all_tags,
			    no_date_return => $no_date_return } );
}

# Add a tag to a video
sub add_tag :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $tagname = $self->sanitize( $c, $c->req->param( 'tag' ) );
    my $video = $c->user->videos->find({ uuid => $mid });
    unless( $video ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
    }
    my $tag = $video->add_tag( $tagname );
    unless( $tag ) {
	$self->status_bad_request( $c, $c->loc( 'Failed to add tag [_1]', $tagname ) );
    }
    $self->status_ok( $c, {} );
}

# Remove a tag from a video
sub rm_tag :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $tagname = $c->req->param( 'tag' );
    my $video = $c->user->videos->find({ uuid => $mid });
    unless( $video ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find media for [_1]', $mid ), $mid );
    }
    my $tag = $video->rm_tag( $tagname );
    unless( $tag ) {
	$self->status_bad_request( $c, $c->loc( 'Failed to remove tag [_1]', $tagname ) );
    }
    $self->status_ok( $c, {} );
}


=head2

services/mediafile/create_video_summary

Input Options

{
    'images[]' : [ # Array of images the user selected.
        image1_uuid,
        image2_uuid,
        ... ],
    'summary_type' : 'moments', # One of a predefined list of summary
				# types, e.g. moments, people, etc.

    'contacts[]' : [ # Who the summary should include, required if
		   # summary_type is 'people', optional otherwise.
		   # NOTE: Initially we will only support the
		   # 'moments' type summary that won't use this most
		   # likely.
        contact1_uuid,
        ... ],
    'videos[]' : [ video1_uuid, ... ] # An array of videos to
				      # summarize for the 'people'
				      # type of summary.
    'audio_track' : media_uuid # The UUID of the audio selected for
			       # this track.

# Optional parameters:

# Additional things:

# Summary controls:
    'summary_style' : 'classic' # One of a predefined list of summary
				# types, e.g. classic, cascade, etc.
    'order' : 'random' # One of a predefined list of how we order
		       # clips, e.g. 'random', 'oldest', 'newest',
		       # etc.. Defaults to random.
    'effects[]' : [ 'vintage', 'music video', ... ] # List of preset
						  # video filters the
						  # user wants us to
						  # provide. NOTE:
						  # Initially this may
						  # not do anything.
    'moment_offsets[]' : [-2.5, 2.5] # How much before the image to
				   # start the summary clip, and how
				   # much after the moment to end the
				   # summary clip, defaults to [-2.5,
				   # 2.5]
    'target_duration' : 99 #The desired number of seconds the summary
			   #will run. Defaults to something sane given
			   #the clips selected and audio selected.
    'summary_options' : { } # Defaults to {} Generic JSON to be passed
			    # to the summary API for future expansions
			    # (e.g. parameters that control blur, slow
			    # motion, ??? ).

# Where to put the summary:
    'album_uuid' : album_uuid # An album to place the resulting
			      # summary into.

# Summary metadata:
    'title' : 'Fun Times!', # OPTIONAL: A title for the video -
			    # defaults "Summary - YYYY-MM-DD" - I
			    # suggest the UI overwrite this with
			    # "FilterName Summary"
    'description' : "Vacation", # OPTIONAL: A description for the
				# video - defaults to nothing.
    'lat' : X, 'lng' : Y, 'geo_city' : Z, # Defaults to nothing
    'tags[]' : [ tag1, tag2, ... ], # Defaults to nothing.
    'recording_date' : 'when' # Defaults to now.
}

=cut

sub create_video_summary :Local {
    my $self = shift; my $c = shift;

    my $args = $self->parse_args
      ( $c,
        [
	 'images[]'         => [],
	 'summary_type'     => 'moments',
	 'contacts[]'       => [],
	 'videos[]'         => [],
	 'audio_track'      => undef,
	 'summary_style'    => 'classic',
	 'order'            => 'oldest',
	 'effects[]'        => [],
	 'moment_offsets[]' => [ -3.5, 3.5 ],
	 'target_duration'  => undef,
	 'summary_options'  => {},
	 'album_uuid'       => undef,
	 'title'            => "Summary - " . strftime( '%Y-%m-%d', localtime() ),
	 'description'      => '',
	 'lat'              => undef,
	 'lng'              => undef,
	 'tags[]'           => [],
	 'recording_date'   => DateTime->now()
        ],
        @_ );

    $args->{user_uuid} = $c->user->uuid();

    # Validate that we got passed one or more images.
    unless ( scalar( @{$args->{'images[]'}} ) ) {
	$self->status_bad_request( $c, $c->loc( 'One or more images must be supplied to the images[] parameter.' ) );
    }

    # Validate the summary type was OK.
    my $summary_types = { moments => 1, people => 1 };
    unless ( exists( $summary_types->{$args->{'summary_type'}} ) ) {
	$self->status_bad_request( $c, $c->loc( 'Invalid or missing summary_type argument.' ) );
    }

    # If we're making a people summary, there had best be a contact list.
    if ( $args->{'summary_type'} eq 'people' ) {
	if ( !scalar( @{$args->{'contacts[]'}} ) ) {
	    $self->status_bad_request( $c, $c->loc( 'One or more contacts must be supplied to the contacts[] parameter for summary_type=people' ) );
	}
	if ( !scalar( @{$args->{'videos[]'}} ) ) {
	    $self->status_bad_request( $c, $c->loc( 'One or more videos must be supplied to the videos[] parameter for summary_type=people' ) );
	}
    }

    unless ( defined( $args->{'audio_track'} ) ) {
	# DEBUG - enable this later
	#$self->status_bad_request( $c, $c->loc( 'An audio_track argument must be provided.' ) );

	# DEBUG - For now we just randomly pick a track from a hard
	# coded list.
	my $hard_coded_songs = [
	    'c637ac8a-3b3f-4030-82a0-af423a227457',
	    '2cecfbf0-66de-4947-a168-590ddc1f200f',
	    'd105304f-6fae-4fab-8fc1-bfe1352100d3',
	    'a75cd2de-0c62-4cb3-bc9c-245ecfda0da7',
	    '5406e7f6-ea76-4f60-98d6-092df9a0b637',
	    '1b324c07-945d-434f-926d-cc5095dabcc8',
	    'f4a6501d-7f85-4040-92b5-e97d5a568c27',
	    '11e033aa-464d-48af-979f-d30a359d1ff8',
	    '9ad4e4ff-69a6-448d-ac44-b86cdbfa8d60',
	    '0db07b3c-2cd2-4624-bd6a-43840ded3f4b',
	    '756c6329-662e-46d4-9ea9-1223585c2487',
	    'c6bfc438-fd26-4742-9b89-576132d86c61',
	    'ff48a1f5-59ae-4c1a-be68-d842dc1a884f',
	    '9664ab37-68c8-4e8a-890a-327ec7ec7c5e',
	    '82c7b7f7-272e-48ef-a989-942872b38456',
	    '1d04fc52-93da-4182-8cff-428b27c49f09'
	    ];
	    
	if ( $ENV{'VA_CONFIG_LOCAL_SUFFIX'} eq 'prod' ) {
	    $hard_coded_songs = [
		'e5483c87-3ffc-4eb1-a0ce-8b15e8588de5',
		'1cd76132-f421-48eb-b8cb-9758b9a78a19',
		'8c18da4a-04ee-415f-887b-1319df19319e',
		'dbd2735d-c9c9-47c3-9048-96605b1b0bad',
		'1c918f69-bccf-4b08-baf2-1bba1213f2a0',
		'79dd6b15-6ea9-470d-bdc6-be5a425b10b3',
		'564d7c84-6bd8-43dd-8a22-9308097f852b',
		'401f07a5-d255-4284-b9ac-067a5494d2e9',
		'6578e271-813b-4c1f-82cf-2cca0364550a',
		'44a82bdc-b8cb-4ddc-be7c-51cad60755be',
		'49e4b313-8263-4587-859f-19027f6ddad4',
		'734d156f-2f06-40d0-a19f-8abd15b336c9',
		'e5e6dddb-436b-4d3a-a0fc-c26bb657d771',
		'07d65af3-e365-4d89-a80f-bdd0b232e1d6',
		'13d96521-4d22-42d5-b7cf-8d8208640345',
		'4c16a3bd-a18e-48cf-8c0d-59832f7e31a3'
		];
	}

	my $song_idx = int( rand( scalar( @$hard_coded_songs ) ) );
	$args->{'audio_track'} = $hard_coded_songs->[$song_idx];
    }

    my $orders = { random => 1, oldest => 1, newest => 1 };
    unless ( exists( $orders->{$args->{'order'}} ) ) {
	$self->status_bad_request( $c, $c->loc( 'Invalid order argument provided.' ) );
    }

    unless ( scalar( @{$args->{'moment_offsets[]'}} ) == 2 ) {
	$self->status_bad_request( $c, $c->loc( 'moment_offsets[] must have exactly two parameters' ) );
    }

    # Validate whether the user has permissions to view the associated resources.
    #
    # This is a result set of all the videos that a user owns, or can
    # see through media_shares.
    my $allowed = {};
    my @own_media_share = $c->user->private_and_shared_videos( 0 )->all();
    foreach my $media ( @own_media_share ) {
	$allowed->{$media->id} = 1;
    }
    
    # If a video isn't owned by the user, or directly shared, check if
    # user->can_view_video, which looks in their communities.
    my @assets = $c->model( 'RDS::MediaAsset' )->search( { uuid => { '-in' => $args->{'images[]'} } } )->all();
    my $suspect_media = {};
    foreach my $asset ( @assets ) {
	if ( !exists( $allowed->{$asset->media_id()} ) and !exists( $suspect_media->{$asset->media_id()} ) ){
	    $suspect_media->{$asset->media->uuid()} = 1;
	}
    }
    my $requested = scalar( keys( %$suspect_media ) );
    my @approved = ();
    if ( $requested ) {
	@approved = $c->user->visible_videos( { 'media_uuids[]' => [ keys( %$suspect_media ) ] } );
    }

    if ( scalar( @approved ) != $requested ) {
	$c->log->error( "NOT ALLOWED TO ACCESS SHARED VIDEOS." );
	$self->status_forbidden( $c, $c->loc( 'You do not have permission to view all videos associated with selected images ' ) );
    } else {
	$c->log->debug( "OK TO ACCESS ALL SHARED VIDEOS: ", keys( %$suspect_media ) );
    }

    $c->log->debug( "OK TO ACCESS ALL VIDEOS" );

    my $ug = new Data::UUID;
    my $summary_uuid = $ug->to_string( $ug->create() );

    $args->{summary_uuid} = $summary_uuid;
    $c->log->debug( "Creating database records for media_uuid: ", $summary_uuid );
    my $user = $c->user->obj();
    my $mediafile = $user->find_or_create_related( 'media', {
	uuid => $summary_uuid,
	status => 'pending',
	media_type => 'original',
	filename => "$args->{summary_type}_$args->{summary_style}_$args->{summary_order}",
	title => $args->{title},
	description => $args->{description},
	view_count => 0,
	recording_date => $args->{recording_date},
	lat => $args->{lat},
	lng => $args->{lng},
	is_viblio_created => 1 } );

    $args->{action} = 'create_video_summary';
    my $error = $c->model( 'SQS', $self->send_sqs( $c, 'album_summary', $args ) );
    if ( $error ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the summary.' ) );
    }

    $self->status_ok( $c, { success => 1 } );
}

=head2

services/mediafile/create_fb_album

{
    'images[]' : [ # Array of images the user selected.
        image1_uuid,
        image2_uuid,
        ... ],
    'access_token' : 'sadfkb234lsdfhdsfkjh234' # A current OAuth token
					   # with the requisite
					   # permissions to publish on
					   # behalf of the user.
					  
# Optional parameters:

# Summary metadata:
    'title' : 'Fun Times!', # OPTIONAL: A title for the album -
			    # defaults to "VIBLIO Photo Summary -
			    # YYYY-MM-DD" - I suggest the UI overwrite
			    # this with "VIBLIO FilterName Summary"
    'description' : "Vacation", # OPTIONAL: A description for the
				# album - defaults to nothing.
}

=cut

sub create_fb_album :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [
	 'images[]'         => [],
	 'access_token'     => undef,
	 'title'            => "VIBLIO Photo Summary - " . strftime( '%Y-%m-%d', localtime() ),
	 'description'      => undef
        ],
        @_ );

    # Validate that we got passed one or more images.
    unless ( scalar( @{$args->{'images[]'}} ) ) {
	$self->status_bad_request( $c, $c->loc( 'One or more images must be supplied to the images[] parameter.' ) );
    }

    # If this call returns, then we have a facebook token in $c->session->{fb_token}.
    my $fb_user = $self->validate_facebook_token( $c, $args->{access_token} );
    $args->{fb_token} = $c->session->{fb_token};

    #$c->log->debug( "fb token:" . $args->{fb_token} );

    $args->{user_uuid} = $c->user->uuid();

    # Validate whether the user has permissions to view the associated resources.
    #
    # This is a result set of all the videos that a user owns, or can
    # see through media_shares.
    my $allowed = {};
    my @owned_videos = $c->model( 'RDS::Media' )->search( { user_id => $c->user->id() } )->all();
    foreach my $media ( @owned_videos ) {
	$allowed->{$media->id} = 1;
    }

    # Does the user own the video the image is from?
    my @assets = $c->model( 'RDS::MediaAsset' )->search( { uuid => { '-in' => $args->{'images[]'} } } )->all();
    foreach my $asset ( @assets ) {
	if ( !exists( $allowed->{$asset->media_id()} ) ) {
	    $c->log->error( "CAN'T SEND UNOWNED IMAGES TO FACEBOOK: ", $asset->uuid() );
	    $self->status_forbidden( $c, $c->loc( 'You do not have permission to share this image to Facebook: ' . $asset->uuid() ), $asset->uuid() );
	}
    }
    $c->log->debug( "OK TO ACCESS ALL IMAGES" );

    # Create a new album.
    my $fb_album_id = undef;
    my $fb_album_url = undef;

    my $web_client = HTTP::Tiny->new();
    my $data = {
	access_token => $args->{fb_token},
	name => 'VIBLIO: ' . $args->{title},
    };
    if ( defined( $args->{description} ) ) {
	$data->{description} = $args->{description};
    }
    my $params = $web_client->www_form_urlencode( $data );
    my $url = $c->config->{'facebook_endpoint'} . 'me/albums?' . $params;
    my $response = $web_client->post( $url );
    if ( !$response->{success} ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the Facebook photo album: ' . $response->{reason} ) );
    }
    my $rjson = from_json( $response->{content} );
    unless ( exists( $rjson->{id} ) and length( $rjson->{id} ) ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the Facebook photo album.' ) );
    } else {
	$fb_album_id = $rjson->{id};
    }

    # Get the URL to that album.
    $data = {
	access_token => $args->{fb_token},
    };
    $params = $web_client->www_form_urlencode( $data );
    $url = $c->config->{'facebook_endpoint'} . $fb_album_id . "?" . $params;
    $response = $web_client->get( $url );
    if ( !$response->{success} ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the Facebook photo album: ' . $response->{reason} ) );
    }
    $rjson = from_json( $response->{content} );
    unless ( exists( $rjson->{link} ) and length( $rjson->{link} ) ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the Facebook photo album.' ) );
    } else {
	$fb_album_url = $rjson->{link};
    }

    $args->{fb_album_id} = $fb_album_id;
    $args->{fb_album_url} = $fb_album_url;

    # Send the request to build the album to the back end.
    $args->{action} = 'create_fb_album';
    my $error = $c->model( 'SQS', $self->send_sqs( $c, 'create_fb_album', $args ) );
    if ( $error ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while creating the Facebook photo album.' ) );
    }
    
    $self->status_ok( $c, { success => 1, fb_album_url => $rjson->{link} } );
}


=head2

services/mediafile/find_photos

{
    'media_uuid' : media_uuid,
    'images_per_second : 1,

# Optional parameters:

    'start_time' : 0.5, # Defaults to 0 - Time in seconds to begin finding photos.
    'end_time'   : 13.5, # Defaults to end of video - Time in seconds to end finding photos.
    # Note: Both start and end time can also accept negative values
    # and interpret them as offsets from the end of the video,
    # e.g. photos from the second to last minute of the video can be
    # found with start_time = -120 and end_time = -60.

    'faces_only' : 0, # Default 0, if true then only images with faces will be found.
}

=cut

sub find_photos :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [
	 'media_uuid'       => undef,
	 'images_per_second' => undef,
	 'start_time'       => 0,
	 'end_time'         => undef,
	 'faces_only'       => 0
        ],
        @_ );

    # Validate inputs.
    unless ( defined( $args->{media_uuid} ) ) {
	$self->status_bad_request( $c, $c->loc( 'media_uuid must be specified.' ) );
    }
    unless ( defined( $args->{images_per_second} ) && $args->{images_per_second} > 0 ) {
	$self->status_bad_request( $c, $c->loc( 'images_per_second must be specified as a positive number.' ) );
    }
    my @owned_videos = $c->model( 'RDS::Media' )->search( { user_id => $c->user->id(), uuid => $args->{media_uuid} } )->all();
    unless ( scalar( @owned_videos ) == 1 ) {
	$self->status_not_found( $c, $c->loc( 'No media of that UUID found for this user.' ), $args->{media_uuid} );
    }

    # Send the request to the back end to get photos.
    my $error = $c->model( 'SQS', $self->send_sqs( $c, 'photo_finder', $args ) );
    if ( $error ) {
	$self->status_bad_request( $c, $c->loc( 'An error occurred while invoking the photo finder.' ) );
    }
    
    $self->status_ok( $c, { success => 1 } );
}




__PACKAGE__->meta->make_immutable;

1;

