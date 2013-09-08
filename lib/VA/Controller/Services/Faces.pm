package VA::Controller::Services::Faces;
use Moose;

use VA::MediaFile;

use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

=head1 /services/faces/*

Services related to getting and manipulating face data

=head2 /services/faces/for_user

Return all faces appearing in all videos belonging to the logged in user.
Some of these faces will be identified, some not.  The data returned looks like:

  {
   "faces" : [
      {
         "provider" : null,
         "contact_name" : "Mark Twain",
         "provider_id" : null,
         "created_date" : "2013-08-16 04:36:40",
         "contact_viblio_id" : null,
         "contact_email" : "viblio.smtesting+mark@gmail.com",
         "asset_id" : "d8001f2b-f547-4bfb-a855-7a6f17deee64",
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/5faf5507-044a-48f1-a708-bdffba1d4f73%2Fface-d8001f2b-f547-4bfb-a855-7a6f17deee64.jpg?Signature=%2BkTNY%2B7eg2a4OL%2FIQ87WzfGTMPw%3D&Expires=1378231949&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA",
         "updated_date" : null,
         "id" : "240"
      },
      {
         "asset_id" : "381c0d17-dc8d-4c74-a389-2a8766febd31",
         "url" : "https://viblio-uploaded-files.s3.amazonaws.com:443/5faf5507-044a-48f1-a708-bdffba1d4f73%2Fface-381c0d17-dc8d-4c74-a389-2a8766febd31.jpg?Signature=ryGNvmpbVc3e9rjsiNXJ7MeDcRc%3D&Expires=1378231948&AWSAccessKeyId=AKIAJHD46VMHB2FBEMMA"
      },
   ]
  }

The first entry in the example above is an identified face, the second entry is
an unidentified face.  In both cases, you will get a URL to the face image, and the
media asset id that refered to this face.  In the identifed case, you also get the
contact info and the contact id.

=cut

sub for_user :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );

    my $user = $c->user->obj;

    # Find all media assets who's type is 'face' belonging to media belonging to this user
    # http://search.cpan.org/~ribasushi/DBIx-Class-0.08250/lib/DBIx/Class/Manual/Cookbook.pod#Using_joins_and_prefetch
    #
    my @faces = ();
    my $pager;

    # $args = {};

    if ( $args->{page} ) {
	my $rs = $c->model( 'RDS::MediaAsset' )
	    ->search(
	    { 'media.user_id' => $user->id, 
	      'asset_type' => 'face' },
	    { join => 'media', prefetch => ['media', 'features' ],
	      page => $args->{page},
	      rows => $args->{rows} } );
	$pager = $rs->pager;
	@faces = $rs->all;
    }
    else {
	@faces = $c->model( 'RDS::MediaAsset' )
	    ->search(
	    { 'media.user_id' => $user->id, 
	      'asset_type' => 'face' },
	    { join => 'media', prefetch => ['media', 'features' ] } );
    }

    my $unique = {};
    my $ids = -100000;
    foreach my $face ( @faces ) {
	my $klass = $c->config->{mediafile}->{$face->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $face->uri );
	my $hash = {};
	my $contact = $face->face_data;
	my $id = $ids++;
	if ( $contact ) {
	    $hash = $contact->TO_JSON;
	    $id = $contact->id;
	}
	$hash->{url} = $url;
	$hash->{asset_id} = $face->uuid;
	$unique->{ $id } = $hash;
    }
    my @data = values( %$unique );

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
		{ contact_id => $contact_id },
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

sub contacts :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );

    my $user = $c->user->obj;

    my @contacts = ();
    my $pager;
    if ( $args->{page} ) {
	my $rs = $user->contacts->search({},{page => $args->{page},rows => $args->{rows}});
	$pager = $rs->pager;
	@contacts = $rs->all;
    }
    else {
	@contacts = $user->contacts;
    }

    my @data = ();
    foreach my $contact ( @contacts ) {
	my @feat = $c->model( 'RDS::MediaAssetFeature' )
	    ->search({ contact_id => $contact->id }, { prefetch => 'media_asset' });
	next unless( $#feat >= 0 );
	my $feat = $feat[0];
	my $asset = $feat->media_asset;
	my $klass = $c->config->{mediafile}->{$asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $asset->uri );
	my $hash = $contact->TO_JSON;
	$hash->{url} = $url;
	$hash->{assert_id} = $asset->uuid;
	$hash->{appears_in} = ( $#feat + 1 );
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

sub location :Local {
    my( $self, $c ) = @_;
    my $lat = $c->req->param( 'lat' );
    my $lng = $c->req->param( 'lng' );

    my $latlng = "$lat,$lng";
    my $res = $c->model( 'GoogleMap' )->get( "/maps/api/geocode/json?latlng=$latlng&sensor=true" );

    $self->status_ok( $c, $res->data->{results} );
}

__PACKAGE__->meta->make_immutable;
1;
