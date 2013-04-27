#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'VA';
all_from 'lib/VA.pm';

requires 'Catalyst::Runtime' => '5.90011';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General';

requires 'DBIx::Class';
requires 'DBIx::Class::Schema::Loader';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Redirect';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'JSON::XS';
requires 'YAML::XS';
requires 'Catalyst::Authentication::Realm::SimpleDB';
requires 'Catalyst::View::TT';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::TT';
requires 'Catalyst::Model::File';
requires 'Imager';
requires 'Catalyst::View::Thumbnail';
requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::PassphraseColumn';
requires 'MooseX::MarkAsMethods';
requires 'MooseX::NonMoose';
requires 'FCGI';
requires 'Net::Amazon::DynamoDB';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Data::UUID';
requires 'DBIx::Class::UUIDColumns';
requires 'Net::SMTP::SSL';
requires 'Catalyst::View::Email::Template';
requires 'Catalyst::Plugin::I18N';
requires 'Catalyst::Plugin::Unicode';
requires 'Catalyst::TraitFor::Request::BrowserDetect';
requires 'CatalystX::I18N::Role::GetLocale';
requires 'CatalystX::I18N::TraitFor::Request';
requires 'Email::AddressParser';
requires 'Email::Address';
requires 'Net::Nslookup';
requires 'Catalyst::Authentication::Realm::Progressive';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Authentication::Credential::Facebook::OAuth2';
requires 'Catalyst::Plugin::Facebook';
requires 'File::Path';
requires 'Try::Tiny';
requires 'Catalyst::Helper';
requires 'DBD::mysql';
requires 'FCGI::ProcManager';
requires 'Catalyst::Plugin::Log::Handler';
requires 'Catalyst::Plugin::Log::Log4perlSimple';
requires 'Muck::FS::S3::QueryStringAuthGenerator';
requires 'Catalyst::Model::REST';
requires 'DBIx::Class::ColumnDefault';
requires 'Catalyst::Model::S3';
requires 'Net::Amazon::S3::Client';
requires 'Digest::HMAC_MD5';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
