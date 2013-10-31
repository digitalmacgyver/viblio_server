package VA::Model::SQS;
use base 'Catalyst::Component';
use Amazon::SQS::Simple;

__PACKAGE__->config();

# Usage:
# try {
#   $response = $c->model( 'SQS', $queue )->SendMessage( "some string" );
# } catch {
#   $c->log->error( $_ );
# };
#

sub ACCEPT_CONTEXT {
    my $self = shift;
    my $c = shift;
    my $queue = shift;

    my $sqs = new Amazon::SQS::Simple( 
	$self->{aws_access_key_id},
	$self->{aws_secret_access_key} );

    # my $endpoint = <some function of $queue>
    #   arn:aws:sqs:$host:$user:$queue
    my $endpoint = $self->{arn} . ":$queue";

    my $q = $sqs->GetQueue( $endpoint );
    return $q;
}

1;
