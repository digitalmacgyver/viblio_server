#!/usr/bin/env perl
use strict;
use File::Basename;
use FileHandle;
use URI;

my $link_pat = "itms-services://?action=download-manifest&url=https://__SERVER__/builds/__RELEASE__.plist";

my ( $ipa, $plist );
while( my $arg = shift( @ARGV ) ) {
    if ( $arg eq '-h' || $arg eq '--help' ) {
	print "Usage: $0 --ipa IPA --plist PLIST";
	exit( 0 );
    }
    if ( $arg eq '--ipa' ) {
	$ipa = shift( @ARGV );
	next;
    }
    if ( $arg eq '--plist' ) {
	$plist = shift( @ARGV );
	next;
    }
    if ( $arg eq '--links' ) {
	my $base = basename( $ipa, ".ipa" );
	my $uri = URI->new( 'itms-services://' );
	$uri->query_form({
	    action => 'download-manifest',
	    url => "https://staging.viblio.com/builds/${base}_staging.plist" });
	print sprintf( "<a href=\"%s\">Download and Install</a>\n", $uri );
	$uri->query_form({
	    action => 'download-manifest',
	    url => "https://viblio.com/builds/${base}_production.plist" });
	print sprintf( "<a href=\"%s\">Download and Install</a>\n", $uri );
	exit(0);
    }
}

unless( $ipa && $plist ) {
    print "Usage: $0 --ipa IPA --plist PLIST";
    exit( 1 );
}

my $target = '../web-clients/durandal02/builds';
unless( -d $target ) {
    die "Cannot find $target, you must run this script in viblio-server.";
}
unless( -f $ipa ) {
    die "Cannot find $ipa";
}
unless( -f $plist ) {
    die "Cannot find $plist";
}

my $base = basename( $ipa, '.ipa' );
if ( system( "cp $ipa $target/${base}_staging.ipa" ) ) {
    die "Failed to copy $ipa";
}
if ( system( "cp $ipa $target/${base}_production.ipa" ) ) {
    die "Failed to copy $ipa";
}

sub fix {
    my( $plist, $platform, $server, $target ) = @_;
    my $base = basename( $plist, '.plist' );
    my $ifh = new FileHandle "<$plist" ;
    my $ofh = new FileHandle ">$target/${base}_${platform}.plist";

    while( <$ifh> ) {
	s/https:\/\/[^<]+/https:\/\/$server\/builds\/${base}_${platform}.ipa/g;
	print $ofh $_;
    }
    close( $ofh ); close( $ifh );

    my $link = $link_pat;
    $link =~ s/__SERVER__/$server/g;
    $link =~ s/__RELEASE__/${base}_${platform}/g;
    print $link, "\n";
}
    
fix( $plist, 'staging', 'staging.viblio.com', $target );
fix( $plist, 'production', 'viblio.com', $target );

exit 0;
