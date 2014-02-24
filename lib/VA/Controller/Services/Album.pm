package VA::Controller::Services::Album;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

sub list :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    my $rs = $c->user->albums->search({},{ page => $page, rows => $rows });
    my @albums = $rs->all;
    my $pager = $rs->pager;

    my @data = ();
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	push( @data, $a );
    }

    $self->status_ok( $c, { albums => \@data, pager => $self->pagerToJson( $pager ) } );
}

sub create :Local {
    my( $self, $c ) = @_;
    my $name = $c->req->param( 'name' ) || 'unnamed';
    my $initial_mid = $c->req->param( 'initial_mid' );

    my $album = $c->user->create_related( 'media', {
	is_album => 1,
	recording_date => DateTime->now,
	media_type => 'original',
	title => $name });

    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Failed to create a new album' ) );
    }

    if ( $initial_mid ) {
	my $media = $c->user->videos->find({ uuid => $initial_mid });
	unless( $media ) {
	    $self->status_bad_request( $c, $c->loc( 'Bad initial media uuid' ) );
	}
	my $rel = $c->model( 'RDS::MediaAlbum' )->create({ album_id => $album->id, media_id => $media->id });
	unless( $rel ) {
	    $self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between new album and initial media' ) );
	}
	# Set the poster of the new album to the poster of the video file just added
	my $poster = $media->assets->find({ asset_type => 'poster' });
	$album->create_related( 'media_assets', {
	    user_id => $c->user->obj->id,
	    asset_type => 'poster',
	    mimetype => $poster->mimetype,
	    uri => $poster->uri,
	    location => $poster->location,
	    bytes => $poster->bytes,
	    width => $poster->width,
	    height => $poster->height,
	    provider => $poster->provider,
	    provider_id => $poster->provider_id });
    }
    else {
	# Set the poster of the new album to a canned image
    }

    my $hash = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
    $hash->{owner} = $album->user->TO_JSON;

    $self->status_ok( $c, { album => $hash } );
}

sub get :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }
    my $hash  = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
    my @m = ();
    push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->media );
    $hash->{media} = \@m;
    $hash->{owner} = $album->user->TO_JSON; 

    $self->status_ok( $c, { album => $hash } );
}

sub add_media :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $mid = $c->req->param( 'mid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
    }

    my $rel = $c->model( 'RDS::MediaAlbum' )->create({ album_id => $album->id, media_id => $media->id });
    unless( $rel ) {
	$self->status_bad_request( $c, $c->loc( 'Unable to establish relationship between album and media' ) );
    }

    $self->status_ok( $c, {} );
}

sub remove_media :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $mid = $c->req->param( 'mid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    my $media = $c->model( 'RDS::Media' )->find({ uuid => $mid });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }
    unless( $media ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find media for [_1]', $mid ) );
    }

    my $rel = $c->model( 'RDS::MediaAlbum' )->find({ album_id => $album->id, media_id => $media->id });
    unless( $rel ) {
	$self->status_bad_request( $c, $c->loc( 'Unable to find relationship between album and media' ) );
    }
    $rel->delete; $rel->update;

    $self->status_ok( $c, {} );
}

sub change_title :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $title = $c->req->param( 'title' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    $album->title( $title );
    $album->update;

    $self->status_ok( $c, {} );
}

sub delete_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );

    my $album = $c->model( 'RDS::Media' )->find({ uuid => $aid, is_album => 1 });
    
    unless( $album ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find album for [_1]', $aid ) );
    }

    my $rs = $c->model( 'RDS::MediaAlbum' )->search({ album_id => $album->id });
    $rs->delete;
    $album->delete;

    $self->status_ok( $c, {} );
}

# List albums shared to me
sub list_shared :Local {
    my( $self, $c ) = @_;
    my $page = $c->req->param( 'page' ) || 1;
    my $rows = $c->req->param( 'rows' ) || 100000;

    # Following copied from User::is_community_member_of() to enable paging
    # my @albums = map { $_->album } $c->user->is_community_member_of();

    my $rs = $c->model( 'RDS::ContactGroup' )->search
	({'contact.contact_email'=>$c->user->email},
	 { page => $page, rows => $rows,
	   prefetch=>['contact',{'cgroup'=>'community'}]});

    my @communities = map { $_->cgroup->community } $rs->all;
    my @albums = map { $_->album } @communities;

    my @data = ();
    foreach my $album ( @albums ) {
	my $a = VA::MediaFile->new->publish( $c, $album, { views => ['poster'] } );
	my @m = ();
	push( @m, VA::MediaFile->new->publish( $c, $_, { views => ['poster'] } ) ) foreach( $album->videos );
	$a->{media} = \@m;
	$a->{owner} = $album->user->TO_JSON; 
	push( @data, $a );
    }

    $self->status_ok( $c, { albums => \@data, pager => $self->pagerToJson( $rs->pager ) } );
}

sub share_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $members = $c->req->param( 'members[]' );
}

sub add_members_to_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $members = $c->req->param( 'members[]' );
}

sub remove_members_from_shared :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $members = $c->req->param( 'members[]' );
}

sub delete_shared_album :Local {
    my( $self, $c ) = @_;
    my $aid = $c->req->param( 'aid' );
    my $album = $c->user->albums->find({ uuid => $aid });
    unless( $album ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not delete this album' ) );
    }
    my $community = $album->community;
    unless( $community ) {
	$self->status_bad_request(
	    $c, $c->loc( 'Could not find community container for album' ) );
    }
    
}

__PACKAGE__->meta->make_immutable;

1;

