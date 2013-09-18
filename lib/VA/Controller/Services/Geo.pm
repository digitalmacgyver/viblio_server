package VA::Controller::Services::Geo;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
BEGIN { extends 'VA::Controller::Services' }

sub valid :Private {
    my( $self, $lat, $lng ) = @_;
    return( undef, undef ) if ( !defined( $lat ) || !defined( $lng ) );
    return( undef, undef ) if ( $lat==0 && $lng==0 );
    return( $lat, $lng );
}

sub all :Local {
    my( $self, $c ) = @_;
    my $user = $c->user->obj;
    my @thumbnails = $c->model( 'RDS::MediaAsset' )
	->search({'me.user_id'=>$user->id, asset_type=>'thumbnail'},
		 {prefetch=>'media'});
    my @data = ();
    foreach my $asset ( @thumbnails ) {
	my( $lat, $lng ) = $self->valid( $asset->media->lat, $asset->media->lng ); 
	my $data = {
	    lat => $lat,
	    lng => $lng,
	    uuid => $asset->media->uuid,
	    title => $asset->media->title,
	};
	my $klass = $c->config->{mediafile}->{$asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $asset->uri );
	$data->{url} = $url;
	push( @data, $data );
    }
    $self->status_ok( $c, { locations => \@data } );
}

sub location :Local {
    my( $self, $c ) = @_;
    my $lat = $c->req->param( 'lat' );
    my $lng = $c->req->param( 'lng' );

    my $latlng = "$lat,$lng";
    my $res = $c->model( 'GoogleMap' )->get( "/maps/api/geocode/json?latlng=$latlng&sensor=true" );

    $self->status_ok( $c, $res->data->{results} );
}

sub change_latlng :Local {
    my( $self, $c ) = @_;
    my $lat = $c->req->param( 'lat' );
    my $lng = $c->req->param( 'lng' );

    my $mid = $c->req->param( 'mid' );
    my $m = $c->user->media->find({uuid=>$mid});
    unless( $m ) {
	$self->status_bad_request
	    ( $c, 
	      $c->loc( 'Unable to find mediafile for [_1]', $mid ) );
    }

    $m->lat( $lat );
    $m->lng( $lng );
    $m->update();
    $self->status_ok( $c, {} );
}

__PACKAGE__->meta->make_immutable;
1;
