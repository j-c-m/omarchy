echo "Move the monospace font rule aside and upgrade your generated font override"

# The package rule moved from 50-omarchy.conf to 51-omarchy.conf so the
# generated user rule (loaded by 50-user.conf) is evaluated first. Only
# clean up once the replacement is actually installed: on a checkout that
# links Omarchy commands without updating fixed system paths, the installed
# settings package may still supply only the old file, and deleting it
# would remove every Omarchy font default from that machine. Staying
# pending retries after the package update lands (omarchy update installs
# packages before running migrations).
if [[ ! -e /usr/share/fontconfig/conf.avail/51-omarchy.conf && ! -L /etc/fonts/conf.d/51-omarchy.conf ]]; then
  echo "The settings package has not installed 51-omarchy.conf yet; leaving this migration pending"
  exit 1
fi

# Pacman orphans the removed 50- files instead of deleting them, so an old
# install would keep the old hijacking rule alongside the new one. Remove
# both the installed target and its conf.d symlink; either may already be
# gone.
if [[ -e /usr/share/fontconfig/conf.avail/50-omarchy.conf || -L /usr/share/fontconfig/conf.avail/50-omarchy.conf || -e /etc/fonts/conf.d/50-omarchy.conf || -L /etc/fonts/conf.d/50-omarchy.conf ]]; then
  sudo rm -f /usr/share/fontconfig/conf.avail/50-omarchy.conf /etc/fonts/conf.d/50-omarchy.conf
fi

# A rule the old omarchy-font-set generated keeps working after the rename,
# and keeps hijacking: its unguarded prepend_first runs before the package
# rule and puts the chosen font ahead of explicit families that only gained
# "monospace" from 48-guessfamily.conf. Upgrade that known block to the
# scoped form, preserving the selected font; anything else in the file is
# the user's own and stays untouched.
user_font="$HOME/.config/fontconfig/fonts.conf"
# The old generated block holds exactly two family strings: the "monospace"
# test and the selected font. Anything more is the user's own editing.
if [[ -f $user_font ]] && grep -Fq 'prepend_first' "$user_font" &&
  (( $(grep -c '<string>monospace</string>' "$user_font") == 1 )) &&
  (( $(grep -c '<string>' "$user_font") == 2 )); then
  chosen=$(grep -o '<string>.*</string>' "$user_font" | sed -e 's/^<string>//' -e 's|</string>$||' | grep -vx 'monospace' | head -n 1)
  if [[ -n $chosen ]]; then
    cat >"$user_font" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any">
      <string>monospace</string>
    </test>
    <test name="family" qual="first" compare="eq">
      <string>monospace</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>$chosen</string>
    </edit>
  </match>
</fontconfig>
XML
    echo "Upgraded the generated monospace override to the scoped form (kept $chosen)"
  fi
fi
