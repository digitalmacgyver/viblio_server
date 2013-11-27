package VA::Controller::Services::Faces;
use Moose;

use VA::MediaFile;
use Data::Page;

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
	  contact_uuid => undef
        ],
        @_ );

    my $user = $c->user->obj;

    my $asset_id = $args->{asset_id};
    my $contact_id;

    if ( $args->{contact_uuid} ) {
	my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$args->{contact_uuid}});
	if ( ! $contact ) {
	    $contact = $c->model( 'RDS::Contact' )->find({id=>$args->{contact_uuid}});
	}
	if ( $contact ) {
	    $contact_id = $contact->id;
	}
    }

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
	    { join => 'media', prefetch => 'media', group_by => ['media.id'] } );
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
		{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'], page => $args->{page}, rows => $args->{rows} } );
	    $pager = $rs->pager;
	    @features = $rs->all;
	}
	else {
	    @features = $c->model( 'RDS::MediaAssetFeature' )
		->search(
		{ contact_id => $contact_id, 'me.user_id' => $user->id },
		{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );
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

=head2 /services/faces/contact_mediafiles_count

Return the total number of mediafiles that this contact uniquely appears in.

=cut

sub contact_mediafile_count :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
    unless( $contact ) {
	$contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
    }
    unless( $contact ) {
	$self->status_bad_request( $c, $c->loc( 'Cannot find contact for [_1]', $cid ) );
    }
    my $count =  $c->model( 'RDS::MediaAssetFeature' )
	->search(
	{ contact_id => $contact->id, 'me.user_id' => $c->user->id },
	{ prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } )->count;
    $self->status_ok( $c, { count => $count } );
}

=head2 /services/faces/contacts

Return all contacts for logged in user that appear in at
least one video.

=cut

sub contacts :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ page => undef,
          rows => 10,
        ],
        @_ );

    my $user = $c->user->obj;

    # Find all contacts for a user that appear in at least one video.
    my $search = {
	'me.user_id' => $user->id,
	contact_id => {'!=',undef},
	'contact.contact_name' => { '!=',undef},
	'contact.picture_uri' => { '!=',undef},
    };
    my $where = {
	select => ['contact_id', 'media_asset_id'],
	prefetch=>['contact', 'media_asset'],
	group_by => ['contact_id'],
    };
    my @feats = $c->model( 'RDS::MediaAssetFeature' )->search( $search, $where );

    my @data = ();
    foreach my $feat ( @feats ) {

	my $contact = $feat->contact;
	my $asset   = $feat->media_asset;
	my $hash    = $contact->TO_JSON;


	my $klass = $c->config->{mediafile}->{$asset->location};
	my $fp = new $klass;
	my $url = $fp->uri2url( $c, $contact->picture_uri );

	$hash->{url} = $url;
	$hash->{asset_id} = $asset->uuid;
	$hash->{appears_in} = $c->model( 'RDS::MediaAssetFeature' )->
	    search({contact_id=>$feat->contact_id},{prefetch => { 'media_asset' => 'media' }, group_by => ['media.id']})->count;

	## REMOVE ME
	if ( ! defined( $hash->{uuid} ) ) {
	    $hash->{uuid} = $hash->{id};
	}

	push( @data, $hash );
    }

    # Because of the nature of this query, I could not use the native DBIX pager,
    # and therefore I need to implement that functionality myself, including the
    # sort.
    #
    my @sorted = sort { $b->{appears_in} <=> $a->{appears_in} } @data;
    $sorted[0]->{star_power} = 'star1' if ( $#sorted >=0 );
    $sorted[1]->{star_power} = 'star2' if ( $#sorted >=1 );
    $sorted[2]->{star_power} = 'star3' if ( $#sorted >=2 );
    
    if ( $args->{page} ) {
	my $pager = Data::Page->new( $#sorted + 1, $args->{rows}, $args->{page} );
	my @slice = ();
	if ( $#sorted >= 0 ) {
	    @slice = @sorted[ $pager->first - 1 .. $pager->last - 1 ];
	}
	
	$self->status_ok( $c, { faces => \@slice, 
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
	$self->status_ok( $c, { faces => \@sorted } );
    }
}

=head2 /services/faces/faces_in_mediafile, /services/na/faces_in_mediafile

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
    $c->forward( '/services/na/faces_in_mediafile' );
}

=head2 /services/faces/contact

Return the contact information for the passed in contact uuid

=cut

sub contact :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    unless( $cid ) {
	$self->status_bad_request
	    ( $c, $c->loc( 'Missing required param: [_1]', 'cid' ) );
    }
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
    unless( $contact ) {
	$contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
    }
    unless( $contact ) {
	$self->status_bad_request
	    ( $c, $c->loc( 'Cannot find contact for [_1]', $cid ) );
    }

    my $klass = $c->config->{mediafile}->{'us'};
    my $fp = new $klass;
    my $url = $fp->uri2url( $c, $contact->picture_uri );

    my $hash = $contact->TO_JSON;
    $hash->{url} = $url;

    $self->status_ok( $c, { contact => $hash } );
}

sub fix_uploads :Private {
    my( $self, $c ) = @_;
    # find all media assert features of type face with contact_id == NULL,
    # a case that happends with uploaded files from popeye, until popeye is
    # fixed.
    my @features = $c->model( 'RDS::MediaAssetFeature' )->
	search({ feature_type => 'face',
		 'me.user_id' => $c->user->obj->id,
		 contact_id => undef },
	       { prefetch => 'media_asset' });

    foreach my $feat ( @features ) {
	my $contact = $c->model( 'RDS::Contact' )->find_or_create(
	    {
		picture_uri => $feat->media_asset->uri,
		user_id => $c->user->obj->id,
	    });
	if ( $contact ) {
	    $feat->contact_id( $contact->id );
	    $feat->update;
	}
    }
}

=head2 /services/faces/all_contacts

Returns list of contacts that match the regular expression passed
in as 'term'.

=cut

sub all_contacts :Local {
    my( $self, $c) = @_;
    my $q = $c->req->param( 'term' );

    ## $self->fix_uploads( $c );  ## REMOVE ME WHEN POPEYE IS FIXED

    my $where = {};
    if ( $q ) {
	$where = { contact_name => { '!=', undef }, 'LOWER(contact_name)' => { 'like', '%'.lc($q).'%' } };
    }

    my @contacts = $c->user->contacts->search($where,{order_by => 'contact_name'});

    my @data = ();
    foreach my $contact ( @contacts ) {
	my $hash = $contact->TO_JSON;
	if ( $contact->picture_uri ) {
	    $hash->{url} = new VA::MediaFile::US()->uri2url( $c, $contact->picture_uri );
	}
	#else {
	#    DO NOT PUT A PLACE HOLDER PIC HERE.  The GUI will look to see it this is
	#    null to determine how to render.
	#}
	$hash->{uuid} = $hash->{id} unless( $hash->{uuid} );
	push( @data, $hash );
    }

    if ( $q ) {
	my @ret = ();
	foreach my $con ( @data ) {
	    push( @ret, { label => $con->{contact_name}, cid => $con->{uuid}, url => $con->{url} });
	}
	$self->status_ok( $c, \@ret );
    }
    else {
	$self->status_ok( $c, { contacts => \@data } );
    }
}

=head2 /services/faces/photos_of

Return all the known photos of a contact uuid

=cut
sub photos_of :Local {
    my( $self, $c ) = @_;
    my $cid = $c->req->param( 'cid' );
    my $contact = $c->model( 'RDS::Contact' )->find({uuid=>$cid});
    unless( $contact ) {
	$contact = $c->model( 'RDS::Contact' )->find({id=>$cid});
    }
    unless( $contact ) {
	$self->status_ok( $c, {} );
    }

=perl
    # THIS WAS HERE TO DEBUG, NEEDED BEFORE IV CAN AGGRAGATE FACES
    my @features = $c->model( 'RDS::Contact' )->search({contact_name => undef, user_id => $c->user->id});
    my @data = ();
    foreach my $feat ( @features ) {
	my $url = new VA::MediaFile::US()->uri2url( $c, $feat->picture_uri );
	push( @data, { url => $url, id => $feat->id } );
    }
    $self->status_ok( $c, \@data );
=cut

    my @features = $c->model( 'RDS::MediaAssetFeature' )->
	search({ contact_id => $contact->id,
		 'me.user_id' => $c->user->id },
	       { prefetch => 'media_asset' });
    my @data = ();
    foreach my $feat ( @features ) {
	my $url = new VA::MediaFile::US()->uri2url( $c, $feat->media_asset->uri );
	push( @data, { url => $url, uri => $feat->media_asset->uri, id => $feat->id } );
    }
    $self->status_ok( $c, \@data );
}

sub contact_emails :Local {
    my( $self, $c ) = @_;
    my $q = $c->req->param( "q" );
    my $where = { -or => [
		       'LOWER(contact_name)' => { 'like', '%'.lc($q).'%' },
		       'LOWER(contact_email)' => { 'like', '%'.lc($q).'%' },
		      ] };
    my @contacts = $c->user->contacts->search($where);

    if ( $#contacts == -1 ) {
	my $email = $self->is_email_valid( $q );
	if ( $email ) {
	    $self->status_ok( $c, [{ id => $email->format, name => $email->format }] );
	}
    }
    my @data = map { {id => $_->contact_email, name => $_->contact_name} } @contacts;
    $self->status_ok( $c, \@data );
}

sub change_contact :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ uuid => undef,
	  cid => undef,
	  new_uri => undef,
	  contact_name => undef,
	  contact_email => undef
	], @_ );

    my $contact = $c->user->contacts->find({ uuid => $args->{uuid} });
    unless( $contact ) {
	$contact = $c->user->contacts->find({ id => $args->{uuid} });
    }
    unless( $contact ) {
	$self->status_bad_request($c, $c->loc("Cannot find contact for [_1]", $args->{uuid} ));
    }

    if ( $args->{contact_name} ) {
	$contact->contact_name( $args->{contact_name} );
    }
    if ( $args->{contact_email} ) {
	$contact->contact_email( $args->{contact_email} );
    }
    if ( $args->{new_uri} ) {
	$contact->picture_uri( $args->{new_uri} );
    }
    $contact->update;

    $self->status_ok( $c, { contact => $contact->TO_JSON } );
}

sub tag :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
      ( $c,
        [ uuid => undef,
	  cid => undef,
	  new_uri => undef,
	  contact_name => undef
	], @_ );

    my $contact = $c->user->contacts->find({ uuid => $args->{uuid} });
    unless( $contact ) {
	$contact = $c->user->contacts->find({ id => $args->{uuid} });
    }
    unless( $contact ) {
	$self->status_bad_request($c, $c->loc("Cannot find contact for [_1]", $args->{uuid} ));
    }

    if ( ! $args->{cid} ) {
	# Just giving this unknown person a name
	$contact->contact_name( $args->{contact_name} );
	if ( $args->{new_uri} ) {
	    $contact->picture_uri( $args->{new_uri} );
	}
	$contact->update;
	$self->status_ok( $c, { contact => $contact->TO_JSON } );
    }
    else {
	# We are identifying this previously unknown person
	# to be the same person as contact_id 'cid'.  For now
	# I think this means finding all media asset features
	# containing $contact->id and changing it to $identified->id
	#
	my $identified = $c->user->contacts->find({ uuid => $args->{cid} });
	unless( $identified ) {
	    $identified = $c->user->contacts->find({ id => $args->{cid} });
	}
	unless( $identified ) {
	    $self->status_bad_request($c, $c->loc("Cannot find contact for [_1]", $args->{cid} ));
	}

	foreach my $feat ( $c->model( 'RDS::MediaAssetFeature' )->search({ contact_id => $contact->id }) ) {
	    $feat->contact_id( $identified->id );
	    $feat->update;
	}

	# Then delete the unknown contact
	$contact->delete; $contact->update;

	$self->status_ok( $c, { contact => $identified->TO_JSON } );
    }
}

__PACKAGE__->meta->make_immutable;
1;
