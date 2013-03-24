package Catalyst::Model::DynamoDB;

use strict;
use warnings;

use base qw/ Catalyst::Model /;

use Carp qw( croak );
use Catalyst::Utils ();
use Class::C3 ();
use Net::Amazon::DynamoDB ();

our $VERSION = '0.03';


=head1 NAME

Catalyst::Model::DynamoDB - Catalyst model for Amazon's DynamoDB web service


=head1 SYNOPSIS

    # Use the helper to add an DynamoDB model to your application...
    script/myapp_create.pl create model DynamoDB DynamoDB
    
    
    # lib/MyApp/Model/DynamoDB.pm
    
    package MyApp::Model::DynamoDB;
    
    use base qw/ Catalyst::Model::DynamoDB /;
    
    __PACKAGE__->config(
        aws_access_key_id     => 'your_access_key_id',
        aws_secret_access_key => 'your_secret_access_key',
        secure                => 0,  # optional: default 0  (false)
        timeout               => 30, # optional: default 30 (seconds)
    );
    
    1;
    
    
    # In a controller...
    my $ddb = $c->model('DynamoDB');
    print ref($ddb);  # Net::Amazon::DynamoDB


=head1 DESCRIPTION

This is a L<Catalyst> model class that interfaces with Amazon's Simple Storage
Service. See the L<Net::Amazon::DynamoDB> documentation for a description of the
methods available. For more on DynamoDB visit: L<http://aws.amazon.com/ddb>


=head1 METHODS

=head2 ->new()

Instantiate a new L<Net::Amazon::DynamoDB> Model. See
L<Net::Amazon::DynamoDB's new method|Net::Amazon::DynamoDB/new> for the options available.

=cut

sub new {
    my $self  = shift->next::method(@_);
    my $class = ref($self);
    
    my ( $c, $arg_ref ) = @_;
    
    # Ensure that the required configuration is available...
    croak "->config->{access_key} must be set for $class\n"
        unless $self->{access_key};
    croak "->config->{secret_key} must be set for $class\n"
        unless $self->{secret_key};
    
    # Instantiate a new DynamoDB object...
    $self->{'.ddb'} = Net::Amazon::DynamoDB->new(
        Catalyst::Utils::merge_hashes( $arg_ref, $self->config )
    );
    
    return $self;
}


=head2 ACCEPT_CONTEXT

Return the L<Net::Amazon::DynamoDB> object. Called automatically via
C<$c-E<gt>model('DynamoDB');>

=cut

sub ACCEPT_CONTEXT {
    return shift->{'.ddb'};
}


1; # End of the module code; everything from here is documentation...
__END__

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Helper::Model::DynamoDB>, L<Net::Amazon::DynamoDB>


=head1 DEPENDENCIES

=over

=item

L<Carp>

=item

L<Catalyst::Model>

=item

L<Catalyst::Utils>

=item

L<Class::C3>

=item

L<Net::Amazon::Simple>

=back


=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalyst-model-ddb at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Model-DynamoDB>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Catalyst::Model::DynamoDB

You may also look for information at:

=over 4

=item * Catalyst::Model::DynamoDB

L<http://perlprogrammer.co.uk/modules/Catalyst::Model::DynamoDB/>

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
