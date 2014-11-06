package VA::MediaFile::US;
use Moose;
use URI;
use Try::Tiny;
use Muck::FS::S3::QueryStringAuthGenerator;
use File::Basename;
use JSON;
use MIME::Types;
use Data::UUID;

# Create a mediafile - presently this is only intended to be called
# from the UI's per-user banner update method, or when creating a
# default album.
sub create {
    my ( $self, $c, $params ) = @_;
    
    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
        $c->log->error( "Cannot get s3 bucket: " . 
                        $c->config->{s3}->{bucket} );
        return undef;
    }

    my $user = $c->user->obj();
    unless ( $user ) {
        $c->log->error( "Cannot get user" );
        return undef;
    }

    # We pass the data only via a stash to ensure security - anyone
    # who manages to call this API must be able to manipulate the
    # stash to effect a state change. This may be an unecessary
    # precaution.
    my $data = $c->stash->{data};
    unless ( defined( $data ) && length( $data ) ) {
        $c->log->error( "No data found in the stash." );
	return undef;
    }

    my $mimetype = $params->{mimetype};
    unless ( defined( $mimetype ) && length( $mimetype ) ) {
        $c->log->error( "No mimetype parameter provided." );
	return undef;
    }
    
    my $extension = undef;
    my $mt = MIME::Types->new();
    my @extensions = $mt->type( $mimetype )->extensions();
    $extension = lc( $extensions[0] );
    unless ( defined( $extension ) && length( $extension ) ) {
	$c->log->error( "Could not determine file extension for mimetype: $mimetype." );
	return undef;
    }

    my $mediatype = 'image';
    if ( exists( $params->{mediatype} ) && length( $params->{mediatype} ) ) {
	$mediatype = $params->{mediatype};
    }
    my $assettype = 'banner';
    if ( exists( $params->{assettype} ) && length( $params->{assettype} ) ) {
	$assettype = $params->{assettype};
    }
    my $width = undef;
    if ( exists( $params->{width} ) && length( $params->{width} ) ) {
	$width = $params->{width};
    }
    my $height = undef;
    if ( exists( $params->{height} ) && length( $params->{height} ) ) {
	$height = $params->{height};
    }

    # For now no API for title, filename, description, recording_date,
    # lat, lng, etc.

    # OK - we have a stashed data stream and a mimetype, our task is
    # to:
    # A. Create an S3 object.
    # B. Create a Mediafile object of the appropriate type, with an
    # asset of the appropriate type.
    
    my $media_ug = new Data::UUID;
    
    my $media_uuid = undef;
    my $media_status = 'complete';
    if ( exists( $params->{album} ) && $params->{album} ) {
	my $album = $params->{album};
	$media_uuid = $album->uuid();
	$mediatype = $album->media_type->type();
	$media_status = $album->status();
    } else {
	$media_uuid = $media_ug->to_string( $media_ug->create() );
    }

    my $asset_ug = new Data::UUID;
    my $asset_uuid = $asset_ug->to_string( $asset_ug->create() );

    my $uri = "$media_uuid/${asset_uuid}_${assettype}.$extension";

    # Store this sucker in S3.
    my $s3_obj = $bucket->object( key => $uri, content_type => $mimetype );
    $s3_obj->put( $data );

    # Write the rows to the database.
    my $mediafile = $user->find_or_create_related( 'media', { 
	uuid => $media_uuid, media_type => $mediatype } );
    $mediafile->status( $media_status );
    $mediafile->update();
    my $asset = $mediafile->find_or_create_related( 'media_assets', {
	uuid => $asset_uuid,
	location => 'us',
	asset_type => $assettype,
	bytes => length( $data ),
	mimetype => $mimetype,
	uri => $uri,
	width => $width,
	height => $height } );

    if ( !exists( $params->{album} ) && $assettype == 'banner' ) {
	$user->banner_uuid( $mediafile->uuid() );
	$user->update();
    }

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

    # This code copied and pasted from delete above - in our case URIs
    # will only ever have one value, the value of the asset in
    # question's URI.
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
    my $expires = undef;
    my $expires_in = undef;
    if ( $params && $params->{expires} ) {
	$aws_generator->expires_in( $params->{expires} );
	$expires_in = $params->{expires};
    }
    else {
	# Have to have an expires, but if we keep it constant then the browser
	# can cache images.  So, get the current year, add 1 to it and set the
	# expire to Jan 1 of next year.
	# 
	$expires = DateTime->new(
	    year => (DateTime->now->year + 1),
	    month => 1, day => 1,
	    hour => 23, minute => 59 )->epoch;
	$aws_generator->expires( $expires );
    }
    my $url = '';
    if ( exists( $params->{'download_url'} ) && $params->{'download_url'} ) {
	my $expiration = {};
	if ( defined( $expires ) ) {
	    $expiration->{'EXPIRES'} = $expires;
	} elsif ( defined( $expires_in ) ) {
	    $expiration->{'EXPIRES_IN'} = $expires_in;
	}
	$url = VA::MediaFile->generate_signed_url( $aws_key, $aws_secret, $aws_use_https, $aws_endpoint, $aws_bucket_name, $s3key, { 'response-content-disposition' => 'attachment' }, $expiration );
    } else {
	$url = $aws_generator->get( $aws_bucket_name, $s3key );
    }
    $url =~ s/\/$aws_bucket_name\//\//g;

    #$c->log->debug( sprintf( "key=%s, secret=%s, https=%s, endpoint=%s, uri=%s, url=%s",
    #			     $aws_key, $aws_secret, $aws_use_https, $aws_endpoint,
    #			     $s3key, $url ) );
    #
    return $url;
}

1;
