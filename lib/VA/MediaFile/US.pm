package VA::MediaFile::US;
use Moose;
use URI;
use Try::Tiny;
use Muck::FS::S3::QueryStringAuthGenerator;
use File::Basename;
use JSON;
use MIME::Types;

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

    # Collect all the uri's (s3 keys) from all the assets that have
    # them, except for faces.  We never want to delete a face
    #
    my @uris = ();
    if ( ref $mediafile eq 'HASH' ) {
	foreach my $view ( keys( %{$mediafile->{views}} ) ) {
	    push( @uris, $mediafile->{views}->{$view}->{uri} ) unless
		( $view eq 'face' );
	}
    }
    else {
	my @assets = $mediafile->assets->search({ 'asset_type.type' => { '!=', 'face' }},
						{ prefetch => 'asset_type' });
	@uris = map { $_->uri } @assets;
    }
    
    my $ret = $mediafile;

    try {
	foreach my $uri ( @uris ) {
	    my $o = $bucket->object( key => $uri );
	    if ( $o ) {
		$o->delete;
	    }
	}
    } catch { 
        $c->log->error( "Trying to delete S3 object: $_" );
        $ret = undef;
    };

    return $ret;
}

# Just delete a single asset.
sub delete_asset {
    my( $self, $c, $asset ) = @_;

    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
        $c->log->error( "Cannot get s3 bucket: " . 
                        $c->config->{s3}->{bucket} );
        return undef;
    }

    # Collect all the uri's (s3 keys) from all the assets that have
    # them, except for faces.  We never want to delete a face
    #
    my @uris = ();
    if ( ref $asset eq 'HASH' ) {
	push( @uris, $asset->{uri} );
    }
    else {
	push( @uris, $asset->uri() );
    }
    
    my $ret = $asset;

    try {
	foreach my $uri ( @uris ) {
	    my $o = $bucket->object( key => $uri );
	    if ( $o ) {
		$o->delete;
	    }
	}
    } catch { 
        $c->log->error( "Error trying to delete S3 object: $_" );
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

    if ( $params->{use_cf} ) {
	return $c->cf_sign( $s3key, {
	    stream => 0,
	    expires => ( $params && $params->{expires} ? $params->{expires} : $c->config->{s3}->{expires} ),
	});
    }

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
    if ( $params && defined($params->{bucket}) ) {
	$aws_bucket_name = $params->{bucket};
    }
    my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
    my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
        $aws_key, $aws_secret, $aws_use_https, $aws_endpoint );
    if ( $params && $params->{expires} ) {
	$aws_generator->expires_in( $params->{expires} );
    }
    else {
	# Have to have an expires, but if we keep it constant then the browser
	# can cache images.  So, get the current year, add 1 to it and set the
	# expire to Jan 1 of next year.
	# 
	$aws_generator->expires( DateTime->new(
				     year => (DateTime->now->year + 1),
				     month => 1, day => 1,
				     hour => 23, minute => 59 )->epoch );
    }
    my $url = $aws_generator->get( $aws_bucket_name, $s3key );
    $url =~ s/\/$aws_bucket_name\//\//g;

    #$c->log->debug( sprintf( "key=%s, secret=%s, https=%s, endpoint=%s, uri=%s, url=%s",
    #			     $aws_key, $aws_secret, $aws_use_https, $aws_endpoint,
    #			     $s3key, $url ) );
    #
    return $url;
}

1;
