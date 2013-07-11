irssi-pushover
==============

Plugin for irssi (a console based IRC client) to send push-notifications using pushover.net.

This allows you to be notified when someone messages/mentions you on IRC, 
when you're not online.


# Installation

  0. Add a new application to your pushover control panel, note the API key.
  1. cp pushover.pl to ~/.irssi/scripts/ and symlink into scripts/autorun if you desire.
  2. touch ~/.irssi/pushover_ignores
  2. Within irssi: 
    1. /load autorun/pushover.pl
    2. /set pushover_token <<your pushover User Key>>
    3. /set pushover_apptoken <<your pushover app token>>
    4. /set pushover_sound (choose one from https://pushover.net/api#sounds, defaults to siren)
    5. /save
    6. /pushtest hello world. (sends test message to your device(s)).


# Dependencies

  0. Account with pushover.net
  1. Crypt::SSLeay / libcrypt-ssleay-perl is installed 

# Other things 

  0. /set pushover_debug 1 - should make it verbose.
  1. /set pushover_ignore 1 - turn on ignore configurability
  2. /set pushover_ignorefile - ignore messages from ....
  3. /set pushover_ignorechannels - space separated list of channels to ignore.
  4. /pushignore help - should get you started in populating the ignore list.
  5. /set pushover_only_if_away [on|off] - if set to on, then you'll 
        need to be set to away before we send notifications.
