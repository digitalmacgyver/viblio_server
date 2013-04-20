package VA::MediaFile::FilePicker;
use Moose;
use URI;

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
	  location => 'fp',
	  type => 'main' } );
    return undef unless( $main );

    if ( $params->{mimetype} =~ /^image/ ) {
	# Create the thumbnail view
	my $thumb = $mediafile->create_related( 
	    'views',
	    { filename => $params->{filename},
	      mimetype => $params->{mimetype},
	      uri => $params->{url},
	      size => int($params->{size}),
	      location => 'fp',
	      type => 'thumbnail' } );
	return undef unless( $thumb );
    }

    return $mediafile;
}

sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $main = $mediafile->view( 'main' );
    my $path = URI->new( $main->uri )->path;
    my $res = $c->model( 'FP' )->delete( $path, { key => $c->config->{filepicker}->{key} } );
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
    unless( $view->{type} eq 'thumbnail' ) {
	return $view->{uri};
    }

    my ( $w, $h ) = ( 64, 64 );
    
    # request param overrides site config
    if ( $c->req->param( 'thumbnails' ) ) {
	if ( $c->req->param( 'thumbnails' ) =~ /(\d+)x(\d+)/ ) {
	    $w = $1; $h = $2;
	}
    }
    else {
	my $client = $c->client_type();
	my $tsize = $c->config->{thumbnails}->{$client}->{image};
	if ( $tsize =~ /(\d+)x(\d+)/ ) {
	    $w = $1; $h = $2;
	}
    }

    return $view->{uri} . "/convert?w=${w}&h=${h}&fit=scale";
}

1;
