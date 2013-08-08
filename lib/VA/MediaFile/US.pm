package VA::MediaFile::US;
use Moose;
use URI;
use Try::Tiny;
use Muck::FS::S3::QueryStringAuthGenerator;
use File::Basename;
use JSON;

sub create {
    my ( $self, $c, $params ) = @_;
    return undef;
}

# Delete all views stored on S3 for this mediafile
sub delete {
    my( $self, $c, $mediafile ) = @_;

    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
        $c->log->error( "Cannot get s3 bucket: " . 
                        $c->config->{s3}->{bucket} );
        return undef;
    }

    my $ret = $mediafile;
    my $uri;
    if ( ref $mediafile eq 'HASH' ) {
        $uri = $mediafile->{views}->{main}->{uri};
    }
    else {
        $uri = $mediafile->asset( 'main' )->uri;
    }
    unless( $uri ) {
        $self->error( $c, "Cannot determine uri of this media file" );
        return undef;
    }

    my( $basename, $path, $suffix ) = fileparse( $uri, qr/\.[^.]*/ );

    try {
        my $stream = $bucket->list({ prefix => $path });
        unless( $stream ) {
            $c->log->debug( "Cannot create a bucket stream for " . $path );
            return undef;
        }
        until( $stream->is_done ) {
            foreach my $s3file ( $stream->items ) {
                $c->log->debug( "Deleting S3 file: " . $s3file->key );
                $s3file->delete;
            }
        }
    } catch {
        $c->log->error( "Trying to delete S3 object: Caught exception for " . $path . ": $_" );
        $ret = undef;
    };

    return $ret;
}

sub metadata {
    my( $self, $c, $mediafile ) = @_;
    my $uri;

    if ( ref $mediafile eq 'HASH' ) {
	if ( $mediafile->{views}->{main}->{metadata_uri} ) {
	    $uri = $mediafile->{views}->{main}->{metadata_uri};
	}
	else {
	    $uri = $mediafile->asset( 'main' )->metadata_uri;
	}
    }

    unless( $uri ) {
	return({});
    }

    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
	$c->log->error( 'Failed to get S3 bucket: ' . $c->config->{s3}->{bucket} );
	return undef;
    }
    my $s3 = $bucket->object( key => $uri );
    unless( $s3 ) {
	$c->log->error( 'Failed to obtain metadata' );
	return undef;
    }

    my $obj;
    try {
	my $md = $s3->get;
	if ( ! defined( $md ) || $md eq '' ) {
	    $md = "{}";
	}
	$obj = decode_json( $md );
    } catch {
	$c->log->debug( $_ );
	$c->log->error( 'Failed to parse metadata as a JSON string! ' . $_ );
	$obj = undef;
    };
    return( $obj );
}

sub uri2url {
    my( $self, $c, $view, $params ) = @_;

    my $s3key = ( ref $view eq 'HASH' ? $view->{uri} : $view );

    my $aws_key = $c->config->{'Model::S3'}->{aws_access_key_id};
    my $aws_secret = $c->config->{'Model::S3'}->{aws_secret_access_key};
    my $aws_use_https = 0;
    if ( $params && defined($params->{aws_use_https}) ) {
        $aws_use_https = $params->{aws_use_https};
    }
    elsif ( $c->config->{s3}->{aws_use_https} == 1 ) {
        $aws_use_https = 1;
    }
    my $aws_bucket_name = $c->config->{s3}->{bucket};
    my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
    my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
        $aws_key, $aws_secret, $aws_use_https, $aws_endpoint );
    $aws_generator->expires_in( ( $params && $params->{expires} ? $params->{expires} : $c->config->{s3}->{expires} ) );

    my $url = $aws_generator->get( $aws_bucket_name, $s3key );
    $url =~ s/\/$aws_bucket_name\//\//g;
    return $url;
}

1;
