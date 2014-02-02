use utf8;
package VA::RDSSchema::Result::Contact;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Contact

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

=head1 TABLE: C<contacts>

=cut

__PACKAGE__->table("contacts");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 1
  size: 36

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 is_group

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 contact_name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 contact_email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 contact_viblio_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 provider

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 16

=head2 provider_id

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 picture_uri

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

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
  { data_type => "varchar", is_nullable => 1, size => 36 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_group",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "contact_name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "contact_email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "contact_viblio_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "provider",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 16 },
  "provider_id",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "picture_uri",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
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

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 communities_curators

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_curators",
  "VA::RDSSchema::Result::Community",
  { "foreign.curators_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 communities_members

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_members",
  "VA::RDSSchema::Result::Community",
  { "foreign.members_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_groups_contact_viblios

Type: has_many

Related object: L<VA::RDSSchema::Result::ContactGroup>

=cut

__PACKAGE__->has_many(
  "contact_groups_contact_viblios",
  "VA::RDSSchema::Result::ContactGroup",
  { "foreign.contact_viblio_id" => "self.contact_viblio_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_groups_contacts

Type: has_many

Related object: L<VA::RDSSchema::Result::ContactGroup>

=cut

__PACKAGE__->has_many(
  "contact_groups_contacts",
  "VA::RDSSchema::Result::ContactGroup",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_groups_groups

Type: has_many

Related object: L<VA::RDSSchema::Result::ContactGroup>

=cut

__PACKAGE__->has_many(
  "contact_groups_groups",
  "VA::RDSSchema::Result::ContactGroup",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_viblio

Type: belongs_to

Related object: L<VA::RDSSchema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "contact_viblio",
  "VA::RDSSchema::Result::User",
  { id => "contact_viblio_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 media_asset_features

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAssetFeature>

=cut

__PACKAGE__->has_many(
  "media_asset_features",
  "VA::RDSSchema::Result::MediaAssetFeature",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_share_messages

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaShareMessage>

=cut

__PACKAGE__->has_many(
  "media_share_messages",
  "VA::RDSSchema::Result::MediaShareMessage",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_shares

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaShare>

=cut

__PACKAGE__->has_many(
  "media_shares",
  "VA::RDSSchema::Result::MediaShare",
  { "foreign.contact_id" => "self.id" },
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

=head2 user

Type: belongs_to

Related object: L<VA::RDSSchema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VA::RDSSchema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q3aF+qGodj/RUc+DqUDJZA

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    # delete $hash->{id}; NEED THIS UNLESS OR UNTIL WE HAVE A UUID
    delete $hash->{user_id};
    return $hash;
}

__PACKAGE__->has_many(
  "contact_groups_contacts",
  "VA::RDSSchema::Result::ContactGroup",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "contact_groups_groups",
  "VA::RDSSchema::Result::ContactGroup",
  { "foreign.contact_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many( 'groups', 'contact_groups_groups', 'cgroup' );
__PACKAGE__->many_to_many( 'contacts', 'contact_groups_contacts', 'contact' );

__PACKAGE__->meta->make_immutable;
1;
