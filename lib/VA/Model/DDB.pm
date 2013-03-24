package VA::Model::DDB;

use strict;
use warnings;

use base qw/ Catalyst::Model::DynamoDB /;

__PACKAGE__->config(
    access_key     => 'AKIAIJ25CQBCBCNFK7LA',
    secret_key     => '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',
    host => 'dynamodb.us-west-1.amazonaws.com',
    tables => {
	'va-users' => {
	    hash_key => 'email',
	    attributes => {
		email => 'S',
	    },
	},
    },
);


=head1 NAME

VA::Model::DDB - DynamoDB Model Class


=head1 SYNOPSIS

See L<VA>.


=head1 DESCRIPTION

DynamoDB Model Class.


=head1 AUTHOR

Andrew Peebles,,,


=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut


1;
