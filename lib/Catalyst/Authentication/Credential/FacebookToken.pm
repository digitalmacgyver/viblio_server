package Catalyst::Authentication::Credential::FacebookToken;
BEGIN {
  $Catalyst::Authentication::Credential::Facebook::OAuth2::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $Catalyst::Authentication::Credential::Facebook::OAuth2::VERSION = '0.02';
}
# ABSTRACT: Authenticate your Catalyst application's users using Facebook's OAuth 2.0

use Moose;
use MooseX::Types::Moose qw(ArrayRef);
use MooseX::Types::Common::String qw(NonEmptySimpleStr);
use aliased 'Facebook::Graph', 'FB';
use namespace::autoclean;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

has [qw(application_id application_secret)] => (
    is       => 'ro',
    isa      => NonEmptySimpleStr,
    required => 1,
);


has oauth_args => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

sub _build_oauth {
    my ($self, @args) = @_;

    return FB->new(
        app_id => $self->application_id,
        secret => $self->application_secret,
        @{ $self->oauth_args },
        @args,
    );
}

sub _get_extended_access_token {
    my( $self, $ctx, $token ) = @_;
    my $args = {
	client_id => $self->application_id,
	client_secret => $self->application_secret,
	grant_type => "fb_exchange_token",
	fb_exchange_token => $token };
    my $uri = URI->new( "https://graph.facebook.com/oauth/access_token" );
    $uri->query_form( $args );
    my $res = FB->request( $uri );
    my $extended_token = $token;
    if ( $res && $res->response && $res->response->code == 200 ) {
	$uri = URI->new( 'http://aaa.com?' . $res->as_json );
	if ( $uri ) {
	    my %q = $uri->query_form;
	    if ( defined( $q{access_token} ) ) {
		$extended_token = $q{access_token};
	    }
	}
    }
    elsif ( $res ) {
	$ctx->log->error( 'Failed to obtain FB extended token' );
	$ctx->logdump( $res );
    }
    return $extended_token;
}

sub BUILDARGS {
    my ($self, $config, $ctx, $realm) = @_;

    return $config;
}

=perl
What comes back from FB:

$VAR1 = {
          'link' => 'http://www.facebook.com/andrew.peebles.9843',
          'timezone' => -7,
          'name' => 'Andrew Peebles',
          'locale' => 'en_US',
          'username' => 'andrew.peebles.9843',
          'last_name' => 'Peebles',
          'email' => 'aqpeeb@gmail.com', ## IF 'email' LISTED IN SCOPE
          'updated_time' => '2013-03-18T23:21:54+0000',
          'verified' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
          'id' => '100005451434129',
          'first_name' => 'Andrew',
          'gender' => 'male'
        };
=cut

sub authenticate {
    my ($self, $ctx, $realm, $auth_info) = @_;

    my $callback_uri = $ctx->request->uri->clone;
    $callback_uri->query(undef);

    my $oauth = $self->_build_oauth(
        postback => $callback_uri,
    );

    unless (defined(my $code = $ctx->request->params->{access_token})) {
        return undef;
    }
    else {
	$ctx->log->debug( "FB Token: " . $code );
	$code = $self->_get_extended_access_token( $ctx, $code );
	$ctx->log->debug( "FB Extended Token: " . $code );
	$oauth->access_token( $code );
	my $fb_user = $oauth->fetch( 'me' );
	$ctx->logdump( $fb_user );
	unless( $fb_user && $fb_user->{email} ) { 
	    $ctx->{authfail_code} = "NOLOGIN_OAUTH_FAILURE";
	    return undef;
	}

	# Check white and black lists...
	if ( $ctx->config->{in_beta} ) {
	    unless( $ctx->model( 'RDS::EmailUser' )->find({email => $fb_user->{email}, status => 'whitelist'}) ) {
		$ctx->{authfail_code} = "NOLOGIN_NOT_IN_BETA";
		return undef;
	    }
	}
	if ( $ctx->model( 'RDS::EmailUser' )->find({email => $fb_user->{email}, status => 'blacklist'}) ) {
	    $ctx->{authfail_code} = "NOLOGIN_BLACKLISTED";
	    return undef;
	}

	my $new_user = 0;
	if ( ! $ctx->model( 'RDS::User' )->find({email=>$fb_user->{email}}) ) {
	    $new_user = 1;
	}

	if ( $new_user && $ctx->{no_autocreate} ) {
	    $ctx->{authfail_code} = "NOLOGIN_EMAIL_NOT_FOUND";
	    $ctx->log->debug( 'Facebook user lookup failed: no db record for ' . $fb_user->{email} );
	    return undef;
	}

	my $attributes = {
	    email => $fb_user->{email},
	};
        my $user = $realm->find_user($attributes, $ctx);
	if ( $user ) { 
	    # Remember the access token, so that other parts of the
	    # server may make Facebook API calls.
	    $ctx->session->{fb_token} = $code;

	    # Also set some user fields directly from FB data:
	    my $needs_update = 0;
	    unless( $user->get_object->displayname ) {
		$user->get_object->displayname( $fb_user->{name} );
		$needs_update = 1;
	    }
	    $user->get_object->update if ( $needs_update );

	    # Get the facebook profile photo for our profile pic, 
	    # if we don't already have one.
	    #
	    if ( ! $user->get_object->profile ) {
		$user->get_object->create_profile();
	    }
	    if ( ! $user->get_object->profile->image ) {
		my $uri = URI->new( 'https://graph.facebook.com/me/picture' );
		$uri->query_form({ access_token => $code, width => 128, height => 128 });
		my $res = FB->request( $uri );
		if ( $res && $res->response && $res->response->code == 200 ) {
		    $user->get_object->profile->image( $res->response->content );
		    $user->get_object->profile->image_mimetype( $res->response->header( 'Content-Type' ) );
		    $user->get_object->profile->image_size( length $res->response->content );
		    $user->get_object->profile->update;
		}
	    }

	    # Automatically link the user's facebook account, and tell 
	    # the video processor pipeline.
	    #
	    my $link = $user->get_object->update_or_create_related
		( 'links', {
		    provider => 'facebook',
		  });
	    if ( $link ) {
		$link->data({
		    link => $fb_user->{link},
		    access_token => $code,
		    id => $fb_user->{id} });
		$link->update; 
	    
		# Call popeye with access_token, so popeye can fetch facebook data
=perl
		my $res = $ctx->model( 'Popeye' )->get( '/processor/facebook',
							{ uid => $user->get_object->uuid,
							  id => $fb_user->{id},
							  access_token => $code } );
		if ( $res->code != 200 ) {
		    $ctx->log->error( "Popeye post returned error code: " . $res->code );
		}
		if ( $res->data->{error} ) {
		    $ctx->log->error( "Popeye post returned error: " . $res->data->message );
		}
=cut
		# Send a facebook link message to the Amazon SQS queue
		try {
		    my $sqs_response = $ctx->model( 'SQS', $ctx->config->{sqs}->{facebook_link} )
			->SendMessage( encode_json({
			    user_uuid => $user->get_object->uuid,
			    fb_access_token => $code,
			    action => 'link',
			    facebook_id => $fb_user->{id} }) );
		    # No doc exists on the response!
		} catch {
		    $ctx->log->error( "facebook link failed: $_" );
		};
	    }

	    # The return value of here plugs into larger
	    # authentication stuff and can't be messed with, but we
	    # need a way of communicating whether this is a new user
	    # elsewhere.  Put it in the stash.
	    $ctx->stash->{new_user} = $new_user;
	    return $user;
	}
	else {
	    die 'Error: Realm did not auto-create user';
	}
    }
}

__PACKAGE__->meta->make_immutable;


1;

__END__
=pod

=encoding utf-8

=head1 NAME

Catalyst::Authentication::Credential::Facebook::OAuth2 - Authenticate your Catalyst application's users using Facebook's OAuth 2.0

=head1 SYNOPSIS

    package MyApp;

    __PACKAGE__->config(
        'Plugin::Authentication' => {
            default => {
                credential => {
                    class              => 'Facebook::OAuth2',
                    application_id     => $app_id,
                    application_secret => $app_secret,
                },
                store => { ... },
            },
        },
    );

    ...

    package MyApp::Controller::Foo;

    sub some_action : Local {
        my ($self, $ctx) = @_;

        my $user = $ctx->authenticate({
            scope => ['offline_access', 'publish_stream'],
        });

        # ->authenticate set up a response that'll redirect to Facebook.
        #
        # Wait for the user to tell Facebook to authorise our application
        # by aborting our own request processing with ->detach and simply
        # sending the redirect.
        #
        # Once the user confirmed access for our application, Facebook will
        # redirect back to the URL of this action and ->authenticate will
        # return a valid user retrieved from the user store using the token
        # received from Facebook.
        $ctx->detach unless $user;

        ... # use your $user object (or $ctx->user, or whatever)
    }

=head1 ATTRIBUTES

=head2 application_id

Your application's API key as retrieved from
L<http://www.facebook.com/developers/>.

=head2 application_secret

Your application's secret key as retrieved from
L<http://www.facebook.com/developers/>.

=head2 oauth_args

An array reference of additional options to pass to L<Facebook::Graph>'s
constructor.

=head1 METHODS

=head2 authenticate

    my $user = $ctx->authenticate({
        scope => ['offline_access', 'publish_stream'],
    });

Attempts to authenticate a user by using Facebook's OAuth 2.0 interface. This
works by generating an HTTP response that will redirect the user to a page on
L<http://facebook.com> that will ask the user to confirm our request to
authenticate him. Once that has happened, Facebook will redirect back to use and
C<authenticate> will return a user instance.

Note how this is different from most other Catalyst authentication
credentials. Successful authentication requires two requests to the Catalyst
application - one is initiated by the user, the second one is caused by Facebook
redirecting the user back to the application.

Because of that, special care has to be taken. If C<authenticate> returns a
false value, that means it set up the appropriate redirect response in
C<< $ctx->response >>. C<authenticate>'s caller should not manipulate with that
response, but finish his request processing and send the response to the user,
for example by doing C<< $ctx->detach >>.

After being redirected back to from Facebook, C<authenticate> will use the
authentication code Facebook sent back to retrieve an access token from
Facebook. This token will be used to look up a user instance from the
authentication realm's store. That user, or undef if none has been found, will
be returned.

If you're only interested in the access token, you might want to use
L<Catalyst::Authentication::Store::Null> as an authentication store and
introspect the C<token> attribute of the return user instance before logging the
user out again immediately using C<< $ctx->logout >>. You can then later use the
access token you got to communicate with Facebook on behalf of the user that
granted you access.

If access token retrieval fails, an exception will be thrown.

The C<scope> key in the auth info hash reference passed as the first argument to
C<authenticate> will be passed along to C<Facebook::Graph::Authorize>'s
C<extend_permissions> method.

=head1 ACKNOWLEDGEMENTS

Thanks L<Reask Limited|http://reask.com/> for funding the development of this
module.

Thanks L<Shutterstock|http://shutterstock.com/> for funding bugfixing of and
enhancements to this module.

=for Pod::Coverage   BUILD

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Florian Ragwitz, Reask Limited.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

