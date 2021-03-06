package VA::Controller::Services::WO;
use Moose;
use VA::MediaFile;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

=head2 Workorder

A Workorder structure is used to contain a multimedia project during the lifetime of
creation, submission and completion.  A workorder belongs to a user and contains
one or more mediafiles.  It looks like:

   {
      "submitted" : "2013-04-18 17:57:40",
      "name" : "New Project",
      "user_id" : "1",
      "id" : "10",
      "uuid" : "766D5D4A-A851-11E2-80B0-F0608BC6C0B6",
      "completed" : "2013-04-18 17:58:07",
      "state" : "WO_COMPLETE"
   }

The "state" field is still being worked out.  Possible states and their meanings should
be listed here.

=head2 /services/wo/create

Create a new workorder.  

=head3 Parameters

A workorder "name" is optional, and if not specified, the workorder name is defaulted
to "New Project".

=head3 Response

  { "wo" : $workorder }

=cut

# DEPRECATED
sub create :Local {
    my( $self, $c ) = @_;

    $self->status_bad_request( $c, "services/wo/create is deprecated." );

    my $name = $c->req->param( 'name' ) || 'New Project';
    my $wo = $c->model( 'RDS::Workorder' )->create({name => $name, user_id => $c->user->obj->id});
    unless( $wo ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to create new work order" ) );
    }
    $self->status_ok( $c, { wo => $wo } );
}

=head2 /services/wo/find_or_create

Return an existing, or create a new workorder.  Returns the
workorder and the bom:

  { wo: $workorder, media => [ media_files ] }

=head3 Parameters

A workorder "name" is optional, and if not specified, the workorder name is defaulted
to "New Project".  A desired "state" is optional, and defaults to "WO_PENDING".  

=cut

# DEPRECATED
sub find_or_create :Local {
    my( $self, $c ) = @_;

    $self->status_bad_request( $c, "services/wo/find_or_create is deprecated." );


    my $name = $c->req->param( 'name' ) || 'New Project';
    my $state = $c->req->param( 'state' ) || 'WO_PENDING';
    my $wo = $c->model( 'RDS::Workorder' )->find_or_create({user_id => $c->user->obj->id, state => $state});
    unless( $wo ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find/create new work order" ) );
    }
    my @media = $wo->media->search({},{prefetch=>'assets', order_by => { -desc => 'medias.id' }});
    my @published = ();
    push( @published, VA::MediaFile->new->publish( $c, $_ ) )
	foreach( @media );
    $self->status_ok( $c, { wo => $wo, media => \@published } );
}

=head2 /services/wo/submit

Submit a workorder for processing.

=head3 Parameters

Workorder id or uuid.

=head3 Response

  { "wo" : $workorder }

The "state" field will be one of WO_SUBMITTED or WO_SUBMIT_FAILED.

=cut

# DEPRECATED
sub submit :Local {
    my( $self, $c, $id ) = @_;

    $self->status_bad_request( $c, "services/wo/submit is deprecated." );

    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );
    
    my $wo = $c->user->workorders->find({uuid => $id });

    unless( $wo ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find workorder for id=[_1]", $id ), $id );
    }

    my @media = $wo->media->search({},{prefetch=>'assets'});
    my @published = ();
    foreach my $mf ( @media ) {
	my $pf = VA::MediaFile->new->publish( $c, $mf );
	if ( $pf->{views}->{thumbnail} ) {
	    # don't send thumbnail views, worker will create its own
	    delete $pf->{views}->{thumbnail};
	}
	push( @published, $pf );
    }

    # Add the viblio site security token.  This will be checked
    # on an incoming completed workorder to make sure it originated
    # here, by a valid user.
    my $woJSON = $wo->TO_JSON;
    $woJSON->{'site-token'} = $c->secure_token( $wo->user->uuid );

    # Send the workorder to the queue
    my $res = $c->model( 'FD' )->post( '/workorder', { wo => $woJSON, media => \@published } );
    $c->log->debug( "Workorder sent, response code is " . $res->code );
    $c->log->debug( "Workorder sent, data is:" );
    $c->logdump( $res->data );

    if ( $res->code == 200 ) {
	$wo->state( 'WO_SUBMITTED' );
    }
    else {
	$wo->state( 'WO_SUBMIT_FAILED' );
    }

    $wo->update;

    $self->status_ok( $c, { wo => $wo } );
}

=head2 /services/wo/bom

Return the "bill of materials" for a workorder.

=head3 Parameters

Workorder id or uuid

=head3 Response

  { "wo" : $workorder, 
    "media": [ $list-of-mediafiles ]
  }

=cut

# DEPRECATED
sub bom :Local {
    my( $self, $c, $id ) = @_;

    $self->status_bad_request( $c, "services/wo/bom is deprecated." );

    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );

    my $wo = $c->user->workorders->find({uuid => $id });

    unless( $wo ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find workorder for id=[_1]", $id ), $id );
    }

    my @media = $wo->media->search({},{prefetch=>'assets', order_by => { -desc => 'medias.id' }});
    my @published = ();
    push( @published, VA::MediaFile->new->publish( $c, $_ ) )
	foreach( @media );
    $self->status_ok( $c, { wo => $wo, media => \@published } );
}

=head2 /services/wo/list

Return a list of workorders belonging to the logged in user.  Supports
optional paging.  With no parameters, returns all workorders owned by
the user.  With paging parameters, returns paged results and a pager.

=head3 Parameters

=over

=item page (optional)

The page number to fetch items from.  The number of items per page
is specified by the 'rows' parameter.

=item rows (optional, defaults to 10)

Ignored unless 'page' is specified.  Specifies number of items per page.
This number of items (or less) will be delivered back to the client.

=back

=head3 Response

Without paging:

  { "workorders" : [ $list-of-workorders ] }

With paging:

  { "workorders" : [ $list-of-workorders ],
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

# DEPRECATED
sub list :Local {
    my $self = shift; my $c = shift;

    $self->status_bad_request( $c, "services/wo/list is deprecated." );

    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );

    if ( $args->{page} ) {
	my $rs = $c->user->workorders
	    ->search( undef,
		      { page => $args->{page},
			rows => $args->{rows} } );
	my $pager = $rs->pager;
	my @wos = $rs->all;

	$self->status_ok(
	    $c,
	    { workorders => \@wos,
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
	my @wos = $c->user->workorders->all;
	$self->status_ok( $c, { workorders => \@wos } );
    }
}

=head2 /services/wo/highlight

Return the mediafile representing the highlight reel.  If there is no highlight
reel, returns the first mediafile it can find.

=head3 Parameters

Workorder id or uuid.

=head3 Response

  { "media" : $mediafile }

=cut

# DEPRECATED
sub highlight :Local {
    my( $self, $c, $id ) = @_;

    $self->status_bad_request( $c, "services/wo/highlight is deprecated." );

    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );
    
    my $wo = $c->user->workorders->find({uuid => $id });

    unless( $wo ) {
	$self->status_not_found
	    ( $c, $c->loc( "Failed to find workorder for id=[_1]", $id ), $id );
    }

    my $mf = $wo->media->find({ media_type => 'highlight' });

    # If there isnt a highlight reel, then return the first media file
    if ( ! $mf ) {
	$mf = $wo->mediafiles->first;
    }

    if ( $mf ) {
	my $view = VA::MediaFile->new->publish( $c, $mf );
	$self->status_ok( $c, { media => $view } );
    }
    else {
	$self->status_ok( $c, { media => {} } );
    }
}

__PACKAGE__->meta->make_immutable;

1;

