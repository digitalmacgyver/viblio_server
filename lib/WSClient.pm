package WSClient;
use strict;

use URI;
use HTTP::Cookies;
use JSON;
use Data::Dumper;
use LWP::UserAgent;
use FileHandle;
use File::Basename;
use JSON;

sub new {
    my $class = shift;
    my %args  = @_;
    my $this  = \%args;

    return undef unless
	( 
	  $this->{base_url} );

    $this->{ua} = LWP::UserAgent->new;

    $this->{ua}->agent( 'Mozilla/5.0 (Linux; U; Android 3.1; en-us; GT-P7310 Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 XXX/534.13' );

    unless( $this->{use_cookies} ) {
	my $headers = new HTTP::Headers;
	$headers->authorization_basic
	    ($this->{email}, $this->{password});
	$this->{ua}->default_headers( $headers );
    }

    # $this->{ua}->default_header( 'Content-type' => 'application/json' );
    if ( $this->{expect} ) {
	$this->{ua}->default_header( 'Accept' => $this->{expect} . ', */*; q=0.01' );
    }

    if ( $this->{xhr} ) {
	$this->{ua}->default_header( 'X-Requested-With' => 'XMLHttpRequest' );
    }

    if ( $this->{debug} ) {
	$this->{ua}->default_header( 'X-Debug' => 'true' );
    }

    $this->{cj} = HTTP::Cookies->new
	( file => "cookie-jar.txt",
	  ignore_discard => 1,
	  autosave => 1 );
    $this->{ua}->cookie_jar
        ( $this->{cj} );

    bless $this, $class;

    return $this;
}

sub call {
    my $this   = shift;
    my $how    = shift;
    my $method = shift;
    my @args   = @_;
    my %hash   = @_;

    # $args{method}

    if ( $this->{dump_request} ) {
	$this->{ua}->add_handler
	    ( 'request_send' => 
	      sub {
		  print "-- R E Q U E S T -----------------\n";
		  print $_[0]->as_string;
		  print "-- E N D  R E Q U E S T ----------\n";
		  return;
	      } );
    }

    my $url = URI->new( $this->{base_url} . "/" . $method );
    my $res;
    if ( $how eq 'put' ) {
	$url->query_form( \%hash );
	$res = $this->{ua}->put( $url, \@args );
    }
    elsif ( $how eq 'delete' ) {
	$url->query_form( \%hash );
	$res = $this->{ua}->delete( $url );
    }
    elsif ( $how eq 'get' ) {
	$url->query_form( \%hash );
	$res = $this->{ua}->get( $url );
    }
    elsif ( $how eq 'post' ) {
	$res = $this->{ua}->post( $url, \@args );
    }

    if ( $this->{dump_response} ) {
	print "-- R E S P O N S E -----------------\n";
	print $res->as_string;
	print "-- E N D  R E S P O N S E ----------\n";
    }

    unless( $this->{no_redirects} ) {
	if ( $res->code == 302 ) {
	    my $loc = $res->header( 'Location' );
	    $loc =~ s/^\///g;
	    if ( $this->{dump_response} ) {
		print "REDIRECTING TO $loc\n";
	    }
	    return $this->call( 'get', $loc, @args );
	}
    }
    
    if ( ! $res->is_success ) {
        return { iserror => 1,
                 error => $res->status_line,
                 content => $res->content };
    }
    elsif ( $res->content_type eq 'application/json' ) {
        return from_json( $res->content );
    }
    else {
        return { iserror => 0,
                 content => $res->content };
    }
}

sub get {
    my $this   = shift;
    my $method = shift;
    my @args   = @_;
    my $res = $this->call( 'get', $method, @args );
    return $res;
}

sub put {
    my $this   = shift;
    my $method = shift;
    my @args   = @_;
    my $res = $this->call( 'put', $method, @args );
    return $res;
}

sub post {
    my $this   = shift;
    my $method = shift;
    my @args   = @_;
    my $res = $this->call( 'post', $method, @args );
    return $res;
}

sub upload {
    my $this = shift;
    my $method = shift;
    my $filename = shift;
    my %args   = @_;
    
    $ENV{ DYNAMIC_FILE_UPLOAD } = 1;
    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;

    my $url = URI->new( $this->{base_url} . "/$method" );

    my @content = ();
    foreach my $key ( keys( %args ) ) {
        push( @content, $key => $args{$key} );
    }
    push( @content,
          upload => [ $filename, ( $args{label} || basename( $filename ) ) ] );

    my $res = $this->{ua}->post
        ( $url,
          Content_Type => 'multipart/form-data',
          Content => \@content );

    if ( $this->{dump_response} ) {
	print "-- R E S P O N S E -----------------\n";
	print $res->as_string;
	print "-- E N D  R E S P O N S E ----------\n";
    }

    if ( ! $res->is_success ) {
        return { iserror => 1,
                 error => $res->status_line,
                 content => $res->content };
    }
    elsif ( $res->content_type eq 'application/json' ) {
        return from_json( $res->content );
    }
    else {
        return { iserror => 0,
                 content => $res->content };
    }
}

sub download {
    my $this = shift;
    my $method = shift;
    my $filename = shift;
    my %args   = @_;

    my $url = URI->new( $this->{base_url} . "/$method" );
    $url->query_form( \%args );

    my $res = $this->{ua}->get
        ( $url,
	  ':content_file' => $filename,
	);

    if ( $this->{dump_response} ) {
	print "-- R E S P O N S E -----------------\n";
	print $res->as_string;
	print "-- E N D  R E S P O N S E ----------\n";
    }

    if ( ! $res->is_success ) {
        return { iserror => 1,
                 error => $res->status_line,
                 content => $res->content };
    }
    elsif ( $res->content_type eq 'application/json' ) {
        return from_json( $res->content );
    }
    else {
        return { iserror => 0,
                 content => "ok" };
    }
}

1;
