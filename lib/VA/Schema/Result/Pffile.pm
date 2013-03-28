use utf8;
package VA::Schema::Result::Pffile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::Pffile

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

=head1 TABLE: C<pffiles>

=cut

__PACKAGE__->table("pffiles");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'text'
  is_nullable: 1

=head2 mimetype

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 filename

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 url

  data_type: 'text'
  is_nullable: 1

=head2 key

  data_type: 'text'
  is_nullable: 1

=head2 size

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 iswritable

  data_type: 'integer'
  default_value: 1
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "text", is_nullable => 1 },
  "mimetype",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "filename",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "url",
  { data_type => "text", is_nullable => 1 },
  "key",
  { data_type => "text", is_nullable => 1 },
  "size",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "iswritable",
  { data_type => "integer", default_value => 1, is_nullable => 1 },
  "user_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
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
  { "foreign.pffile_id" => "self.id" },
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

=head2 workorders

Type: many_to_many

Composing rels: L</pffile_workorders> -> workorder

=cut

__PACKAGE__->many_to_many("workorders", "pffile_workorders", "workorder");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-03-27 21:01:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7Zj/0TRJjR+aSATDxk+8pQ

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = $self->{_column_data};
    return $hash;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
