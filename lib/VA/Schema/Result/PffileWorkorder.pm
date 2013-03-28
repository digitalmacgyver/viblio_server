use utf8;
package VA::Schema::Result::PffileWorkorder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::PffileWorkorder

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

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=item * L<DBIx::Class::UUIDColumns>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "TimeStamp",
  "PassphraseColumn",
  "UUIDColumns",
);

=head1 TABLE: C<pffile_workorders>

=cut

__PACKAGE__->table("pffile_workorders");

=head1 ACCESSORS

=head2 pffile_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 workorder_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pffile_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "workorder_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</pffile_id>

=item * L</workorder_id>

=back

=cut

__PACKAGE__->set_primary_key("pffile_id", "workorder_id");

=head1 RELATIONS

=head2 pffile

Type: belongs_to

Related object: L<VA::Schema::Result::Pffile>

=cut

__PACKAGE__->belongs_to(
  "pffile",
  "VA::Schema::Result::Pffile",
  { id => "pffile_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 workorder

Type: belongs_to

Related object: L<VA::Schema::Result::Workorder>

=cut

__PACKAGE__->belongs_to(
  "workorder",
  "VA::Schema::Result::Workorder",
  { id => "workorder_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-27 21:01:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Uca6tihQrG6AT1DnURusEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
