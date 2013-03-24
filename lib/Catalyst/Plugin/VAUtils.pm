package Catalyst::Plugin::VAUtils;
use strict;
use warnings;

# Utility functions that get attached to $c

use Class::C3;
use Set::Object         ();
use Scalar::Util        ();
use Catalyst::Exception ();

use Data::Dumper;

sub logdump {
    my( $c, $var ) = @_;
    $c->log->debug( Dumper( $var ) );
}

1;

