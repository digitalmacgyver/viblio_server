#!/usr/bin/env perl
use lib "lib";
use Data::Dumper;
use VA;

$c = VA->new;

$user = $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' });
$c->user( $user );

# New relationships added for getting albums and videos:
@albums = $user->albums;
@videos = $user->videos;

print sprintf( "%s has %d albums\n", $user->displayname, ( $#albums + 1 ) );
print sprintf( "%s has %d videos\n", $user->displayname, ( $#videos + 1 ) );

$group = $user->create_group( 'Matt and Bidyut', 'matt@viblio.com,bidyut@viblio.com' );
if( $group ) {
    print sprintf( "Created a group called %s\n", $group->contact_name );
}
else {
    print "For some reason, group is undefined\n";
}
$group = $user->create_group( 'Matt and Mona', 'matt@viblio.com,mona@viblio.com' );

@groups = $user->groups;
print sprintf( "%s owns %d groups\n", $user->displayname, ( $#groups + 1 ) );

foreach my $group ( @groups ) {
    print sprintf( "Group: %s\n", $group->contact_name );
    foreach my $member ( $group->contacts ) {
	print sprintf( "  Member: %s ( %s )\n", $member->contact_name, $member->contact_email );
    }
}

$matt = $c->model( 'RDS::User' )->find({ email => 'matt@viblio.com' });
# What groups is Matt a member of...
foreach my $g ( $matt->is_member_of ) {
    print sprintf( " * %s is in group: %s\n", $matt->email, $g->contact_name );
    $g_uuid = $g->uuid;
}
print sprintf( "%s is a member of %s ?: %d\n",
	       $matt->email, $g_uuid, $matt->is_member_of( $g_uuid ) );

print sprintf( "%s is a member of %s ?: %d\n",
	       $matt->email, 'xxx-yyy-zzz', $matt->is_member_of( 'xxx-yyy-zzz' ) );

#foreach my $g ( $user->groups ) {
#    $g->delete;
#}
