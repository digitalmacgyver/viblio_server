use utf8;
package VA::RDSSchema::Result::MediaAlbum;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::MediaAlbum

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

=head1 TABLE: C<media_albums>

=cut

__PACKAGE__->table("media_albums");

=head1 ACCESSORS

=head2 album_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 media_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
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
  "album_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "media_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
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

=item * L</album_id>

=item * L</media_id>

=back

=cut

__PACKAGE__->set_primary_key("album_id", "media_id");

=head1 RELATIONS

=head2 album

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "album",
  "VA::RDSSchema::Result::Media",
  { id => "album_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 media

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Media>

=cut

__PACKAGE__->belongs_to(
  "media",
  "VA::RDSSchema::Result::Media",
  { id => "media_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2o6ZFfcDENAlzTfJ9yAZ7A

__PACKAGE__->belongs_to(
    "videos",
    "VA::RDSSchema::Result::Media",
    { id => "media_id" },
    { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

# Put in a mapping for album_id as well.
__PACKAGE__->belongs_to(
    "album",
    "VA::RDSSchema::Result::Media",
    { id => "album_id" },
    { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

# Allow self joins.
__PACKAGE__->belongs_to( 
    'album_media',
    'VA::RDSSchema::Result::MediaAlbum',
    { 'foreign.album_id' => 'self.album_id' },
    { cascade_copy => 0, cascade_delete => 0 },
    );

# Allow optional realtionship to communities (this is a little cheeky
# - there is no direct relationship between these tables in terms of
# DB constraints).
__PACKAGE__->has_many(
    'community',
    'VA::RDSSchema::Result::Community',
    { 'foreign.media_id' => 'self.album_id' },
    { cascade_copy => 0, cascade_delete => 0 },
    );

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
