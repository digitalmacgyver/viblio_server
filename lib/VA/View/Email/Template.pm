package VA::View::Email::Template;

use strict;
use base 'Catalyst::View::Email::Template';

__PACKAGE__->config(
    stash_key => 'email'
);

=head1 NAME

VA::View::Email::Template - Email View for VA

=head1 DESCRIPTION

View for sending email from VA. 

=head1 AUTHOR

Andrew Peebles,,,

=head1 SEE ALSO

L<VA>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
