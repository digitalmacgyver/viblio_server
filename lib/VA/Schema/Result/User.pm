use utf8;
package VA::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::User

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

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 provider

  data_type: 'text'
  is_nullable: 1

=head2 provider_id

  data_type: 'text'
  is_nullable: 1

=head2 username

  data_type: 'text'
  is_nullable: 1

=head2 password

  data_type: 'text'
  is_nullable: 1

=head2 email

  data_type: 'text'
  is_nullable: 1

=head2 displayname

  data_type: 'text'
  is_nullable: 1

=head2 active

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 uuid

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 accepted_terms

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "provider",
  { data_type => "text", is_nullable => 1 },
  "provider_id",
  { data_type => "text", is_nullable => 1 },
  "username",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", is_nullable => 1 },
  "email",
  { data_type => "text", is_nullable => 1 },
  "displayname",
  { data_type => "text", is_nullable => 1 },
  "active",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "uuid",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "accepted_terms",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 mediafiles

Type: has_many

Related object: L<VA::Schema::Result::Mediafile>

=cut

__PACKAGE__->has_many(
  "mediafiles",
  "VA::Schema::Result::Mediafile",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_roles

Type: has_many

Related object: L<VA::Schema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "VA::Schema::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workorders

Type: has_many

Related object: L<VA::Schema::Result::Workorder>

=cut

__PACKAGE__->has_many(
  "workorders",
  "VA::Schema::Result::Workorder",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-04-18 09:39:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pp/BKv2pY2ALxqcAsRZW4Q

sub TO_JSON {
    my $self = shift;
    my $hash = $self->{_column_data};
    delete $hash->{password};
    return $hash;
}

__PACKAGE__->uuid_columns( 'uuid' );

# Have the 'password' column use a SHA-1 hash and 20-byte salt
# with RFC 2307 encoding; Generate the 'check_password" method
__PACKAGE__->add_columns(
    'password' => {
       data_type => 'text',
       passphrase       => 'rfc2307',
       passphrase_class => 'SaltedDigest',
       passphrase_args  => {
           algorithm   => 'SHA-1',
           salt_random => 20,
       },
       passphrase_check_method => 'check_password',
    },
    'active' => {
       data_type => 'datetime',
       inflate_datetime => 1,
       set_on_create => 1, set_on_update => 1,
    },
    'accepted_terms' => {
       data_type => 'datetime',
       inflate_datetime => 1,
    },
    );

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
