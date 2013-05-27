# Push hilights and private  while away
# Author: Marcus Carlsson <carlsson.marcus@gmail.com>

use strict;
use warnings;

use Irssi;
use vars qw($VERSION %IRSSI %config);
use LWP::UserAgent;
use Scalar::Util qw(looks_like_number);

$VERSION = '0.2.1';

%IRSSI = (
    authors => 'Marcus Carlsson',
    contact => 'carlsson.marcus@gmail.com',
    name => 'pushover',
    description => 'Push hilights and private messages when away',
    license => 'BSD',
    url => 'https://github.com/xintron',
);

my $pushover_ignorefile;


sub cmd_help {
    my $out = <<'HELP_EOF';
PUSHIGNORE LIST
PUSHIGNORE ADD <hostmask>
PUSHIGNORE REMOVE <number>

The mask matches in the format ident@host. Notice that no-ident responses puts
a tilde in front of the ident.

Examples:
  Will match foo@test.bar.se but *not* ~foo@test.bar.se.
    /PUSHIGNORE ADD foo@*.bar.se  
  Use the list-command to show a list of ignores and the number in front
  combined with remove to delete that mask.
    /PUSHIGNORE REMOVE 2

For a list of available settings, run:
  /set pushover
HELP_EOF
    chomp $out;
    Irssi::print($out, MSGLEVEL_CLIENTCRAP);
}
sub read_settings {
    $pushover_ignorefile = Irssi::settings_get_str('pushover_ignorefile');
}

sub debug {
    return unless Irssi::settings_get_bool('pushover_debug');
    my $text = shift;
    my @caller = caller(1);
    Irssi::print('From '.$caller[3].': '.$text);
}

sub send_push {
    my $user_token = Irssi::settings_get_str('pushover_token');
    my $app_token = Irssi::settings_get_str('pushover_apptoken');
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
            sound => Irssi::settings_get_str('pushover_sound'),
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
    my ($server, $data, $nick, $address, $target) = @_;
    my $safeNick = quotemeta($server->{nick});

    if ($server->{usermode_away} == '1' && $data =~ /$safeNick/i && !check_ignore($address) && !check_ignore_channels($target)) {
        debug('Got pub msg.');
        send_push($target, $nick.': '.strip_formating($data));
    }
}

sub msg_pri {
    my ($server, $data, $nick, $address) = @_;
    if ($server->{usermode_away} == '1' && !check_ignore($address)) {
        debug('Got priv msg.');
        send_push('Priv, '.$nick, strip_formating($data));
    }
}

sub msg_kick {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
    if ($server->{usermode_away} == '1' && $nick eq $server->{nick} && !check_ignore($address)) {
        debug('Was kicked.');
        send_push('Kicked: '.$channel, 'Was kicked by: '.$kicker.'. Reason: '.strip_formating($reason));
    }
}

sub msg_test {
   my ($data, $server, $item) = @_;
   $data =~ s/^([\s]+).*$/$1/;
   my $orig_debug = Irssi::settings_get_bool('pushover_debug');
   Irssi::settings_set_bool('pushover_debug', 1);
   debug("Sending test message :" . $data);
   send_push("Test Message", strip_formating($data));
   Irssi::settings_set_bool('pushover_debug', $orig_debug);
}

sub strip_formating {
    my ($msg) = @_;
    $msg =~ s/\x03[0-9]{0,2}(,[0-9]{1,2})?//g;
    $msg =~ s/[^\x20-\xFF]//g;
    $msg =~ s/\xa0/ /g;
    return $msg;
}


sub check_ignore {
    return 0 unless(Irssi::settings_get_bool('pushover_ignore'));
    my @ignores = read_file();
    return 0 unless(@ignores);
    my ($mask) = @_;

    foreach (@ignores) {
        $_ =~ s/\./\\./g;
        $_ =~ s/\*/.*?/g;
        if ($mask =~ m/^$_$/i) {
            debug('Ignore matches, not pushing.');
            return 1;
        }
    }
    return 0;
}
sub check_ignore_channels {
	my ($target) = @_;
	my @ignore_channels = split(' ', Irssi::settings_get_str('pushover_ignorechannels'));
	return 0 unless @ignore_channels;
	if (grep {lc($_) eq lc($target)} @ignore_channels) {
		debug("$target set as ignored channel.");
		return 1;
	}

	return 0;
}
sub ignore_handler {
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub('pushignore', $data, $server, $item);
}

sub ignore_unknown {
    cmd_help();
    Irssi::signal_stop(); # Don't print 'no such command' error.
}

sub ignore_list {
    my @data = read_file();
    if (@data) {
        my $i = 1;
        my $out;
        foreach(@data) {
            $out .= $i++.". $_\n";
        }
        chomp $out;
        Irssi::print($out, MSGLEVEL_CLIENTCRAP);
    }
}

sub ignore_add {
    my ($data, $server, $item) = @_;
    $data =~ s/^([\s]+).*$/$1/;
    return Irssi::print("No hostmask given.", MSGLEVEL_CLIENTCRAP) unless($data ne "");

    my @ignores = read_file();
    push(@ignores, $data);
    write_file(@ignores);
    Irssi::print("Successfully added '$data'.", MSGLEVEL_CLIENTCRAP);
}

sub ignore_remove {
    my($num, $server, $item) = @_;
    $num =~ s/^(\d+).*$/$1/;
    return Irssi::print("List-number is needed when removing", MSGLEVEL_CLIENTCRAP) unless(looks_like_number($num));
    my @ignores = read_file();
    
    # Index out of range
    return Irssi::print("Number was out of range.", MSGLEVEL_CLIENTCRAP) unless(scalar(@ignores) >= $num);
    delete $ignores[$num-1];
    write_file(@ignores); 
}

sub write_file {
    read_settings();
    my $fp;
    if (!open($fp, ">", $pushover_ignorefile)) {
        Irssi::print("Error opening ignore file", MSGLEVEL_CLIENTCRAP);
        return;
    }
    print $fp join("\n", @_);
    close $fp;
}

sub read_file {
    read_settings();
    my $fp;
    if (!open($fp, "<", $pushover_ignorefile)) {
        Irssi::print("Error opening ignore file", MSGLEVEL_CLIENTCRAP);
        return;
    }

    my @out;
    while (<$fp>) {
        chomp;
        next if $_ eq '';
        push(@out, $_);
    }
    close $fp;

    return @out;
}

Irssi::settings_add_str($IRSSI{'name'}, 'pushover_token', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushover_apptoken', '');
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_debug', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_ignore', 1);
Irssi::settings_add_str($IRSSI{'name'}, 'pushover_ignorefile', Irssi::get_irssi_dir().'/pushover_ignores');
Irssi::settings_add_str($IRSSI{'name'}, 'pushover_ignorechannels', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushover_sound', 'siren');

Irssi::command_bind('help pushignore', \&cmd_help);
Irssi::command_bind('pushignore help', \&cmd_help);
Irssi::command_bind('pushignore add', \&ignore_add);
Irssi::command_bind('pushignore remove', \&ignore_remove);
Irssi::command_bind('pushignore list', \&ignore_list);
Irssi::command_bind('pushignore', \&ignore_handler);
Irssi::command_bind('pushtest', \&msg_test);
Irssi::signal_add_first("default command pushignore", \&ignore_unknown);


Irssi::signal_add_last('message public', 'msg_pub');
Irssi::signal_add_last('message private', 'msg_pri');
Irssi::signal_add_last('message kick', 'msg_kick');

Irssi::print('%Y>>%n '.$IRSSI{name}.' '.$VERSION.' loaded.');
if (!Irssi::settings_get_str('pushover_token')) {
    Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover User Key token is not set, set it with /set pushover_token token.');
}
if (!Irssi::settings_get_str('pushover_apptoken')) {
    Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover application token is not set, set it with /set pushover_apptoken token.');
}
