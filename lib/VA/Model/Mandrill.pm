package VA::Model::Mandrill;

use strict;
use base 'Catalyst::Model::REST';
use JSON;
use Digest::SHA qw(hmac_sha1 hmac_sha1_base64);

sub authenticate {
    my( $self, $c ) = @_;

    my $signed_data = $c->req->uri;
    # Because nginx is resolving https and proxying to
    # me as http, I need to turn this uri back into https
    # so the signing works!
    $signed_data =~ s/^http:/https:/g;

    foreach my $key ( sort keys %{$c->req->body_params} ) {
	$signed_data .= $key;
	$signed_data .= $c->req->body_params->{$key};
    }

    # Ok this is dubious, but I've sort of learned by trial and
    # error to remove this padding stuff.  
    my $mandrill = $c->req->header( 'X-Mandrill-Signature' );
    $mandrill =~ s/==$//g;
    $mandrill =~ s/=$//g;

    return( $mandrill eq hmac_sha1_base64( $signed_data, $self->{webhook_key} ) );
}

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
