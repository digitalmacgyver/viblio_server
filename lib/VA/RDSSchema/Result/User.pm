use utf8;
package VA::RDSSchema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::User

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::ColumnDefault>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=item * L<DBIx::Class::UUIDColumns>

=item * L<DBIx::Class::FilterColumn>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "ColumnDefault",
  "TimeStamp",
  "PassphraseColumn",
  "UUIDColumns",
  "FilterColumn",
);

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 provider

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 16

=head2 provider_id

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 displayname

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 active

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 confirmed

  data_type: 'tinyint'
  is_nullable: 1

=head2 accepted_terms

  data_type: 'tinyint'
  is_nullable: 1

=head2 access_token

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 api_key

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 metadata

  data_type: 'text'
  is_nullable: 1

=head2 user_type

  data_type: 'varchar'
  default_value: 'individual'
  is_foreign_key: 1
  is_nullable: 0
  size: 32

=head2 banner_uuid

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 36

=head2 created_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "provider",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 16 },
  "provider_id",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "displayname",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "active",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "confirmed",
  { data_type => "tinyint", is_nullable => 1 },
  "accepted_terms",
  { data_type => "tinyint", is_nullable => 1 },
  "access_token",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "api_key",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "metadata",
  { data_type => "text", is_nullable => 1 },
  "user_type",
  {
    data_type => "varchar",
    default_value => "individual",
    is_foreign_key => 1,
    is_nullable => 0,
    size => 32,
  },
  "banner_uuid",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 36 },
  "created_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "updated_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<email_UNIQUE>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("email_UNIQUE", ["email"]);

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 banner_uuid

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "banner_uuid",
  "VA::RDSSchema::Result::Media",
  { uuid => "banner_uuid" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);

=head2 communities

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities",
  "VA::RDSSchema::Result::Community",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contacts

Type: has_many

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->has_many(
  "contacts",
  "VA::RDSSchema::Result::Contact",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contacts_contact_viblios

Type: has_many

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->has_many(
  "contacts_contact_viblios",
  "VA::RDSSchema::Result::Contact",
  { "foreign.contact_viblio_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 links

Type: has_many

Related object: L<VA::RDSSchema::Result::Link>

=cut

__PACKAGE__->has_many(
  "links",
  "VA::RDSSchema::Result::Link",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_comments

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaComment>

=cut

__PACKAGE__->has_many(
  "media_comments",
  "VA::RDSSchema::Result::MediaComment",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_shares

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaShare>

=cut

__PACKAGE__->has_many(
  "media_shares",
  "VA::RDSSchema::Result::MediaShare",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 medias

Type: has_many

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->has_many(
  "medias",
  "VA::RDSSchema::Result::Media",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organization_users_organizations

Type: has_many

Related object: L<VA::RDSSchema::Result::OrganizationUser>

=cut

__PACKAGE__->has_many(
  "organization_users_organizations",
  "VA::RDSSchema::Result::OrganizationUser",
  { "foreign.organization_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organization_users_users

Type: has_many

Related object: L<VA::RDSSchema::Result::OrganizationUser>

=cut

__PACKAGE__->has_many(
  "organization_users_users",
  "VA::RDSSchema::Result::OrganizationUser",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 profiles

Type: has_many

Related object: L<VA::RDSSchema::Result::Profile>

=cut

__PACKAGE__->has_many(
  "profiles",
  "VA::RDSSchema::Result::Profile",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 provider

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Provider>

=cut

__PACKAGE__->belongs_to(
  "provider",
  "VA::RDSSchema::Result::Provider",
  { provider => "provider" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "CASCADE",
  },
);

=head2 user_devices

Type: has_many

Related object: L<VA::RDSSchema::Result::UserDevice>

=cut

__PACKAGE__->has_many(
  "user_devices",
  "VA::RDSSchema::Result::UserDevice",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_roles

Type: has_many

Related object: L<VA::RDSSchema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "VA::RDSSchema::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_type

Type: belongs_to

Related object: L<VA::RDSSchema::Result::UserType>

=cut

__PACKAGE__->belongs_to(
  "user_type",
  "VA::RDSSchema::Result::UserType",
  { type => "user_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 viblio_added_contents

Type: has_many

Related object: L<VA::RDSSchema::Result::ViblioAddedContent>

=cut

__PACKAGE__->has_many(
  "viblio_added_contents",
  "VA::RDSSchema::Result::ViblioAddedContent",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workorders

Type: has_many

Related object: L<VA::RDSSchema::Result::Workorder>

=cut

__PACKAGE__->has_many(
  "workorders",
  "VA::RDSSchema::Result::Workorder",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IzmaJs5Ob10y/4NwREDCjg
use Email::AddressParser;
use Email::Address;

use Storable qw/ dclone /;

sub is_email_valid {
    my( $self, $email ) = @_;
    my @addresses = Email::Address->parse( $email );
    return undef if ( $#addresses == -1 );
    return $addresses[0];
}

# I like this relationship name better
#
__PACKAGE__->has_many(
  "media",
  "VA::RDSSchema::Result::Media",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
    "albums" => "VA::RDSSchema::Result::Media",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0,
      where => { "me.is_album" => 1 }
    },
);

__PACKAGE__->has_many(
    "videos" => "VA::RDSSchema::Result::Media",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0 },
);

# Return an rs that can find videos, both owned by user and shared to
# user via the legacy MediaShares mechanism.
#
# NOTE: this does not include things shared to the user via the new
# Community mechanism.
# 
sub private_and_shared_videos {
    my( $self, $only_visible, $status, $only_videos, $where_arg ) = @_;

    if ( !defined( $only_visible ) ) {
	$only_visible = 1;
    }
    if ( !defined( $only_videos ) ) {
	$only_videos = 1;
    }

    my $where = {};
    if ( defined( $where_arg ) ) {
	$where = dclone( $where_arg );
    }
    $where->{'-or'} = ['me.user_id' => $self->id, 
		       'media_shares.user_id' => $self->id];
    if ( $only_visible ) {
	$where->{'me.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{'me.status'} = $status;
    }
    if ( $only_videos ) {
	$where->{ 'me.media_type' } = 'original';
    }

    return $self->result_source->schema->resultset( 'Media' )->search(
	$where,
	{ prefetch => 'media_shares',
	  order_by => [ 'me.recording_date desc', 'me.created_date desc' ] } );
}

__PACKAGE__->has_many(
    "contacts" => "VA::RDSSchema::Result::Contact",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0,
      where => { 'me.is_group' => 0 }
    },
);

# groups the user owns
__PACKAGE__->has_many(
    "groups" => "VA::RDSSchema::Result::Contact",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0,
      where => { 'me.is_group' => 1, 'me.provider_id' => undef }
    },
);

__PACKAGE__->has_many(
    "contacts_and_groups" => "VA::RDSSchema::Result::Contact",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0,
      where => {provider_id => undef}
    }
);

# Called with a group uuid, return 1/0 if user is a member of
# Called with no arg, return list of groups user is a member of
sub is_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'ContactGroup' )->search
	    ({'contact.contact_email'=>$self->email,
	      'cgroup.uuid' => $gid},
	     {prefetch=>['contact','cgroup']});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'ContactGroup' )->search
	    ({'contact.contact_email'=>$self->email},
	     {prefetch=>['contact','cgroup']});
	return map { $_->cgroup } @cgroups;
    }
}

# Called with a community uuid, return 1/0 if user is a member of
# Called with no arg, return list of communities user is a member of
sub is_community_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'ContactGroup' )->search
	    ({'contact.contact_email'=>$self->email,
	      'community.uuid' => $gid},
	     {prefetch=>['contact',{'cgroup'=>'community'}]});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'ContactGroup' )->search
	    ({'contact.contact_email'=>$self->email},
	     {prefetch=>['contact',{'cgroup'=>'community'}]});
	return map { $_->cgroup->community } @cgroups;
    }
}

# Given a mediafile uuid, is the user able to view it
# via the new community shared albums mechanism.
#
# NOTE: This does not return true for videos shared under the legacy
# sharing mechanism.
sub can_view_video {
    my( $self, $mid ) = @_;
    my $rs1 = $self->result_source->schema->resultset( 'ContactGroup' )->search
	({'contact.contact_email'=>$self->email},
	 {prefetch=>['contact',{'cgroup'=>'community'}]});

    my $rs2 = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	({'videos.uuid'=>$mid,
	  -or => [ 'album.user_id' => $self->id,
		   'community.id' => {
		       -in => $rs1->get_column('community.id')->as_query} ] },
	 {prefetch=>['videos',{'album'=>'community'}]});

    return ( $rs2->count );
}

# A user really only has one profile
__PACKAGE__->has_one(
  "profile",
  "VA::RDSSchema::Result::Profile",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{password};
    delete $hash->{id};
    return $hash;
}

__PACKAGE__->uuid_columns( 'uuid' );

# Have the 'password' column use a SHA-1 hash and 20-byte salt
# with RFC 2307 encoding; Generate the 'check_password" method
__PACKAGE__->add_columns(
    'password' => {
       data_type => 'text',
       passphrase       => 'rfc2307',
       passphrase_class => 'SaltedDigest',
       passphrase_args  => {
           algorithm   => 'SHA-1',
           salt_random => 20,
       },
       passphrase_check_method => 'check_password',
    },
    'active' => {
       data_type => 'datetime',
       inflate_datetime => 1,
       set_on_create => 1, set_on_update => 1,
    },
    );

sub create_profile {
    my( $self ) = @_;
    
    $self->create_related( 'profile', {} );
    
    # Add some fields
    $self->profile->create_related( 'profile_fields',
                                    { name => 'email_notifications',
                                      value => 'True',
                                      public => 1 } );

    $self->profile->create_related( 'profile_fields',
                                    { name => 'email_comment',
                                      value => 'True',
                                      public => 1 } );

    $self->profile->create_related( 'profile_fields',
                                    { name => 'email_upload',
                                      value => 'True',
                                      public => 1 } );

    $self->profile->create_related( 'profile_fields',
                                    { name => 'email_face',
                                      value => 'True',
                                      public => 1 } );

    $self->profile->create_related( 'profile_fields',
                                    { name => 'email_viblio',
                                      value => 'True',
                                      public => 1 } );
}

sub create_contact {
    my( $self, $email_or_name ) = @_;
    my $address = $self->is_email_valid( $email_or_name );
    my( $email, $name, $contact );
    my $needs_update = 0;

    if ( $address ) { $email = $email_or_name; }
    else { $name = $email_or_name; }
    if ( $email ) {
	$name = $address->name;
	$contact = $self->find_or_create_related(
	    'contacts', { contact_email => $email });
	unless( $contact ) {
	    die "Unable to create contact";
	}
	unless( $contact->contact_name ) {
	    $contact->contact_name( $name );
	    $needs_update = 1;
	}
	unless( $contact->contact_viblio_id ) {
	    my $vuser = $self->result_source->schema->resultset( 'User' )
		->find({ email => $email });
	    if ( $vuser ) {
		$contact->contact_viblio_id( $vuser->id );
		$needs_update = 1;
	    }
	}
    }
    elsif ( $name ) {
	$contact = $self->find_or_create_related(
	    'contacts', { contact_name => $name });
	unless( $contact ) {
	    die "Unable to create contact";
	}	
    }

    if ( $needs_update ) { $contact->update; }
    return $contact;
}

# When creating a normal group, $provider will be NULL
# but when creating a group intended as a membership
# group, provider will be non-NULL and this can be used
# to filter user observable groups.
sub create_group {
    my( $self, $name, $list, $provider ) = @_;
    my @clean = ();

    my @new_contacts = ();
    my @display_names = ();

    if ( $list && (ref $list eq 'ARRAY') ) {
        @clean = @$list;
    }
    elsif ( $list && ( ref $list eq 'VA::Model::RDS::Contact' ) ) {
	@new_contacts = $list->contacts;
    }
    elsif ( $list ) {
        my @list = split( /[ ,]+/, $list );
        @clean = map { $_ =~ s/^\s+//g; $_ =~ s/\s+$//g; $_ } @list;
    }

    if ( $#new_contacts >= 0 ) {
	foreach my $contact ( @new_contacts ) {
	    push( @display_names, $contact->contact_name );
	}
    }
    else {
	foreach my $email ( @clean ) {
	    my $contact = $self->create_contact( $email );
	    push( @new_contacts, $contact );
	    push( @display_names, $contact->contact_name );
	}
    }

    # Create a name for this group unless supplied
    unless( $name ) {
        if ( $#display_names == -1 ) {
            $name = 'Unnamed Group';
        }
        elsif ( $#display_names == 0 ) {
            $name = $display_names[0] . ' Group';
        }
        elsif ( $#display_names == 1 ) {
            $name = join( ', ', @display_names );
        }
        elsif ( $#display_names > 1 ) {
            $name = $display_names[0] . ', ' .
		   $display_names[1] . ' and others';
	}
    }

    my $group = $self->find_or_create_related(
	'groups', {
	    is_group => 1,
	    provider_id => $provider,
	    contact_name => $name });
    unless( $group ) {
	die "Cannot create group: $name";
    }
    foreach my $contact ( @new_contacts ) {
	$self->result_source->schema->resultset( 'ContactGroup' )
	    ->find_or_create({ group_id => $group->id, contact_id => $contact->id });
    }
    return $group;
}

# Utility to create a shared album
sub create_shared_album {
    my( $self, $album, $members ) = @_;
    # Name of community is same as title of shared album
    my $name = $album->title;
    my $community = $self->create_related(
	'communities', {
	    name => ( $name || 'Unnamed' ),
	    media_id => $album->id
	});
    # Want to make sure the membership group is a *copy*
    # of anything passed in.  So give it a unique name.
    my $group_name = $community->name . $community->id;
    my $group = $self->create_group( $group_name, $members, '_shared_album' );
    $community->members_id( $group->id );
    $community->update;
    return $community;
}

# Used to create the pulldown menu of possible filters; find all
# unique activities in the user's videos.  This method returns an
# array of activities found across all videos, NOT a searchable rs.
sub video_filters {
    my( $self, $only_visible, $status ) = @_;

    if ( !defined( $only_visible ) ) {
	$only_visible = 1;
    }

    my $where = { 'media.user_id' => $self->id,
		  "media.is_album" => 0,
		  'me.feature_type' => 'activity',
		  'media.media_type' => 'original' };
    
    if ( $only_visible ) {
	$where->{'media.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{'media.status'} = $status;
    }
    
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search( 
	$where,
	{ prefetch => { 'media_asset' => 'media' },
	  group_by => ['coordinates'] } );
    my @feats = $rs->all;
    my @filters = map { $_->coordinates } @feats;
    # how about faces?

    $where = { 'media.user_id' => $self->id,
	       "media.is_album" => 0,
	       'me.feature_type' => 'face',
	       'media.media_type' => 'original' };

    if ( $only_visible ) {
	$where->{'media.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{'media.status'} = $status;
    }

    $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	$where,
	{ prefetch => { 'media_asset' => 'media' } } );
    

    if ( $rs->count ) {
	push( @filters, 'people' );
    }
    return @filters;
}

# Return the list of videos that contain one of the activities passed
# in as a list.
sub videos_with_activities {
    my( $self, $act_list, $from, $to, $only_visible, $status ) = @_;

    if ( !defined( $only_visible ) ) {
	$only_visible = 1;
    }

    my $where = { 'media.user_id' => $self->id,
		  "media.is_album" => 0,
		  'me.feature_type' => 'activity',
		  'me.coordinates' => { -in => $act_list },
		  'media.media_type' => 'original' };

    if ( $only_visible ) {
	$where->{'media.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{'media.status'} = $status;
    }

    if ( $from && $to ) {
	my $dtf = $self->result_source->schema->storage->datetime_parser;
	$where->{ 'media.recording_date' } = { 
	    -between => [
		 $dtf->format_datetime( $from ),
		 $dtf->format_datetime( $to ) ] };
    }
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	$where,
	{ prefetch => { 'media_asset' => 'media' },
	  group_by => ['media.id'] } );
    return map { $_->media_asset->media } $rs->all;
}

# Return the list of videos that contain faces
sub videos_with_people {
    my( $self, $from, $to, $only_visible, $status ) = @_;
    
    if ( !defined( $only_visible ) ) {
	$only_visible = 1;
    }

    my $where = { 'media.user_id' => $self->id,
		  "media.is_album" => 0,
		  'me.contact_id' => { '!=', undef },
		  'me.feature_type' => 'face',
		  'media.media_type' => 'original' };

    if ( $only_visible ) {
	$where->{'media.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{'media.status'} = $status;
    }

    if ( $from && $to ) {
	my $dtf = $self->result_source->schema->storage->datetime_parser;
	$where->{ 'media.recording_date' } = { 
	    -between => [
		 $dtf->format_datetime( $from ),
		 $dtf->format_datetime( $to ) ] };
    }
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	$where,
	{ prefetch => { 'media_asset' => 'media' },
	  group_by => ['media.id'] } );
    return map { $_->media_asset->media } $rs->all;
}    

use VA::Controller::Services;
# NOTE: This function does not return albums.  It returns the contents
# of albums, but ignores albums as potential "media".
#
# If sent an array reference of media_uuid's in input, returns a
# subset of that list the user is allowed to view, otherwise returns a
# list of visible media, including both media owned by the user,
# shared via legacy media_shares, or shared via community.
# 
# Return things in a predictable order (recording_date, created_date
# descending) and with no duplicates.
#
# This has become a central method of which function which many other
# functions rely on to implement their logic.  The two main parts of
# application logic for fetching media resources are:
#
# Operation 1. Get a list of media visible to the user constrainted by
# some search criteria.
#
# Operation 2. Publish that list.
#
# Operation 1 is handled here, operation 2 is handled via
# VA::Controller::Services and it's call to VA::MediaFile::publish.
#
# This method computes a ton of data, ideally in the future it will
# check caches for this data rather than recomputing it.
# 
# This method gets and returns entire data sets, paging is the
# responsibility of the caller.  In part this is because this method
# computes many global properties of a result set that may not occur
# in a given page (for example a list of all tags in a given album,
# regardless of the page of results).
sub visible_media {
    my ( $self, $params ) = @_;

    return $self->visible_media_1( $params );
}

sub get_cities {
    my ( $self, $params ) = @_;
    
    $params->{rows} = undef;
    $params->{page} = undef;
    
    my ( $rs, $prefetch ) = $self->_get_visible_result_set( $params );
    
    my $cities_rs = $rs->search( undef, { join => $prefetch } );
    
    $cities_rs = $cities_rs->search( undef,
				     { columns => [
					   { 'city_name' => { distinct => 'me.geo_city' } } ],
					   order_by => undef } );
    
    return map { $_->{_column_data}->{city_name}  } $cities_rs->all();
}

# Returns only string tags, not also faces associated with the videos,
# those are handlded by get_face_tags.
# 
# For a given result set returns a hash of of tag_name : unique_videos_with_tag
#
sub get_tags {
    my ( $self, $params ) = @_;
    
    $params->{rows} = undef;
    $params->{page} = undef;
    
    my ( $rs, $prefetch ) = $self->_get_visible_result_set( $params );
    
    my $tags_search = { 'media_asset_features.feature_type' => 'activity' };
    my $tags_columns = [
	{ 'tag_name' => 'media_asset_features.coordinates' }, 
	{ 'tag_count' => { count => { distinct => 'media_asset_features.media_id' } } } ];
    my $tags_group_by = 'media_asset_features.coordinates';

    my $tags_rs = $rs->search( $tags_search, 
			       { join => $prefetch,
				 columns => $tags_columns,
				 group_by => $tags_group_by,
				 order_by => undef } );
    
    my @result = ();
    push( @result, $tags_rs->all() );
    
    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $no_date_date = DateTime->from_epoch( epoch => 0 );
    my $no_date_rs = $rs->search( { 'me.recording_date' => $dtf->format_datetime( $no_date_date ) },
				  { join => $prefetch,
				    columns => [
					{ 'no_date_count' => { count => { distinct => 'me.id' } } } ],
					order_by => undef } );
    
    my @no_date_result = $no_date_rs->all();
    if ( scalar( @no_date_result ) and $no_date_result[0]->{_column_data}->{no_date_count} > 0 ) {
	push( @result, {
	    _column_data => { 
		tag_name => 'No Dates',
		tag_count => $no_date_result[0]->{_column_data}->{no_date_count} } } );
    }
    
    my $result_hash = {};
    foreach my $result ( @result ) {
	$result_hash->{$result->{_column_data}->{tag_name}} = $result->{_column_data}->{tag_count};
    }
    
    return $result_hash;
}

# Note - this returns its result based on contact_uuid, because two
# contacts can have the same name.
#
# Called when various APIs have a true include_contact_info flag.
# This information is used to build the tag clouds with approrpiate
# sizes for face tags.
#
# For a given result set returns a hash of of contact_uuid : unique_videos_with_contact_uuid
#
sub get_face_tags {
    my ( $self, $params ) = @_;

    $params->{rows} = undef;
    $params->{page} = undef;

    my ( $rs, $prefetch ) = $self->_get_visible_result_set( $params );

    # DEBUG
    #$DB::single = 1;

    # Do this goofy thing here for performance reasons - the more
    # direct approach takes several seconds.
    my $media_rs = $rs->search( undef,
				{  join => [ 'media_assets' ],
				   columns => [
				       { 'media_ids' => { distinct => 'me.id' } } ],
				       order_by => undef } );
    
    my $search = { 'media_asset_features.feature_type' => 'face',
		   'contact.contact_name' => { '!=', undef } };
    my $faces_columns = [
	{ 'contact_name' => 'contact.contact_name' }, 
	{ 'contact_uuid' => 'contact.uuid' }, 
	{ 'asset_uuid' => 'me.uuid' },
	{ 'asset_location' => 'me.location' },
	{ 'picture_uri' => 'contact.picture_uri' },
	{ 'face_count' => { count => { distinct => 'media_asset_features.media_id' } } } ];
    my $group_by = 'contact.id';
    
    $search->{'media_asset_features.media_id'} = { -in => $media_rs->get_column('media_ids')->as_query() };
    my $face_rs = $self->result_source->schema->resultset( 'MediaAsset' )->search
	( $search,
	  { join => { media_asset_features => 'contact' },
	    columns => $faces_columns,
	    group_by => $group_by } );
    $rs = $face_rs;

    my @result = ();
    push( @result, $rs->all() );
    my $result_hash = {};
    foreach my $result ( @result ) {
	$result_hash->{$result->{_column_data}->{contact_uuid}} = 
	    { contact_name => $result->{_column_data}->{contact_name},
	      contact_uuid => $result->{_column_data}->{contact_uuid},
	      asset_uuid => $result->{_column_data}->{asset_uuid},
	      asset_location => $result->{_column_data}->{asset_location},
	      picture_uri => $result->{_column_data}->{picture_uri},
	      face_count => $result->{_column_data}->{face_count} };
    }
    
    return $result_hash;
}

# Note - this returns its result based on contact_uuid, because two
# contacts can have the same name.
#
# NOTE: This method enforces no access control, the caller must ensure
# only appropriate data is returned.
#
sub get_face_tags_for_media_id {
    my ( $self, $media_ids ) = @_;

    my $search = { 'media_asset_features.feature_type' => 'face',
		   'contact.contact_name' => { '!=', undef },
		   # Not UUIDs, but IDs here - this is a hack.
		   'me.media_id' => { -in => $media_ids } };
    my $faces_columns = [
	{ 'contact_name' => 'contact.contact_name' }, 
	{ 'contact_uuid' => 'contact.uuid' }, 
	{ 'asset_uuid' => 'me.uuid' },
	{ 'asset_location' => 'me.location' },
	{ 'picture_uri' => 'contact.picture_uri' },
	{ 'face_count' => { count => { distinct => 'media_asset_features.media_id' } } } ];
    my $group_by = 'contact.id';

    my $rs = $self->result_source->schema->resultset( 'MediaAsset' )->search( 
	$search,
	{ join => { media_asset_features => 'contact' },
	  columns => $faces_columns,
	  group_by => $group_by } );

    my @result = ();
    push( @result, $rs->all() );
    my $result_hash = {};
    foreach my $result ( @result ) {
	$result_hash->{$result->{_column_data}->{contact_uuid}} = 
	    { contact_name => $result->{_column_data}->{contact_name},
	      contact_uuid => $result->{_column_data}->{contact_uuid},
	      asset_uuid => $result->{_column_data}->{asset_uuid},
	      asset_location => $result->{_column_data}->{asset_location},
	      picture_uri => $result->{_column_data}->{picture_uri},
	      face_count => $result->{_column_data}->{face_count} };
    }
    
    return $result_hash;
}

sub visible_media_1 {
    my ( $self, $params ) = @_;

    my $args = $self->_get_args( $params );
    
    my ( $rs, $prefetch ) = $self->_get_visible_result_set( $params );

    $rs = $rs->search( undef, { 
	prefetch => $prefetch } );
    
    my @output = $rs->all();

    my $pager = undef;
    if ( $args->{page} and $args->{rows} ) {
	$pager = $rs->pager();
    }

    # Sort the result set by descending recorded date, then created date.
    return ( \@output, $pager );
}

sub _get_args {
    my ( $self, $params ) = @_;

    my $args = {
	# Default result pages and rows.
	page                => 1,
	rows                => 10000,

	# If specified, the set of videos under consideration, if not
	# set all videos visible to this user are considered.
	'media_uuids[]'      => [],

	# Controls the level of detail in our return data for each
	# media returned.
	include_contact_info => 0,
	include_images       => 0,
	include_tags         => 0,

	# If any of these are set, the boolean and of these will be
	# applied to the result to filter the results down.

	'album_uuids[]'      => [],    # List of album UUIDs to search
				       # within.  If not specified
				       # consider all albums and no
				       # albums.
	'contact_uuids[]'    => [],    # List of contact UUIDs to
				       # search within.
        'owner_uuids[]'      => [],    # List of owner UUIDs to search
				       # within.  If not specified
				       # consdier all owners.

	no_dates             => 0,     # Limit results to videos with
				       # no recording_date set.

	recent_created_days  => 0,     # If true limit results to
				       # those whose creation date is
				       # within recent_created_days of
				       # the most recenly created
				       # video.

	search_string        => undef, # Title, description, tags, contact name
	'tags[]'             => [],    # A list of tags and/or contact names.

	only_videos          => 1,     # Set by default, the results
				       # will only include media of
				       # type 'original' (not Facebook
				       # faces, albums, images, etc.)

	# The order of operations here is: 
	#
	# If only_visible is set then the media.status field must be
	# one of 'visible' or 'complete'.
	#
	# However, even if only_visible is set, if status[] is set
	# only media meeting the values in the status[] array will be
	# returned.
	only_visible         => 1,
	'status[]'           => [],	
	
	'views[]'            => [],

	# Default where clause for each query.
	where                => {},
	# Default order clause for each query.
	order_by             => [ 'me.recording_date desc', 'me.created_date desc' ]
    };

    for my $arg ( keys( %$args ) ) {
	if ( exists( $params->{$arg} ) ) {
	    $args->{$arg} = $params->{$arg}
	}
    }

    # Fix up the views argument if specified.
    if ( scalar( @{$args->{'views[]'}} ) ) {
	my $requested_views = {};
	for my $rv ( @{$args->{'views[]'}} ) {
	    $requested_views->{$rv} = 1;
	}
	if ( $args->{include_contact_info} and !exists( $requested_views->{'face'} ) ) {
	    # Include face views if the user wants contact info.
	    push( @{$args->{'views[]'}}, 'face' );
	    $requested_views->{'face'} = 1;
	}
	if ( scalar( @{$args->{'contact_uuids[]'}} ) and !exists( $requested_views->{'face'} ) ) {
	    # Include face views if the user wants contact info.
	    push( @{$args->{'views[]'}}, 'face' );
	    $requested_views->{'face'} = 1;
	}
	if ( $args->{include_tags} and !exists( $requested_views->{'main'} ) ) {
	    # Include the main view (which has the features related to
	    # the tags associate with it).
	    push( @{$args->{'views[]'}}, 'main' );
	    $requested_views->{'main'} = 1;
	}
    }

    return $args;
}

sub _get_visible_result_set {
    my ( $self, $params ) = @_;

    my $args = $self->_get_args( $params );

    # Get a list of all the media this user can see by virtue of
    # communities.
    my @user_communities = $self->is_community_member_of();
    my @user_community_ids = map { $_->id(); } @user_communities;
    
    my $where = $args->{where};
    $where->{ '-or' } = [ 'community.id' => { -in => \@user_community_ids },
			  'me.user_id' => $self->id(),
			  'media_shares.user_id' => $self->id() ];
    if ( $args->{only_visible} ) {
	$where->{'me.status'} = [ 'visible', 'complete' ];
    }
    if ( scalar( @{$args->{'status[]'}} ) ) {
	$where->{'me.status'} = $args->{'status[]'};
    }
    if ( $args->{only_videos} ) {
	$where->{ 'me.media_type' } = 'original';
    }
    $where->{'me.is_album'} = 0;

    my $prefetch = [ 
	# Get the media that is in community albums.
	{ 'media_albums_other' => { 'community' => 'community_album' } },
	# Get the media that is in an abum period.
	{ 'media_albums_other' => 'album' },
	# Get media that is shared via the old style share mechanism.
	'media_shares'
	];

    if ( scalar( @{$args->{'contact_uuids[]'}} )
	 or scalar( @{$args->{'tags[]'}} )
	 or defined( $args->{search_string} ) ) {
	push( @$prefetch, { 'media_assets' => { 'media_asset_features' => 'contact' } } );
    } else {
	push( @$prefetch, 'media_assets' );
    }
    
    my $rs = $self->result_source->schema->resultset( 'Media' )->search
	( $where,
	  { columns => [ { 'media_ids' => { distinct => 'me.id' } } ],
	    join => $prefetch } );

    # Limit to the desired media_uuids if any.
    if ( scalar( @{$args->{'media_uuids[]'}} ) ) {
	$rs = $rs->search( { 'me.uuid' => { -in => $args->{'media_uuids[]'} } } );
    }
    
    # Limit to the desired album_uuids if any.
    if ( scalar( @{$args->{'album_uuids[]'}} ) ) {
	$rs = $rs->search( { -or => [ 'community_album.uuid' => { -in => $args->{'album_uuids[]'} },
				      'album.uuid' => { -in => $args->{'album_uuids[]'} } ] } );
    }

    # Limit to the desired owner_uuids if any.
    if ( scalar( @{$args->{'owner_uuids[]'}} ) ) {
	# DEBUG - do we need to do a pre-query to get user.uuids into
	# ids, or should we add more prefetching here.
	$rs = $rs->search( { 'user.uuid' => { -in => $args->{'owner_uuids[]'} } } );
    }

    # Limit to videos with no recording_date set if appropriate.
    if ( $args->{no_dates} ) {
	# DEBUG - make no_date_date a configuration element for
	# performance and simplicity.
	my $dtf = $self->result_source->schema->storage->datetime_parser;
	my $no_date_date = DateTime->from_epoch( epoch => 0 );
	$rs = $rs->search( { 'me.recording_date' => $dtf->format_datetime( $no_date_date ) } );
    }

    # Searches over contacts, tags, and search strings all collide
    # with one another over what they want from features, if more than
    # one are present we have to daisy chain the queries together.
    my $mutually_exclusive_tag_searches = 0;

    # Limit to the desired contact_uuids if any.
    if ( scalar( @{$args->{'contact_uuids[]'}} ) ) {
	$rs = $rs->search( { 'contact.uuid' => { -in => $args->{'contact_uuids[]'} } } );
	$mutually_exclusive_tag_searches++;
    }

    # Limit the videos to those whose tags are in tags[].
    if ( scalar( @{$args->{'tags[]'}} ) ) {
	if ( $mutually_exclusive_tag_searches ) {
	    my $tmp_rs = $self->result_source->schema->resultset( 'Media' )->search( { 'me.id' => { -in => $rs->get_column('media_ids')->as_query() } },
										     { columns => [ { 'media_ids' => { distinct => 'me.id' } } ],
										       join => { 'media_assets' => { 'media_asset_features' => 'contact' } } } );
	    $rs = $tmp_rs;
	}
	$rs = $rs->search( { -or => [ -and => [ 'media_asset_features.feature_type' => 'activity', 
						'media_asset_features.coordinates' => { -in => $args->{'tags[]'} } ],
				      -and => [ 'media_asset_features.feature_type' => 'face',
						'media_asset_features.recognition_result' => { -in => [ 'machine_recognized', 'human_recognized', 'new_face' ] },
						'media_asset_features.contact_id' => { '!=', undef },
						'contact.contact_name' => { -in => $args->{'tags[]'} } ] ] } );
	$mutually_exclusive_tag_searches++;
    }

    # Limit the videos to things in the search criteria.
    if ( defined( $args->{search_string} ) ) {
	if ( $mutually_exclusive_tag_searches ) {
	    my $tmp_rs = $self->result_source->schema->resultset( 'Media' )->search( { 'me.id' => { -in => $rs->get_column('media_ids')->as_query() } },
										     { columns => [ { 'media_ids' => { distinct => 'me.id' } } ],
										       join => { 'media_assets' => { 'media_asset_features' => 'contact' } } } );
	    $rs = $tmp_rs;
	}
	$rs = $rs->search( { 
	    -or => [ 'LOWER(me.title)' => { 'like' => '%'.lc( $args->{search_string} ) . '%' },
		     'LOWER(me.description)' => { 'like' => '%'.lc( $args->{search_string} ) . '%' },
		     -and => [ 'media_asset_features.feature_type' => 'activity', 
			       'LOWER(media_asset_features.coordinates)' => { like => '%'.lc( $args->{search_string} ).'%' } ],
		     -and => [ 'media_asset_features.feature_type' => 'face',
			       'media_asset_features.recognition_result' => { -in => [ 'machine_recognized', 'human_recognized', 'new_face' ] },
			       'media_asset_features.contact_id' => { '!=', undef },
			       'LOWER(contact.contact_name)' => { 'like' => '%'.lc( $args->{search_string} ).'%' } ]
		]
			   } );
	$mutually_exclusive_tag_searches++;
    }

    # NOTE: This has to be the last search we make.
    # Limit the videos to those recently created (not recorded).
    #
    # NOTE: We used to do a query by finding videos within
    # recent_created_days of the latest visible video - this ended up
    # having very poor performance.  So we changed the definition to
    # just be videos within recent_created_days of the present.
    
    if ( $args->{recent_created_days} ) {
	# OLD CODE.
	#
	# Hoo boy...
	#my $recent_rs = $rs;
	#my $recent_rs_prefetch = dclone( $prefetch );
	#
	#my @latest = $self->result_source->schema->resultset( 'Media' )->search( { 'me.id' => { -in => $recent_rs->get_column('media_ids')->as_query() } },  { 
	#    join => $recent_rs_prefetch,
	#    order_by => [ 'me.created_date desc' ],
	#    page => 1,
	#    rows => 1 } )->all();
	#
	#if ( scalar( @latest ) and defined( $latest[0]->created_date() ) ) {
	#    my $dtf = $self->result_source->schema->storage->datetime_parser;
	#    my $from_when = DateTime->from_epoch( epoch => $latest[0]->created_date()->epoch() - 60*60*24*$args->{recent_created_days} );
	#    $rs = $rs->search( { 'me.created_date' =>  { '>=', $dtf->format_datetime( $from_when ) } } );
	#}

	# NEW CODE
	my $dtf = $self->result_source->schema->storage->datetime_parser;
	my $from_when = DateTime->from_epoch( epoch => time() - 60*60*24*$args->{recent_created_days} );
	$rs = $rs->search( { 'me.created_date' =>  { '>=', $dtf->format_datetime( $from_when ) } } );
    }

    # This is a modifier of the secondary resultset.
    my $where2 = { 'me.id' => { -in => $rs->get_column('media_ids')->as_query() } };
    if ( scalar( @{$args->{'views[]'}} ) ) {
	$where2->{'media_assets.asset_type'} = { '-in' => $args->{'views[]'} };
    }

    my $rs2 = $self->result_source->schema->resultset( 'Media' )->search( 
	$where2,
	{ order_by => $args->{order_by} } );

    my $prefetch2 = [ 'media_assets' ];

    # The secondary query will look at these to decide what to add to prefetch.
    if ( $args->{include_contact_info} or $args->{include_tags} ) {
	$prefetch2 = { 'media_assets' => { 'media_asset_features' => 'contact' } };
    }
    
    # Agument result sets with the various filters we have.    
    if ( defined( $args->{page} ) ) {
	$rs2 = $rs2->search( undef, { page => $args->{page} } );
    }
    if ( defined( $args->{rows} ) ) {
	$rs2 = $rs2->search( undef, { rows => $args->{rows} } );
    }

    return ( $rs2, $prefetch2 );
}

__PACKAGE__->meta->make_immutable;
1;
