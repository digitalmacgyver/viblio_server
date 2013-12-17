package VA::Model::YesVideo;
use strict;
use base 'Catalyst::Model::REST';
use JSON;
use MIME::Base64;

sub authenticate {
    my( $self ) = @_;

    my $e = encode_base64( "$self->{client_id}:$self->{secret}", "" );
    $self->set_header( 'Authorization' => "Basic $e" );
    $self->set_persistent_header( 'Accept' => 'application/json' );
    $self->type( 'application/x-www-form-urlencoded' );

    my $r = $self->post( '/oauth/token', { grant_type => 'client_credentials'} );
    if ( $r->code == 200 ) {
	if ( $r->data && $r->data->{access_token} ) {
	    $self->{access_token} = $r->data->{access_token};
	    $self->set_persistent_header( 'Authorization:Bearer', $self->{access_token} );
	    return $self;
	}
	else {
	    return undef;
	}
    }
    else {
	return undef;
    }
}

1;
