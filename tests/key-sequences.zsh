#!/usr/bin/env zsh

set -eu

source "${0:A:h}/../zsh-named-keybind.plugin.zsh"

typeset -gi tests=0

check_sequence() {
  local key=$1 expected=$2
  (( ++tests ))

  _named_keybind_sequence "$key"
  if [[ $REPLY != $expected ]]; then
    print -u2 -- "FAIL: $key: expected ${(qqqq)expected}, got ${(qqqq)REPLY}"
    return 1
  fi
}

check_binding() {
  local widget=$1 key=$2
  (( ++tests ))

  keybind "$widget" "$key"
  _named_keybind_sequence "$key"
  local actual=$(bindkey "$REPLY")
  [[ $actual == *" $widget" ]] || {
    print -u2 -- "FAIL: binding $key: expected $widget, got $actual"
    return 1
  }
}

# Control and Meta characters.
check_sequence Ctrl+A $'\x01'
check_sequence Ctrl+P $'\x10'
check_sequence Ctrl+Z $'\x1a'
check_sequence Alt+C  $'\ec'

# Named keys must resolve to terminfo.
check_sequence Up       "$terminfo[kcuu1]"
check_sequence Down     "$terminfo[kcud1]"
check_sequence Left     "$terminfo[kcub1]"
check_sequence Right    "$terminfo[kcuf1]"
check_sequence Home     "$terminfo[khome]"
check_sequence End      "$terminfo[kend]"
check_sequence Insert   "$terminfo[kich1]"
check_sequence Delete   "$terminfo[kdch1]"
check_sequence PageUp   "$terminfo[kpp]"
check_sequence PageDown "$terminfo[knp]"

# Modified cursor/navigation keys use the xterm CSI modifier convention.
check_sequence Shift+Up          $'\e[1;2A'
check_sequence Alt+Left          $'\e[1;3D'
check_sequence Alt+Shift+Right   $'\e[1;4C'
check_sequence Ctrl+Down         $'\e[1;5B'
check_sequence Ctrl+Shift+Home   $'\e[1;6H'
check_sequence Ctrl+Alt+End      $'\e[1;7F'
check_sequence Ctrl+Alt+Shift+Up $'\e[1;8A'

check_sequence Shift+Delete       $'\e[3;2~'
check_sequence Alt+PageUp         $'\e[5;3~'
check_sequence Ctrl+Insert        $'\e[2;5~'
check_sequence Ctrl+Shift+PageDown $'\e[6;6~'

# Backspace has historical control/meta encodings rather than CSI modifiers.
check_sequence Backspace          "$terminfo[kbs]"
check_sequence Alt+Backspace      $'\e\x7f'
check_sequence Ctrl+Backspace     $'\x08'
check_sequence Ctrl+Alt+Backspace $'\e\x08'

# Verify that keybind installs the generated sequence in the active keymap.
check_binding history-substring-search-up Up
check_binding history-substring-search-up Ctrl+P

print -- "ok: $tests tests"
