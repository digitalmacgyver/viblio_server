package VA::MediaFile;
use Moose;
use Module::Find;
use VA::MediaFile;
use MIME::Types;

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

# Standard way to "publish" a media file to a client in JSON.  Convert
# the array of views into a hash whose keys are the view types.  This
# makes it easier for a client to access the information they need,
# for example:
#
#  <img src="{{ media.views.thumbnail.url }}" />
#
# This also transforms URIs to URLs in a view location -specific way
#
# Params:
# {
#  assets => [ array-of-prefetched-assets ]       def: fetch all views
#  views  => [ array-of-view-names-to-include ]   def: include all views
#  include_contact_info => 0                      def: don't include faces
#  expires => epoc                                def: $c->config
#  use_cf => 0                                    def: don't generate cf urls
# }
#
sub publish {
    my( $self, $c, $mediafile, $params ) = @_;
    # If our caller was kind enough to pass us the owner_uuid of the
    # mediafile in question, pass it on down.
    my $mf_json = $mediafile->TO_JSON( $params );
    $mf_json->{'views'} = {}; 
    my @views;
    if ( $params->{assets} ) {
	@views = @{$params->{assets}};
    }
    else {
	# We'll do faces later if requested
	@views = $mediafile->assets;
    }
    my %include;
    if ( $params->{views} ) {
	%include = map { $_ => 1 } @{$params->{views}};
	if ( $include{poster} ) {
	    $include{poster_animated} = 1;
	}
    }
    my $include_images = 0;
    if ( exists( $params->{include_images} ) ) {
	$include_images = $params->{include_images};
    }
    foreach my $view ( @views ) {
	my $type = $view->{_column_data}->{asset_type};
	
	next if ( $type eq 'face' ); # We will do faces later if requested
	next if ( $params->{views} && !defined($include{$type}) );
	# Skip the new image asset type, of which there will be many,
	# unless they have been specifically requested.
	next if ( $type eq 'image' && !$include_images );

	my $view_json = $view->TO_JSON;

	# Generate the URL from the URI
	# THIS IS DONE EVEN FOR VIDEOS WITH A CLOUDFRONT URL because the iPad needs
	# the original .mp4 file from S3!!
	#
	my $location = $view_json->{location};
	
	# For facebook stuff we just store the URI as the URL.
	if ( $location eq 'facebook' ) {
	    $view_json->{url} = $view_json->{uri};
	} else {
	    my $klass = $c->config->{mediafile}->{$location};
	    my $fp = new $klass;
	    $view_json->{url} = 
		$fp->uri2url( $c, $view_json, $params );

	    my $download_params = $params;
	    $download_params->{'download'} = 1;

	    $view_json->{download_url} = 
		$fp->uri2url( $c, $view_json, $params );

	    # If this is a video, also generate a cloudfront url
	    #
	    my $mimetype = MIME::Types->new()->mimeTypeOf( $view_json->{uri} ) || $view_json->{mimetype};
	    unless( $mimetype ) {
		$mimetype="unknown";
		$c->log->error( "Could not determine mimetype for $view_json->{uuid}" );
	    }
	    if ( $mimetype =~ /^video/ ) {
		$view_json->{cf_url} = $c->cf_sign( $view_json->{uri}, {
		    stream => 1,
		    expires => ( $params && $params->{expires} ? $params->{expires} : $c->config->{s3}->{expires} ),
						    });
	    }
	}

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
	    $mf_json->{'views'}->{$type} = $view_json;
	}
    }

    # If faces were requested ...
    if ( $params->{include_contact_info} ) {
	my @feat = ();
	if ( exists( $params->{features} ) ) {
	    @feat = @{$params->{features}};
	} else {
	    @feat = $c->model( 'RDS::MediaAssetFeature' )
		->search({'me.media_id'=>$mediafile->id,
			  'contact.id' => { '!=', undef },
			  'me.feature_type'=> [ 'face', 'fb_face'] },
			 {prefetch=>['contact','media_asset'],
			  group_by=>['contact.id']
			 });
	}
	my @data = ();
	foreach my $feat ( @feat ) {
	    my $hash = $feat->media_asset->TO_JSON;
	    if ( $feat->media_asset->uri ) {
		my $klass = $c->config->{mediafile}->{$feat->media_asset->location};
		my $fp = new $klass;
		my $url = $fp->uri2url( $c, $feat->media_asset->uri );
		$hash->{url} = $url;
	    }
	    else {
		$hash->{url} = $c->server() . 'css/images/avatar-nobd.png';
	    }
	    $hash->{contact} = $feat->contact->TO_JSON;
	    push( @data, $hash );
	}
	$mf_json->{views}->{face} = \@data;
    }

    if ( $params->{include_tags} ) {
	# Attach an array of unique tag names
	if ( exists( $params->{media_tags} ) ) {
	    $mf_json->{tags} = [ keys( %{$params->{media_tags}} ) ];
	} else {
	    my @tags = $mediafile->tags;
	    $mf_json->{tags} = \@tags;
	}
    }

    if ( $params->{include_shared} ) {
	if ( exists( $params->{shared} ) ) {
	    $mf_json->{shared} = $params->{shared};
	} else {
	    $mf_json->{shared} = $c->model( 'RDS::MediaShare' )->search(
		{ 'media.uuid' => $mediafile->uuid },
		{ prefetch => 'media' })->count;
	}
    }

    return $mf_json;
}

sub publish_minimal {
    my( $self, $c, $mediafile, $assets ) = @_;
    return $self->publish( $c, $mediafile, {
	views => ['poster'],
	assets => $assets || [] } );
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
