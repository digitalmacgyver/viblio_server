package VA::Model::Mandrill;

use strict;
use base 'Catalyst::Model::REST';
use JSON;

sub info {
    my( $self ) = @_;
    my $res = $self->post( '/users/info.json', { key => $self->{key} } );
    if ( $res->code != 200 ) {
	return from_json( $res->response->content );
    }
    else {
	return $res->data;
    }
}

sub send {
    my( $self, $message ) = @_;
    my $data = {
	key => $self->{key},
	message => $message };
    my $res = $self->post( '/messages/send.json', $data );
    if ( $res->code != 200 ) {
	return from_json( $res->response->content );
    }
    else {
	return ${$res->data}[0];
    }
}

1;
