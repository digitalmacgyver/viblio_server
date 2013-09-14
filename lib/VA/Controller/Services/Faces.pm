package VA::Controller::Services::Faces;
use Moose;

use VA::MediaFile;

use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/faces/*

Services related to getting and manipulating face data

=head2 /services/faces/media_face_appears_in

Return the list of published media files belonging to the logged in user that the passed in face appears in.

=cut

sub media_face_appears_in :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
	  asset_id => undef,
	  contact_id => undef
        ],
        @_ );

    my $user = $c->user->obj;

    my $asset_id = $args->{asset_id};
    my $contact_id = $args->{contact_id};

    # If this is an unidentified face, then only asset_id will be
    # defined.  If it is an identifed face, then contact_id will be defined as well.
    #

    if ( ! defined( $contact_id ) ) {
	# This face is unidentifed, and so belongs to exactly one video, the
	# one in which it was detected.
	my $asset = $c->model( 'RDS::MediaAsset' )
	    ->find(
	    { 'media.user_id' => $user->id, 
	      'me.uuid' => $asset_id },
	    { join => 'media', prefetch => 'media' } );
	unless( $asset ) {
	    $self->status_bad_request
	    ( $c, 
	      $c->loc( 'Unable to find asset for [_1]', $asset_id ) );
	}
	my $mediafile = VA::MediaFile->new->publish( $c, $asset->media );
	$self->status_ok( $c, { media => [ $mediafile ] } );
    }
    else {
	# This is an identified face and may appear in multiple media files.
	my @features = ();
	my $pager;
	if ( $args->{page} ) {
	    my $rs = $c->model( 'RDS::MediaAssetFeature' )
		->search(
		{ contact_id => $contact_id, 'me.user_id' => $user->id},
		{ prefetch => 'media_asset', page => $args->{page}, rows => $args->{rows} } );
	    $pager = $rs->pager;
	    @features = $rs->all;
	}
	else {
	    @features = $c->model( 'RDS::MediaAssetFeature' )
		->search(
		{ contact_id => $contact_id },
		{ prefetch => 'media_asset' } );
	}
	my @media = ();
	foreach my $feature ( @features ) {
	    push( @media, VA::MediaFile->new->publish( $c, $feature->media_asset->media ) );
	}
	if ( $pager ) {
	    $self->status_ok( $c, { media => \@media,
				    pager => {
				    total_entries => $pager->total_entries,
				    entries_per_page => $pager->entries_per_page,
				    current_page => $pager->current_page,
				    entries_on_this_page => $pager->entries_on_this_page,
				    first_page => $pager->first_page,
				    last_page => $pager->last_page,
				    first => $pager->first,
				    'last' => $pager->last,
				    previous_page => $pager->previous_page,
				    next_page => $pager->next_page,
				    } } );
	}
	else {
	    $self->status_ok( $c, { media => \@media } );
	}
    }
}

# print $_->contact->contact_name, ' ', $_->media_asset->uri,"\n" foreach(  $schema->resultset( 'MediaAssetFeature' )->search({'me.user_id'=>$u->id,contact_id => {'!=',undef}},{columns=>[qw/contact_id media_asset_id/],group_by=>[qw/contact_id/],prefetch=>[qw/contact media_asset/]}) )
#
# $schema->resultset( 'MediaAssetFeature' )->search({contact_id=>251,user_id=>124})->count

sub ratings_db :Private {
    my( $self, $c, $uid ) = @_;
    my $hash_db = {};
    my @feats = $c->model( 'RDS::MediaAssetFeature' )
	->search({ 'me.user_id' => $uid,
		   contact_id => {'!=',undef},
		 }, 
		 { columns => [qw/contact_id/],
		 });
    foreach my $feat ( @feats ) {
	if ( defined( $hash_db->{$feat->contact_id} ) ) {
	    $hash_db->{$feat->contact_id}->{appears_in} += 1;
	}
	else {
	    $hash_db->{$feat->contact_id} = {
		appears_in => 1,
		star_power => 'star0',
		contact_id => $feat->contact_id };
	}
    }
    # Sort these to determine the #1, 2 and 3 folks in terms of
    # how many videos they appear in.

    my @sorted = sort { $b->{appears_in} <=> $a->{appears_in} } values( %$hash_db );
    if ( $#sorted >= 0 ) {
	$hash_db->{ $sorted[0]->{contact_id} }->{star_power} = 'star1';
    }
    if ( $#sorted >= 1 ) {
	$hash_db->{ $sorted[1]->{contact_id} }->{star_power} = 'star2';
    }
    if ( $#sorted >= 2 ) {
	$hash_db->{ $sorted[2]->{contact_id} }->{star_power} = 'star3';
    }
    return $hash_db;
}

sub contacts :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );

    my $user = $c->user->obj;

    my $ratings = $self->ratings_db( $c, $user->id );

    # Find all contacts for a user that appear in at least one video.
    my $search = {
	'me.user_id' => $user->id,
	contact_id => {'!=',undef}
    };
    my $where = {
	select => ['contact_id', 'media_asset_id', {count => 'media_asset.media_id', -as => 'appears_in'}],
	group_by => [qw/contact_id/],
	prefetch=>[qw/contact media_asset/],
	order_by => 'appears_in desc'
    };
    if ( $args->{page} ) {
	$where->{page} = $args->{page};
	$where->{rows} = $args->{rows};
    }
    my $pager;
    my $rs = $c->model( 'RDS::MediaAssetFeature' )->search( $search, $where );
    $pager = $rs->pager if ( $args->{page} );
    my @feats = ();
    @feats = $rs->all if ( $rs );

    my @data = ();
    foreach my $feat ( @feats ) {

	my $contact = $feat->contact;
	my $asset   = $feat->media_asset;
	my $hash    = $contact->TO_JSON;

	my $klass = $c->config->{mediafile}->{$asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $asset->uri );

	$hash->{url} = $url;
	$hash->{asset_id} = $asset->uuid;
	$hash->{appears_in} = $feat->{_column_data}->{appears_in};
	$hash->{star_power} = $ratings->{$contact->id}->{star_power} if ( $ratings->{$contact->id}->{star_power} );
	push( @data, $hash );
    }

    if ( $pager ) {
	$self->status_ok( $c, { faces => \@data, 
				pager => {
				    total_entries => $pager->total_entries,
				    entries_per_page => $pager->entries_per_page,
				    current_page => $pager->current_page,
				    entries_on_this_page => $pager->entries_on_this_page,
				    first_page => $pager->first_page,
				    last_page => $pager->last_page,
				    first => $pager->first,
				    'last' => $pager->last,
				    previous_page => $pager->previous_page,
				    next_page => $pager->next_page,
				} } );
    }
    else {
	$self->status_ok( $c, { faces => \@data } );
    }
}

=head2 /services/faces/faces_in_mediafile

For a passed in mediafile (uuid), return all the faces, known and unknown,
present in that video.  Returns something that looks like:

  {
   "faces" : [
      {
         "appears_in" : 1,
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/91d90a85-0786-43b6-acef-928799e27507%2Fface-ecf16301-7d86-452c-b05c-43fa0f73af9e.jpg?Signature=ONC91C9PhUqW%2BzJcB0qRlszky1A%3D&Expires=1379278215&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
         "contact" : {
            "provider" : null,
            "contact_name" : "Nikola Tesla",
            "provider_id" : null,
            "created_date" : "2013-09-07 18:54:05",
            "uuid" : null,
            "intellivision_id" : null,
            "contact_viblio_id" : null,
            "picture_uri" : null,
            "contact_email" : "viblio.smtesting+nikola@gmail.com",
            "id" : "257",
            "updated_date" : null
         }
      },
      {
         "appears_in" : 1,
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/91d90a85-0786-43b6-acef-928799e27507%2Fface-3819b4fe-f297-4a52-93d6-4872dcbb0db6.jpg?Signature=b7qJcOXdb%2Bh63%2Fn3EHStC3asbHc%3D&Expires=1379278215&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA"
      },
   ]
  }

In the example above, the first record is a known face, and thus contains a "contact"
record.  The second face is present but unknown.

=cut

sub faces_in_mediafile :Local {
    my( $self, $c ) = @_;
    my $mid = $c->req->param( 'mid' );
    my $m = $c->user->media->find({uuid=>$mid});
    unless( $m ) {
	$self->status_bad_request
	    ( $c, 
	      $c->loc( 'Unable to find mediafile for [_1]', $mid ) );
    }
    my @feat = $c->model( 'RDS::MediaAssetFeature' )
	->search({'me.media_id'=>$m->id,
		  'me.feature_type'=>'face'},
		 {prefetch=>['contact','media_asset']});
    my @data = ();
    foreach my $feat ( @feat ) {
	my $klass = $c->config->{mediafile}->{$feat->media_asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $feat->media_asset->uri );
	my $hash = {
	  url => $url,
	  appears_in => 1,
	};
	if ( $feat->contact_id ) {
	    $hash->{contact} = $feat->contact->TO_JSON;
	}
	push( @data, $hash );
    }
    $self->status_ok( $c, { faces => \@data } );
}
    

__PACKAGE__->meta->make_immutable;
1;
