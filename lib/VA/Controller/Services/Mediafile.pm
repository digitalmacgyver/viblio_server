package VA::Controller::Services::Mediafile;
use Moose;
use namespace::autoclean;

use JSON;
use URI::Escape;

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
    # Delete from database
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
	  type => undef,
	  include_contact_info => 0,
        ],
        @_ );

    my $where = undef;
    if ( $args->{type} ) {
	$where = { type => $args->{type} };
    }

    if ( $args->{page} ) {
	my $rs = $c->user->media
	    ->search( $where,
		      { prefetch => 'assets',
			order_by => { -desc => 'me.id' },
			page => $args->{page},
			rows => $args->{rows} } );
	my $pager = $rs->pager;
	my @media = ();
	push( @media, VA::MediaFile->new->publish( $c, $_, { include_contact_info => $args->{include_contact_info} } ) )
	    foreach( $rs->all );
	$self->status_ok(
	    $c,
	    { media => \@media,
	      pager => {
		  total_entries => $pager->total_entries,
		  entries_per_page => $pager->entries_per_page,
		  current_page => $pager->current_page,
		  entries_on_this_page => $pager->entries_on_this_page,
		  first_page => $pager->first_page,
		  last_page => $pager->last_page,
		  first => $pager->first,
		  'last' => $pager->last,
		  previous_page => $pager->previous_page,
		  next_page => $pager->next_page,
	      }
	    } );
    }
    else {
	my @media = ();
	push( @media, VA::MediaFile->new->publish( $c, $_, { include_contact_info => $args->{include_contact_info} } ) )
	    foreach( $c->user->media->search( $where, {prefetch=>'assets', order_by => { -desc => 'me.id' }} ) );
	$self->status_ok( $c, { media => \@media } );
    }
}

sub get :Local {
    my( $self, $c, $mid, $include_contact_info ) = @_;
    $mid = $c->req->param( 'mid' ) unless( $mid );
    $include_contact_info = $c->req->param( 'include_contact_info' ) unless( $include_contact_info );
    $include_contact_info = 0 unless( $include_contact_info );

    my $mf = $c->user->media->find({uuid=>$mid},{prefetch=>'assets'});

    unless( $mf ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
    }

    my $view = VA::MediaFile->new->publish( $c, $mf, { include_contact_info => $include_contact_info } );
    $self->status_ok( $c, { media => $view } );
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
    my $mid = $c->req->param( 'mid' );
    unless( $mid ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", "mid" ) );
    }
    my $mf = $c->model( 'RDS::Media' )->find({uuid=>$mid});
    unless( $mf ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
    }
    my @comments = $mf->comments->search({},{prefetch=>'user', order_by=>'me.created_date desc'});
    my @data = ();
    foreach my $comment ( @comments ) {
	my $hash = $comment->TO_JSON;
	if ( $comment->user_id ) {
	    $hash->{who} = $comment->user->displayname;
	}
	push( @data, $hash );
    }
    $self->status_ok( $c, { comments => \@data } );
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
    my $list = $c->req->param( 'list' );
    my $subject = $c->req->param( 'subject' );
    my $body = $c->req->param( 'body' );
    my $disposition = $c->req->param( 'private' );
    $disposition = 'private' unless( $disposition );

    my $media = $c->user->media->find({ uuid => $mid });
    unless( $media ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find mediafile for uuid=[_1]", $mid ) );
    }
    
    if ( $list ) {
	my @list = split( /[ ,]+/, $list );
	my @clean = map { $_ =~ s/^\s+//g; $_ =~ s/\s+$//g; $_ } @list;
	my $addrs = {};
	foreach my $email ( @clean ) {
	    my $share;
	    my $recip = $c->model( 'RDS::User' )->find({ email => $email });
	    if ( $disposition eq 'private' ) {
		# This is a private share to another viblio user
		if ( $recip ) {
		    # The target user already exists
		    $share = $media->find_or_create_related( 'media_shares', { 
			view_count => 0,
			user_id => $recip->id,
			share_type => 'private' } );
		    unless( $share ) {
			$self->status_bad_request
			    ( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
		    }
		    $addrs->{$email} = $c->server . '#/web_player?mid=' . $media->uuid;
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
			view_count => 0,
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
		    # my $url = URI->new( $c->server . '#/register' );
		    # $url->query_form( email => $email, url => '#/web_player?mid=' . $media->uuid );
		    my $url = $c->server . '#/register?email=' .
			uri_escape( $email ) . '&url=' .
			uri_escape( '#/web_player?mid=' . $media->uuid );
		    $addrs->{$email} = $url;
 		}

		# Add to user's contact list
		my $contact = $c->user->obj->find_or_create_related( 'contacts', { contact_email => $email, contact_name => $email } );
		unless( $contact ) {
		    $c->log->error( "Failed to create a contact out of a shared email address!" );
		}
	    }
	    else {
		# This is a hidden share, emailed to someone but technically viewable
		# by anyone with the link
		$share = $media->find_or_create_related( 'media_shares', { share_type => 'hidden', view_count => 0 } );
		unless( $share ) {
		    $self->status_bad_request
			( $c, $c->loc( "Failed to create a share for for uuid=[_1]", $mid ) );
		}
		$addrs->{$email} = $c->server . '#/web_player?mid=' . $media->uuid;
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
		}
	    };
	    $c->stash->{no_wrapper} = 1;
	    $c->stash->{body} = $body;
	    $c->stash->{media} = VA::MediaFile->new->publish( $c, $media, { expires => (60*60*24*365) } );
	    $c->stash->{from} = $c->user;
	    $c->stash->{url} = $addrs->{$addr};

	    $email->{html} = $c->view( 'HTML' )->render( $c, 'email/share.tt' );
	    my $res = $c->model( 'Mandrill' )->send( $email );
	    if ( $res && $res->{status} && $res->{status} eq 'error' ) {
		$c->log->error( "Error using Mailchimp to send" );
		$c->logdump( $res );
		$c->logdump( $email );
	    }
	}
    }
    else {
	my $share = $media->find_or_create_related( 'media_shares', { share_type => 'public', view_count => 0 } );
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
    if ( $uid ) {
	my $user = $c->model( 'RDS::User' )->find({uuid => $uid });
	if ( $user ) {
	    $count = $user->media->count;
	}
    }
    else {
	$count = $c->user->media->count;
    }
    $self->status_ok( $c, { count => $count } );
}

__PACKAGE__->meta->make_immutable;

1;

