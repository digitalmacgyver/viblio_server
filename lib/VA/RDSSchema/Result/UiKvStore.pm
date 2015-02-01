use utf8;
package VA::RDSSchema::Result::UiKvStore;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::UiKvStore

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

=head1 TABLE: C<ui_kv_store>

=cut

__PACKAGE__->table("ui_kv_store");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 domain

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 key

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 value

  data_type: 'text'
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
  "domain",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "key",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "value",
  { data_type => "text", is_nullable => 1 },
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

=head2 C<domain_UNIQUE>

=over 4

=item * L</domain>

=item * L</key>

=back

=cut

__PACKAGE__->add_unique_constraint("domain_UNIQUE", ["domain", "key"]);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vQSVF2nl+gRnJ4bFdDjJ8Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
