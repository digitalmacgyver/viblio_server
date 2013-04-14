package VA::MediaFile;
use Moose;
use Module::Find;
usesub VA::MediaFile;

# Different types of media file sources will
# likely override this function; see MediaFile::FilePicker
# for an example.
#
sub create {
    my ( $self, $c, $params ) = @_;

    my $location = $params->{location};
    unless( $location ) {
        $self->status_bad_request(
            $c, $c->loc( "Cannot determine location of this media file" ));
    }
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
        $self->status_bad_request(
            $c, $c->loc( "Cannot determine type of this media file" ));
    }
    my $fp = new $klass;
    my $mediafile = $fp->create( $c, $c->req->params );
    return $mediafile;
}

# Media sources will override this, if they need
# to do something extra-ordinary to remove the 
# media.
#
sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $location = $mediafile->view( 'main' )->location;
    unless( $location ) {
        $self->status_bad_request(
            $c, $c->loc( "Cannot determine location of this media file" ));
    }
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
        $self->status_bad_request(
            $c, $c->loc( "Cannot determine type of this media file" ));
    }
    my $fp = new $klass;
    return $fp->delete( $c, $mediafile );
}

# Standard way to "publish" a media file to
# a client in JSON.  Convert the array of
# views into a hash who's keys are the view
# types.  This makes it easier for a client
# to access the information they need, for example:
#
#  <img src="{{ media.views.thumbnail.url }}" />
#
# This also transforms URIs to URLs in a view 
# location -specific way
sub publish {
    my( $self, $c, $mediafile ) = @_;
    my $mf_json = $mediafile->TO_JSON;
    $mf_json->{'views'} = {};
    my @views = $mediafile->views;
    foreach my $view ( @views ) {
	$mf_json->{'views'}->{$view->type} = $view->TO_JSON;
	# Generate the URL from the URI
	my $location = $mf_json->{'views'}->{$view->type}->{location};
	my $klass = $c->config->{mediafile}->{$location};
	my $fp = new $klass;
	$mf_json->{'views'}->{$view->type}->{url} = 
	    $fp->uri2url( $c, $mf_json->{'views'}->{$view->type} );
    }
    return $mf_json;
}

1;
