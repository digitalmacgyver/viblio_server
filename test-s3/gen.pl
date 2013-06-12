#!/usr/bin/env perl
#
use strict;
use Muck::FS::S3::QueryStringAuthGenerator;

my $s3key = $ARGV[0]; # The 'key' from filepicker.io, the key used to store in this bucket.

my $key = 'AKIAJHD46VMHB2FBEMMA';
my $secret = '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';
my $use_https = 1;
my $bucket_name = 'viblio-mediafiles';
my $endpoint = $bucket_name . ".s3.amazonaws.com";

my $generator = Muck::FS::S3::QueryStringAuthGenerator->new(
    $key, $secret, $use_https, $endpoint );
die $_ unless( $generator );

$generator->expires_in(3600); # 1 hour = 3600 seconds

my $url = $generator->get( $bucket_name, $s3key );
$url =~ s/\/$bucket_name\//\//g;
print $url, "\n";

# wget 'http://viblio-mediafilesfiles.s3.amazonaws.com:80/Isab1XldQ1OhKud84iQa_20121113_180254.JPG?Signature=crC88zsSw3T%2B91MKsRk5kXymjGM%3D&Expires=1364670354&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA'
