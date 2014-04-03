use Net::APNS;

my $APNS = Net::APNS->new;
my $Notifier = $APNS->notify({
    cert   => "root/push/apns/APNS-cert.pem",
    key    => "root/push/apns/APNS-private.pem",
    passwd => "Viblio1234$$" });

$Notifier->devicetoken( $ARGV[0] );
$Notifier->message("Hey Vinay, another test!");
# $Notifier->badge(2);
$Notifier->sound('default');
$Notifier->custom({ type => 'NEWVIDEO', uuid => 'df8dfa29-b31d-4fd6-b4d4-3127d196c126' });
$Notifier->write;
