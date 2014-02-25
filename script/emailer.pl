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
    $ENV{'VA_CONFIG_LOCAL_SUFFIX'} = 'local';
}

$c = VA->new;
$c->{server_override} = $servers->{$ENV{'VA_CONFIG_LOCAL_SUFFIX'}};

while( 1 ) {
    my $message = $c->model( 'SQS', $c->config->{sqs}->{email} )->ReceiveMessage(
	MaxNumberOfMessages => 1,
	WaitTimeSeconds => 10,
	VisibilityTimeout => 30 );
    next unless( $message );

    my $msg;
    try {
	$msg = decode_json( $message->MessageBody() );
    } catch {
	$c->log->error( 'Could not decode: ' . $message->MessageBody() . ': ' . $_ );
    };

    $c->log->debug( encode_json( $msg ) );
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
	$c->log->error( 'Could not send email! ' . $message->MessageBody() );
    }

    my $res = $c->model( 'SQS', $c->config->{sqs}->{email} )->DeleteMessage( $message->ReceiptHandle() );
    if ( ! ( $res && $res->{ResponseMetadata} && $res->{ResponseMetadata}->{RequestId} ) ) {
	$c->log->error( 'Trouble deleting message: ' . $message->ReceiptHandle() );
	sleep 3;
    }
    # Without this, c->log output does not go out!
    $c->log->_flush;
}

sub send_email {
    my( $c, $opts ) = @_;

    my $from_email = 'reply@' . $c->config->{viblio_return_email_domain};
    my $from_name  = 'Viblio';

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
	$headers->{html} = $c->view( 'HTML' )->render( $c, $opts->{template} );
    }
    my $res = $c->model( 'Mandrill' )->send( $headers );
    if ( $res && $res->{status} && $res->{status} eq 'error' ) {
	$c->log->error( "Error using Mailchimp to send" );
	$c->logdump( $res );
	$c->logdump( $headers );
    }
    return ( $res && $res->{status} && $res->{status} eq 'error' );
}
