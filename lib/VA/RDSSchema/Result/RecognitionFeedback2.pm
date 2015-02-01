use utf8;
package VA::RDSSchema::Result::RecognitionFeedback2;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::RecognitionFeedback2

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

=head1 TABLE: C<recognition_feedback2>

=cut

__PACKAGE__->table("recognition_feedback2");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 face_url

  data_type: 'varchar'
  is_nullable: 0
  size: 2048

=head2 face1_id

  data_type: 'integer'
  is_nullable: 1

=head2 face1_confidence

  data_type: 'double precision'
  is_nullable: 1

=head2 face2_id

  data_type: 'integer'
  is_nullable: 1

=head2 face2_confidence

  data_type: 'double precision'
  is_nullable: 1

=head2 face3_id

  data_type: 'integer'
  is_nullable: 1

=head2 face3_confidence

  data_type: 'double precision'
  is_nullable: 1

=head2 feedback_received

  data_type: 'tinyint'
  is_nullable: 1

=head2 recognized

  data_type: 'tinyint'
  is_nullable: 1

=head2 feedback_result

  data_type: 'integer'
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
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "face_url",
  { data_type => "varchar", is_nullable => 0, size => 2048 },
  "face1_id",
  { data_type => "integer", is_nullable => 1 },
  "face1_confidence",
  { data_type => "double precision", is_nullable => 1 },
  "face2_id",
  { data_type => "integer", is_nullable => 1 },
  "face2_confidence",
  { data_type => "double precision", is_nullable => 1 },
  "face3_id",
  { data_type => "integer", is_nullable => 1 },
  "face3_confidence",
  { data_type => "double precision", is_nullable => 1 },
  "feedback_received",
  { data_type => "tinyint", is_nullable => 1 },
  "recognized",
  { data_type => "tinyint", is_nullable => 1 },
  "feedback_result",
  { data_type => "integer", is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8YV03PjDCHemuZJV0Pmy/Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
