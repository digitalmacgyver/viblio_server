package VA::Controller::Create;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # The default template for this action will be rendered:
    # templates/create/index.tt

    $c->stash->{create_active} = 'active';
}


__PACKAGE__->meta->make_immutable;

1;
