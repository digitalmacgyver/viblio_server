#!/usr/bin/env perl
use strict;
use lib "lib";
use VA;
use GeoData;

my $c = VA->new;

my @media = $c->model( 'RDS::Media' )->all();
foreach my $media ( @media ) {
    my $lat = $media->lat;
    my $lng = $media->lng;
    if ( $lat && $lng && $lat != 0 && $lng != 0 ) {
	my $info = GeoData::get_data( $c, $lat, $lng );
	next unless ( $info->{city} && $info->{address} );
	print sprintf( "%-20s : %s ( %s, %s )\n", $info->{city}, $info->{address}, $lat, $lng );
	$media->geo_address( $info->{address} );
	$media->geo_city( $info->{city} );
	$media->update;
	sleep( 1 );
    }
}
