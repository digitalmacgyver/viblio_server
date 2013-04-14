package VA::Controller::Services::Mediafile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

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

=item page (optional)

The page number to fetch items from.  The number of items per page
is specified by the 'rows' parameter.

=item rows (optional, defaults to 10)

Ignored unless 'page' is specified.  Specifies number of items per page.
This number of items (or less) will be delivered back to the client.

This is another description

=back

=head3 Example Response

Without paging:

  {
     "media" : [
        {
           "filename" : "facebook-connect2.png",
           "user_id" : "3",
           "path" : "/home/peebles/viblio-server/uploads/3/2CC7C252-93FC-11E2-83AF-729329C23E77",
           "id" : "1",
           "uuid" : "2CC7C252-93FC-11E2-83AF-729329C23E77",
           "mimetype" : "image/png",
           "size" : "130119"
        },
        {
           "filename" : "facebook-connect2.png",
           "user_id" : "3",
           "path" : "/home/peebles/viblio-server/uploads/3/9E8291F6-93FC-11E2-9E7D-7A9329C23E77",
           "id" : "2",
           "uuid" : "9E8291F6-93FC-11E2-9E7D-7A9329C23E77",
           "mimetype" : "image/png",
           "size" : "130119"
        }
     ]
  }

With paging:

  {
     "media" : [
        {
           "filename" : "facebook-connect2.png",
           "user_id" : "3",
           "path" : "/home/peebles/viblio-server/uploads/3/2CC7C252-93FC-11E2-83AF-729329C23E77",
           "id" : "1",
           "uuid" : "2CC7C252-93FC-11E2-83AF-729329C23E77",
           "mimetype" : "image/png",
           "size" : "130119"
        },
        {
           "filename" : "facebook-connect2.png",
           "user_id" : "3",
           "path" : "/home/peebles/viblio-server/uploads/3/9E8291F6-93FC-11E2-9E7D-7A9329C23E77",
           "id" : "2",
           "uuid" : "9E8291F6-93FC-11E2-9E7D-7A9329C23E77",
           "mimetype" : "image/png",
           "size" : "130119"
        }
     ],
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
        ],
        @_ );

    if ( $args->{page} ) {
	my $rs = $c->user->mediafiles
	    ->search( undef,
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
	    foreach( $c->user->mediafiles->all );
	$self->status_ok( $c, { media => \@media } );
    }
}

__PACKAGE__->meta->make_immutable;

1;

