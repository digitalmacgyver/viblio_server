#!/usr/bin/env perl
#
# Generate test data for yes-video.js
#
use strict;
use lib "lib";
use Data::Dumper;
use JSON;
use VA;

my $c = VA->new;

unless( $ARGV[0] ) {
    die "Usage: $0 email_address";
}
my $user = $c->model( 'RDS::User' )->find({ email => $ARGV[0] });
unless( $user ) {
    die "Cannot find user for $ARGV[0]";
}
# Get the four smallest videos
my @assets = $c->model( 'RDS::MediaAsset' )->search(
    { 'me.asset_type' => 'main',
      'me.user_id' => $user->id,
    },
    { prefetch => 'media',
      order_by => 'me.bytes asc',
      group_by => [ 'media.id' ],
      page => 1, rows => 4,
    } );
my @files = map {
    { filename => $_->media->filename,
      mimetype => $_->mimetype,
      size => $_->bytes,
      duration => $_->duration,
      uri => $_->uri,
      title => $_->media->title,
    } } @assets;

my $json = JSON->new;
print $json->pretty->encode(
    {
	disk_type => 'dvd_4_7G',
	user => {
	    uuid => $user->uuid,
	    email => $user->email,
	},
	s3 => {
	    bucket => $c->config->{s3}->{bucket},
	    access_key_id => $c->config->{'Model::S3'}->{aws_access_key_id},
	    secret_access_key => $c->config->{'Model::S3'}->{aws_secret_access_key},
	},
	files => \@files
    });
