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

$c = VA->new;

my $message = {
    subject => 'This is a TEST',
    to => [{ email => 'aqpeeb@gmail.com',
	     name  => 'Andrew Peebles' }],
    template => 'email/test.tt',
    stash => {
	model => {
	    user => {
		displayname => 'Andrew Peebles',
	    },
	    vars => {
		foo => 'Bar',
	    },
	},
    }
};

my $res = $c->model( 'SQS', $c->config->{sqs}->{email} )
    ->SendMessage( encode_json( $message ) );
print Dumper $res;
