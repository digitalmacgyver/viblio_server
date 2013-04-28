package VA::Model::FS;
#
# REST interface for the local File Storage server (fs)
#
use strict;
use base 'Catalyst::Model::REST';

# A secure version of GET for the FS REST API.  Call
# this instead of get() to add the secure auth tokens
# to the access to the fs server.
#
sub get_secure {
    my ( $self, $c, $path, $params ) = @_;
    $params = {} unless( $params );
    $params->{'site-uid'} = $c->user->obj->uuid;
    $params->{'site-token'} = $c->secure_token( $params->{'site-uid'} );
    my $res = $self->get( $path, $params );
    return $res;
}

1;
