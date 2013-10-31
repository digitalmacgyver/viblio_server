#!/usr/bin/env perl
use strict;
use lib "lib";
use FileHandle;

my $Usage = <<_EOM;
Usage: $0 <staging|prod> [email|email,list|file]
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

my @emails = ();
my $arg = $ARGV[1];
die $Usage unless( $arg );
if ( -f $arg ) {
    my $f = new FileHandle "<$arg";
    die "Cannot open $arg to read: $_" unless( $f );
    while(<$f>) {
	chomp;
	push( @emails, $_ );
    }
    close $f;
}
else {
    @emails = split( /,/, $arg );
}

my $schema = VA::RDSSchema->connect
    ( $conn->{$db}->{dsn}, $conn->{$db}->{user}, $conn->{$db}->{pass} ); 

foreach my $email ( @emails ) {
    my $e = $schema->resultset( 'EmailUser' )->find_or_create({ email=>$email, status=>'whitelist'});
    die "Cannot create record: $_" unless( $e );
}
