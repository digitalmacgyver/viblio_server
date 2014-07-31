package VA::Controller::Services::Filters;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use Data::Page;

BEGIN { extends 'VA::Controller::Services' }

# Return an array of possible video filters that the user has on
# their videos.  Ex. [ 'bithday', 'soccer', 'people' ]
sub video_filters :Local {
    my( $self, $c ) = @_;
    my $only_visible = $self->boolean( $c->req->param( 'only_visible', 1 ) );
    my @filters = $c->user->video_filters( $only_visible );
    $self->status_ok( $c, { filters => \@filters } );
}

sub filter_by :Local {
    my( $self, $c ) = @_;

    my @filters = $c->req->param( 'filters[]' );   # required
    my $page = $c->req->param( 'page' ) || 1;      # optional
    my $rows = $c->req->param( 'rows' ) || 10000;
    my $month = $c->req->param( 'month' );
    my $year  = $c->req->param( 'year' );

    my $only_visible = $self->boolean( $c->req->param( 'only_visible' ), 1 );

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

    if ( $month && ! $year ) {
	if ( $month =~ /(\S+)\s+(\d+)/ ) {
	    $month = $1; $year = $2;
	}
    }

    my( $from, $to ) = between( $month, $year );

    my @a = ();  my @b = ();
    if ( $#activities >= 0 ) {
	@a = $c->user->videos_with_activities( \@activities, $from, $to, $only_visible );
    }
    if ( $with_people ) {
	@b = $c->user->videos_with_people( $from, $to, $only_visible );
    }
    my @all = ( @a, @b );
    if ( $#all == -1 ) {
	$self->status_ok( $c, { media => [] } );
    }

    # Now sort them by recording date, decending
    my @sorted = sort{ $b->recording_date->epoch <=> $a->recording_date->epoch } @all;

    # Since we had to do two fetches here, a video could be
    # duplicated; having people in one array and an activity in the
    # other array.  Sigh...
    my %seen = ();
    my @uniq = ();
    foreach my $mf ( @sorted ) {
	unless( $seen{$mf->uuid} ) {
	    push( @uniq, $mf );
	    $seen{$mf->uuid} = 1;
	}
    }

    # Slice out the portion requested with page, rows
    my $pager = new Data::Page( $#uniq + 1, $rows, $page );
    my @slice = ();
    if ( $#uniq >= 0 ) {
	@slice = @uniq[ $pager->first - 1 .. $pager->last - 1 ];
    }

    # and convert them to media files
    my @media = map { VA::MediaFile->publish( $c, $_, { views => ['poster' ] } ) } @slice;

    # And gather the "calander" data
    my $bin = {};
    my @months = ();
    foreach my $mf ( @slice ) {
	my $label = $mf->recording_date->month_name . ' ' . $mf->recording_date->year;
	if ( $mf->recording_date->epoch == 0 ) {
	    $label = $c->loc( 'Missing dates' );
	}
	if ( ! defined( $bin->{$label} ) ) {
	    $bin->{$label} = 1;
	    push( @months, $label );
	}
    }

    $self->status_ok( $c, { media => \@media, pager => $self->pagerToJson( $pager ), months => \@months } );
}

sub tags_for_video :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $video = $c->user->videos->find({ uuid => $mid });
    my @tags = $video->tags;
    $self->status_ok( $c, { tags => \@tags } );
}

sub between :Private {
    my( $month, $year ) = @_;
    my( $from, $to );

    my @month_names = ( 'NA',
			'January', 'February', 'March',
			'April', 'May', 'June',
			'July', 'August', 'September',
			'October', 'November', 'December' );

    if ( ! ( $month || $year ) ) {
	# for all time
	$from = DateTime->from_epoch( epoch => 0 );
	$to   = DateTime->now();
    }
    elsif ( $year && ! $month ) {
	$from = DateTime->new(
	    year => $year,
	    month => 1, day => 1, 
	    hour => 0, minute => 0 );
	$to = DateTime->new(
	    year => $year,
	    month => 12, day => 31,
	    hour => 23, second => 59 );
    }
    elsif ( $year && $month ) {
	my $mo = 0;
        for( $mo = 0; $mo <= $#month_names; $mo++ ) {
            last if ( $month_names[$mo] eq $month );
        }
        $from = DateTime->new(
            year => $year,
            month => $mo, day => 1, 
            hour => 0, minute => 0 );
        $to = $from->clone;
        $to->add( months => 1 )->subtract( days => 1 );
    }

    return( $from, $to );
}

__PACKAGE__->meta->make_immutable;
1;
