#!/usr/bin/env perl
#
# Populate the database with test data.
#
# Test data generated from http://www.generatedata.com/#generator
#
use strict;
use lib "lib";
use VA::RDSSchema;
use FileHandle;
use Email::Address;
use JSON::XS ();

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

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

unless( defined( $ARGV[0] ) ) {
    die "Must specify 'test' or 'staging' for the database you are populating.";
}
my $db = $ARGV[0];

my $schema = VA::RDSSchema->connect
    ( $conn->{$db}->{dsn}, $conn->{$db}->{user}, $conn->{$db}->{pass} ); 

die "Cannot connect to database!"
    unless( $schema );

# Delete them all.  This is a good test of cascading deletes too.
#
# $schema->resultset( 'User' )->delete_all;

my @roles = ( 'admin', 'dbadmin', 'instructor' );
my $roles = {};
foreach my $rname ( @roles ) {
    $roles->{ $rname } = $schema->resultset( 'Role' )->find({role=>$rname});
    die "Could not find role: $rname"
	unless( $roles->{ $rname } );
}
my $user;

# Andrew Peebles
#
$user = $schema->resultset( 'User' )
    ->find_or_create({ username => 'aqpeeb',
		       email => 'aqpeeb@gmail.com',
		       provider => 'local',
		       displayname => 'Andrew Peebles',
		     });
die "Could not create admin user: $!"
    unless( $user );

$user->password( 'password' );
$user->find_or_create_related
    ( 'user_roles', 
      { user_id => $user->id, 
	role_id => $roles->{admin}->id});
print $encoder->encode( $user );
$user->update;
$user->create_profile();

# vaadmin
#
$user = $schema->resultset( 'User' )
    ->find_or_create({ username => 'vaadmin',
		       email => 'vaadmin@viblio.com',
		       provider => 'local',
		       displayname => 'Viblio Admin',
		     });
die "Could not create admin user: $!"
    unless( $user );

$user->password( 'password' );
$user->find_or_create_related
    ( 'user_roles', 
      { user_id => $user->id, 
	role_id => $roles->{admin}->id});
print $encoder->encode( $user );
$user->update;
$user->create_profile();

