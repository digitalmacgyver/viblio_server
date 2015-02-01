use utf8;
package VA::RDSSchema::Result::ContactGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::ContactGroup

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

=head1 TABLE: C<contact_groups>

=cut

__PACKAGE__->table("contact_groups");

=head1 ACCESSORS

=head2 group_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 contact_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 contact_viblio_id

  data_type: 'integer'
  is_foreign_key: 1
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
  "group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contact_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "contact_viblio_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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

=item * L</group_id>

=item * L</contact_id>

=back

=cut

__PACKAGE__->set_primary_key("group_id", "contact_id");

=head1 RELATIONS

=head2 contact

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "contact",
  "VA::RDSSchema::Result::Contact",
  { id => "contact_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 contact_viblio

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "contact_viblio",
  "VA::RDSSchema::Result::Contact",
  { contact_viblio_id => "contact_viblio_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 group

Type: belongs_to

Related object: L<VA::RDSSchema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "group",
  "VA::RDSSchema::Result::Contact",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IFoZwkBV+3ufrYEW0UQgiA

# Need to create another relation who's name is not "group", because "group"
# causes syntax errors (its a reserved word).
__PACKAGE__->belongs_to(
  "cgroup",
  "VA::RDSSchema::Result::Contact",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
