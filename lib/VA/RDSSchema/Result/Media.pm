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

=head2 unique_hash

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 media_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 is_album

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

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

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

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
  "unique_hash",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "media_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "is_album",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
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
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
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

=head2 C<unique_hash_UNIQUE>

=over 4

=item * L</unique_hash>

=item * L</user_id>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_hash_UNIQUE", ["unique_hash", "user_id"]);

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 communities_medias

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_medias",
  "VA::RDSSchema::Result::Community",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 communities_pending

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_pending",
  "VA::RDSSchema::Result::Community",
  { "foreign.pending_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_albums_albums

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAlbum>

=cut

__PACKAGE__->has_many(
  "media_albums_albums",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_albums_medias

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAlbum>

=cut

__PACKAGE__->has_many(
  "media_albums_medias",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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

=head2 media_comments

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaComment>

=cut

__PACKAGE__->has_many(
  "media_comments",
  "VA::RDSSchema::Result::MediaComment",
  { "foreign.media_id" => "self.id" },
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

=head2 media_workflow_stages

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaWorkflowStage>

=cut

__PACKAGE__->has_many(
  "media_workflow_stages",
  "VA::RDSSchema::Result::MediaWorkflowStage",
  {
    "foreign.media_id" => "self.id",
    "foreign.user_id"  => "self.user_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2014-02-01 18:58:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lou6RGhKxwhu6g9iERaGVw

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

__PACKAGE__->has_many(
  "comments",
  "VA::RDSSchema::Result::MediaComment",
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

__PACKAGE__->has_many(
  "media_albums_albums",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "media_albums_medias",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0,
    where => { "media.is_album" => 0,
	       -or => [ "media.status" => "visible",
			"media.status" => "complete" ] }
  },
);
__PACKAGE__->has_many(
  "media_albums_videos",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0,
    where => { "videos.is_album" => 0,
	       -or => [ "videos.status" => "visible",
			"videos.status" => "complete" ] }
  },
);
__PACKAGE__->many_to_many( 'albums', 'media_albums_albums', 'album' );
__PACKAGE__->many_to_many( 'media',  'media_albums_medias', 'media' );
__PACKAGE__->many_to_many( 'videos',  'media_albums_videos', 'videos' );

__PACKAGE__->has_one(
    "community",
    "VA::RDSSchema::Result::Community",
    { "foreign.media_id" => "self.id" },
);

# Called with an album uuid, return 1/0 if video is a member of
# Called with no arg, return list of albums video is a member of
sub is_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id,
	      'album.uuid' => $gid},
	     {prefetch=>['videos','album']});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id},
	     {prefetch=>['videos','album']});
	return map { $_->album } @cgroups;
    }
}

# Called with a community uuid, return 1/0 if video is a member of
# Called with no arg, return list of communities video is a member of
sub is_community_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id,
	      'community.uuid' => $gid},
	     {prefetch=>['videos',{'album'=>'community'}]});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id},
	     {prefetch=>['videos',{'album'=>'community'}]});
	return map { $_->album->community } @cgroups;
    }
}

__PACKAGE__->meta->make_immutable;
1;
