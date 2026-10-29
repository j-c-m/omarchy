#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

unset FONTCONFIG_FILE FONTCONFIG_PATH

if ! command -v fc-match >/dev/null; then
  skip "fontconfig monospace scoping needs fc-match"
  exit 0
fi

# The matrix needs real fonts behind every name it resolves. Read the list
# into a variable first: grep -q closing the pipe early would SIGPIPE
# fc-list and, under pipefail, read as a missing font.
installed_fonts=$(fc-list)
for family in "Adwaita Mono" "Liberation Mono" "JetBrains Mono" "JetBrainsMono Nerd Font"; do
  if ! grep -Fqi -- "$family" <<<"$installed_fonts"; then
    skip "fontconfig monospace scoping needs $family"
    exit 0
  fi
done

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

fake_home="$test_tmp/fakehome"
mkdir -p "$fake_home/.config/fontconfig"

# The block omarchy-font-set generates, with the caller's font substituted.
# Kept byte-identical to bin/omarchy-font-set's heredoc apart from that.
write_user_font() {
  cat >"$fake_home/.config/fontconfig/fonts.conf" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any">
      <string>monospace</string>
    </test>
    <test name="family" qual="all" compare="eq">
      <string>monospace</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$1</string>
    </edit>
  </match>
</fontconfig>
XML
}

candidate="$ROOT/default/fontconfig/conf.avail/51-omarchy.conf"
{
  echo '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>'
  echo "<dir>/usr/share/fonts</dir><cachedir>$test_tmp/cache</cachedir>"
  placed=false
  for conf in /etc/fonts/conf.d/*.conf; do
    name=${conf##*/}
    # Skip the installed rule, old name included: the candidate replaces it.
    [[ $name == "50-omarchy.conf" || $name == "51-omarchy.conf" ]] && continue
    if ! $placed && [[ $name > "51-omarchy.conf" ]]; then
      echo "<include>$candidate</include>"
      placed=true
    fi
    echo "<include>$conf</include>"
  done
  $placed || echo "<include>$candidate</include>"
  echo '</fontconfig>'
} >"$test_tmp/fonts.conf"

# env -i keeps a leaked XDG_CONFIG_HOME (or HOME) from loading the
# developer's real user config into the rig and invalidating the result.
rig() {
  env -i HOME="$fake_home" XDG_CONFIG_HOME="$fake_home/.config" FONTCONFIG_FILE="$test_tmp/fonts.conf" PATH="$PATH" LANG=C.UTF-8 "$@"
}

resolve() {
  rig fc-match -f '%{family[0]}\n' "$1"
}

explicit_families=("JetBrains Mono" "Liberation Mono" "Adwaita Mono" "JetBrainsMono Nerd Font")

check_matrix() {
  local chosen=$1
  local actual

  actual=$(resolve monospace)
  [[ $actual == "$chosen" ]] || fail "monospace resolves to the generated font ($chosen)" "$actual"

  local family
  for family in "${explicit_families[@]}"; do
    actual=$(resolve "$family")
    [[ $actual == "$family" ]] || fail "explicit $family resolves to itself with $chosen generated" "$actual"
  done

  # FC_DEBUG=7 prefixes edits a rule actually applied with "Substitute";
  # the bare rule listing repeats every Assign in the config, applied or not.
  for family in "${explicit_families[@]}"; do
    if rig FC_DEBUG=7 fc-match "$family" 2>&1 | grep -q 'Substitute Edit family Assign'; then
      fail "no Assign fires for explicit $family" "$family"
    fi
  done
}

write_user_font "Adwaita Mono"
rig fc-cache >/dev/null
check_matrix "Adwaita Mono"
pass "the generated font wins bare monospace and explicit monospace families resolve to themselves"

write_user_font "JetBrainsMono Nerd Font"
rig fc-cache >/dev/null
check_matrix "JetBrainsMono Nerd Font"
pass "with the default generated font, bare monospace is the Nerd Font and explicit families are unchanged"
