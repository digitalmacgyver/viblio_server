package VA::Controller::Services::Geo;
use Moose;
use VA::MediaFile;
use GeoData;

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
	->search({'me.user_id'=>$user->id, asset_type=>'poster', 'media.lat' => { '!=', undef }},
		 {prefetch=>'media'});
    my @data = ();
    foreach my $asset ( @thumbnails ) {
	my( $lat, $lng ) = $self->valid( $asset->media->lat, $asset->media->lng ); 
	my $data = {
	    lat => $lat,
	    lng => $lng,
	    uuid => $asset->media->uuid,
	    title => $asset->media->title,
	    view_count => $asset->media->view_count
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
    $c->forward( '/services/na/geo_loc' );
}

sub change_latlng :Local {
    my( $self, $c ) = @_;
    my $lat = $self->sanitize( $c, $c->req->param( 'lat' ) );
    my $lng = $self->sanitize( $c, $c->req->param( 'lng' ) );
    my $addr = $self->sanitize( $c, $c->req->param( 'addr' ) );

    my $mid = $c->req->param( 'mid' );
    my $m = $c->user->media->find({uuid=>$mid});
    unless( $m ) {
	$self->status_not_found
	    ( $c, 
	      $c->loc( 'Unable to find mediafile for [_1]', $mid ), $mid );
    }

    $m->lat( $lat );
    $m->lng( $lng );
    $m->geo_address( $addr ) if ( $addr );

    my $info = GeoData::get_data( $c, $lat, $lng );
    if ( $info->{city} && $info->{address} ) {
	$m->geo_address( $info->{address} );
	$m->geo_city( $info->{city} );
    }

    $m->update();
    $self->status_ok( $c, { address => $info->{address} } );
}

__PACKAGE__->meta->make_immutable;
1;
