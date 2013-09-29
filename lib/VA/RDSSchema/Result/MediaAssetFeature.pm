use utf8;
package VA::RDSSchema::Result::MediaAssetFeature;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::MediaAssetFeature

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

=head1 TABLE: C<media_asset_features>

=cut

__PACKAGE__->table("media_asset_features");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 media_asset_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 media_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 feature_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 coordinates

  data_type: 'text'
  is_nullable: 1

=head2 contact_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 detection_confidence

  data_type: 'decimal'
  is_nullable: 1
  size: [9,6]

=head2 recognition_confidence

  data_type: 'decimal'
  is_nullable: 1
  size: [9,6]

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
  "media_asset_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "media_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "user_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "feature_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "coordinates",
  { data_type => "text", is_nullable => 1 },
  "contact_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "detection_confidence",
  { data_type => "decimal", is_nullable => 1, size => [9, 6] },
  "recognition_confidence",
  { data_type => "decimal", is_nullable => 1, size => [9, 6] },
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

=item * L</media_asset_id>

=item * L</media_id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("id", "media_asset_id", "media_id", "user_id");

=head1 RELATIONS

=head2 contact

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "contact",
  "VA::RDSSchema::Result::Contact",
  { id => "contact_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 feature_type

Type: belongs_to

Related object: L<VA::RDSSchema::Result::FeatureType>

=cut

__PACKAGE__->belongs_to(
  "feature_type",
  "VA::RDSSchema::Result::FeatureType",
  { type => "feature_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 media_asset

Type: belongs_to

Related object: L<VA::RDSSchema::Result::MediaAsset>

=cut

__PACKAGE__->belongs_to(
  "media_asset",
  "VA::RDSSchema::Result::MediaAsset",
  { id => "media_asset_id", media_id => "media_id", user_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 08:21:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AIgG+EUZRAu4tUP6JwXLdQ

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    return $hash;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
