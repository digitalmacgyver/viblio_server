package VA::MediaFile::Facebook;
use Moose;
use URI;
use Try::Tiny;
use File::Basename;
use JSON;
use MIME::Types;

sub create {
    my ( $self, $c, $params ) = @_;
    $c->log->error( "Create not implemented for VA::MediaFile::Facebook" );
    return undef;
}

# No op.
sub delete {
    my( $self, $c, $mediafile ) = @_;
    $c->log->error( "Delete not implemented for VA::MediaFile::Facebook" );
    return undef;
}

sub metadata {
    my( $self, $c, $mediafile ) = @_;
    $c->log->error( "Metadata not implemented for VA::MediaFile::Facebook" );
    return undef;
}

sub uri2url {
    my( $self, $c, $view, $params ) = @_;

    return $view->{uri};
}

1;
