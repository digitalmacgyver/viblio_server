#!/usr/bin/env perl
use lib "lib";
use Data::Dumper;
use VA;

$c = VA->new;

my @lines = <>;

shift @lines; shift @lines;
foreach my $line ( @lines ) {
    chomp $line;
    next if ( $line =~ /^unknown/ );
    my( $uuid, $started, $completed ) = split( /,/, $line );
    my $user = $c->model( 'RDS::User' )->find({ uuid => $uuid });
    next unless( $user );
    next if ( $started == $completed );
    print sprintf( "%-30s %d/%d\n",
		   $user->email, $completed, $started );
}
