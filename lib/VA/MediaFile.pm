package VA::MediaFile;
use Moose;
use Module::Find;
usesub VA::MediaFile;

# This is a proxy class, not a super class.  The methods
# called here will proxy to the class indicated by the
# location of the media file.

# create() will delegate to a location-based class that
# creates and returns a real DB::Mediafile object.
#
sub create {
    my ( $self, $c, $params ) = @_;

    my $location = $params->{location};
    unless( $location ) {
	$self->error( $c, "Cannot determine location of this media file" );
	return undef;
    }
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
	$self->error( $c, "Cannot determine type of this media file" );
	return undef;
    }
    my $fp = new $klass;
    my $mediafile = $fp->create( $c, $c->req->params );
    return $mediafile;
}

# Delete can take either a DB::Mediafile or a published mediafile (JSON)
# and delegates to a location-based class to delete any persistent storage
# related to the mediafile views.  It does not delete the passed in
# $mediafile object.
#
sub delete {
    my( $self, $c, $mediafile ) = @_;
    my $location;
    if ( ref $mediafile eq 'HASH' ) {
	$location = $mediafile->{views}->{main}->{location};
    }
    else {
	$location = $mediafile->view( 'main' )->location;
    }
    unless( $location ) {
	$self->error( $c, "Cannot determine location of this media file" );
	return undef;
    }
    my $klass = $c->config->{mediafile}->{$location};
    unless( $klass ) {
	$self->error( $c, "Cannot determine type of this media file" );
	return undef;
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
	if ( ! $klass ) {
	    $DB::single = 1;
	}
	my $fp = new $klass;
	$mf_json->{'views'}->{$view->type}->{url} = 
	    $fp->uri2url( $c, $mf_json->{'views'}->{$view->type} );
    }
    return $mf_json;
}

# Log or return error messages
sub error {
    my( $self, $c, $msg ) = @_;
    if ( $msg ) {
	$self->{emsg} = $msg;
	$c->log->error( "VA::MediaFile ERROR: $msg" );
    }
    else {
	return $self->{emsg};
    }
}

1;
