#!/usr/bin/env perl
use lib "lib";
use Data::Dumper;
use VA;

$c = VA->new;

$user = $c->model( 'RDS::User' )->find({ email => 'aqpeeb@gmail.com' });
$rs = $c->model( 'RDS::MediaAsset' )->search({ 'me.asset_type' => 'poster',-and => [ -or => ['media.user_id' => $user->id, 'media_shares.user_id' => $user->id], -or => ['media.status' => 'TranscodeComplete','media.status' => 'FaceDetectComplete','media.status' => 'FaceRecognizeComplete' ]]}, {prefetch=>{'media' => 'media_shares'}, group_by=>['media.id']});
print $user->displayname, "\n";

