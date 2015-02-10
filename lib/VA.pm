package VA;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use CatalystX::RoleApplicator;

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
    Redirect

    StackTrace
    Log::Dispatch

    Authentication
    AdditionalRoles
    Authorization::Roles

    Session
    Session::Store::DBIC
    Session::State::Cookie

    VAUtils
    Cloudfront

    I18N
    Unicode
    +CatalystX::I18N::Role::Base
    +CatalystX::I18N::Role::GetLocale

/;

#use Devel::NYTProf;

extends 'Catalyst';

__PACKAGE__->apply_request_class_roles(qw/
        Catalyst::TraitFor::Request::BrowserDetect
        CatalystX::I18N::TraitFor::Request
    /);

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in va.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.
with 'CatalystX::DebugFilter';

__PACKAGE__->config(
    name => 'VA',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header => 1, # Send X-Catalyst header

    default_view => 'HTML',

    'CatalystX::DebugFilter' => {
        Request => { params => [ 'password' ] },
    },

    'Model::File' => {
	root_dir => __PACKAGE__->path_to( 'root', 'static', 'images' ),
    },

    'View::HTML' => {
	TEMPLATE_EXTENSION => '.tt',
	render_die => 1,
	INCLUDE_PATH => [
	    __PACKAGE__->path_to( 'root' ),
	    __PACKAGE__->path_to( 'root', 'templates' ),
	    __PACKAGE__->path_to( 'root', 'include' ),
	    ],
	WRAPPER => 'wrapper.tt',
    },

    'View::JSON' => {
	allow_callback => 1,
	callback_param => 'callback',
    },

    'View::Email::Template' => {
	default => {
	    view => 'HTML',
	    charset => 'utf-8',
	    content_type => 'text/html',
	},
	sender => {
	    mailer => 'SMTP',
	    mailer_args => {
		host=>'email-smtp.us-east-1.amazonaws.com',
		ssl => 1,
		sasl_username => 'AKIAJLPWQJSOREYBUA6A',
		sasl_password => 'AvXzxIUt91MTw5wT7xgK9B5rjaBt0MKLKpU0N9GkBmJ/',
		port => 465,
	    },
	},
    },

    'Plugin::Session' => {
	dbic_class => 'RDS::Session',
	expires    => 94608000,
    },

);

# Start the application
__PACKAGE__->setup();


=head1 NAME

VA - Catalyst based application

=head1 SYNOPSIS

    script/va_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<VA::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Andrew Peebles,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
