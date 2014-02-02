use utf8;
package VA::RDSSchema::Result::WorkflowStage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::WorkflowStage

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

=head1 TABLE: C<workflow_stages>

=cut

__PACKAGE__->table("workflow_stages");

=head1 ACCESSORS

=head2 stage

  data_type: 'varchar'
  is_nullable: 0
  size: 64

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
  "stage",
  { data_type => "varchar", is_nullable => 0, size => 64 },
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

=item * L</stage>

=back

=cut

__PACKAGE__->set_primary_key("stage");

=head1 RELATIONS

=head2 media_workflow_stages

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaWorkflowStage>

=cut

__PACKAGE__->has_many(
  "media_workflow_stages",
  "VA::RDSSchema::Result::MediaWorkflowStage",
  { "foreign.workflow_stage" => "self.stage" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dStXXBzSFMEP8WextJo2Yw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
