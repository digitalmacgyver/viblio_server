package VA::Controller::Services::AIR;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
BEGIN { extends 'VA::Controller::Services' }

sub dates :Private {
    my( $self, $c, $rs ) = @_;
    return $rs->search({},{columns=>['recording_date']});
}

# Return an array of years, from most to least recent, in which
# there are recorded videos.
#
sub years :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }
    my $media_rs = $album->media;
    my @dates = $self->dates( $c, $media_rs );

    my $years = {};
    $years->{$_->recording_date->year} = 1 foreach( @dates );
    my @data = sort {$b <=> $a} keys( %$years );
    $self->status_ok( $c, { years => \@data } );
}

# Return an array of months, from most to least recent, in which
# there are recorded videos.
#
sub months :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }
    my $media_rs = $album->media;
    my @dates = $self->dates( $c, $media_rs );

    my @sorted = sort{ $b->recording_date->epoch <=> $a->recording_date->epoch } @dates;
    my $bin = {};
    my @uniq = ();
    foreach my $mf ( @sorted ) {
	my $label = $mf->recording_date->month_name . ' ' . $mf->recording_date->year;
	if ( $mf->recording_date->epoch == 0 ) {
	    $label = $c->loc( 'Missing dates' );
	}
	if ( ! defined( $bin->{$label} ) ) {
	    $bin->{$label} = 1;
	    push( @uniq, $label );
	}
    }
    $self->status_ok( $c, { months => \@uniq } );
}

sub posters :Private {
    my( $self, $c, $dtf, $from, $to, $media_rs, $page, $rows, $pager ) = @_;

    my $rs = $media_rs->search(
	{ 'media.recording_date' => {
	    -between => [
		 $dtf->format_datetime( $from ),
		 $dtf->format_datetime( $to )
		]}
	},
	{ prefetch => 'assets',
	  page => $page, rows => $rows,
	  order_by => 'media.recording_date desc' } );

    my @posters = $rs->all;
    $$pager = $self->pagerToJson( $rs->pager );

    return @posters;
}

# Return the list of videos taken in a particular year,
# in month bins, from most recent to least.
#
sub videos_for_year :Local {
    my( $self, $c ) = @_;
    my $aid  = $c->req->param( 'aid' );
    my $year = $c->req->param( 'year' );
    my $page  = $c->req->param( 'page' ) || 1;
    my $rows  = $c->req->param( 'rows' ) || 10000;
    my $pager;

    unless( $year ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Missing year parameter' ) );
    }

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }
    my $media_rs = $album->media;

    # Create a from and to date to include all videos
    # created during this period
    #
    my $from = DateTime->new(
	year => $year,
	month => 1, day => 1, 
	hour => 0, minute => 0 );
    my $to = DateTime->new(
	year => $year,
	month => 12, day => 31,
	hour => 23, second => 59 );

    # This thing is a date formatter which will format DateTime
    # dates properly for our database model.
    my $dtf = $c->model( 'RDS' )->schema->storage->datetime_parser;

    my @posters = $self->posters( $c, $dtf, $from, $to, $media_rs, $page, $rows, \$pager );

    # Now bin them by month, reverse order
    my @month_names = ( 'NA',
			'January', 'February', 'March',
			'April', 'May', 'June',
			'July', 'August', 'September',
			'October', 'November', 'December' );

    # This creates a hash who's keys are month names and
    # values are array of mediafiles created during this
    # month.
    #
    my $db = {};
    foreach my $poster ( @posters ) {
	my $month = $month_names[ $poster->recording_date->month ];
	unless( defined( $db->{$month} ) ) {
	    $db->{$month} = ();
	}
	my $hash = VA::MediaFile->new->publish( $c, $poster, { views => ['poster'] } );
	push( @{$db->{$month}}, $hash );
    }

    # Now convert this into an array of hashes for the UI
    my @data = ();
    for( my $i=12; $i>0; $i-- ) {
	if ( defined( $db->{ $month_names[$i] } ) ) {
	    push( @data, { month => $month_names[$i],
			   data  => $db->{ $month_names[$i] } } );
	}
    }
    
    $self->status_ok( $c, { media => \@data, pager => $pager } );
}

# Return the list of videos taken in a particular month/year,
# from most recent to least.
#
sub videos_for_month :Local {
    my( $self, $c ) = @_;
    my $month = $c->req->param( 'month' );
    my $year  = $c->req->param( 'year' );
    my $aid   = $c->req->param( 'aid' );
    my $page  = $c->req->param( 'page' ) || 1 ;
    my $rows  = $c->req->param( 'rows' ) || 10000 ;

    my $missing = 0;

    unless( $month ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Missing month parameter' ) );
    }

    if ( $month eq $c->loc( 'Missing dates' ) ) {
	$missing = 1;
    }

    my $from;
    my $to;
    if ( $missing ) {
	$from = DateTime->from_epoch( epoch => 0 );
	$to   = $from;
    }
    else {

	unless( $year ) {
	    if ( $month =~ /(\S+)\s+(\d+)/ ) {
		$month = $1; $year = $2;
	    }
	}
	unless ( $year ) {
	    $self->status_bad_request(
		$c, $c->loc( 'Missing year parameter' ) );
	}

	my @month_names = ( 'NA',
			    'January', 'February', 'March',
			    'April', 'May', 'June',
			    'July', 'August', 'September',
			    'October', 'November', 'December' );

	my $mo = 0;
	for( $mo = 0; $mo <= $#month_names; $mo++ ) {
	    last if ( $month_names[$mo] eq $month );
	}

	# Create a from and to date to include all videos
	# created during this period
	#
	$from = DateTime->new(
	    year => $year,
	    month => $mo, day => 1, 
	    hour => 0, minute => 0 );

	$to = $from->clone;
	$to->add( months => 1 )->subtract( days => 1 );

    }

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_not_found( $c, $c->loc( 'Cannot find album for [_1]', $aid ), $aid );
    }
    my $media_rs = $album->media;

    # This thing is a date formatter which will format DateTime
    # dates properly for our database model.
    my $dtf = $c->model( 'RDS' )->schema->storage->datetime_parser;
    my $pager = {};
    my @posters = $self->posters( $c, $dtf, $from, $to, $media_rs, $page, $rows, \$pager );

    my @data = ();
    foreach my $poster ( @posters ) {
	my $hash = VA::MediaFile->new->publish( $c, $poster, { views => ['poster'] } );
	push( @data, $hash );
    }

    $self->status_ok( $c, { media => \@data, pager => $pager } );
}

__PACKAGE__->meta->make_immutable;
1;
