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

my $Usage = "VA_CONFIG_LOCAL_SUFFIX=staging|prod|local $0 --days-ago N [--page N --rows M] [--report]";

# Parse the args
#
my( $days_ago, $report, $page, $rows ) = ( 1, 0, undef, 100 );
while( my $arg = shift( @ARGV ) ) {
    if ( $arg eq '--days-ago' ) {
	$days_ago = shift( @ARGV ); next;
    }
    if ( $arg eq '--report' ) {
	$report = 1; next;
    }
    if ( $arg eq '--page' ) {
	$page = shift( @ARGV ); next;
    }
    if ( $arg eq '--rows' ) {
	$rows = shift( @ARGV ); next;
    }
}

# The email template to use.
#
my $email_template = 'email/newVideos.tt';
my $subject        = 'Videos uploaded today';
if ( $days_ago > 1 ) {
    $email_template = 'email/weeklyDigest.tt';
    $subject        = 'Videos uploaded last week';
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

#my @users;
#my $u = $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' });
#push( @users, $u );

my $pager;
if ( defined( $page ) ) {
    $pager = {
	page => $page,
	rows => $rows
    };
}
my @users = $c->model( 'RDS::User' )->search({ email => { '!=', undef } }, $pager );

if ( $report ) {
    print sprintf( "%-30s %-7s %-7s %-7s\n", "User", "Total", "Found", "Viewed" );
}

my $where = {
    -and => [
	 created_date => { '>', $dtf->format_datetime( $TARGET ) },
	 -or => [ status => 'TranscodeComplete',
		  status => 'FaceDetectComplete',
		  status => 'FaceRecognizeComplete' ]
	] };

foreach my $user ( @users ) {
    unless ( $user->profile->setting( 'email_notifications' ) && $user->profile->setting( 'email_upload' ) ) {
	print sprintf( "%-30s %s\n", $user->email, "does not want email" ) if ( $report );
	next;
    }
    my $total = $user->media->count({
	-or => [ status => 'TranscodeComplete',
		 status => 'FaceDetectComplete',
		 status => 'FaceRecognizeComplete' ] });
    my @media = $user->media->search({
	-and => [
	     'me.created_date' => { '>', $dtf->format_datetime( $TARGET ) },
	     -or => [ status => 'TranscodeComplete',
		      status => 'FaceDetectComplete',
		      status => 'FaceRecognizeComplete' ]
	    ] }, {
		prefetch => 'assets' } );

    my @published = ();
    my $view_count = 0;
    foreach my $m ( @media ) {
	push( @published, VA::MediaFile->new->publish( $c, $m ) );
	$view_count += $m->view_count;
    }

    # Only send email if there was some activity
    #
    next if ( $#published == -1 );

    if ( $report ) {
	# Just print a report
	print sprintf( "%-30s %-7s %-7s %-7s\n", 
		       $user->email, $total, ($#published + 1), $view_count );
    }
    else {
	# Send the email
	if ( send_mail( $c, $user, $total, ($#published + 1), $view_count, \@published ) ) {
	    $c->log->error( "Failed to send ($days_ago) email to " . $user->email );
	}
    }
}

exit 0;

sub send_mail {
    my( $c, $user, $total, $found, $view_count, $media ) = @_;

    my $res  = VA::Controller::Services->send_email( $c, {
	subject => $c->loc( $subject ),
	to => [{ email => $user->email,
		 name  => $user->displayname }],
	template => $email_template,
	stash => {
	    model => {
		user => $user,
		media => $media,
		vars => {
		    totalVideosInAccount => $total,
		    numVideosUploadedLastWeek => $found,
		    numVideosViewedLastWeek => $view_count,
		}
	    }
	} });
    return $res;
}

END {
    # Without this, c->log output does not go out!
    $c->log->_flush;
}
