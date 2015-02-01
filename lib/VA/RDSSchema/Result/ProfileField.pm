use utf8;
package VA::RDSSchema::Result::ProfileField;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::ProfileField

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

=head1 TABLE: C<profile_fields>

=cut

__PACKAGE__->table("profile_fields");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 profiles_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 value

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 public

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 created_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated_date

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "profiles_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "value",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "public",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "created_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "updated_date",
  { data_type => "varchar", is_nullable => 1, size => 45 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 profile

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Profile>

=cut

__PACKAGE__->belongs_to(
  "profile",
  "VA::RDSSchema::Result::Profile",
  { id => "profiles_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:h07TBOsp04c0PcFwyFghHw

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{profiles_id};
    delete $hash->{id};
    delete $hash->{created_date};
    delete $hash->{updated_date};
    return $hash;
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
