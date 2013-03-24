#!/usr/bin/env perl
use strict;
use lib "lib";

my $Usage = <<_EOM;
Usage: $0 -u <username> -f <fullname> [-e <email>] [-p <password] [-r <list of roles>]
email defaults to username (in which case, username should be email!)
if no -p, will be prompted
if -r, comma delim list of roles to add
_EOM

use VA::Schema;
use Term::ReadKey;

my $schema = VA::Schema->connect( 'dbi:mysql:vadb', 'vaadmin', 'viblio' );

my( $username,
    $password,
    $email,
    $fullname );

my( $pw1, $pw2 );
my @roles = ();

while((my $arg = shift @ARGV)) {
    if ( $arg eq '-u' ) {
	$username = shift @ARGV;
	next;
    }
    if ( $arg eq '-f' ) {
	$fullname = shift @ARGV;
	next;
    }
    if ( $arg eq '-e' ) {
	$email = shift @ARGV;
	next;
    }
    if ( $arg eq '-p' ) {
	$password = shift @ARGV;
	next;
    }
    if ( $arg eq '-r' ) {
	@roles = split(/,/, shift @ARGV);
	next;
    }
    print $Usage;
    exit 0;
}

die $Usage unless( $username );
die $Usage unless( $fullname );

$email = $username unless( $email );

unless( $password ) {
    print "password: ";
    ReadMode('noecho');
    $pw1 = ReadLine(0);
    chomp $pw1;

    print "\n";

    print "confirm password: ";
    ReadMode('noecho');
    $pw2 = ReadLine(0);
    chomp $pw2;

    ReadMode(0);
    print "\n";

    die "Passwords don't match! User not created!\n" unless( $pw1 eq $pw2 );
    $password = $pw1;
}

my $user = $schema->resultset( 'User' )->find({ username => $username });
if ( $user ) {
    die "User \"$username\" already exists! User not created!\n";
}

$user = $schema->resultset( 'User' )->create
    ({ username => $username,
       fullname => $fullname,
       email => $email,
       password => $password });
unless( $user ) {
    die "Problems creating user!\n";
}

foreach my $role ( @roles ) {
    my $r = $schema->resultset( 'Role' )->find({ role => $role });
    if ( $r ) {
	$user->add_to_roles( $r );
    }
    else {
	print "warning: role \"$role\" not found!\n";
    }
    $user->update;
}

exit 0;


