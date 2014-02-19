package VA::Controller::Services::Mediafile;
use Moose;
use namespace::autoclean;

use JSON;
use URI::Escape;
use DateTime::Format::Flexible;

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
tag passed back from the permenent storage server that holds the actual file.  Media file
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

sub create :Local {
    my( $self, $c, $wid ) = @_;
    $wid = $c->req->param( 'workorder_id' ) unless( $wid );
    $wid = 0 unless( $wid );

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
with server-side generated credencials.  

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

Delete a mediafile.  Deletes the file in permenant storage as well.

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
	$self->status_bad_request(
	    $c, $c->loc( "Cannot find media file to delete." ) );
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

    # Leverage the publish routine to obtain faces for
    # this mediafile.
    my $mediafile = VA::MediaFile->new->publish( $c, $mf, { assets => [], include_contact_info => 1 } );
    my @faces = @{$mediafile->{views}->{face}};

    # Generic resultset for finding other mediafiles (other than this one)
    my $rs = $c->model( 'RDS::MediaAssetFeature' )->search({
	'media.id' => { '!=', $mf->id } }, {
	    prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );

    foreach my $face ( @faces ) {
	$c->log->debug( "Face: name: " . $face->{contact}->{contact_name} . ", uuid: " . $face->{contact}->{uuid} );
	if ( ! $face->{contact}->{contact_name} ) {
	    # unidentified
	    $c->log->debug( "  unidentified" );
	    # Other mediafiles with this contact
	    my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	    $c->log->debug( "  -> in $count other videos" );
	    if ( $count == 0 ) {
		# No others, so delete the contact
		my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		if ( $contact ) {
		    $c->log->debug( "  -> DELETE " . $face->{contact}->{uuid} );
		    $contact->delete; $contact->update;
		}
	    }
	}
	else {
	    # identified
	    $c->log->debug( "  identified" );
	    # Other mediafiles with this contact
	    my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	    $c->log->debug( "  -> in $count other videos" );
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
		    $c->log->debug( "  -> PRESERVE picture_uri" );
		}
		else {
		    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		    if ( $contact ) {
			# There is a picture_uri, and it points to an asset about to be
			# deleted, and there are no other videos to which to point to,
			# so unset the picture_uri.
			$c->log->debug( "  -> UNSET picture_uri " . $face->{contact}->{uuid} );
			$contact->picture_uri( undef ); $contact->update;
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
		    $c->log->debug( "  -> PRESERVE picture_uri" );
		}
		else {
		    # The picture_uri needs to be changed.
		    $c->log->debug( "  -> SWITCH picture_uri" );
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
    $self->status_ok( $c, {} );
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
        [ page => undef,
          rows => 10,
	  include_contact_info => 0,
	  'views[]' => undef
        ],
        @_ );

    my $params = {
	include_contact_info => $args->{include_contact_info},
	views => $args->{'views[]'}
    };

    my $rs = $c->user->media->search(
	$self->where_valid_mediafile(),
	{ prefetch => 'assets',
	  order_by => { -desc => 'me.id' } } );

    if ( $args->{page} ) {
	my $rss = $rs->search({},{ page => $args->{page}, rows => $args->{rows}});
	my $pager = $rss->pager;
	my @media = ();
	push( @media, VA::MediaFile->new->publish( $c, $_, $params ) )
	    foreach( $rss->all );
	$self->status_ok(
	    $c,
	    { media => \@media,
	      pager => $self->pagerToJson( $pager ),
	    } );
    }
    else {
	my @media = ();
	push( @media, VA::MediaFile->new->publish( $c, $_, $params ) )
	    foreach( $rs->all );
	$self->status_ok( $c, { media => \@media } );
    }
}

sub popular :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => 1,
          rows => 10000,
	  'views[]' => undef
        ],
        @_ );
    
    my $where = $self->where_valid_mediafile();
    $where->{ 'me.view_count' } = { '!=', 0 };
    my $rs = $c->user->media->search( $where, 
				      { prefetch => 'assets',
					page => $args->{page},
					rows => $args->{rows},
					order_by => { -desc => 'me.view_count' } });
    my @media;
    push( @media, VA::MediaFile->new->publish( $c, $_, { views => $args->{'views[]'} } ) )
	foreach( $rs->all );
    my $pager = $self->pagerToJson( $rs->pager );
    $self->status_ok( $c, { media => \@media, pager => $pager } );
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

    my $params = {
	include_contact_info => $include_contact_info,
    };
    if ( $c->req->param( 'views[]' ) ) {
	my @views = $c->req->param( 'views[]' );
	$params->{views} = \@views;
    }

    my $mf = $c->user->media->find({uuid=>$mid},{prefetch=>['assets','user']});

    unless( $mf ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
    }

    my $view = VA::MediaFile->new->publish( $c, $mf, $params );
    $self->status_ok( $c, { media => $view, owner => $mf->user->TO_JSON } );
}

sub get_metadata :Local {
    my( $self, $c, $mid ) = @_;
    $mid = $c->req->param( 'mid' ) unless( $mid );

    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }

    my $mf = $c->user->media->find({uuid=>$mid});

    unless( $mf ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
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
    my $title = $c->req->param( 'title' );
    my $description = $c->req->param( 'description' );
    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }
    my $mf = $c->user->media->find({uuid=>$mid});
    unless( $mf ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
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

sub sanitize :Private {
    my( $self, $c, $txt ) = @_;


    # Finally, comments can only be 2048 chars in length
    if ( length( $txt ) > 2048 ) {
	$txt = substr( $txt, 0, 2047 );
    }
    return $txt;
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
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
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

    $self->status_ok( $c, { comment => $hash } );

    #################################################################################

    # Send emails and notifications (but not to myself!)

    # Who should get email/notofications?  The owner of the video being commented on,
    # and everybody who has been shared this video.  The logged in user
    # making the comment should never get an email.

    my $published_mf = VA::MediaFile->new->publish( $c, $mf, { views => ['poster'] } );
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
		template => 'email/commentsOnYourVid.tt',
		stash => {
		    from => $c->user->obj,
		    commentText => $comment->comment,
		    model => {
			media => [ $published_mf ] 
		    }
		} });
	}
    }

    # Now see if the mediafile has private shares, and send email to those
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
comma delimitted list of email addresses.  If an email address belongs to a viblio user,
a private share is created, otherwise a hidden share.  Email is sent to each address
on the list.  The url to the video is different depending on private or hidden.

If a list is passed, every email address on that list is added to the user's
contact list unless it is already present.

=cut

sub add_share :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my @list = $c->req->param( 'list[]' );
    my $subject = $c->req->param( 'subject' );
    my $body = $c->req->param( 'body' );
    my $disposition = $c->req->param( 'private' );
    $disposition = 'private' unless( $disposition );

    my $media = $c->user->media->find({ uuid => $mid });
    unless( $media ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
    }
    
    if ( $#list >=0 ) {
	my $addrs = {};
	my @clean = $self->expand_email_list( $c, \@list );
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
		subject => $subject || $c->loc( "Check out this video on viblio.com" ),
		from_email => 'reply@' . $c->config->{viblio_return_email_domain},
		from_name => 'Viblio',
		to => [{
		    email => $addr }],
		headers => {
		    'Reply-To' => 'reply@' . $c->config->{viblio_return_email_domain},
		},
		inline_css => 1,
	    };
	    $c->stash->{no_wrapper} = 1;
	    $c->stash->{body} = $body;
	    $c->stash->{from} = $c->user;
	    $c->stash->{url} = $addrs->{$addr}->{url};

	    $c->stash->{model} = {
		media => [ VA::MediaFile->new->publish( $c, $media, { expires => (60*60*24*365) } ) ],
		vars => {
		    shareType => $addrs->{$addr}->{type},
		}
	    };

	    $email->{html} = $c->view( 'HTML' )->render( $c, 'email/videosSharedWithYou.tt' );
	    my $res = $c->model( 'Mandrill' )->send( $email );
	    if ( $res && $res->{status} && $res->{status} eq 'error' ) {
		$c->log->error( "Error using Mailchimp to send" );
		$c->logdump( $res );
		$c->logdump( $email );
	    }
	}
    }
    elsif ( $disposition eq 'potential' ) {
	# This is a potential share.  A potencial share is created in any context
	# where we don't otherwise know that the share will ever actually be used.
	# Currently this is the case for cut-n-paste or copy-to-clipboard link
	# displayed in the shareVidModal in the web gui.  We don't know if the user
	# will actually c-n-p or c-t-c, and if they do, we don't know if they 
	# actually utilize the information.  So we create a potencial share, which
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
    }

    $self->status_ok( $c, {} );
}

=head2 /services/mediafile/count

Simply return the total number of mediafiles owned by the logged in user.

=cut

sub count :Local {
    my( $self, $c ) = @_;
    my $uid = $c->req->param( 'uid' );
    my $count = 0;

    my $where = $self->where_valid_mediafile();

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
	    my @shares = $user->media_shares->search( {},{prefetch=>{ media => 'user'}} );
	    my @media_ids = map { $_->media->id } @shares;
	    my @feats = $c->model( 'RDS::MediaAssetFeature' )
		->search({ 'me.contact_id' => $contact->id,
			   'me.feature_type' => 'face',
			   'media.id', { '-in', \@media_ids } },
			 { prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] });
	    @media = map { $_->media_asset->media } @feats;
	}
    }
    else {
	my @shares = $user->media_shares->search( {},{prefetch=>{ media => 'user'}} );
	@media = map { $_->media } @shares;
    }
    
    # partition this into an array of users, each with an array of videos they've
    # shared with you.

    my $users = {};
    foreach my $media ( @media ) {
	my $owner = $media->user->displayname;
	if ( ! defined( $users->{ $owner } ) ) {
	    $users->{ $owner } = [];
	}
	push( @{$users->{ $owner }}, $media );
    }
    my @sorted_user_keys = sort{ lc( $a ) cmp lc( $b ) } keys( %$users );
    my @data = ();
    foreach my $key ( @sorted_user_keys ) {
	my @media = map { VA::MediaFile->publish( $c, $_, { views => ['poster' ] } ) } sort{ $b->created_date->epoch <=> $a->created_date->epoch } @{$users->{ $key }};

	# iOS app wants to sort based on shared on date ...
	my @mids = map { $_->id } sort{ $b->created_date->epoch <=> $a->created_date->epoch } @{$users->{ $key }};
	for( my $i=0; $i<=$#media; $i++ ) {
	    my $share = $c->model( 'RDS::MediaShare' )->find({ media_id => $mids[$i],
							       user_id  => $c->user->obj->id });
	    # force the date to be formatted like other dates
	    my $s = { %{$share->{_column_data}} };
	    $media[$i]->{shared_date} = $s->{created_date};
	}

	push( @data, {
	    owner => $users->{ $key }[0]->user->TO_JSON,
	    media => \@media
	      });
    }
    
    $self->status_ok( $c, { shared => \@data } );
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
    my $rs = $c->model( 'RDS::MediaAsset' )->search(
	{ 'media.uuid' => $mid,
	  'me.asset_type' => 'main',
	  -or => [ 'media.user_id' => $c->user->id,
		   'media_shares.user_id' => $c->user->id ] },
	{ prefetch => {'media' => 'media_shares' } });
    my $asset = $rs->first;
    unless( $asset ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find main asset for media [_1]', $mid ) );
    }
    $self->status_ok( $c, { 
	url    => VA::MediaFile::US->new->uri2url( $c, $asset->uri ),
	cf_url => $c->cf_sign( $asset->uri, {stream=>1} ) } );
}
    

=head2 /services/mediafile/related

Return list of mediafiles related to the passed in mediafile.  You can specify
one or more of:

  by_date=1    : All videos taken on same day followed by all videos 
                 taken in same month as this video
  by_faces=1   : All videos that contain at least one of the faces contained
                 in this video
  by_geo=1     : All videos taken "near" this video (see below)

If more than one by_ is specified, the array returned is in the order shown
above (date, faces, geo).

If by_geo is specified, geo_unit=meter, geo_distance=100 are the defaults used
to determine "near" and the results are returned sorted from closest to furthest.
Legal values for geo_unit are: kilometer, kilometre, meter, metre, centimeter, 
centimetre, millimeter, millimetre, yard, foot, inch, light second, mile, nautical mile, 
poppy seed, barleycorn, rod, pole, perch, chain, furlong, league, fathom.

=cut

sub related :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );

    my $page = $c->req->param( 'page' );
    my $rows = $c->req->param( 'rows' ) || 10;

    my $by_date  = $self->boolean( $c->req->param( 'by_date'  ), 1 );
    my $by_faces = $self->boolean( $c->req->param( 'by_faces' ), 1 );
    my $by_geo   = $self->boolean( $c->req->param( 'by_geo'   ), 1 );

    my $geo_unit = $c->req->param( 'geo_unit' ) || 'meter';
    my $geo_distance = $c->req->param( 'geo_distance' ) || '100';

    unless( $mid ) {
	$self->status_bad_request( $c, $c->loc( 'Missing param [_1]', 'mid' ) );
    }
    my $user = $c->user->obj;

    # The passed in uuid might be from a shared video
    #
    my $media = $c->model( 'RDS::Media' )->find({ 
	'me.uuid' => $mid,
	'me.is_album' => 0,
	-and => [ -or => ['me.user_id' => $user->id, 
			  'media_shares.user_id' => $user->id], 
		  -or => [status => 'TranscodeComplete',
			  status => 'FaceDetectComplete',
			  status => 'FaceRecognizeComplete',
			  status => 'visible',
			  status => 'complete' ]
	    ]}, {prefetch=>'media_shares'});
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find mediafile for [_1]', $mid ) );
    }

    # Array of mediafile objects to return
    my @results = ();
    # Hash of media uuid's already added to results (to prevent dups in results)
    my $seen = {};
    $seen->{ $media->uuid } = $media; # DO NOT SHOW MYSELF IN RELATED

    # First get a mediafile resultset that contains all media belonging to
    # the user or shared to the user.
    #
    # Fetch by MediaAsset of poster, because all related videos needs
    # is the mediafile and its poster.  Prefetch media and media_shares;
    # media_shares so we get user's media plus all media shared with them,
    # media so publish is fast.  Group by media.id so we get only only
    # unique mediafiles in case there are multiple posters per mediafile.
    #
    # This prefetch into a resultset makes subsequent search queries
    # easier.
    #
    my $rs = $c->model( 'RDS::MediaAsset' )->search({ 
	'me.asset_type' => 'poster',
	'media.is_album' => 0,
	-and => [ -or => ['media.user_id' => $user->id, 
			  'media_shares.user_id' => $user->id], 
		  -or => ['media.status' => 'TranscodeComplete',
			  'media.status' => 'FaceDetectComplete',
			  'media.status' => 'FaceRecognizeComplete',
			  'media.status' => 'visible',
			  'media.status' => 'complete' ]
	    ]}, {prefetch=>{'media' => 'media_shares'}, group_by=>['media.id']});

    # Return:
    #
    # 1. All other videos taken on same date as this video (within 24 hours)
    # 2. All other videos taken in same month as this video
    # 3. All other videos that contain at least one of the known faces in this video taken this year
    # 3. All other videos that contain at least one of the known faces in this video ever taken
    # 4. All other videos taken "at same location as" this video
    #
    if ( $by_date ) {
	my $taken_on = $media->recording_date || $media->created_date;
	my $dtf = $c->model( 'RDS' )->schema->storage->datetime_parser;

	# Taken on same day
	my $from = DateTime->new( year => $taken_on->year,
				  month => $taken_on->month,
				  day => $taken_on->day,
				  hour => 0, minute => 0 );
	my $to   = DateTime->new( year => $taken_on->year,
				  month => $taken_on->month,
				  day => $taken_on->day,
				  hour => 23, minute => 59 );

	my @taken_on_same_day = $rs->search({
	    'media.recording_date' => {
		-between => [
		     $dtf->format_datetime( $from ),
		     $dtf->format_datetime( $to )
		    ]} }, { order_by => 'media.recording_date desc' } );
	foreach my $a ( @taken_on_same_day ) {
	    push( @results, $a ) unless( $seen->{ $a->media->uuid } );
	    $seen->{ $a->media->uuid } = $a;
	}

	# Taken in same month
	$from = DateTime->new( year => $taken_on->year,
			       month => $taken_on->month,
			       day => 1, hour => 0, minute => 0 );
	$to = $from->clone;
	$to->add( months => 1 )->subtract( days => 1 )->add( hours => 23 )->add( minutes => 59 );

	my @taken_in_same_month = $rs->search({
	    'media.recording_date' => {
		-between => [
		     $dtf->format_datetime( $from ),
		     $dtf->format_datetime( $to )
		    ]} }, { order_by => 'media.recording_date desc' } );
	foreach my $a ( @taken_in_same_month ) {
	    push( @results, $a ) unless( $seen->{ $a->media->uuid } );
	    $seen->{ $a->media->uuid } = $a;
	}
    }

    if ( $by_faces ) {
	# FACES...
	#
	# First of all, find all known faces in the passed in mediafile
	#
	my @face_features = $c->model( 'RDS::MediaAssetFeature' )
	    ->search({ 'me.media_id' => $media->id,
		       'me.feature_type' => 'face',
		       'contact.contact_name' => { '!=', undef } },
		     { prefetch=>['contact','media_asset'], group_by=>['contact.id'] });

	if ( $#face_features >= 0 ) {
	    # There are faces.  Lets find all other videos in our list that contain at
	    # least on of these faces, ordered by most recently recorded.
	    #
	    my @contact_ids = map { $_->contact->id } @face_features;
	    my @media_ids   = map { $_->media->id } $rs->all;

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
		    push( @results, $feat->media_asset->media->assets->find({ asset_type => 'poster' }) );
		    $seen->{ $feat->media_asset->media->uuid } = $feat->media_asset->media;
		}
	    }
	}
    }

    if ( $by_geo && defined( $media->lat ) && defined( $media->lng ) ) {

	my $geo = new Geo::Distance;
	$geo->formula('hsin');

	my @geodata = ();
	foreach my $asset ( $rs->search({ 'media.lat' => {'!=' => undef}, 'media.lng' => { '!=' => undef } }) ) {
	    next if ( $asset->media->id == $media->id );
	    my $distance = $geo->distance( $geo_unit, $media->lng, $media->lat => $asset->media->lng, $asset->media->lat );
	    push( @geodata, { distance => $distance, asset => $asset } ) if ( $distance <= $geo_distance );
	}
	my @sorted = sort { $a->{distance} <=> $b->{distance} } @geodata;
	foreach my $sd ( @sorted ) {
	    push( @results, $sd->{asset} ) unless( defined( $seen->{ $sd->{asset}->media->uuid } ) );
	    $seen->{ $sd->{asset}->media->uuid } = $sd->{asset}->media;
	}
    }

    # Prepare and return results
    #
    my @data  = ();
    my $pager = {};
    if ( $page ) {
	my $data_pager = Data::Page->new( $#results + 1, $rows, $page );
	if ( $#results >= 0 ) {
	    @data = @results[ $data_pager->first - 1 .. $data_pager->last - 1 ];
	}
	$pager = $self->pagerToJson( $data_pager );
    }
    else {
	@data = @results;
    }

    my @media = ();
    #
    # This form of publish, where we pass the mediafile and assets in an array is
    # much faster, since the assets do not need to be fetched.  We can do this if
    # we know the assets already, and are sure we know how the media file will be
    # consumed on the client.
    # $_->media->assets->find({ asset_type=>'main'})
    push( @media, VA::MediaFile->new->publish( $c, $_->media, { assets => [$_] } ) ) foreach( @data );
    $self->status_ok( $c, { media => \@media, pager => $pager } );
}

sub change_recording_date :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $dstring = $c->req->param( 'date' );
    my $media = $c->user->media->find({uuid => $mid });
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
    }
    $media->recording_date( DateTime::Format::Flexible->parse_datetime( $dstring ) );
    $media->update;
    $self->status_ok( $c, { date => $media->recording_date } );
}

sub get_animated_gif :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
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

# Pass in a MD5 checksum, see if a mediafile exists with that hash
sub media_exists :Local {
    my( $self, $c ) = @_;
    my $hash = $c->req->param( 'hash' );
    my $count = $c->user->media->count({
	unique_hash => $hash });
    $self->status_ok( $c, { count => $count } );
}

# see if a particular mediafile has ever been shared by the user
sub has_been_shared :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my @shared = $c->model( 'RDS::MediaShare' )->search(
	{ 'media.uuid' => $mid, 'me.user_id' => $c->user->obj->id },
	{ prefetch => 'media' });
    $self->status_ok( $c, { count => ( $#shared + 1 ) } );
}

__PACKAGE__->meta->make_immutable;

1;

