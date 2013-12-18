package VA::Model::YesVideo;
use strict;
use base 'Catalyst::Model::REST';
use JSON;
use MIME::Base64;

=head1 YesVideo DVD Creation

Interact with the web service API of Yes Video, a service for
creating DVDs or Blueray disks with video files or data files.

Usage:

  my $yv = $c->model( 'YesVideo' )->authenticate
  unless( $yv ) {
    return 'Unable to reach/authenticate with Yes Video';
  }
  my $res = $yv->post( '/api/v1/collections', { type => 'dvd_4_7g' } );
  if ( $res->code == 200 ) {
    print encode_json( $res->data );
  }

See http://aas.yesvideo.com/docs/api for a complete description of the
API available.

=cut

sub authenticate {
    my( $self ) = @_;

    return $self if ( $self->{access_token} );

    my $e = encode_base64( "$self->{client_id}:$self->{secret}", "" );
    $self->set_header( 'Authorization' => "Basic $e" );
    $self->set_persistent_header( 'Accept' => 'application/json' );
    $self->type( 'application/x-www-form-urlencoded' );

    my $r = $self->post( '/oauth/token', { grant_type => 'client_credentials'} );
    if ( $r->code == 200 ) {
	if ( $r->data && $r->data->{access_token} ) {
	    $self->{access_token} = $r->data->{access_token};
	    $self->set_persistent_header( 'Authorization', "Bearer $self->{access_token}" );
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
