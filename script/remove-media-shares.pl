#!/usr/bin/env perl
use strict;
use lib "lib";

my $Usage = <<_EOM;
Usage: $0 <staging|prod> email [remove]
_EOM

use VA::RDSSchema;
use Data::Dumper;

my $conn = {
    staging => {
	dsn => 'dbi:mysql:database=video_dev_1;host=testpub.c9azfz8yt9lz.us-west-2.rds.amazonaws.com',
	user => 'web_dev',
	pass => 'Yn8U!2Y52Pt#5MEK',
    },
    prod => {
	dsn => 'dbi:mysql:database=video_dev;host=videos.c9azfz8yt9lz.us-west-2.rds.amazonaws.com;port=3306',
	user => 'web_prod',
	pass => 'AVxXwDC9Y%sKaPG@',
    },
};

my $db = $ARGV[0];
die $Usage unless( $db );

my $email = $ARGV[1];
die $Usage unless( $email );

my $command;
if ( $ARGV[2] ) {
    $command = $ARGV[2];
}

my $schema = VA::RDSSchema->connect
    ( $conn->{$db}->{dsn}, $conn->{$db}->{user}, $conn->{$db}->{pass} ); 

my $u = $schema->resultset( 'User' )->find({email => $email});
die "Cannot find user for $email" unless( $u );
my @media = $u->media;
my $count = 0;
foreach my $m ( @media ) {
    my @shares = $m->media_shares;
    foreach my $s ( @shares ) {
	$s->delete if ( $command eq 'remove' );
	$count += 1;
    }
}
print "$email has $count media shares.\n";
if ( $command eq 'remove' ) {
    print "Deleted $count shares for $email\n";
}

