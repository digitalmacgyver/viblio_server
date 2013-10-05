use utf8;
package VA::RDSSchema::Result::Serialize;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Serialize

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

=head1 TABLE: C<serialize>

=cut

__PACKAGE__->table("serialize");

=head1 ACCESSORS

=head2 app

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 object_name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 owner_id

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 expirey_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 server

  data_type: 'varchar'
  is_nullable: 1
  size: 64

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
  "app",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "object_name",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "owner_id",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "expirey_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "server",
  { data_type => "varchar", is_nullable => 1, size => 64 },
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

=item * L</app>

=item * L</object_name>

=back

=cut

__PACKAGE__->set_primary_key("app", "object_name");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-10-04 22:00:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4FgDhCCPXiA1/Lh8bJwycw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
