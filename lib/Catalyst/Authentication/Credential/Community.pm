package Catalyst::Authentication::Credential::Community;
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
    my $apikey = $authinfo->{apikey};
    my $cid    = $authinfo->{cid};
    my $userid = $authinfo->{userid};
    my $uuid   = $authinfo->{uuid};  # debug

    # Lookup community by apikey, cid
    # Lookup uuid by cid, userid
    # Verify uuid is a member of community
    # call realm->find_user to get the user object

    my $user_obj = $realm->find_user({uuid=>$uuid},$c);
    if ( $user_obj ) {
	return $user_obj;
    }
    else {
	$c->log->debug( 'Unable to lookup user user in community' );
	return;
    }
}

__PACKAGE__;
__END__
