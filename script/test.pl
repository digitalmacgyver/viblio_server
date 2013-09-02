#!/usr/bin/env perl
use strict;
use lib "lib";

my $Usage = <<_EOM;
Usage: $0 <test|staging|prod>
_EOM

use VA::RDSSchema;
use Data::Dumper;

my $conn = {
    test => {
	dsn => 'dbi:mysql:database=video_dev_1;host=testpub.c9azfz8yt9lz.us-west-2.rds.amazonaws.com',
	user => 'video_dev_1',
	pass => 'video_dev_1',
    },
    staging => {
	dsn => 'dbi:mysql:database=video_dev_1;host=testpub.c9azfz8yt9lz.us-west-2.rds.amazonaws.com',
	user => 'video_dev_1',
	pass => 'video_dev_1',
    },
    prod => {
	dsn => 'dbi:mysql:database=video_dev;host=videos.c9azfz8yt9lz.us-west-2.rds.amazonaws.com;port=3306',
	user => 'video_dev',
	pass => 'video_dev',
    },
};

my $db = $ARGV[0];
die $Usage unless( $db );

my $schema = VA::RDSSchema->connect
    ( $conn->{$db}->{dsn}, $conn->{$db}->{user}, $conn->{$db}->{pass} ); 

my $u = $schema->resultset( 'User' )->find({email => 'aqpeeb@gmail.com'});
print $u->displayname, "\n";
