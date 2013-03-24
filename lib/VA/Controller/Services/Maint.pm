package VA::Controller::Services::Maint;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

sub base :Chained("/") :PathPart("services/maint") :CaptureArgs(0) {
    my( $self, $c ) = @_;
    unless ( $c->check_user_roles( 'tester' ) ) {
	$self->status_forbidden( $c, $c->user->email . ", You do not have permission to access this service." );
    }
}

sub delete_user :Chained("base") :PathPart("delete_user") {
    my $self = shift;
    my $c    = shift;
    my $args = $self->parse_args
	( $c,
	  [ uid => undef,
	  ],
	  @_ );
    unless( $args->{uid} ) {
	$self->status_bad_request
	    ( $c, $c->loc( "Missing required field: [_1]", 'uid' ) );
    }

    my $user = $c->model( 'DB::User' )->find({ id => $args->{uid} });
    unless( $user ) {
	$user = $c->model( 'DB::User' )->find({ email => $args->{uid} });
    }
    unless( $user ) {
	$self->status_bad_request
	    ( $c, $c->loc( "User '[_1]' not found", $args->{uid} ) );
    }
    $user->delete;
    $self->status_ok( $c, { deleted => $args->{uid} } );
}



__PACKAGE__->meta->make_immutable;

1;
