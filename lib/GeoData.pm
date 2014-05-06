package GeoData;
use strict;
use Geo::GeoNames;
#
# Obtain the nearest address for a lat/lng, and the city that
# contains the point.  First try the free Geonames api and if
# that doesn't work (it only works in the US) than fall back
# to Google, which has usage limits
#
sub get_data {
    my ( $c, $lat, $lng ) = @_;

    my $gn = Geo::GeoNames->new( username => $c->config->{geodata}->{geonames}->{username} );
    my $res = $gn->find_nearest_address( lat => $lat, lng => $lng );
    if ( $#{$res} >= 0 ) {
	return {
	    address => join( ' ', 
			     @$res[0]->{streetNumber}, 
			     @$res[0]->{street},
			     @$res[0]->{placename},
			     @$res[0]->{adminCode1} || @$res[0]->{adminName1} ),
	    city => @$res[0]->{placename},
	    source => 'geonames'
	};
    }
    else {
	my $keystr = '';
	if ( $c->config->{geodata}->{google}->{key} ) {
	    $keystr = '&key=' + $c->config->{geodata}->{google}->{key};
	}
	$res = $c->model( 'GoogleMap' )->
	    get( "/maps/api/geocode/json?latlng=$lat,$lng&sensor=false$keystr" );
	if ( $res && $res->data && $#{$res->data->{results}} >= 0 ) {
	    return {
		address => @{$res->data->{results}}[0]->{formatted_address},
		city => google_city( @{$res->data->{results}}[0] ),
		source => 'google'
	    };
	}
	else {
	    return {};
	}
    }
}

# This is a helper function to obtain the nearest city
sub google_city {
    my $s = shift;
    foreach my $comp ( @{ $s->{address_components } } ) {
        if ( grep( $_ eq 'locality',  @{$comp->{types}} ) &&
             grep( $_ eq 'political', @{$comp->{types}} ) ) {
            return $comp->{short_name};
        }
    }
}

1;


