package VA::Schema::ResultSet::User;
use strict;
use warnings;
use base qw( DBIx::Class::ResultSet );
sub auto_create {
    my ( $class, $hashref, $c ) = @_;
    my $user = $class->create( $hashref );
    return $user;
}
1;
