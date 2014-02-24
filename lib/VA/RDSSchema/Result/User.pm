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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bK65PAD554nWisep7G9mWA
use Email::AddressParser;
use Email::Address;

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
      cascade_delete => 0,
      where => { "me.is_album" => 0,
		 -or => [ "me.status" => "visible",
			  "me.status" => "complete" ] }
    },
);

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
      where => { 'me.is_group' => 1 }
    },
);

__PACKAGE__->has_many(
    "contacts_and_groups" => "VA::RDSSchema::Result::Contact",
    { "foreign.user_id" => "self.id" },
    { cascade_copy => 0, 
      cascade_delete => 0 }
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
# via shared albums?
sub can_view_video {
    my( $self, $mid ) = @_;
    my $rs1 = $self->result_source->schema->resultset( 'ContactGroup' )->search
	({'contact.contact_email'=>$self->email},
	 {prefetch=>['contact',{'cgroup'=>'community'}]});

    my $rs2 = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	({'videos.uuid'=>$mid,
	  'community.id' => {
	      -in => $rs1->get_column('community.id')->as_query}},
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

sub create_group {
    my( $self, $name, $list ) = @_;
    my @clean = ();

    if ( $list && (ref $list eq 'ARRAY') ) {
        @clean = @$list;
    }
    elsif ( $list ) {
        my @list = split( /[ ,]+/, $list );
        @clean = map { $_ =~ s/^\s+//g; $_ =~ s/\s+$//g; $_ } @list;
    }

    my @new_contacts = ();
    my @display_names = ();

    foreach my $email ( @clean ) {
        my $contact = $self->create_contact( $email );
	push( @new_contacts, $contact );
        push( @display_names, $contact->contact_name );
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


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
