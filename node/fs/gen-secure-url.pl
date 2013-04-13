#!/usr/bin/env perl
#
# Example to generate a secure url
#
use strict;
use Digest::MD5 qw(md5 md5_hex md5_base64);

# secret has to match that in the nginx conf file (see ./nginx/secure.conf).
my $secret = 'mysecret';

# path is that returned from /upload
my $path   = $ARGV[0];

# set an expire time; now + something
my $expire = time() + 120;  # two minutes from now

my $md5 = md5_base64( $secret . $path . $expire );

# escape special characters so this works as a url
$md5 =~ s/=//g;
$md5 =~ s/\+/-/g;
$md5 =~ s/\//_/g;

# here is the final url
print "${path}?st=$md5&e=$expire\n";
