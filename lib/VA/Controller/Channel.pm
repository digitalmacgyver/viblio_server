package VA::Controller::Channel;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # The default template for this action will be rendered:
    # templates/channel/index.tt

    $c->stash->{channel_active} = 'active';
}


__PACKAGE__->meta->make_immutable;

1;
