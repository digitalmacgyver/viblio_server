package Catalyst::Authentication::Credential::ViblioToken;
use Moose;
use namespace::autoclean;

with 'MooseX::Emulate::Class::Accessor::Fast';

use Scalar::Util        ();
use Catalyst::Exception ();
use Digest              ();

__PACKAGE__->mk_accessors(qw/_config realm/);

sub new {
    my ($class, $config, $app, $realm) = @_;

    # Note _config is horrible back compat hackery!
    my $self = { _config => $config };
    bless $self, $class;
    $self->realm($realm);
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;
    my $access_token = $authinfo->{access_token};

    my $user_obj = $realm->find_user({access_token=>$access_token},$c);
    if ( $user_obj ) {
	return $user_obj;
    }
    else {
	$c->log->debug( 'Unable to lookup user user by access_token' );
	return;
    }
}

__PACKAGE__;
__END__
