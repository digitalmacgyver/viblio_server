package VA::Controller::Login;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Get the username and password from form
    my $username = $c->request->params->{username};
    my $password = $c->request->params->{password};
    my $realm = $c->req->params->{realm} || 'facebook';

    # Different realms require different lookup and password values
    #
    my $creds = {};
    if ( $realm eq 'db' ) {
	$creds = {
	    provider => 'local',
	    email => $username,
	    password => $password,
	};
    }
    elsif ( $realm =~ /facebook/ ) {
	$creds = {};
    }

    if ( $c->authenticate( $creds, $realm ) ) {
	$c->response->redirect(
	    $c->uri_for( '/home' ) );
	return;
    } else {
	# Set an error message
	$c->stash(error_msg => "Unable to log you in with those credencials.");
    }
    
    # If either of above don't work out, send to the login page
    $c->stash(template => 'login.tt');
}


__PACKAGE__->meta->make_immutable;

1;
