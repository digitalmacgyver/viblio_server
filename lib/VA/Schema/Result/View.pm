use utf8;
package VA::Schema::Result::View;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::View

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

=head1 TABLE: C<views>

=cut

__PACKAGE__->table("views");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'text'
  is_nullable: 1

=head2 filename

  data_type: 'text'
  is_nullable: 1

=head2 uri

  data_type: 'text'
  is_nullable: 1

=head2 mimetype

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 size

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 location

  data_type: 'varchar'
  default_value: 'fp'
  is_nullable: 0
  size: 28

=head2 type

  data_type: 'varchar'
  default_value: 'main'
  is_nullable: 0
  size: 28

=head2 mediafile_id

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
  "filename",
  { data_type => "text", is_nullable => 1 },
  "uri",
  { data_type => "text", is_nullable => 1 },
  "mimetype",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "size",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "location",
  { data_type => "varchar", default_value => "fp", is_nullable => 0, size => 28 },
  "type",
  {
    data_type => "varchar",
    default_value => "main",
    is_nullable => 0,
    size => 28,
  },
  "mediafile_id",
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

=head2 mediafile

Type: belongs_to

Related object: L<VA::Schema::Result::Mediafile>

=cut

__PACKAGE__->belongs_to(
  "mediafile",
  "VA::Schema::Result::Mediafile",
  { id => "mediafile_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-04-06 16:53:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:leVYuOYjz+cHFYLOh1FwdQ

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = $self->{_column_data};
    # automatically expand and include the url field
    $hash->{url} = $self->url;
    return $hash;
}

# Junk for S3 uri expansion.  Creates a signed, timed URL.
use Muck::FS::S3::QueryStringAuthGenerator;
my $aws_key = 'AKIAJHD46VMHB2FBEMMA';
my $aws_secret = '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';
my $aws_use_https = 0;
my $aws_bucket_name = 'viblio.filepicker.io';
my $aws_endpoint = $aws_bucket_name . ".s3.amazonaws.com";
my $aws_generator = Muck::FS::S3::QueryStringAuthGenerator->new(
    $aws_key, $aws_secret, $aws_use_https, $aws_endpoint );

# Special accessor that creates a url based on the storage location
# and uri field.
#
sub url {
    my $self = shift;
    # If there is an update to the column, we'll let the original accessor
    # deal with it.
    return $self->uri(@_) if @_;
    if ( $self->location && $self->location eq 's3' ) {
	my $url = $aws_generator->get( $aws_bucket_name, $self->uri );
	$url =~ s/\/$aws_bucket_name\//\//g;
	return $url;
    }
    else {
	return $self->uri;
    }
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;