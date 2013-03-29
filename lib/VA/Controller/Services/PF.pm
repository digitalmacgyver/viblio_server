package VA::Controller::Services::PF;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

sub create :Local {
    my( $self, $c ) = @_;

    my $params = $c->req->params;
    $params->{user_id} = $c->user->id;

    my $rw = $params->{isWriteable};
    delete $params->{isWriteable};
    $params->{iswritable} = 1;
    if ( $rw ne 'true' ) {
	$params->{iswritable} = 0;
    }

    my $pffile = $c->model( 'DB::Pffile' )->create({
	filename => $params->{filename},
	mimetype => $params->{mimetype},
	url => $params->{url},
	s3key => $params->{key},
	size => int($params->{size}),
	iswritable => $params->{iswritable},
	user_id => $c->user->obj->id });
    if ( $pffile ) {
	if ( $params->{workorder_id} ) {
	    # being added into a workorder
	    $c->model( 'DB::PffileWorkorder')->create(
		{ workorder_id => $params->{workorder_id},
		  pffile_id => $pffile->id } );
	}
	$self->status_ok( $c, { media => $pffile } );
    }
    else {
	$self->status_bad_request
		( $c,
		  $c->loc( "Unable to create PFFile" ) );
    }
}

sub delete :Local {
    my( $self, $c ) = @_;
    my $id = $c->req->param( 'id' );
    my $media = $c->user->pffiles->find( $id );
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( "Cannot find that media file: id=[_1]", $id ) );
    }
    $media->delete;
    $self->status_ok( $c, { media => $media } );
}

sub list :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );
    if ( $args->{page} ) {
        my $rs = $c->user->pffiles
            ->search( undef,
                      { page => $args->{page},
                        rows => $args->{rows} });
        my $pager = $rs->pager;
        my @media = $rs->all;
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
        my @media = $c->user->pffiles->all;
        $self->status_ok( $c, { media => \@media } );
    }
}

__PACKAGE__->meta->make_immutable;

1;

