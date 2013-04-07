package VA::Controller::Services::Mediafile;
use Moose;
use Module::Find;
usesub VA::MediaFile;
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
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
	$self->status_bad_request(
	    $c, $c->loc( "Cannot determine type of this media file" ));
    }
    my $fp = new $klass;

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
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
	$self->status_bad_request(
	    $c, $c->loc( "Cannot determine type of this media file" ));
    }
    my $fp = new $klass;
    # Delete from filepicker servers
    my $res = $fp->delete( $c, $mf );
    # Delete from database
    $mf->delete;
    $self->status_ok( $c, {} );
}

sub list :Local {
    my( $self, $c ) = @_;
    $c->forward( '/services/user/media' );
}

__PACKAGE__->meta->make_immutable;

1;

