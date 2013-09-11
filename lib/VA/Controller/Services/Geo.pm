package VA::Controller::Services::Geo;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
BEGIN { extends 'VA::Controller::Services' }

sub valid :Private {
    my( $self, $v ) = @_;
    return $v if ( defined($v) && $v != 0 );
    return undef;
}

sub all :Local {
    my( $self, $c ) = @_;
    my $user = $c->user->obj;
    my @thumbnails = $c->model( 'RDS::MediaAsset' )
	->search({'me.user_id'=>$user->id, asset_type=>'thumbnail'},
		 {prefetch=>'media'});
    my @data = ();
    foreach my $asset ( @thumbnails ) {
	my $data = {
	    lat => $self->valid( $asset->media->lat ),
	    lng => $self->valid( $asset->media->lng ),
	    uuid => $asset->media->uuid
	};
	my $klass = $c->config->{mediafile}->{$asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $asset->uri );
	$data->{url} = $url;
	push( @data, $data );
    }
    $self->status_ok( $c, { locations => \@data } );
}

__PACKAGE__->meta->make_immutable;
1;
