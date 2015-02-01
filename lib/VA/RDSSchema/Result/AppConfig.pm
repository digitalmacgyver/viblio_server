use utf8;
package VA::RDSSchema::Result::AppConfig;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::AppConfig

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

=head1 TABLE: C<app_configs>

=cut

__PACKAGE__->table("app_configs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 app

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 version_string

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 feature

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 enabled

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 current

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 config

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
  "app",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "version_string",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 64 },
  "feature",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "enabled",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "current",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "config",
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

=head2 C<app_UNIQUE>

=over 4

=item * L</app>

=item * L</version_string>

=item * L</feature>

=back

=cut

__PACKAGE__->add_unique_constraint("app_UNIQUE", ["app", "version_string", "feature"]);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jup5Z7MIM78CsLF891UOYA

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    return $hash;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
