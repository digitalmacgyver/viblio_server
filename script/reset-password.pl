#!/usr/bin/env perl
use lib "lib";
use VA;

my $c = VA->new;

my $email = $ARGV[0];
unless( $email ) {
    die "Usage: $0 email-address";
}
my $user  = $c->model( 'RDS::User' )->find({ email => $email });
unless( $user ) {
    die "No user found with email: $email";
}
my $code = invite_code();
$user->password( $code );
$user->update;

my $res  = VA::Controller::Services->send_email( $c, {
    subject  => $c->loc( "Reset your password on Viblio" ),
    to => [{
	email => $email }],
    template => 'email/18-forgotPassword.tt',
    stash => {
	new_password => $code,
	user => $user,
    } });

print "User $email password changed to: $code\n";

exit 0;

sub invite_code {
    my ( $len ) = @_;
    $len = 8 unless( $len );
    my $code = '';
    for( my $i=0; $i<$len; $i++ ) {
        $code .= substr("abcdefghjkmnpqrstvwxyz23456789",int(1+rand()*30),1);
    }
    return $code;
}
