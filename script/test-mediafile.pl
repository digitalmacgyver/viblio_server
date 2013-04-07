#!/usr/bin/env perl
#
# Populate the database with test data.
#
# Test data generated from http://www.generatedata.com/#generator
#
use strict;
use lib "lib";
use VA::Schema;
use Data::Dumper;

my $db = 'vadb';
my $schema = VA::Schema->connect( "dbi:mysql:$db", 'vaadmin', 'viblio' );

my $m1 = $schema->resultset('Mediafile')->find_or_create({filename=>'filename_1.txt',user_id=>1});
my $m2 = $schema->resultset('Mediafile')->find_or_create({filename=>'filename_2.txt',user_id=>1});

# Find or create an associated view
my $view1 = $m1->find_or_create_related( 'views', {filename=>'filename_1.txt',uri=>'foo'});
my $view2 = $m1->find_or_create_related( 'views', {filename=>'filename_1.txt',uri=>'bar',location=>'s3',type=>'thumbnail'});

my $view3 = $m2->find_or_create_related( 'views', {filename=>'filename_2.txt',uri=>'foo'});
my $view4 = $m2->find_or_create_related( 'views', {filename=>'filename_2.txt',uri=>'bar',location=>'s3',type=>'thumbnail'});

# Get the url, based on current location
# print $view1->url, "\n";

# The url field is automatically returned on json
# print Dumper $view2->TO_JSON;

# Return the first view of type 'main' or undef.
# my $main = $m1->view( 'main' );
# print Dumper $main->TO_JSON;

# To prefetch a media file and all of its views:
# my $mf = $schema->resultset('Mediafile')->find(1,{prefetch=>'views'});

# To get a WO BOM, use prefetch
my $w = $schema->resultset( 'Workorder' )->create({name=>'wo', user_id=>1});
# Add the media file
$m1->add_to_workorders( $w );
$m2->add_to_workorders( $w );

$DB::single = 1;
my @files = $w->mediafiles->search({},{prefetch=>'views'});
my @jfiles = ();
foreach my $f ( @files ) {
    my $mf = $f->TO_JSON;
    my @views = $f->views;
    my @jviews = ();
    foreach my $v ( @views ) {
	push( @jviews, $v->TO_JSON );
    }
    $mf->{views} = \@jviews;
    push( @jfiles, $mf );
}
print Dumper { wo => $w->TO_JSON,
	       files => \@jfiles };

$DB::single = 1;

print "Done\n";
exit 0;
