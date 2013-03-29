use utf8;
package VA::Schema::Result::Workorder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::Workorder

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

=head1 TABLE: C<workorders>

=cut

__PACKAGE__->table("workorders");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 state

  data_type: 'varchar'
  default_value: 'WO_NEW'
  is_nullable: 0
  size: 24

=head2 uuid

  data_type: 'text'
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 submitted

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 completed

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "state",
  {
    data_type => "varchar",
    default_value => "WO_NEW",
    is_nullable => 0,
    size => 24,
  },
  "uuid",
  { data_type => "text", is_nullable => 1 },
  "user_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "submitted",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "completed",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 pffile_workorders

Type: has_many

Related object: L<VA::Schema::Result::PffileWorkorder>

=cut

__PACKAGE__->has_many(
  "pffile_workorders",
  "VA::Schema::Result::PffileWorkorder",
  { "foreign.workorder_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<VA::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VA::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pffiles

Type: many_to_many

Composing rels: L</pffile_workorders> -> pffile

=cut

__PACKAGE__->many_to_many("pffiles", "pffile_workorders", "pffile");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-29 13:19:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xcvWuM92f9WnT3PG6ogaKw

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = $self->{_column_data};
    return $hash;
}

__PACKAGE__->add_columns(
    'submitted' => {
       data_type => 'datetime',
       inflate_datetime => 1,
       set_on_create => 1,
    },
    'completed' => {
       data_type => 'datetime',
       inflate_datetime => 1,
    },
    );

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
