package VA::MediaFile::US;
use Moose;
use URI;
use Try::Tiny;
use Muck::FS::S3::QueryStringAuthGenerator;
use File::Basename;
use JSON;

sub create {
    my ( $self, $c, $params ) = @_;

    my $mediafile = $c->model( 'DB::Mediafile' )->create({
        filename => $params->{filename},
        user_id  => $params->{user_id} });
    return undef unless( $mediafile );

    # Create the main view
    my $main = $mediafile->create_related( 
        'views',
        { filename => $params->{filename},
          mimetype => $params->{mimetype},
          uri => $params->{uri},
          size => int($params->{size}),
          location => 'us',
          type => 'main' } );
    return undef unless( $main );

    # The thumbnail and poster views follow a naming convension:
    #
    my( $basename, $path, $suffix ) = fileparse( $params->{uri}, qr/\.[^.]*/ );
    my $thumbnail_uri = "${path}${basename}_thumbnail.jpg";
    my $poster_uri = "${path}${basename}_poster.jpg";
    my $metadata_uri = "${path}${basename}_metadata.json";

    # Create the thumbnail view
    my $thumb = $mediafile->create_related( 
	'views',
	{ filename => $params->{filename},
	  mimetype => 'image/jpg',
	  uri => $thumbnail_uri,
	  size => int($params->{size}),
	  location => 'us',
	  type => 'thumbnail' } );
    return undef unless( $thumb );

    # Create the poster
    my $poster = $mediafile->create_related( 
	'views',
	{ filename => $params->{filename},
	  mimetype => 'image/jpg',
	  uri => $poster_uri,
	  size => int($params->{size}),
	  location => 'us',
	  type => 'poster' } );
    return undef unless( $poster );

    # Metadata
    my $metadata = $mediafile->create_related( 
	'views',
	{ filename => $params->{filename},
	  mimetype => 'application/json',
	  uri => $metadata_uri,
	  size => int($params->{size}),
	  location => 'us',
	  type => 'metadata' } );
    return undef unless( $metadata );

    return $mediafile;
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
        $uri = $mediafile->view( 'main' )->uri;
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
	if ( $mediafile->{views}->{metadata} ) {
	    $uri = $mediafile->{views}->{metadata}->{uri};
	}
	else {
	    # does not have a metadata view
	    return({});
	}
    }

    unless( $uri ) {
	my $view = $mediafile->view( 'metadata' );
	if ( $view ) {
	    $uri = $view->uri;
	}
	else {
	    # does not have metadata
	    return({});
	}
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
