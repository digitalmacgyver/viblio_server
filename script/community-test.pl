#!/usr/bin/env perl
use lib "lib";
use Data::Dumper;
use VA;

$c = VA->new;

$user = $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' });
$c->user( $user );

$services = VA::Controller::Services->new( $c );

# New relationships added for getting albums and videos:
@albums = $user->albums;
@videos = $user->videos;

print sprintf( "%s has %d albums\n", $user->displayname, ( $#albums + 1 ) );
print sprintf( "%s has %d videos\n", $user->displayname, ( $#videos + 1 ) );

$group = $services->create_group( $c, 'Matt and Bidyut', 'matt@viblio.com,bidyut@viblio.com' );
if( $group ) {
    print sprintf( "Created a group called %s\n", $group->contact_name );
}
else {
    print "For some reason, group is undefined\n";
}
$matt = $c->model( 'RDS::User' )->find({ email => 'matt@viblio.com' });

my $com = $user->find_or_create_related( 
    'communities', {
	name => 'My video friends',
	members_id => $group->id,
    });

				 
