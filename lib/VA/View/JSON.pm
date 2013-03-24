package VA::View::JSON;

use strict;
use base 'Catalyst::View::JSON';

use JSON::XS ();

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

sub encode_json {
    my( $self, $c, $data ) = @_;
    $encoder->encode( $data );
}

1;
