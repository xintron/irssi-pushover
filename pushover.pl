# Push hilights and private  while away
# Author: Marcus Carlsson <carlsson.marcus@gmail.com>

use strict;
use warnings;

use Irssi;
use vars qw($VERSION %IRSSI %config);
use LWP::UserAgent;

$VERSION = '0.1';

%IRSSI = (
    authors => 'Marcus Carlsson',
    contact => 'carlsson.marcus@gmail.com',
    name => 'pushover',
    description => 'Push hilights and private messages when away',
    license => 'BSD',
    url => 'https://github.com/xintron',
);

my $app_token = 'yy4E5dCm5FKx1AGrxsxVgmZu3pBWs0';

sub debug {
    return unless Irssi::settings_get_bool('pushover_debug');
    my $text = shift;
    my @caller = caller(1);
    Irssi::print('From '.$caller[3].': '.$text);
}

sub send_push {
    my $user_token = Irssi::settings_get_str('pushover_token');
    if (!$user_token) {
        debug('Missing pushover token.');
        return;
    }

    debug('Sending notification.');
    my ($channel, $text) = @_;
    my $resp = LWP::UserAgent->new()->post(
        'https://api.pushover.net/1/messages.json', [
            token => $app_token,
            user => $user_token,
            message => $text,
            title => $channel
        ]
    );

    if ($resp->is_success) {
        debug('Notification successfully sent.');
    }
    else {
        debug('Notification not sent: '.$resp->decoded_content);
    }
}

sub msg_pub {
    my ($server, $data, $nick, $mask, $target) = @_;
    my $safeNick = quotemeta($server->{nick});

    if ($server->{usermode_away} == '1' && $data =~ /$safeNick/i) {
        debug('Got pub msg.');
        send_push($target, $nick.': '.strip_formating($data));
    }
}

sub msg_pri {
    my ($server, $data, $nick, $address) = @_;
    if ($server->{usermode_away} == '1') {
        debug('Got priv msg.');
        send_push('Priv, '.$nick, strip_formating($data));
    }
}

sub msg_kick {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
    if ($server->{usermode_away} == '1' && $nick eq $server->{nick}) {
        debug('Was kicked.');
        send_push('Kicked: '.$channel, 'Was kicked by: '.$kicker.'. Reason: '.strip_formating($reason));
    }
}

sub strip_formating {
    my ($msg) = @_;
    $msg =~ s/\x03[0-9]{0,2}(,[0-9]{1,2})?//g;
    $msg =~ s/[^\x20-\xFF]//g;
    $msg =~ s/\xa0/ /g;
    return $msg;
}

Irssi::settings_add_str($IRSSI{'name'}, 'pushover_token', '');
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_debug', 0);

Irssi::signal_add_last('message public', 'msg_pub');
Irssi::signal_add_last('message private', 'msg_pri');
Irssi::signal_add_last('message kick', 'msg_kick');

Irssi::print('%Y>>%n '.$IRSSI{name}.' '.$VERSION.' loaded.');
if (!Irssi::settings_get_str('pushover_token')) {
    Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover token is not set, set it with /set pushover_token token.');
}
