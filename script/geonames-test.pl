#!/usr/bin/env perl
use strict;
use Data::Dumper;
use Geo::GeoNames;
use lib "./lib";
use VA;
use GeoData;

my $c = VA->new;

# fremont
#my $lat = 37.515330;
#my $lng = -121.952029;

# bangalore
my $lat = 12.958361;
my $lng = 77.600968;

print Dumper GeoData::get_data( $c, $lat, $lng );
exit 0;

my $gn = Geo::GeoNames->new( username => 'viblio' );

# Get address

# Try the geonames free lookup first, which only works in the US.
# If that fails try google.
my $res = $gn->find_nearest_address( lat => $lat, lng => $lng );
if ( $#{$res} >= 0 ) {
    print "Free address:\n";
    print join( ' ', 
		@$res[0]->{streetNumber}, 
		@$res[0]->{street},
		@$res[0]->{placename},
		@$res[0]->{adminCode1} || @$res[0]->{adminName1} ), "\n";
    my $free_city = @$res[0]->{placename};		   
    print "Free city:   $free_city\n";
}
$res = $c->model( 'GoogleMap' )->
    get( "/maps/api/geocode/json?latlng=$lat,$lng&sensor=true" );
if ( $res && $res->data && $#{$res->data->{results}} >= 0 ) {
    print "Google Address:\n";
    print @{$res->data->{results}}[0]->{formatted_address}, "\n";
    my $google_city = google_city( @{$res->data->{results}}[0] );
    print "Google city: $google_city\n";
}
sub google_city {
    my $s = shift;
    foreach my $comp ( @{ $s->{address_components } } ) {
	if ( grep( $_ eq 'locality',  @{$comp->{types}} ) &&
	     grep( $_ eq 'political', @{$comp->{types}} ) ) {
	    return $comp->{short_name};
	}
    }
}
