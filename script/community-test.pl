#!/usr/bin/env perl
use lib "lib";
use Data::Dumper;
use VA;

$c = VA->new;

$user = $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' });
$c->user( $user );

$matt = $c->model( 'RDS::User' )->find({ email => 'matt@viblio.com' });
$mona = $c->model( 'RDS::User' )->find({ email => 'msabet@viblio.com' });

# New relationships added for getting albums and videos:
@albums = $user->albums;
@videos = $user->videos;

print sprintf( "%s has %d albums\n", $user->displayname, ( $#albums + 1 ) );
print sprintf( "%s has %d videos\n", $user->displayname, ( $#videos + 1 ) );

$group = $user->create_group( 'Matt and Bidyut', 
			      [ $user->email,
			        'matt@viblio.com',
			        'bidyut@viblio.com' ] );
$group2 = $user->create_group( 'Matt and Mona', 
			       [ $user->email,
			        'matt@viblio.com',
			        'mona@viblio.com' ] );
if( $group ) {
    print sprintf( "Created a group called %s, id=%d\n", $group->contact_name, $group->id );
}
else {
    print "For some reason, group is undefined\n";
}
=perl
my $com = $user->find_or_create_related( 
    'communities', {
	name => 'My video friends',
	members_id => $group->id,
	media_id => $albums[0]->id
    });
=cut
my $com = $user->create_shared_album
    ( $albums[0], $group );

print sprintf( "Community created, id=%d\n", $com->id );
print "The album is called: " . $albums[0]->title, "\n";
print "Media uuids in " . $com->name, "\n";

for my $m ( $com->album->videos ) {
    print $m->uuid, "\n";
}

# All groups that matt belongs to:
@matt_groups = $matt->is_member_of();
print "Matt belongs to these groups:\n";
print $_->contact_name, "\n" foreach( @matt_groups );

# All communities that matt belongs to:
@matt_coms = $matt->is_community_member_of();
print "Matt belongs to these communities:\n";
print $_->name, "\n" foreach( @matt_coms );

# All shared albums matt can see
@matt_shared_albums = map { $_->album } $matt->is_community_member_of();
print "Matt can see these albums:\n";
print $_->title, "\n" foreach( @matt_shared_albums );

# is the mediafile uuid viewable to matt?  If so return the
# mediafile contents.

$video = $user->albums->first->videos->first;
print "The video " . $video->title . " is a member of the following albums\n";
print $_->title, "\n" foreach( $video->is_member_of() );

print "The video " . $video->title . " is a member of the following communities\n";
print $_->name, "\n" foreach( $video->is_community_member_of() );

# can can see a particular mediafile ?

print "Can matt see the video?: " . $matt->can_view_video( $video->uuid ), "\n";
print "Can mona see the video?: " . $mona->can_view_video( $video->uuid ), "\n";

# Add mona to the shared album
$com->members->add_contacts( $mona->email );
print "After adding Mona, can mona see the video?: " . $mona->can_view_video( $video->uuid ), "\n";

# Remove matt from the shared album
$com->members->remove_contacts( $matt->email );
print "After removing Matt, can Matt see the video?: " . $matt->can_view_video( $video->uuid ), "\n";

print "Done\n";
$com->members->delete;
$com->delete;

