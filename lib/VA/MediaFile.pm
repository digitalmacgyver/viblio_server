package VA::MediaFile;
use Moose;

# Different types of media file sources will
# likely override this function; see MediaFile::FilePicker
# for an example.
#
sub create {
    my ( $self, $c, $params ) = @_;
}

# Media sources will override this, if they need
# to do something extra-ordinary to remove the 
# media.
#
sub delete {
    my( $self, $c, $mediafile ) = @_;
    return $mediafile;
}

# Standard way to "publish" a media file to
# a client in JSON.  Convert the array of
# views into a hash who's keys are the view
# types.  This makes it easier for a client
# to access the information they need, for example:
#
#  <img src="{{ media.views.thumbnail.url }}" />
#
sub publish {
    my( $self, $c, $mediafile ) = @_;
    my $mf_json = $mediafile->TO_JSON;
    $mf_json->{'views'} = {};
    my @views = $mediafile->views;
    foreach my $view ( @views ) {
	$mf_json->{'views'}->{$view->type} = $view->TO_JSON;
    }
    return $mf_json;
}

1;
