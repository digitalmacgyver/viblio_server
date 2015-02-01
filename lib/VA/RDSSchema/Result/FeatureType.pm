use utf8;
package VA::RDSSchema::Result::FeatureType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::FeatureType

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

=head1 TABLE: C<feature_types>

=cut

__PACKAGE__->table("feature_types");

=head1 ACCESSORS

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 16

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
  "type",
  { data_type => "varchar", is_nullable => 0, size => 16 },
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

=item * L</type>

=back

=cut

__PACKAGE__->set_primary_key("type");

=head1 RELATIONS

=head2 media_asset_features

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAssetFeature>

=cut

__PACKAGE__->has_many(
  "media_asset_features",
  "VA::RDSSchema::Result::MediaAssetFeature",
  { "foreign.feature_type" => "self.type" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:THxasKo9V+rNvDtqCIorYw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
