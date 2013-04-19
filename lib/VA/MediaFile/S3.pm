package VA::MediaFile::S3;
use Moose;
use URI;
use Try::Tiny;
use Muck::FS::S3::QueryStringAuthGenerator;

sub create {
    my ( $self, $c, $params ) = @_;
    return undef;
}

# Delete all views stored on S3 for this mediafile
sub delete {
    my( $self, $c, $mediafile ) = @_;

    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
	$c->log->debug( "Cannot get s3 bucket: " . 
			$c->config->{s3}->{bucket} );
	return undef;
    }

    my $ret = $mediafile;
    foreach my $view ( $mediafile->views ) {
	my $s3file = $bucket->object( key => $view->uri );
	unless( $s3file ) {
	    $c->log->debug( "Cannot get s3 object for " . $view->uri );
	    $ret = undef;
	    next;
	}
	try {
	    $s3file->delete;
	} catch {
	    $c->log->debug( "Caught exception for " . $view->uri . ": $_" );
	    $ret = undef;
	};
    }

    return $ret;
}

sub uri2url {
    my( $self, $c, $view ) = @_;

    my $aws_key = $c->config->{'Model::S3'}->{aws_access_key_id};
    my $aws_secret = $c->config->{'Model::S3'}->{aws_secret_access_key};
    my $aws_use_https = $c->config->{aws_use_https} || 0;
    my $aws_bucket_name = $c->config->{s3}->{bucket};
    my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
    my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
	$aws_key, $aws_secret, $aws_use_https, $aws_endpoint );
    $aws_generator->expires_in( 60 * 60 ); # one hour

    my $url = $aws_generator->get( $aws_bucket_name, $view->{uri} );
    $url =~ s/\/$aws_bucket_name\//\//g;
    return $url;
}

1;
