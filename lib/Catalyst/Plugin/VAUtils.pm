package Catalyst::Plugin::VAUtils;
use strict;
use warnings;

# Utility functions that get attached to $c

use Class::C3;
use Set::Object         ();
use Scalar::Util        ();
use Catalyst::Exception ();

use Data::Dumper;
use Digest::HMAC_MD5 qw(hmac_md5 hmac_md5_hex);
use URI;

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

# If the passed in host is 'http://localhost[:port]' then
# replace 'localhost' with this server's host.
#
sub localhost {
    my( $c, $host ) = @_;
    return $host unless( $host =~ /^http[s]?:\/\/localhost/ );
    my $localhost = URI->new( $c->req->uri )->host;
    $host =~ s/localhost/$localhost/g;
    return $host;
}

# Return this server's base url
#
sub server {
    my( $c ) = @_;

    if ( $c->{server_override} ) {
	my $server = $c->{server_override};
	unless( $server =~ /\/$/ ) {
	    $server .= '/';
	}
	return $server;
    }

    my $server = $c->req->base;
    my $uri = URI->new( $c->req->uri );
    my $path = $uri->path;

    $server =~ s/$path//g;
    $server =~ s/\/$//g;

    if ( $c->req->header( 'port' ) && $c->req->header( 'port' ) != 80 ) {
	$server .= ':' . $c->req->header( 'port' );
    }
    elsif ( $uri->port && $uri->port != 80 ) {
	$server .= ':' . $uri->port;
    }
    $server .= '/';
    return $server;
}

# Return the type of connected client
sub client_type {
    my( $c ) = @_;
    # should be one of 'web', 'mobile_small', 'mobile_large'
    # This code is derived from /services/NA/device_info
    my $d = $c->req->browser;
    return 'mobile_small' if ( $d->android );
    return 'mobile_small' if ( $d->ipod );
    return 'mobile_small' if ( $d->iphone );
    return 'mobile_large' if ( $d->ipad );
    return 'web';
}

# Generate a secure token to protect public apis
#
sub secure_token {
    my( $c, $data ) = @_;
    return hmac_md5_hex( $data,
			 $c->config->{file_storage}->{secret} );
}



1;

