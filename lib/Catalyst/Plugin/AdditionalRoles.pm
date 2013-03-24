package Catalyst::Plugin::AdditionalRoles;
use strict;
use warnings;

#
#    AdditionalRoles
#    Authorization::Roles
#
# THE ORDER IS IMPORTANT!!  This plugin allows you to
# define additional roles that the Authorization::Roles
# would not otherwise find.  These roles go into your
# yml file like:
#
# roles:
#   admin: 
#     - peebles
#

use Class::C3;
use Set::Object         ();
use Scalar::Util        ();
use Catalyst::Exception ();

sub assert_user_roles {
    my ($c, @roles ) = @_;

    my $user;

    if ( Scalar::Util::blessed( $roles[0] )
        && $roles[0]->isa("Catalyst::Plugin::Authentication::User") )
    {
        $user = shift @roles;
    }

    $user ||= $c->user;

    unless ( $user ) {
        Catalyst::Exception->throw(
            "No logged in user, and none supplied as argument");
    }

    # check if in addition roles
    my $have = Set::Object->new( find_additional_roles( $c, $user->email ) );
    my $need = Set::Object->new(@roles);

    if ( $have->superset($need) ) {
        $c->log->debug("Additional Role granted: @roles") if $c->debug;
        return 1;
    }

    return $c->next::method( $user, @roles );
}

sub assert_any_user_role {
    my ( $c, @roles ) = @_;

    my $user;

    if ( Scalar::Util::blessed( $roles[0] )
        && $roles[0]->isa("Catalyst::Plugin::Authentication::User") )
    {
        $user = shift @roles;
    }

    $user ||= $c->user;

    unless ( $user ) {
        Catalyst::Exception->throw(
            "No logged in user, and none supplied as argument");
    }

    # check if in addition roles
    my $have = Set::Object->new( find_additional_roles( $c, $user->email ) );
    my $need = Set::Object->new(@roles);

    if ( $have->intersection($need)->size > 0 ) {
        $c->log->debug("At least one additional role granted: @roles") if $c->debug;
        return 1;
    }

    return $c->next::method( $user, @roles );
}

sub find_additional_roles {
    my ( $c, $username ) = @_;

    my @roles = ();
    foreach my $role( keys( %{$c->config->{roles}} ) ) {
        my @users = @{$c->config->{roles}->{$role}};
        foreach my $user ( @users ) {
            if ( $user eq $username ) {
                push( @roles, $role );
                last;
            }
        }
    }
    return @roles;
}

1;
