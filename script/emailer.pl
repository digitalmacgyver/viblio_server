#!/usr/bin/env perl
#
# This server goes into a loop listening for messages on an Amazon SQS
# queue.  These messages are requests to send an email, and are sent by
# the va_server.pl server.
#
use lib "lib";
use Data::Dumper;
use VA;
use Try::Tiny;
use JSON;

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
    $ENV{'VA_CONFIG_LOCAL_SUFFIX'} = 'staging';
}

$c = VA->new;
$c->{server_override} = $servers->{$ENV{'VA_CONFIG_LOCAL_SUFFIX'}};

# Change the logger so it does not clobber viblio's
$c->log( Log::Dispatch->new );

$c->log->add( Log::Dispatch::File->new( 
		  name => 'emailer', 
		  min_level => 'debug', 
		  filename => '/tmp/emailer.log' ) );

$c->log->add( Log::Dispatch::Syslog->new( 
		  name => 'syslog', 
		  min_level => 'info',
		  format_o => '%m %X',
		  ident =>  => 'emailer' ) );

$c->log->add( Log::Dispatch::Screen::Color->new( 
    name => 'screen',
    min_level => 'debug',
    format => '[%p] %m at %F line %L%n',
    newline => 1,
    color => {
      debug => {
        text => 'green' },
      info => {
        text => 'red' },
      error => {
        background => 'red' },
      alert => {
        text => 'red',
        background => 'white' },
      warning => {
        text => 'red',
        background => 'white',
        bold => 1 }
}));

while( 1 ) {
    my $message;
    try {
	$message = $c->model( 'SQS', $c->config->{sqs}->{email} )->ReceiveMessage(
	    MaxNumberOfMessages => 1,
	    WaitTimeSeconds => 10,
	    VisibilityTimeout => 30 );
    } catch {
	$c->log->error( 'SQS ReceiveMessage bombed: ' . $_ . "\n" );
	# $c->log->_flush;
	undef $message;
    };
    next unless( $message );

    my $msg;
    try {
	$msg = decode_json( $message->MessageBody() );
    } catch {
	if ( $message->can( 'MessageBody' ) ) {
	    $c->log->error( 'Emailer: Could not decode: ' . 
			    $message->MessageBody() . ': ' . $_ . "\n" );
	}
	else {
	    $c->log->error( 'Emailer: No MessageBody: ' . $_ . "\n" );
	}
	# $c->log->_flush;
	next;
    };

    #
    # A decoded message is going to look something like this:
    #
    # {	subject => $c->loc( $subject ),
    #	to => [{ email => $user->email,
    #		 name  => $user->displayname }],
    #	template => $email_template,
    #	stash => {
    #	    model => {
    #		user => $user,
    #		media => $media,
    #		faces => $faces,
    #		vars => {
    #		    totalVideosInAccount => $total,
    #		    numVideosUploadedLastWeek => $found,
    #		    numVideosViewedLastWeek => $view_count,
    #		}
    #	    }
    #	} 
    # }
    #
    # The UI server will construct a message like this and enqueue it
    # to the Amazon queue.  This server then dequeues those and does
    # the actual sending.  This is to offload the UI server from actually
    # performing email sends, which can be time expensive.
    #
    if ( send_email( $c, $msg ) ) {
	$c->log->error( 'Emailer: Could not send email! ' . $message->MessageBody() . "\n" );
    }
    else {
	$c->log->info( 
	    sprintf( "Emailer: Sent email: Subject: '%s': To: %s\n",
		     ( $msg->{subject} || 'Unknown' ),
		     ( $msg->{to} ? encode_json( $msg->{to} ) : 'Unknown' ) ));
    }

    my $res = $c->model( 'SQS', $c->config->{sqs}->{email} )->DeleteMessage( $message->ReceiptHandle() );
    if ( ! ( $res && $res->{ResponseMetadata} && $res->{ResponseMetadata}->{RequestId} ) ) {
	$c->log->error( 'Emailer: Trouble deleting message: ' . $message->ReceiptHandle() . "\n" );
	sleep 3;
    }
    # Without this, c->log output does not go out!
    # $c->log->_flush;
}

sub send_email {
    my( $c, $opts ) = @_;

    my $from_email = 'reply@' . $c->config->{viblio_return_email_domain};
    my $from_name  = 'VIBLIO';

    if ( $opts->{from} ) {
	$from_email = $opts->{from}->{email} || $from_email;
	$from_name  = $opts->{from}->{name}  || $from_name;
    }

    my $headers = {
	subject => $opts->{subject} || 'No Subject',
	from_email => $from_email,
	from_name => $from_name,
	to => $opts->{to},
	headers => {
	    'Reply-To' => $from_email,
	},
	inline_css => 1,
    };
    $c->stash->{no_wrapper} = 1;
    foreach my $key ( keys( %{$opts->{stash}} ) ) {
	$c->stash->{$key} = $opts->{stash}->{$key};
    }
    if ( $opts->{body} ) {
	$headers->{html} = $opts->{body};
    }
    else {
	try {
	    $headers->{html} = $c->view( 'HTML' )->render( $c, $opts->{template} );
	} catch {
	    $c->log->error( "Could not render $opts->{template}: $_\n" );
	    return 1;
	};
    }
    my $res = $c->model( 'Mandrill' )->send( $headers );
    if ( $res && $res->{status} && $res->{status} eq 'error' ) {
	$c->log->error( "Emailer: Error using Mailchimp to send\n" );
	# $c->logdump( $res );
	# $c->logdump( $headers );
    }
    return ( $res && $res->{status} && $res->{status} eq 'error' );
}
