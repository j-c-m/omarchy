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
if [[ -f $user_font ]] && grep -Fq 'prepend_first' "$user_font"; then
  chosen=$(grep -o '<string>.*</string>' "$user_font" | sed -e 's/^<string>//' -e 's|</string>$||' | grep -vx 'monospace' | head -n 1)
  old_start=$(grep -n '<match' "$user_font" | awk -F: -v pl="$(grep -n 'prepend_first' "$user_font" | head -n 1 | cut -d: -f1)" '$1 <= pl {s=$1} END {print s}')
  old_end=$(awk -v pl="$(grep -n 'prepend_first' "$user_font" | head -n 1 | cut -d: -f1)" 'NR >= pl && /<\/match>/ {print NR; exit}' "$user_font")
  if [[ -n $chosen && -n $old_start && -n $old_end ]]; then
    scoped=$(mktemp)
    cat >"$scoped" <<XML
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
XML
    replaced=$(mktemp)
    {
      head -n $((old_start - 1)) "$user_font"
      cat "$scoped"
      tail -n +"$((old_end + 1))" "$user_font"
    } >"$replaced"
    mv "$replaced" "$user_font"
    rm -f "$scoped"
    echo "Upgraded the generated monospace override to the scoped form (kept $chosen)"
  fi
fi
