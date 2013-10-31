#!/usr/bin/env perl
use strict;
use lib "lib";

my $Usage = <<_EOM;
Usage: $0 <staging|prod>
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

my $schema = VA::RDSSchema->connect
    ( $conn->{$db}->{dsn}, $conn->{$db}->{user}, $conn->{$db}->{pass} ); 

my $u = $schema->resultset( 'User' )->find({email => 'aqpeeb@gmail.com'});
print $u->displayname, "\n";
