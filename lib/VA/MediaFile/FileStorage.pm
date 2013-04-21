package VA::MediaFile::FileStorage;
use Moose;
use URI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

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
	  uri => $params->{url},
	  size => int($params->{size}),
	  location => 'fs',
	  type => 'main' } );
    return undef unless( $main );

    my $client = $c->client_type();

    if ( $params->{mimetype} =~ /^image/ ) {
	# Create the thumbnail view
	my $thumb = $mediafile->create_related( 
	    'views',
	    { filename => $params->{filename},
	      mimetype => $params->{mimetype},
	      uri => '/thumb' . $params->{url},
	      size => int($params->{size}),
	      location => 'fs',
	      type => 'thumbnail' } );
	return undef unless( $thumb );
    }

    if ( $params->{mimetype} =~ /^video/ ) {
	# Create the thumbnail view
	my $thumb = $mediafile->create_related( 
	    'views',
	    { filename => $params->{filename},
	      mimetype => $params->{mimetype},
	      uri => '/thumb' . $params->{url},
	      size => int($params->{size}),
	      location => 'fs',
	      type => 'thumbnail' } );
	return undef unless( $thumb );
    }

    return $mediafile;
}

sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $uri;
    if ( ref $mediafile eq 'HASH' ) {
	$uri = $mediafile->{views}->{main}->{uri};
    }
    else {
	$uri = $mediafile->view( 'main' )->uri;
    }
    my $res = $c->model( 'FS' )->get( '/delete', { path => $uri } );
    if ( $res->code != 200 ) {
	$c->log->error( "Delete FileStorage file: response status is: " . $res->response->as_string );
	return undef;
    }
    else {
	return $mediafile;
    }
}

sub uri2url {
    my( $self, $c, $view ) = @_;

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

	if ( $view->{mimetype} =~ /^image/ ) {
	    $view->{uri} .= "?dim=$xy";
	}
	elsif ( $view->{mimetype} =~ /^video/ ) {
	    $view->{uri} .= ".png?vim=$xy";
	}
	
    }

    if ( $view->{uri} =~ /^\/thumb/ ) {
	return $c->storage_server . $view->{uri};
    }
    my $fs_secret = $c->config->{file_storage}->{secret};
    my $expire = time() + (60 * 60);
    my $md5 = md5_base64( $fs_secret . $view->{uri} . $expire );
    # escape special characters so this works as a url
    $md5 =~ s/=//g;
    $md5 =~ s/\+/-/g;
    $md5 =~ s/\//_/g;
    return $c->storage_server . $view->{uri} . "?st=$md5&e=$expire";
}

1;
