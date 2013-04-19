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
	      uri => '/thumb' . $params->{url} . '?dim=' . $c->config->{thumbnails}->{$client}->{image},
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
	      uri => '/thumb' . $params->{url} . '.png?vim=' . $c->config->{thumbnails}->{$client}->{image},
	      size => int($params->{size}),
	      location => 'fs',
	      type => 'thumbnail' } );
	return undef unless( $thumb );
    }

    return $mediafile;
}

sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $main = $mediafile->view( 'main' );
    my $res = $c->model( 'FS' )->get( '/delete', { path => $main->uri } );
    $c->log->debug( $res->response->as_string );
    if ( $res->code != 200 ) {
	return undef;
    }
    else {
	return $mediafile;
    }
}

sub uri2url {
    my( $self, $c, $view ) = @_;
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
