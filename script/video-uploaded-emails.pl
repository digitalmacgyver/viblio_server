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
use Try::Tiny;
use URI::Escape;
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

# The original report.
foreach my $user ( @users ) {
    try {
	unless ( $user->profile->setting( 'email_notifications' ) && $user->profile->setting( 'email_upload' ) ) {
	    print sprintf( "%-30s %s\n", $user->email, "does not want email" ) if ( $report );
	    next;
	}

	my $user_uuid = $user->uuid;

	my @media = $user->videos->search(
	    { 'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) },
	      'me.is_viblio_created' => 0, 'me.media_type' => 'original', 'me.is_album' => 0 },
	    {prefetch => 'assets' } );
	my @albums = $user->albums->search(
	    { 'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) },
	      'me.is_viblio_created' => 0, 'me.media_type' => 'original' },
	    {prefetch => 'assets' } );

	# Move on unless there is something to report for this user.
	unless ( scalar( @media ) or scalar( @albums ) ) {
	    if ( $report ) {
		print sprintf( "%-30s %-7s %-7s %-7s %-7s %-7s\n", 
			       $user->email, 0, 0, 0, 0, 0 );
	    }
	    next;
	}

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
	    push( @published, VA::MediaFile->new->publish( $c, $m, { owner_uuid => $user_uuid } ) );
	    $view_count += $m->view_count;
	}
	
	my @apublished = ();
	foreach my $m ( @albums ) {
	    push( @apublished, VA::MediaFile->new->publish( $c, $m, { owner_uuid => $user_uuid } ) );
	}
	
	# Only send email if there was some activity
	#
	next if ( ($#published == -1) && ($#apublished == -1) );
	
	# Actually - only send email if there were new videos.
	next if ( $#published == -1 );

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
	    # Send the email.  This sends a message via Amazon SQS, which
	    # is limited to 64 KB per message, so we may have to truncate
	    # some of the data here.
	    
	    # Boil down the media object to the few fields the template
	    # cares about to save space.
	    #
	    # All we really need in the template for daily emails is:
	    #
	    # model.media - an array of 1 or more elements
	    # model.media.0.uuid
	    # The first two elements of model.media are used.
	    #  + media.title
	    #  + media.uuid
	    #  + media.views.poster.uri
	    # The total number of new movies is listed based on length of the array
	    my @sent_media = ();
	    foreach my $media ( @published ) {
		push( @sent_media, { 
		    title => $media->{title}, 
		    uuid => $media->{uuid}, 
		    views => { poster => { uri => $media->{views}->{poster}->{uri} } } } );
	    }

	    my $res  = VA::Controller::Services->send_email( $c, {
		subject => $c->loc( $subject ),
		to => [{ email => $user->email,
			 name  => $user->displayname }],
		template => $email_template,
		stash => {
		    model => {
			user => $user,
			media => \@sent_media,
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
    } catch {
	$c->log->error( "Error: ", $_, " sending message to user: ", $user->email );
    }
}

# A new report of shared album updates.

# For each user.
foreach my $user ( @users ) {
    try {
	my $user_json = $user->TO_JSON;

	unless ( $user->profile->setting( 'email_notifications' ) && $user->profile->setting( 'email_upload' ) ) {
	    print sprintf( "%-30s %s\n", $user->email, "does not want email" ) if ( $report );
	    next;
	}

	# Get a list of shared albums for the user.
	my $rs = $c->model( 'RDS::ContactGroup' )->search
	    ({'contact.contact_email'=>$user->email()},
	     { prefetch=>['contact',{'cgroup'=>'community'}]});

	my @communities = map { $_->cgroup->community } $rs->all;
	my @albums = map { $_->album } @communities;
	
	foreach my $album ( @albums ) {

	    # Pull up a list of all videos added to that album in the
	    # last day.
	    my ( $all_videos, $pager ) = $user->visible_media( { recent_created_days => 1, 'album_uuids[]' => [ $album->uuid() ] } );

	    # And that aren't owned by the user under consideration.
	    my @videos = ();
	    foreach my $video ( @$all_videos ) {
		if ( $video->user_id() != $user->id() ) {
		    push( @videos, $video );
		}
	    }

	    my $template = undef;

	    if ( scalar( @videos ) > 1 ) {
		$template = 'email/20-newVideosAddedToAlbum.tt';
	    } elsif ( scalar( @videos ) == 1 ) {
		$template = 'email/20-newVideoAddedToAlbum.tt';
	    } else {
		# No new videos for this user/album combination.
	    }

	    if ( defined( $template ) ) {
		my $model = {
		    user => $user_json,
		    album => VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } ),
		    video => VA::MediaFile->new->publish( $c, $videos[0], { views => ['poster'] } ),
		    url => sprintf( "%s#register?email=%s&url=%s",
				    $c->server,
				    uri_escape( $user->email() ),
				    uri_escape( '#home?aid=' . $album->uuid() ) ),
		    num => scalar( @videos )
		};

		my $res = VA::Controller::Services->send_email( $c, {
		    subject => $c->loc( "New videos in your shared [_1] Album", $album->title() ),
		    to => [ { email => $user->email(), name => $user->displayname() } ],
		    template => $template,
		    stash => $model } );
		if ( $res ) {
		    $c->log->error( "Failed to send ($days_ago) email to " . $user->email() );
		}
		
	    }
	}
    } catch {
	$c->log->error( "Error: ", $_, " sending message to user: ", $user->email() );
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
	    try {
		if ( $user->videos->count < 3 || $email_addr eq $user->email ) {
		    my $res  = VA::Controller::Services->send_email( $c, {
			subject => $c->loc( "Get started with your new VIBLIO account" ),
			to => [{ email => $user->email,
				 name  => $user->displayname }],
			template => 'email/08-dontForgetViblio.tt' });
		    if ( $res ) {
			$c->log->error( "Failed to send one-week upload reminder email to " . $user->email );
		    }
		}
	    } catch {
		$c->log->error( "Error: ", $_, " sending one-week upload reminder email to user: ", $user->email );
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
	    try {
		if ( $user->videos->count < 3 || $email_addr eq $user->email ) {
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
	    } catch {
		$c->log->error( "Error: ", $_, " sending two-week upload reminder email to user: ", $user->email );
	    }
	}
    }
}

exit 0;

END {
    # Without this, c->log output does not go out!
    $c->log->_flush;
}
