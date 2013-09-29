#!/usr/bin/env perl
use strict;
use lib "lib";

my $Usage = <<_EOM;
Usage: $0 <src_email:staging|prod target_email:staging|prod>
_EOM

use VA::RDSSchema;
use Data::Dumper;

my $conn = {
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

if ( $#ARGV != 1 ) {
    die $Usage;
}

my( $src_email, $src_db ) = split( /:/, $ARGV[0] );
my( $tar_email, $tar_db ) = split( /:/, $ARGV[1] );

my $src = VA::RDSSchema->connect
    ( $conn->{$src_db}->{dsn}, $conn->{$src_db}->{user}, $conn->{$src_db}->{pass} ); 

my $tar;
if ( $tar_db eq $src_db ) {
    $tar = $src;
}
else {
    $tar = VA::RDSSchema->connect
	( $conn->{$tar_db}->{dsn}, $conn->{$tar_db}->{user}, $conn->{$tar_db}->{pass} ); 
}

my $src_user = $src->resultset( 'User' )->find({ email => $src_email });
my $tar_user = $tar->resultset( 'User' )->find({ email => $tar_email });

unless( $src_user ) {
    die "Could not find $src_email";
}

unless( $tar_user ) {
    die "Could not find $tar_email";
}

foreach my $smedia ( $src_user->media ) {
    print "copy media ...\n";
    my $data = $smedia->TO_JSON;
    delete $data->{id};
    delete $data->{user_id};
    delete $data->{uuid};
    delete $data->{created_date};
    delete $data->{updated_date};

    my $tmedia = $tar_user->find_or_create_related( 'media', $data );
    unless( $tmedia ) { die "Failed to create a media file"; }

    foreach my $sasset ( $smedia->assets ) {
	print "  copy asset ...\n";
	$data = $sasset->TO_JSON;
	delete $data->{id};
	delete $data->{media_id};
	delete $data->{user_id};
	delete $data->{uuid};
	delete $data->{created_date};
	delete $data->{updated_date};

	$data->{user_id} = $tar_user->id;

	my $tasset = $tmedia->find_or_create_related( 'media_assets', $data );
	unless( $tasset ) { die "Failed to create an asset"; }
   
	foreach my $sfeature ( $sasset->media_asset_features ) {
	    print "    copy feature ...\n";
	    $data = $sfeature->TO_JSON;
	    delete $data->{id};
	    delete $data->{media_asset_id};
	    delete $data->{media_id};
	    delete $data->{user_id};
	    delete $data->{uuid};
	    delete $data->{contact_id};
	    delete $data->{created_date};
	    delete $data->{updated_date};

	    $data->{user_id} = $tar_user->id;
	    $data->{media_id} = $tmedia->id;

	    my $tfeature = $tasset->find_or_create_related( 'media_asset_features', $data );
	    unless( $tfeature ) { die "Failed to create an asset feature"; }

	    # make the contact
	    my $scontact = $sfeature->contact;
	    if ( $scontact ) {
		print "      copy contact ...\n";
		my $d = $scontact->TO_JSON;
		delete $d->{id};
		delete $d->{user_id};
		delete $d->{uuid};
		delete $d->{created_date};
		delete $d->{updated_date};

		$d->{user_id} = $tar_user->id;

		my $tcontact = $tar->resultset( 'Contact' )->find_or_create( $d );
		unless( $tcontact ) { die "Failed to create a contact"; }
		
		$tfeature->contact_id( $tcontact->id );
		$tfeature->update;
	    }
	}
    }
}
