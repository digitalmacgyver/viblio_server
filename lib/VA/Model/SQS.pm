package VA::Model::SQS;
use base 'Catalyst::Component';
use Amazon::SQS::Simple;

__PACKAGE__->config();

# Usage:
# try {
#   $response = $c->model( 'SQS', $c->config->{sqs}->{facebook_link} )->SendMessage( "some string" );
# } catch {
#   $c->log->error( $_ );
# };
#

sub ACCEPT_CONTEXT {
    my $self = shift;
    my $c = shift;
    my $endpoint = shift;

    my $sqs = new Amazon::SQS::Simple( 
	$c->config->{'Model::S3'}->{aws_access_key_id},
	$c->config->{'Model::S3'}->{aws_secret_access_key} );

    my $q = $sqs->GetQueue( $endpoint );
    return $q;
}

1;
