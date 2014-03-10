package VA::Controller::Services::Filters;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
BEGIN { extends 'VA::Controller::Services' }

# Return an array of possible video filters that the user has on
# their videos.  Ex. [ 'bithday', 'soccer', 'people' ]
sub video_filters :Local {
    my( $self, $c ) = @_;
    my @filters = $c->user->video_filters();
    $self->status_ok( $c, { filters => \@filters } );
}

sub filter_by :Local {
    my( $self, $c ) = @_;
    my @filters = $c->req->param( 'filters[]' );
    my @activities = ();
    my $with_people = 0;
    foreach my $f ( @filters ) {
	if ( $f eq 'people' ) {
	    $with_people = 1;
	}
	else {
	    push( @activities, $f );
	}
    }
    my @a = ();  my @b = ();
    if ( $#activities >= 0 ) {
	@a = $c->user-->videos_with_activities( \@activities );
    }
    if ( $with_people ) {
	@b = $c->user->videos_with_people();
    }
    my @all = ( @a, @b );
    if ( $#all == -1 ) {
	$self->status_ok( $c, { media => [] } );
    }

    # Now sort them by recording date, decending
    
    # and convert them to media files

}

__PACKAGE__->meta->make_immutable;
1;
