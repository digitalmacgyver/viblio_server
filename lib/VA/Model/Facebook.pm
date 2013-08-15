package VA::Model::Facebook;
use base 'Catalyst::Component';
use Facebook::Graph;

__PACKAGE__->config();

sub ACCEPT_CONTEXT {
    my $self = shift;
    my $c = shift;
    my @args = @_;

    # my $token = $c->session->{fb_token};

    my $token;
    if ( $#args == 0 ) {
	$token = $args[0];
    }
    unless( $token ) {
	my $link = $c->user->links->find({provider=>'facebook'});
	if ( $link ) {
	    my $data = $link->data;
	    $token = $data->{access_token};
	}
    }
    unless( $token ) {
	$token = $c->session->{fb_token};
    }

    unless( $token ) {
	$c->log->error( "Facebook token missing from session!" );
	return undef;
    }

    my $fb = Facebook::Graph->new;
    unless( $fb ) {
	$c->log->error( "Cannot instanciate a Facebook::Graph!" );
	return undef;
    }

    $fb->access_token( $token );
    return $fb;
}

1;
