use utf8;
package VA::RDSSchema::Result::Profile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Profile

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

=head1 TABLE: C<profiles>

=cut

__PACKAGE__->table("profiles");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 image

  data_type: 'mediumblob'
  is_nullable: 1

=head2 image_mimetype

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 image_size

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

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "image",
  { data_type => "mediumblob", is_nullable => 1 },
  "image_mimetype",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "image_size",
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
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 profile_fields

Type: has_many

Related object: L<VA::RDSSchema::Result::ProfileField>

=cut

__PACKAGE__->has_many(
  "profile_fields",
  "VA::RDSSchema::Result::ProfileField",
  { "foreign.profiles_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<VA::RDSSchema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VA::RDSSchema::Result::User",
  { id => "user_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-08-15 08:17:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qolM+UdNX6JPWm8i64BU9w

# I like this relation name better
__PACKAGE__->has_many(
  "fields",
  "VA::RDSSchema::Result::ProfileField",
  { "foreign.profiles_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub setting {
    my( $self, $name ) = @_;
    my $field = $self->fields->find({ name => $name });
    return undef unless( $field );
    my $value = $field->value;
    return 1 if ( $value && ( $value eq 'true' || $value eq 'True' || $value eq '1' ) );
    return 0 if ( $value && ( $value eq 'false' || $value eq 'False' || $value eq '0' ) );
    return $value;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
