package Catalyst::Plugin::VAUtils;
use strict;
use warnings;

# Utility functions that get attached to $c

use Class::C3;
use Set::Object         ();
use Scalar::Util        ();
use Catalyst::Exception ();

use Data::Dumper;

# Use Data::Dumper to print an object into the
# debug log.
#
sub logdump {
    my( $c, $var ) = @_;
    $c->log->debug( Dumper( $var ) );
}

# Template can call this to get the url to the message queue
# server.  If the 'mq_server' variable is not in the global
# config, then derive one based on *this* server; in other words,
# assume the message queue server is running on this host on
# its default port (3002).
sub message_server {
    my( $c ) = @_;
    if ( $c->config->{message_queue}->{server} ) {
	return $c->config->{message_queue}->{server};
    }
    else {
	my $host = $c->req->uri->host || 'unknown';
	$host =~ s/:[\d+]$//g;
	$host .= ":3002";
	return $c->req->uri->scheme . '://' . $host;
    }
}

# Again, for the local file storage server
sub storage_server {
    my( $c ) = @_;
    if ( $c->config->{file_storage}->{server} ) {
	return $c->config->{file_storage}->{server};
    }
    else {
	my $host = $c->req->uri->host || 'unknown';
	$host =~ s/:[\d+]$//g;
	$host .= ":5000";
	return $c->req->uri->scheme . '://' . $host;
    }
}

1;

