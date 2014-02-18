package VA::Controller::Services::Group;
use Moose;
use namespace::autoclean;
use Try::Tiny;

BEGIN { extends 'VA::Controller::Services' }

sub create :Local {
    my( $self, $c ) = @_;
    my $name = $c->req->param( 'name' );
    my $list = $c->req->param( 'list' );

    my $group = $self->create_group( $c, $name, $list );
    unless( $group ) {
	$self->status_bad_request( 
	    $c, $c->loc( 'Unable to create group [_1]', $name ) );
    }
    $c->status_ok( $c, { group => $group->TO_JSON } );
}

sub get :Local {
    my( $self, $c ) = @_;
    my $gid = $c->req->param( 'gid' );
}

__PACKAGE__->meta->make_immutable;
1;
