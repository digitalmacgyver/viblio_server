package VA::MediaFile::JFS;
use Moose;
use URI;

sub create {
    my ( $self, $c, $params ) = @_;

    my $mediafile = $c->model( 'DB::Mediafile' )->create({
	filename => $params->{name},
	user_id  => $params->{user_id} });
    return undef unless( $mediafile );

    # Create the main view
    my $main = $mediafile->create_related( 
	'views',
	{ filename => $params->{name},
	  mimetype => $params->{type},
	  uri => URI->new( $params->{url} )->path_query,
	  size => int($params->{size}),
	  location => 'jfs',
	  type => 'main' } );
    return undef unless( $main );

    my $client = $c->client_type();

    if ( $params->{thumbnail_url} ) {
	# Create the thumbnail view
	my $thumb = $mediafile->create_related( 
	    'views',
	    { filename => $params->{name},
	      mimetype => 'image/jpg',
	      uri => URI->new( $params->{thumbnail_url} )->path_query,
	      size => int($params->{size}),
	      location => 'jfs',
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

    my $res = $c->model( 'JFS' )->delete( $uri );
    if ( $res->code != 200 ) {
	$c->log->error( "Delete JFS FileStorage file: response status is: " . $res->response->as_string );
	return undef;
    }
    else {
	return $mediafile;
    }
}

sub uri2url {
    my( $self, $c, $view ) = @_;

    return $c->localhost( $c->model( 'JFS' )->protected_url( ( ref $view eq 'HASH' ? $view->{uri} : $view ) ) );
}

1;
