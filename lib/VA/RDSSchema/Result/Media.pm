use utf8;
package VA::RDSSchema::Result::Media;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Media

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

=head1 TABLE: C<media>

=cut

__PACKAGE__->table("media");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 media_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 filename

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 recording_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 view_count

  data_type: 'integer'
  is_nullable: 1

=head2 lat

  data_type: 'decimal'
  is_nullable: 1
  size: [11,8]

=head2 lng

  data_type: 'decimal'
  is_nullable: 1
  size: [11,8]

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
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "media_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "filename",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "recording_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "view_count",
  { data_type => "integer", is_nullable => 1 },
  "lat",
  { data_type => "decimal", is_nullable => 1, size => [11, 8] },
  "lng",
  { data_type => "decimal", is_nullable => 1, size => [11, 8] },
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

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("id", "user_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 media_assets

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAsset>

=cut

__PACKAGE__->has_many(
  "media_assets",
  "VA::RDSSchema::Result::MediaAsset",
  {
    "foreign.media_id" => "self.id",
    "foreign.user_id"  => "self.user_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_shares

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaShare>

=cut

__PACKAGE__->has_many(
  "media_shares",
  "VA::RDSSchema::Result::MediaShare",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_type

Type: belongs_to

Related object: L<VA::RDSSchema::Result::MediaType>

=cut

__PACKAGE__->belongs_to(
  "media_type",
  "VA::RDSSchema::Result::MediaType",
  { type => "media_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 media_workorders

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaWorkorder>

=cut

__PACKAGE__->has_many(
  "media_workorders",
  "VA::RDSSchema::Result::MediaWorkorder",
  { "foreign.media_id" => "self.id" },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 workorders

Type: many_to_many

Composing rels: L</media_workorders> -> workorder

=cut

__PACKAGE__->many_to_many("workorders", "media_workorders", "workorder");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 08:21:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:21j8UZGZXf0T974FMiZyVA

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{id};
    delete $hash->{user_id};
    return $hash;
}

# I like this relationship name better
#
__PACKAGE__->has_many(
  "assets",
  "VA::RDSSchema::Result::MediaAsset",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

# Accessor to return the first asset of the matching type.
#
sub asset {
    my( $self, $type ) = @_;
    my $assets = $self->assets;
    if ( $assets ) {
        my $types = $assets->search({asset_type=>$type});
        if ( $types ) {
            return $types->first;
        }
    }
    return undef;
}

# Return all of the assets representing faces
#
sub faces {
    my( $self ) = @_;
    my @faces = ();
    foreach( $self->assets ) {
	push( @faces, $_ ) if ( $_->{_column_data}->{asset_type} eq 'face' ); 
    }
    return @faces;
}

# Given a face asset, return the contact info if any
#
sub face_data {
    my( $self, $face ) = @_;
    my $feat = $face->features->first({ feature_type => 'face' });
    return undef unless( $feat );
    return undef unless( $feat->contact_id );
    return $feat->contact;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
