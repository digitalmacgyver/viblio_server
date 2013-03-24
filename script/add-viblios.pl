#!/usr/bin/env perl
#
# For adding viblios for testing.  Pass in data/viblios.txt.
#
use strict;
use lib "lib";
use VA::Schema;
use FileHandle;

my $schema = VA::Schema->connect( 'dbi:mysql:vadb', 'vaadmin', 'viblio' );

die "Cannot connect to database!"
    unless( $schema );

my $f = new FileHandle "<$ARGV[0]";
die "Cannot open input file: $!"
    unless( $f );

# Delete them all.
#
$schema->resultset( 'Viblio' )->delete_all;

while( <$f> ) {
    chomp;
    next if ( /^$/ );
    my $name = $_;
    my $desc = <$f>;
    chomp $desc;
    $schema->resultset( 'Viblio' )->create
	({ name => $name,
	   description => $desc });
}
