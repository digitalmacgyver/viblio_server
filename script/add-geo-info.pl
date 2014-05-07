#!/usr/bin/env perl
use strict;
use lib "lib";
use VA;
use GeoData;

my $c = VA->new;

my $cache = {};

my @media = $c->model( 'RDS::Media' )->all();
foreach my $media ( @media ) {
    next if ( $media->geo_address );
    my $lat = $media->lat;
    my $lng = $media->lng;
    if ( $lat && $lng && $lat != 0 && $lng != 0 ) {
	my $info = $cache->{"$lat$lng"};
	$info = GeoData::get_data( $c, $lat, $lng ) unless( $info );
	next unless ( $info->{city} && $info->{address} );
	print sprintf( "%-20s : %s ( %s, %s )\n", $info->{city}, $info->{address}, $lat, $lng );
	$media->geo_address( $info->{address} );
	$media->geo_city( $info->{city} );
	$media->update;
	sleep( 1 ) unless( $cache->{"$lat$lng"} ); 
	$cache->{"$lat$lng"} = $info;
    }
}
