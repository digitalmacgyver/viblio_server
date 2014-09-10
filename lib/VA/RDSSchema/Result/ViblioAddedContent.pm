use utf8;
package VA::RDSSchema::Result::ViblioAddedContent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::ViblioAddedContent

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

=head1 TABLE: C<viblio_added_content>

=cut

__PACKAGE__->table("viblio_added_content");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 media_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 media_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 album_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 album_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 content_type

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 attempts

  data_type: 'integer'
  is_nullable: 1

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
  "media_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "media_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "album_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "album_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "content_type",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "attempts",
  { data_type => "integer", is_nullable => 1 },
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

=head1 RELATIONS

=head2 media

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "media",
  "VA::RDSSchema::Result::Media",
  { id => "media_id", user_id => "media_user_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 media_album_id_album_user_id

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "media_album_id_album_user_id",
  "VA::RDSSchema::Result::Media",
  { id => "album_id", user_id => "album_user_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-09-09 14:27:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4De6U1UTkwJjHfDyibB03g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
