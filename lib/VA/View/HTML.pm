package VA::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    render_die => 1,
);

=head1 NAME

VA::View::HTML - TT View for VA

=head1 DESCRIPTION

TT View for VA.

=head1 SEE ALSO

L<VA>

=head1 AUTHOR

Andrew Peebles,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
