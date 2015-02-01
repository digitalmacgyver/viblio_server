use utf8;
package VA::RDSSchema::Result::Provider;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Provider

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

=head1 TABLE: C<providers>

=cut

__PACKAGE__->table("providers");

=head1 ACCESSORS

=head2 provider

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
  "provider",
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

=item * L</provider>

=back

=cut

__PACKAGE__->set_primary_key("provider");

=head1 RELATIONS

=head2 contacts

Type: has_many

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->has_many(
  "contacts",
  "VA::RDSSchema::Result::Contact",
  { "foreign.provider" => "self.provider" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_assets

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAsset>

=cut

__PACKAGE__->has_many(
  "media_assets",
  "VA::RDSSchema::Result::MediaAsset",
  { "foreign.provider" => "self.provider" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 users

Type: has_many

Related object: L<VA::RDSSchema::Result::User>

=cut

__PACKAGE__->has_many(
  "users",
  "VA::RDSSchema::Result::User",
  { "foreign.provider" => "self.provider" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bKAoZaIg0EbaWegw1lsEAg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
