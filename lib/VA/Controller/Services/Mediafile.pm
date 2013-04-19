package VA::Controller::Services::Mediafile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

=head2 Mediafile

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
          "url" : "http://viblio.filepicker.io.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM_thumbnail.png?Signature=zhODpgAovbcu2gVUI4hmspz2P2g%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
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
          "url" : "http://viblio.filepicker.io.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM_poster.png?Signature=8wPQjM49kHEtTodERkdJ1aoDVZo%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
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
          "url" : "http://viblio.filepicker.io.s3.amazonaws.com:80/7A61E6B4-A851-11E2-9CEA-F0608BC6C0B6_main_Video%20Mar%2026%2C%202%2059%2053%20PM.mov?Signature=AZZKBuGNzpCphOojFKm%2FieBmN4M%3D&Expires=1366313112&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
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
	my $wo = $c->model( 'DB::Workorder' )->find( $wid );
	unless( $wo ) {
	    $self->status_bad_request(
		$c, $c->loc( "Cannot find workorder to attach media file." ));
	}
	$mediafile->add_to_workorders( $wo );
    }

    $self->status_ok( $c, { media => $fp->publish( $c, $mediafile ) } );
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

    my $mf = $c->user->mediafiles->find( $id, { prefetch => 'views' } );
    unless( $mf ) {
	$mf = $c->user->mediafiles->find( { uuid => $id }, 
					  { prefetch => 'views' } );
    }
    unless( $mf ) {
	$self->status_bad_request(
	    $c, $c->loc( "Cannot find media file to delete." ) );
    }

    my $location = $mf->view( 'main' )->location;
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
        ],
        @_ );

    my $where = undef;
    if ( $args->{type} ) {
	$where = { type => $args->{type} };
    }

    if ( $args->{page} ) {
	my $rs = $c->user->mediafiles
	    ->search( $where,
		      { prefetch => 'views',
			page => $args->{page},
			rows => $args->{rows} } );
	my $pager = $rs->pager;
	my @media = ();
	push( @media, VA::MediaFile->new->publish( $c, $_ ) )
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
	push( @media, VA::MediaFile->new->publish( $c, $_ ) )
	    foreach( $c->user->mediafiles->search( $where ) );
	$self->status_ok( $c, { media => \@media } );
    }
}

__PACKAGE__->meta->make_immutable;

1;

