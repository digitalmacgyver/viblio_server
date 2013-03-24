#!/usr/bin/env perl
#
# Populate the database with test data.
#
# Test data generated from http://www.generatedata.com/#generator
#
use strict;
use lib "lib";
use VA::Schema;
use FileHandle;
use Email::Address;

my $schema = VA::Schema->connect( 'dbi:mysql:vadb', 'vaadmin', 'viblio' );

die "Cannot connect to database!"
    unless( $schema );

# Delete them all.  This is a good test of cascading deletes too.
#
$schema->resultset( 'User' )->delete_all;

my @roles = ( 'admin', 'dbadmin', 'instructor' );
my $roles = {};
foreach my $rname ( @roles ) {
    $roles->{ $rname } = $schema->resultset( 'Role' )->find({role=>$rname});
    die "Could not find role: $rname"
	unless( $roles->{ $rname } );
}

# Andrew Peebles
#
my $user = $schema->resultset( 'User' )
    ->find_or_create({ username => 'aqpeeb',
		       email => 'aqpeeb@gmail.com',
		       provider => 'local',
		       displayname => 'Andrew Peebles',
		       password => 'password' });
die "Could not create admin user: $!"
    unless( $user );

$user->add_to_roles( $roles->{admin} );
$user->update;

# vaadmin
#
$user = $schema->resultset( 'User' )
    ->find_or_create({ username => 'vaadmin',
		       email => 'vaadmin@viblio.com',
		       provider => 'local',
		       displayname => 'Viblio Admin',
		       password => 'password' });
die "Could not create admin user: $!"
    unless( $user );

$user->add_to_roles( $roles->{admin} );
$user->update;

