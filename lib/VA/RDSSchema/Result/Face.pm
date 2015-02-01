use utf8;
package VA::RDSSchema::Result::Face;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Face

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

=head1 TABLE: C<faces>

=cut

__PACKAGE__->table("faces");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 contact_id

  data_type: 'integer'
  is_nullable: 0

=head2 face_id

  data_type: 'integer'
  is_nullable: 0

=head2 face_url

  data_type: 'varchar'
  is_nullable: 0
  size: 2048

=head2 external_id

  data_type: 'integer'
  is_nullable: 1

=head2 score

  data_type: 'double precision'
  is_nullable: 0

=head2 l1_idx

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 l1_tag

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 l2_idx

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 l2_tag

  data_type: 'varchar'
  is_nullable: 0
  size: 128

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
  { data_type => "integer", is_nullable => 0 },
  "contact_id",
  { data_type => "integer", is_nullable => 0 },
  "face_id",
  { data_type => "integer", is_nullable => 0 },
  "face_url",
  { data_type => "varchar", is_nullable => 0, size => 2048 },
  "external_id",
  { data_type => "integer", is_nullable => 1 },
  "score",
  { data_type => "double precision", is_nullable => 0 },
  "l1_idx",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "l1_tag",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "l2_idx",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "l2_tag",
  { data_type => "varchar", is_nullable => 0, size => 128 },
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

=head2 C<user_id_UNIQUE>

=over 4

=item * L</user_id>

=item * L</contact_id>

=item * L</face_id>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id_UNIQUE", ["user_id", "contact_id", "face_id"]);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LC13WTtPXha1Zxgje/8SDg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
