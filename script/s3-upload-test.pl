#!/usr/bin/env perl
#
# Simple test to get S3 file upload code correct
#
use strict;
use Net::Amazon::S3;
use Net::Amazon::S3::Client;
use Data::Dumper;

my $aws_access_key_id = 'AKIAJHD46VMHB2FBEMMA';
my $aws_secret_access_key = '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';

my $file = $ARGV[0];

my $s3 = Net::Amazon::S3->new(
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
    retry                 => 1,
  );
die "Cannot create s3" unless( $s3 );

my $client = Net::Amazon::S3::Client->new( s3 => $s3 );
die "Cannot create client" unless( $client );

my $bucket = $client->bucket( name => 'viblio-uploaded-files' );
die "Cannot find bucket" unless( $bucket );

my $object = $bucket->object(
    key => 'thumbs/testfile',
    content_type => 'image/png'
    );
die "Cannot create object" unless( $object );
my $res = $object->put_filename( $file );
if ( $res ) {
    print Dumper $res;
}


