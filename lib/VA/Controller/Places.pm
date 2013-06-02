package VA::Controller::Places;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # The default template for this action will be rendered:
    # templates/places/index.tt

    $c->stash->{places_active} = 'active';
}


__PACKAGE__->meta->make_immutable;

1;
