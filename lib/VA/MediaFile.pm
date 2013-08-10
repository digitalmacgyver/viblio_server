package VA::MediaFile;
use Moose;
use Module::Find;
usesub VA::MediaFile;

# This is a proxy class, not a super class.  The methods
# called here will proxy to the class indicated by the
# location of the media file.

# create() will delegate to a location-based class that
# creates and returns a real RDS::Mediafile object.
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

# Delete can take either a RDS::Mediafile or a published mediafile (JSON)
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
	$location = $mediafile->asset( 'main' )->location;
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

sub metadata {
    my( $self, $c, $mediafile ) = @_;
    my $location;
    if ( ref $mediafile eq 'HASH' ) {
	$location = $mediafile->{views}->{main}->{location};
    }
    else {
	$location = $mediafile->asset( 'main' )->location;
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
    if ( $fp->can( 'metadata' ) ) {
	return $fp->metadata( $c, $mediafile );
    }
    else {
	return {};
    }
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
    my( $self, $c, $mediafile, $params ) = @_;
    my $mf_json = $mediafile->TO_JSON;
    $mf_json->{'views'} = {};
    my @views = $mediafile->assets;
    foreach my $view ( @views ) {
	my $type = $view->asset_type->type;
	my $view_json = $view->TO_JSON;

	# Generate the URL from the URI
	my $location = $view_json->{location};
	my $klass = $c->config->{mediafile}->{$location};
	my $fp = new $klass;
	$view_json->{url} = 
	    $fp->uri2url( $c, $view_json, $params );

	if ( defined( $mf_json->{'views'}->{$type} ) ) {
	    if ( ref $mf_json->{'views'}->{$type} eq 'ARRAY' ) {
		push( @{$mf_json->{'views'}->{$type}}, $view_json );
	    }
	    else {
		my $tmp = $mf_json->{'views'}->{$type};
		$mf_json->{'views'}->{$type} = [];
		push( @{$mf_json->{'views'}->{$type}}, $tmp );
		push( @{$mf_json->{'views'}->{$type}}, $view_json );
	    }
	}
	else {
	    if ( $type eq 'face' ) {
		$mf_json->{'views'}->{$type} = [];
		push( @{$mf_json->{'views'}->{$type}}, $view_json );
	    }
	    else {
		$mf_json->{'views'}->{$type} = $view_json;
	    }
	}
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
