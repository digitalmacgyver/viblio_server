package VA::Model::JFS;
#
# REST interface for the local File Storage server (jfs)
#
use strict;
use base 'Catalyst::Model::REST';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Escape;

sub protected_uri {
    my $self   = shift;
    my $uri    = shift;
    my $expire = shift;

    $expire = time() + (60 * 60) unless( $expire );

    my $fs_secret = $self->{secret};

    $uri = uri_unescape( $uri );

    my $md5 = md5_base64( $fs_secret . $uri . $expire );
    # escape special characters so this works as a uri
    $md5 =~ s/=//g;
    $md5 =~ s/\+/-/g;
    $md5 =~ s/\//_/g;
    return $uri . "?st=$md5&e=$expire";
}

sub protected_url {
    my $self   = shift;
    my $uri    = shift;
    my $expire = shift;

    return $self->{server} . $self->protected_uri( $uri, $expire );
}

sub get {
    my( $self, $path, $params ) = @_;
    return $self->SUPER::get( $self->protected_uri( $path ), $params );
}

sub delete {
    my( $self, $path, $params ) = @_;
    return $self->SUPER::delete( $self->protected_uri( $path ), $params );
}


1;
