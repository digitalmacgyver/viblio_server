package VA::Controller::Faces;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # The default template for this action will be rendered:
    # templates/faces/index.tt

    $c->stash->{faces_active} = 'active';
}


__PACKAGE__->meta->make_immutable;

1;
