#!/usr/bin/env perl
#
# Script to send emails to users who have had video upload activity within some 
# specified period of time.
#
# This is effectively a standalone version of the Cat server.  As such, it needs 
# to be "configured" the same way, using $VA_CONFIG_LOCAL_SUFFIX env variable
# to indicate which domain this script is running in.
#
use strict;
use lib "lib";
use Data::Dumper;
use DateTime;
use VA;

my $Usage = "VA_CONFIG_LOCAL_SUFFIX=staging|prod|local $0 --days-ago N [--page N --rows M] [--report] [--user test-email] [--force-one-day]";

# Parse the args
#
my( $days_ago, $report, $page, $rows, $email_addr, $force1 ) = ( 1, 0, undef, 100, undef, 0 );
while( my $arg = shift( @ARGV ) ) {
    if ( $arg eq '--days-ago' ) {
	$days_ago = shift( @ARGV ); next;
    }
    if ( $arg eq '--report' ) {
	$report = 1; next;
    }
    if ( $arg eq '--force-one-day' ) {
	$force1 = 1; next;
    }
    if ( $arg eq '--page' ) {
	$page = shift( @ARGV ); next;
    }
    if ( $arg eq '--rows' ) {
	$rows = shift( @ARGV ); next;
    }
    if ( $arg eq '--user' ) {
	$email_addr = shift( @ARGV ); next;
    }
}

# The email template to use.
#
my $email_template = 'email/05-youveGotVideos.tt';
my $subject        = "You've got videos";
unless( $force1 ) {
    if ( $days_ago > 1 ) {
	$email_template = 'email/12-memoriesFromPastWeek.tt';
	$subject        = 'Your weekly video summary';
    }
}

# The value of $c->server, used in email templates, has to be
# manually set, since there is not request involved in this
# standalone script.  We'll use $VA_CONFIG_LOCAL_PREFIX to
# choose a server, since that variable must be set in the environment
# anyway for everything else to work.
#
my $servers = {
    prod => 'https://viblio.com',
    staging => 'https://staging.viblio.com',
    'local' => 'https://localhost',
};
unless( $ENV{'VA_CONFIG_LOCAL_SUFFIX'} ) {
    $ENV{'VA_CONFIG_LOCAL_SUFFIX'} = 'local';
}

my $c = VA->new;
$c->{server_override} = $servers->{$ENV{'VA_CONFIG_LOCAL_SUFFIX'}};

my $NOW    = DateTime->now;
my $TARGET = DateTime->from_epoch( epoch => ($NOW->epoch - 60*60*24*$days_ago) );
my $dtf    = $c->model( 'RDS' )->schema->storage->datetime_parser;

my $pager;
if ( defined( $page ) ) {
    $pager = {
	page => $page,
	rows => $rows
    };
}

my @users;
if ( $email_addr ) {
    my $u = $c->model( 'RDS::User' )->find({ email => $email_addr });
    unless( $u ) {
	die "Cannot find $email_addr in users in db";
    }
    push( @users, $u );
}
else {
    @users = $c->model( 'RDS::User' )->search({ email => { '!=', undef } }, $pager );
}

if ( $report ) {
    print sprintf( "%-30s %-7s %-7s %-7s %-7s %-7s\n", "User", "Videos", "Albums", "Faces", "Unamed", "Tagged" );
}

# Handle updates to shared albums seperately from the normal email
# updates.
sub send_shared_album_updates {
    my $users = shift;

    # First get a list of all album entries created in the last day.
    my @albums = $c->model( 'RDS::MediaAlbum' )
	->search( { 'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) } },
		  { prefetch => { 'album' => 'community' } } );

    #my @videos = $c->model( 'RDS::Media' )
	#->search( { 'media_albums_medias.created_date' => { '>', $dtf->format_datetime( $TARGET ) } },
	#	  { prefetch => [ 'media_albums_medias', 'community' ] } );

    # Build up a set of album, uploader, ( media1, media2, ... ) structures.
    my $album_uploaders = {}
    foreach my $video ( @albums ) {
	print( $video->album_id, " ", $video->media_id, " ", $video->album->title, "\n" );
	my $uploader = $video->album->user_id;
	my $upload_uuid = $video->album->uuid;
    }
    # From this list I can break it down into:
    # UPLOADER, ALBUM, [ MEDIA ] and then use the existing logic from Album.pm.

    # Find any album the user is a member of that had videos added to it.
    # For each album get a list of [ video_uploader, [ vid1, vid2, ... ] ]
    # For each item in the above list, if video_uploader != user, send an email.

    
    # DEBUG - for testing we only want to do this.
    exit 0;
}

send_shared_album_updates( \@users );

foreach my $user ( @users ) {
    unless ( $user->profile->setting( 'email_notifications' ) && $user->profile->setting( 'email_upload' ) ) {
	print sprintf( "%-30s %s\n", $user->email, "does not want email" ) if ( $report );
	next;
    }
    
    my @media = $user->videos->search(
	{ 'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) },
	  'me.is_viblio_created' => 0 },
	{prefetch => 'assets' } );
    my @albums = $user->albums->search(
	{ 'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) },
	  'me.is_viblio_created' => 0 },
	{prefetch => 'assets' } );
    my @tagged_faces = $user->contacts->search(
	{ updated_date => { '>', $dtf->format_datetime( $TARGET ) },
	  picture_uri  => { '!=', undef },
	  contact_name => { '!=', undef } });
    my @tf = map {{ uuid => $_->uuid, picture_uri => $_->picture_uri, contact_name => $_->contact_name }} @tagged_faces;
    my @ids = map{ $_->id } @media;
    my @feat = $c->model( 'RDS::MediaAssetFeature' )
	->search({'me.media_id' => { -in => \@ids }, 
		  'me.contact_id' => { '!=', undef },
		  'contact.contact_name' => { '!=', undef }, 
		  'me.feature_type'=>'face'}, 
		 {prefetch=>['contact','media_asset'], 
		  group_by=>['contact.id'] });
    my @named_faces = ();
    foreach my $feat ( @feat ) {
	push( @named_faces, { uri => $feat->media_asset->uri,
			name => $feat->contact->contact_name
	      });
    }
    @feat = $c->model( 'RDS::MediaAssetFeature' )
	->search({'me.media_id' => { -in => \@ids }, 
		  'me.contact_id' => { '!=', undef },
		  'contact.contact_name' => { '=', undef }, 
		  'me.feature_type'=>'face'}, 
		 {prefetch=>['contact','media_asset'], 
		  group_by=>['contact.id'] });
    my @unnamed_faces = ();
    foreach my $feat ( @feat ) {
	push( @unnamed_faces, { uri => $feat->media_asset->uri,
	      });
    }

    my @published = ();
    my $view_count = 0;
    foreach my $m ( @media ) {
	push( @published, VA::MediaFile->new->publish( $c, $m ) );
	$view_count += $m->view_count;
    }

    my @apublished = ();
    foreach my $m ( @albums ) {
	push( @apublished, VA::MediaFile->new->publish( $c, $m ) );
    }

    # Only send email if there was some activity
    #
    next if ( ($#published == -1) && ($#apublished == -1) );

    if ( $days_ago == 1 ) {
	# The daily report should not include albums
	next if ($#published == -1);
    }

    if ( $report ) {
	# Just print a report
	print sprintf( "%-30s %-7s %-7s %-7s %-7s %-7s\n", 
		       $user->email, ($#published + 1), ($#apublished + 1), ($#named_faces + 1), ($#unnamed_faces + 1), ($#tagged_faces + 1) );
    }
    else {
	# Send the email
	my $res  = VA::Controller::Services->send_email( $c, {
	    subject => $c->loc( $subject ),
	    to => [{ email => $user->email,
		     name  => $user->displayname }],
	    template => $email_template,
	    stash => {
		model => {
		    user => $user,
		    media => \@published,
		    albums => \@apublished,
		    faces => \@named_faces,
		    unnamedfaces => \@unnamed_faces,
		    tagged_faces => \@tf,
		}
	    } });
	if ( $res ) {
	    $c->log->error( "Failed to send ($days_ago) email to " . $user->email );
	}
    }
}

if ( $days_ago >= 7 ) {
    # This is kind of a hack, but its not easy to change the cron script that
    # fires this thing.  We have two more checks to perform:
    # 1.  If a user creates an account, but does not upload videos in a week, send them a reminder
    # 2.  If they haven't uploaded videos in two weeks, send them a different reminder.
    #
    # So, once a week, find all user accounts created between 1 and 2 weeks ago, and if they don't
    # have videos, send the first email.  For any user accounts created between 2 and 3 weeks ago and
    # no videos, send the send email.
    #
    my $one_week_ago = DateTime->from_epoch( epoch => ($NOW->epoch - 60*60*24*($days_ago)) );
    my $two_weeks_ago = DateTime->from_epoch( epoch => ($NOW->epoch - 60*60*24*($days_ago+7)) );
    my $three_weeks_ago = DateTime->from_epoch( epoch => ($NOW->epoch - 60*60*24*($days_ago+14)) );

    my @users = $c->model( 'RDS::User' )->search(
	{ created_date => {
	    -between => [
		 $dtf->format_datetime( $two_weeks_ago ),
		 $dtf->format_datetime( $one_week_ago ) 
		]
	  },
		email => { '!=', undef }
	});
    if ( $report ) {
	print( "There are " . ($#users + 1 ) . " users who created accounts between 1 and 2 weeks ago.\n" );
	foreach my $user ( @users ) {
	    print sprintf( "%-30s %-20s : video count: %d\n", $user->email, $user->created_date, $user->videos->count );
	}
    }
    else {
	foreach my $user ( @users ) {
	    if ( $user->videos->count == 0 || $email_addr eq $user->email ) {
		my $res  = VA::Controller::Services->send_email( $c, {
		    subject => $c->loc( "Get started with your new VIBLIO account" ),
		    to => [{ email => $user->email,
			     name  => $user->displayname }],
		    template => 'email/08-dontForgetViblio.tt' });
		if ( $res ) {
		    $c->log->error( "Failed to send one-week upload reminder email to " . $user->email );
		}
	    }
	}
    }
	
    my @users = $c->model( 'RDS::User' )->search(
	{ created_date => {
	    -between => [
		 $dtf->format_datetime( $three_weeks_ago ),
		 $dtf->format_datetime( $two_weeks_ago ) 
		]
	  },
		email => { '!=', undef }
	});
    if ( $report ) {
	print( "There are " . ($#users + 1 ) . " users who created accounts between 2 and 3 weeks ago.\n" );
	foreach my $user ( @users ) {
	    print sprintf( "%-30s %-20s : video count: %d\n", $user->email, $user->created_date, $user->videos->count );
	}
    }
    else {
	foreach my $user ( @users ) {
	    if ( $user->videos->count == 0 || $email_addr eq $user->email ) {
		$c->log->debug( 'Sending email to ' . $user->email );
		my $res  = VA::Controller::Services->send_email( $c, {
		    subject => $c->loc( "VIBLIO wants to help"  ),
		    to => [{ email => $user->email,
			     name  => $user->displayname }],
		    template => 'email/10-uploadSomeVideos-DRAFT.tt',
		    stash => {
			user => $user,
		    } });
		if ( $res ) {
		    $c->log->error( "Failed to send two-week upload reminder email to " . $user->email );
		}
	    }
	}
    }
}

exit 0;

END {
    # Without this, c->log output does not go out!
    $c->log->_flush;
}
