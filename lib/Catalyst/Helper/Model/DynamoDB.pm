package Catalyst::Helper::Model::DynamoDB;

use strict;
use warnings;

use Carp qw( croak );

our $VERSION = '0.01';


=head1 NAME

Catalyst::Helper::Model::DynamoDB - Helper for DynamoDB Catalyst models


=head1 SYNOPSIS

    script/myapp_create.pl model ModelName DynamoDB [ key=your_key secret=your_secret ] [ secure ] [ timeout=30 ]


=head1 DESCRIPTION

Use this module to set up a new L<Catalyst::Model::DynamoDB> model for your Catalyst
application.

=head2 Arguments

    ModelName is the short name for the Model class being generated (eg. "DynamoDB")

    key and secret correspond to your Amazon Web Services account's Access Key
    ID and Secret Access Key respectively. For more information see:
    L<http://aws.amazon.com/s3>

    The presence of secure indicates that your Model should use SSL-encrypted
    connections when talking to DynamoDB.

    Explicitly setting timeout (in seconds) overrides the default of 30.


=head1 METHODS

=head2 mk_compclass

This method takes the given arguments and generates a Catalyst::Model::DynamoDB
model for your application.

=cut

sub mk_compclass {
    my ( $self, $helper, @options ) = @_;
    
    # Extract the arguments...
    foreach (@options) {
        if ( /^key=(.+)$/ ) {
            $helper->{aws_key} = $1;
        }
        elsif ( /^secret=(.+)$/ ) {
            $helper->{aws_secret} = $1;
        }
        elsif ( /^read_consistent$/ ) {
            $helper->{read_consistent} = 1;
        }
        elsif ( /^host=(.+)$/ ) {
            $helper->{host} = $1;
        }
    }
    
    $helper->{config_encountered} = (
        exists $helper->{aws_key}
     || exists $helper->{aws_secret}
     || exists $helper->{read_consistent}
     || exists $helper->{host}
    );
    
    $helper->render_file( 's3class', $helper->{file} );
}


=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Helper>, L<Catalyst::Model::DynamoDB>


=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalyst-model-s3 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Model-DynamoDB>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Catalyst::Helper::Model::DynamoDB

You may also look for information at:

=over 4

=item * Catalyst::Model::DynamoDB

L<http://perlprogrammer.co.uk/module/Catalyst::Model::DynamoDB/>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Catalyst-Model-DynamoDB/>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Model-DynamoDB>

=item * Search CPAN

L<http://search.cpan.org/dist/Catalyst-Model-DynamoDB/>

=back


=head1 AUTHOR

Dave Cardwell <dcardwell@cpan.org>


=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007 Dave Cardwell. All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut


1;
__DATA__
=begin pod_to_ignore

__s3class__
package [% class %];

use strict;
use warnings;

use base qw/ Catalyst::Model::DynamoDB /;

[%- IF config_encountered %]
__PACKAGE__->config(
    [% "access_key     => '" _ aws_key    _ "',\n" IF aws_key    -%]
    [% "secret_key     => '" _ aws_secret _ "',\n" IF aws_secret -%]
    [% 'read_consistent       => '  _ read_consistent   _ ",\n"  IF read_consistent     -%]
    [% "host => '" _ host _ "',\n" IF host -%]
);
[%- END %]


=head1 NAME

[% class %] - DynamoDB Model Class


=head1 SYNOPSIS

See L<[% app %]>.


=head1 DESCRIPTION

DynamoDB Model Class.


=head1 AUTHOR

[% author %]


=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut


1;
