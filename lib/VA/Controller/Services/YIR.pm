package VA::Controller::Services::YIR;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
BEGIN { extends 'VA::Controller::Services' }

=head1 /services/yir/*

Services related to the Year In Review

=cut

sub dates_for_user :Private {
    my( $self, $c ) = @_;
    return $c->user->media
	->search({
	    -or => [ status => 'TranscodeComplete',
		     status => 'FaceDetectComplete',
		     status => 'FaceRecognizeComplete' ] },
		 {columns=>['recording_date'], 
		  order_by=>'recording_date desc'});
}

sub dates_for_contact :Private {
    my( $self, $c, $cid ) = @_;
    my @features = $c->model( 'RDS::MediaAssetFeature' )
	->search(
	{ contact_id => $cid },
	{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );
    my @media = map { $_->media_asset->media } @features;
    return @media;
}

# Return an array of years, from most to least recent, in which
# there are recorded videos.
#
sub years :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my @dates = ();
    if ( $cid ) {
	my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
	unless( $contact ) {
	    $contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
	}
	if ( $contact ) {
	    @dates = $self->dates_for_contact( $c, $contact->id );
	}
    }
    else {
	@dates = $self->dates_for_user($c);
    }
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
    my $cid = $c->req->param( 'cid' );
    my @dates = ();
    if ( $cid ) {
	my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
	unless( $contact ) {
	    $contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
	}
	if ( $contact ) {
	    @dates = $self->dates_for_contact( $c, $contact->id );
	}
    }
    else {
	@dates = $self->dates_for_user($c);
    }

    my @sorted = sort{ $b->recording_date->epoch <=> $a->recording_date->epoch } @dates;
    my $bin = {};
    my @uniq = ();
    foreach my $mf ( @sorted ) {
	my $label = $mf->recording_date->month_name . ' ' . $mf->recording_date->year;
	if ( ! defined( $bin->{$label} ) ) {
	    $bin->{$label} = 1;
	    push( @uniq, $label );
	}
    }
    $self->status_ok( $c, { months => \@uniq } );
}

sub posters_for_user :Private {
    my( $self, $c, $dtf, $from, $to, $page, $rows, $pager ) = @_;
    # Do the query
    my @posters;
    if ( ! defined( $page ) ) {
	@posters = $c->model( 'RDS::MediaAsset' )->
	    search({ 'me.asset_type' => 'poster',
		     'me.user_id' => $c->user->id,
		     'media.recording_date' => {
			 -between => [
			      $dtf->format_datetime( $from ),
			      $dtf->format_datetime( $to )
			     ]}},
		   { prefetch => 'media',
		     group_by => ['media.id'],
		     order_by => 'media.recording_date desc' });
    }
    else {
	my $rs = $c->model( 'RDS::MediaAsset' )->
	    search({ 'me.asset_type' => 'poster',
		     'me.user_id' => $c->user->id,
		     'media.recording_date' => {
			 -between => [
			      $dtf->format_datetime( $from ),
			      $dtf->format_datetime( $to )
			     ]}},
		   { prefetch => 'media',
		     group_by => ['media.id'],
		     order_by => 'media.recording_date desc',
		     page => $page, rows => $rows });
	@posters = $rs->all;
	$$pager = {
	    total_entries => $rs->pager->total_entries,
	    entries_per_page => $rs->pager->entries_per_page,
	    current_page => $rs->pager->current_page,
	    entries_on_this_page => $rs->pager->entries_on_this_page,
	    first_page => $rs->pager->first_page,
	    last_page => $rs->pager->last_page,
	    first => $rs->pager->first,
	    'last' => $rs->pager->last,
	    previous_page => $rs->pager->previous_page,
	    next_page => $rs->pager->next_page,
	};
    }

    return @posters;
}

sub posters_for_contact :Private {
    my( $self, $c, $cid, $dtf, $from, $to, $page, $rows, $pager ) = @_;
    my @features;
    if ( ! defined( $page ) ) {
	@features = $c->model( 'RDS::MediaAssetFeature' )
	    ->search(
	    { contact_id => $cid,
	      'media.recording_date' => {
		  -between => [
		       $dtf->format_datetime( $from ),
		       $dtf->format_datetime( $to )
		  ]},
	    },
	    { prefetch => { 'media_asset' => 'media' },
	      group_by => ['media.id'],
	      order_by => 'media.recording_date desc',
	    } );
    }
    else {
	my $rs = $c->model( 'RDS::MediaAssetFeature' )
	    ->search(
	    { contact_id => $cid,
	      'media.recording_date' => {
		  -between => [
		       $dtf->format_datetime( $from ),
		       $dtf->format_datetime( $to )
		  ]},
	    },
	    { prefetch => { 'media_asset' => 'media' },
	      group_by => ['media.id'],
	      order_by => 'media.recording_date desc',
	      page => $page, rows => $rows,
	    } );
	@features = $rs->all;
	$$pager = {
	    total_entries => $rs->pager->total_entries,
	    entries_per_page => $rs->pager->entries_per_page,
	    current_page => $rs->pager->current_page,
	    entries_on_this_page => $rs->pager->entries_on_this_page,
	    first_page => $rs->pager->first_page,
	    last_page => $rs->pager->last_page,
	    first => $rs->pager->first,
	    'last' => $rs->pager->last,
	    previous_page => $rs->pager->previous_page,
	    next_page => $rs->pager->next_page,
	};
    }
    my @posters = map { $_->media_asset->media->assets->find({ asset_type => 'poster' }) } @features;
    return @posters;
}

# Return the list of videos taken in a particular year,
# in month bins, from most recent to least.
#
sub videos_for_year :Local {
    my( $self, $c ) = @_;
    my $year = $c->req->param( 'year' );
    unless( $year ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Missing year parameter' ) );
    }

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

    my $cid = $c->req->param( 'cid' );
    my @posters = ();
    if ( $cid ) {
	my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
	unless( $contact ) {
	    $contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
	}
	if ( $contact ) {
	    @posters = $self->posters_for_contact( $c, $contact->id, $dtf, $from, $to );
	}
    }
    else {
	@posters = $self->posters_for_user( $c, $dtf, $from, $to );
    }

    # Now bin them by month, reverse order
    my @month_names = ( 'NA',
			'January', 'Feburary', 'March',
			'April', 'May', 'June',
			'July', 'August', 'September',
			'October', 'November', 'December' );

    # This creates a hash who's keys are month names and
    # values are array of mediafiles created during this
    # month.
    #
    my $db = {};
    foreach my $poster ( @posters ) {
	my $month = $month_names[ $poster->media->recording_date->month ];
	unless( defined( $db->{$month} ) ) {
	    $db->{$month} = ();
	}
	my $hash = $poster->media->TO_JSON;
	my $klass = $c->config->{mediafile}->{$poster->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $poster->uri );
	$hash->{views}->{poster}->{url} = $url;
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
    
    $self->status_ok( $c, { media => \@data } );
}

# Return the list of videos taken in a particular month/year,
# from most recent to least.
#
sub videos_for_month :Local {
    my( $self, $c ) = @_;
    my $month = $c->req->param( 'month' );
    my $year  = $c->req->param( 'year' );

    my $page  = $c->req->param( 'page' );
    my $rows  = $c->req->param( 'rows' );

    unless( $month ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Missing month parameter' ) );
    }

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
			'January', 'Feburary', 'March',
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
    my $from = DateTime->new(
	year => $year,
	month => $mo, day => 1, 
	hour => 0, minute => 0 );

    my $to = $from->clone;
    $to->add( months => 1 )->subtract( days => 1 );

    # This thing is a date formatter which will format DateTime
    # dates properly for our database model.
    my $dtf = $c->model( 'RDS' )->schema->storage->datetime_parser;

    my $cid = $c->req->param( 'cid' );
    my @posters = ();
    my $pager = {};
    if ( $cid ) {
	my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
	unless( $contact ) {
	    $contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
	}
	if ( $contact ) {
	    @posters = $self->posters_for_contact( $c, $contact->id, $dtf, $from, $to, $page, $rows, \$pager );
	}
    }
    else {
	@posters = $self->posters_for_user( $c, $dtf, $from, $to, $page, $rows, \$pager );
    }

    # This creates a hash who's keys are month names and
    # values are array of mediafiles created during this
    # month.
    #
    my @data = ();
    foreach my $poster ( @posters ) {
	my $hash = $poster->media->TO_JSON;
	my $klass = $c->config->{mediafile}->{$poster->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $poster->uri );
	$hash->{views}->{poster}->{url} = $url;
	push( @data, $hash );
    }

    $self->status_ok( $c, { media => \@data }, pager => $pager );
}

__PACKAGE__->meta->make_immutable;
1;
