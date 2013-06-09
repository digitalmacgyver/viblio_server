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
	$c->log->error( "Cannot get s3 bucket: " . 
			$c->config->{s3}->{bucket} );
	return undef;
    }

    # All of the assets related to this media file are located in
    # s3 under the mediafile's uuid/  so this single delete should
    # blow it all away.
    #
    my $ret = $mediafile;
    my $uuid = ( $mediafile->{uuid} ? $mediafile->{uuid} : $mediafile->uuid );

    try {
	my $stream = $bucket->list({ prefix => $uuid . '/' });
	unless( $stream ) {
	    $c->log->debug( "Cannot create a bucket stream for " . $uuid . '/' );
	    return undef;
	}
	until( $stream->is_done ) {
	    foreach my $s3file ( $stream->items ) {
		$c->log->debug( "Deleting S3 file: " . $s3file->key );
		$s3file->delete;
	    }
	}
    } catch {
	$c->log->error( "Trying to delete S3 object: Caught exception for " . $uuid . ": $_" );
	$ret = undef;
    };

    return $ret;
}

sub uri2url {
    my( $self, $c, $view ) = @_;

    my $s3key = ( ref $view eq 'HASH' ? $view->{uri} : $view );

    if ( ref $view eq 'HASH' && $view->{type} eq 'thumbnail' ) {
        # Modify the uri to include proper dimensions
        my $xy = '64x64';
        if ( $c->req->param( 'thumbnails' ) ) {
            $xy = $c->req->param( 'thumbnails' );
        }
        else {
            my $client = $c->client_type();
            if ( $view->{mimetype} =~ /^image/ ) {
                $xy = $c->config->{thumbnails}->{$client}->{image};
            }
            elsif ( $view->{mimetype} =~ /^video/ ) {
                $xy = $c->config->{thumbnails}->{$client}->{video};
            }
        }

	$s3key .= '_' . $xy . '.png';
    }

    my $aws_key = $c->config->{'Model::S3'}->{aws_access_key_id};
    my $aws_secret = $c->config->{'Model::S3'}->{aws_secret_access_key};
    my $aws_use_https = $c->config->{aws_use_https} || 0;
    my $aws_bucket_name = $c->config->{s3}->{bucket};
    my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
    my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
	$aws_key, $aws_secret, $aws_use_https, $aws_endpoint );
    $aws_generator->expires_in( 60 * 60 ); # one hour

    my $url = $aws_generator->get( $aws_bucket_name, $s3key );
    $url =~ s/\/$aws_bucket_name\//\//g;
    return $url;
}

# Wowza
sub uri2urlWOW {
    my( $self, $c, $view ) = @_;

    if ( $view->{type} eq 'main' ) {
	my $url = "http://ec2-54-214-160-185.us-west-2.compute.amazonaws.com:1935/vods3/_definst_/mp4:amazons3/viblio.filepicker.io/" .
	    $view->{uri} . "/playlist.m3u8";
	return $url;
    }

    my $s3key = $view->{uri};

    if ( $view->{type} eq 'thumbnail' ) {
        # Modify the uri to include proper dimensions
        my $xy = '64x64';
        if ( $c->req->param( 'thumbnails' ) ) {
            $xy = $c->req->param( 'thumbnails' );
        }
        else {
            my $client = $c->client_type();
            if ( $view->{mimetype} =~ /^image/ ) {
                $xy = $c->config->{thumbnails}->{$client}->{image};
            }
            elsif ( $view->{mimetype} =~ /^video/ ) {
                $xy = $c->config->{thumbnails}->{$client}->{video};
            }
        }

	$s3key .= '_' . $xy . '.png';
    }

    my $aws_key = $c->config->{'Model::S3'}->{aws_access_key_id};
    my $aws_secret = $c->config->{'Model::S3'}->{aws_secret_access_key};
    my $aws_use_https = $c->config->{aws_use_https} || 0;
    my $aws_bucket_name = $c->config->{s3}->{bucket};
    my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
    my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
	$aws_key, $aws_secret, $aws_use_https, $aws_endpoint );
    $aws_generator->expires_in( 60 * 60 ); # one hour

    my $url = $aws_generator->get( $aws_bucket_name, $s3key );
    $url =~ s/\/$aws_bucket_name\//\//g;
    return $url;
}

1;
