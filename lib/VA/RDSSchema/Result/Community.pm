use utf8;
package VA::RDSSchema::Result::Community;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Community

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

=head1 TABLE: C<communities>

=cut

__PACKAGE__->table("communities");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 webhook

  data_type: 'text'
  is_nullable: 1

=head2 members_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 media_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 curators_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 pending_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 is_curated

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

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
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "webhook",
  { data_type => "text", is_nullable => 1 },
  "members_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "media_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "curators_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "pending_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_curated",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
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

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("id", "user_id");

=head1 RELATIONS

=head2 curator

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "curator",
  "VA::RDSSchema::Result::Contact",
  { id => "curators_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 media

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "media",
  "VA::RDSSchema::Result::Media",
  { id => "media_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 member

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "member",
  "VA::RDSSchema::Result::Contact",
  { id => "members_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 pending

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "pending",
  "VA::RDSSchema::Result::Media",
  { id => "pending_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DAR+hRqtknI2ZBfUWNFL/Q

__PACKAGE__->uuid_columns( 'uuid' );

__PACKAGE__->belongs_to(
  "album",
  "VA::RDSSchema::Result::Media",
  { id => "media_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
    where => { "me.is_album" => 1 }
  },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
