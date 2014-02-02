use utf8;
package VA::RDSSchema::Result::MediaAsset;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::MediaAsset

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

=head1 TABLE: C<media_assets>

=cut

__PACKAGE__->table("media_assets");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 media_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 asset_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 32

=head2 mimetype

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 uri

  data_type: 'text'
  is_nullable: 1

=head2 location

  data_type: 'varchar'
  default_value: 'fp'
  is_nullable: 0
  size: 28

=head2 duration

  data_type: 'decimal'
  is_nullable: 1
  size: [14,6]

=head2 bytes

  data_type: 'integer'
  is_nullable: 1

=head2 width

  data_type: 'integer'
  is_nullable: 1

=head2 height

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_uri

  data_type: 'text'
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

=head2 view_count

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
  "media_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "asset_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 32 },
  "mimetype",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "uri",
  { data_type => "text", is_nullable => 1 },
  "location",
  { data_type => "varchar", default_value => "fp", is_nullable => 0, size => 28 },
  "duration",
  { data_type => "decimal", is_nullable => 1, size => [14, 6] },
  "bytes",
  { data_type => "integer", is_nullable => 1 },
  "width",
  { data_type => "integer", is_nullable => 1 },
  "height",
  { data_type => "integer", is_nullable => 1 },
  "metadata_uri",
  { data_type => "text", is_nullable => 1 },
  "provider",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 16 },
  "provider_id",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "view_count",
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

=item * L</media_id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("id", "media_id", "user_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 asset_type

Type: belongs_to

Related object: L<VA::RDSSchema::Result::AssetType>

=cut

__PACKAGE__->belongs_to(
  "asset_type",
  "VA::RDSSchema::Result::AssetType",
  { type => "asset_type" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
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
  { id => "media_id", user_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 media_asset_features

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAssetFeature>

=cut

__PACKAGE__->has_many(
  "media_asset_features",
  "VA::RDSSchema::Result::MediaAssetFeature",
  {
    "foreign.media_asset_id" => "self.id",
    "foreign.media_id"       => "self.media_id",
    "foreign.user_id"        => "self.user_id",
  },
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:p0+EMmjHKFKrfDNdChCRHA

__PACKAGE__->uuid_columns( 'uuid' );

# I like this relation name better ...
__PACKAGE__->has_many(
  "features",
  "VA::RDSSchema::Result::MediaAssetFeature",
  { "foreign.media_asset_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{id};
    delete $hash->{media_id};
    return $hash;
}

# Given a face asset, return the contact info if any
#
sub face_data {
    my( $self ) = @_;
    my $feat = $self->features->first({ feature_type => 'face' },{prefetch => 'contact'});
    return undef unless( $feat );
    return undef unless( $feat->contact_id );
    return $feat->contact;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
