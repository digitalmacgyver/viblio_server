use Net::APNS;

my $APNS = Net::APNS->new;
my $Notifier = $APNS->notify({
    cert   => "push-notifications/APNS-cert.pem",
    key    => "push-notifications/APNS-private.pem",
    passwd => "Viblio1234$$" });

$Notifier->devicetoken( $ARGV[0] );
$Notifier->message("Hey Vinay, another test!");
# $Notifier->badge(2);
$Notifier->sound('default');
$Notifier->custom({ type => 'NEWVIDEO' });
$Notifier->write;
