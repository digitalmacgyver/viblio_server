package VA::MediaFile::FilePicker;
use Moose;
use URI;
extends 'VA::MediaFile';

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

    # Create the thumbnail view
    my $thumb = $mediafile->create_related( 
	'views',
	{ filename => $params->{filename},
	  mimetype => $params->{mimetype},
	  uri => $params->{url} . '/convert?w=64&h=64&fit=scale',
	  size => int($params->{size}),
	  location => 'fp',
	  type => 'thumbnail' } );
    return undef unless( $thumb );

    return $mediafile;
}

sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $main = $mediafile->view( 'main' );
    my $path = URI->new( $main->uri )->path;
    my $res = $c->model( 'FP' )->delete( $path, { key => $c->config->{filepicker}->{key} } );
    $c->log->debug( $res->response->as_string );
    return $mediafile;
}

1;
