echo "Remove the old 50-omarchy fontconfig rule so it stops overriding your monospace font"

# The package rule moved from 50-omarchy.conf to 51-omarchy.conf so the
# generated user rule (loaded by 50-user.conf) is evaluated first. Pacman
# orphans the removed 50- files instead of deleting them, so an old install
# would keep the old hijacking rule alongside the new one. Remove both the
# installed target and its conf.d symlink; either may already be gone.
if [[ -e /usr/share/fontconfig/conf.avail/50-omarchy.conf || -L /usr/share/fontconfig/conf.avail/50-omarchy.conf || -e /etc/fonts/conf.d/50-omarchy.conf || -L /etc/fonts/conf.d/50-omarchy.conf ]]; then
  sudo rm -f /usr/share/fontconfig/conf.avail/50-omarchy.conf /etc/fonts/conf.d/50-omarchy.conf
fi
