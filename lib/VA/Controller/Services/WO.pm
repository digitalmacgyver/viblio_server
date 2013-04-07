package VA::Controller::Services::WO;
use Moose;
use VA::MediaFile;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

sub create :Local {
    my( $self, $c ) = @_;
    my $name = $c->req->param( 'name' ) || 'New Project';
    my $wo = $c->model( 'DB::Workorder' )->create({name => $name, user_id => $c->user->obj->id});
    unless( $wo ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to create new work order" ) );
    }
    $self->status_ok( $c, { wo => $wo } );
}

sub submit :Local {
    my( $self, $c, $id ) = @_;
    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );
    
    my $wo = $c->user->workorders->find( $id );
    unless( $wo ) {
	$wo = $c->user->workorders->find({uuid => $id });
    }
    unless( $wo ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find workorder for id=[_1]", $id ) );
    }

    my @media = $wo->mediafiles->search({},{prefetch=>'views'});
    my @published = ();
    push( @published, VA::MediaFile->new->publish( $c, $_ ) )
	foreach( @media );

    # Send the workorder to the queue
    my $res = $c->model( 'FD' )->post( '/workorder', { wo => $wo->TO_JSON, media => \@published } );
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

sub bom :Local {
    my( $self, $c, $id ) = @_;

    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );

    my $wo = $c->user->workorders->find( $id );
    unless( $wo ) {
	$wo = $c->user->workorders->find({uuid => $id });
    }
    unless( $wo ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Failed to find workorder for id=[_1]", $id ) );
    }

    my @media = $wo->mediafiles->search({},{prefetch=>'views'});
    my @published = ();
    push( @published, VA::MediaFile->new->publish( $c, $_ ) )
	foreach( @media );
    $self->status_ok( $c, { wo => $wo, media => \@published } );
}

__PACKAGE__->meta->make_immutable;

1;

