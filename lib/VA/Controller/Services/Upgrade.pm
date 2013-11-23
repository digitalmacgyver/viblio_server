package VA::Controller::Services::Upgrade;
use Moose;
use namespace::autoclean;
use VA::MediaFile::US;
use JSON::XS ();

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/upgrade/*

Services related to upgrading external applications, like the
Tray App.

=cut

sub check :Local {
    my( $self, $c ) = @_;
    my $app = $c->req->param( 'app' );
    unless( $app ) {
	$self->status_bad_request(
	    $c, $c->loc( "Missing required parameter: [_1]", "app" ) );
    }
    my $data = $c->model( 'RDS::AppConfig' )->
	find({ app => $app, current => 1 });
    if ( $data ) {
	my $hash = $data->TO_JSON;

	if ( $hash->{config} ) {
	    my $json = $encoder->decode( $hash->{config} );
	    $hash->{config} = $json;

	    ## The uri in the config struct is of the form:
	    ## bucket/key
	    my @parts = split( /\//, $hash->{config}->{uri} );
	    my $bucket = shift @parts;
	    my $key = join( '/', @parts );

	    $hash->{url} = 
		new VA::MediaFile::US()->uri2url( $c, $key, { bucket => $bucket , use_s3 => 1 } );
	}

	$self->status_ok( $c, $hash );
    }
    else {
	$self->status_ok( $c, {} );
    }
}

__PACKAGE__->meta->make_immutable;
1;
