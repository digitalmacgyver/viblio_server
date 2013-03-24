package VA::Controller::Logout;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Clear the user's state
    $c->logout;
    
    # Send the user to the starting point
    $c->response->redirect($c->uri_for('/'));
}

__PACKAGE__->meta->make_immutable;

1;
