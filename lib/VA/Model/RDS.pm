package VA::Model::RDS;

use strict;
use base 'Catalyst::Model::DBIC::Schema';
=perl
__PACKAGE__->config(
    schema_class => 'VA::RDSSchema',
    
    connect_info => {
        dsn => 'dbi:mysql:database=video_dev_1;host=testpub.c9azfz8yt9lz.us-west-2.rds.amazonaws.com',
        user => 'video_dev_1',
        password => 'video_dev_1',
        mysql_enable_utf8 => q{1},
        AutoCommit => q{1},
    }
);
=cut
=head1 NAME

VA::Model::RDS - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<VA>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<VA::RDSSchema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.6

=head1 AUTHOR

Ubuntu

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
