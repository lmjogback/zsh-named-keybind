#!/usr/bin/env zsh

set -eu

source "${0:A:h}/../zsh-named-keybind.plugin.zsh"

typeset -gi tests=0

check_sequence() {
  local key=$1 expected=$2
  (( ++tests ))
  _named_keybind_sequence "$key"
  [[ $REPLY == $expected ]] || {
    print -u2 -- "FAIL: $key: expected ${(qqqq)expected}, got ${(qqqq)REPLY}"
    return 1
  }
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

# Classic control characters.
check_sequence Ctrl+Space $'\x00'
check_sequence Ctrl+@     $'\x00'
check_sequence Ctrl+A     $'\x01'
check_sequence Ctrl+P     $'\x10'
check_sequence Ctrl+Z     $'\x1a'
check_sequence 'Ctrl+['   $'\x1b'
check_sequence 'Ctrl+\\'  $'\x1c'
check_sequence 'Ctrl+]'   $'\x1d'
check_sequence 'Ctrl+^'   $'\x1e'
check_sequence 'Ctrl+_'   $'\x1f'
check_sequence 'Ctrl+?'   $'\x7f'

# Meta characters.
check_sequence Alt+Space $'\e '
check_sequence Alt+C     $'\eC'
check_sequence Alt+c     $'\ec'

# Named keys resolved through terminfo.
check_sequence Up        "$terminfo[kcuu1]"
check_sequence Down      "$terminfo[kcud1]"
check_sequence Left      "$terminfo[kcub1]"
check_sequence Right     "$terminfo[kcuf1]"
check_sequence Home      "$terminfo[khome]"
check_sequence End       "$terminfo[kend]"
check_sequence Insert    "$terminfo[kich1]"
check_sequence Delete    "$terminfo[kdch1]"
check_sequence PageUp    "$terminfo[kpp]"
check_sequence PageDown  "$terminfo[knp]"
check_sequence Backspace "$terminfo[kbs]"
check_sequence F1        "$terminfo[kf1]"
check_sequence F2        "$terminfo[kf2]"
check_sequence F3        "$terminfo[kf3]"
check_sequence F4        "$terminfo[kf4]"
check_sequence F5        "$terminfo[kf5]"
check_sequence F6        "$terminfo[kf6]"
check_sequence F7        "$terminfo[kf7]"
check_sequence F8        "$terminfo[kf8]"
check_sequence F9        "$terminfo[kf9]"
check_sequence F10       "$terminfo[kf10]"
check_sequence F11       "$terminfo[kf11]"
check_sequence F12       "$terminfo[kf12]"

# Modified cursor/navigation keys use the xterm CSI modifier convention.
check_sequence Shift+Up           $'\e[1;2A'
check_sequence Alt+Left           $'\e[1;3D'
check_sequence Alt+Shift+Right    $'\e[1;4C'
check_sequence Ctrl+Down          $'\e[1;5B'
check_sequence Ctrl+Shift+Home    $'\e[1;6H'
check_sequence Ctrl+Alt+End       $'\e[1;7F'
check_sequence Ctrl+Alt+Shift+Up  $'\e[1;8A'
check_sequence Shift+Delete        $'\e[3;2~'
check_sequence Alt+PageUp          $'\e[5;3~'
check_sequence Ctrl+Insert         $'\e[2;5~'
check_sequence Ctrl+Shift+PageDown $'\e[6;6~'

# Backspace modifier encodings.
check_sequence Alt+Backspace      $'\e\x7f'
check_sequence Ctrl+Backspace     $'\x08'
check_sequence Ctrl+Alt+Backspace $'\e\x08'

# Verify actual ZLE bindings.
check_binding history-substring-search-up Up
check_binding history-substring-search-up Ctrl+P
check_binding copy-prev-shell-word Alt+C

# Uppercase Alt names bind both shifted and unshifted variants.
(( ++tests ))
[[ $(bindkey $'\eC') == *' copy-prev-shell-word' ]] || {
  print -u2 -- 'FAIL: Alt+C shifted binding'
  return 1
}
(( ++tests ))
[[ $(bindkey $'\ec') == *' copy-prev-shell-word' ]] || {
  print -u2 -- 'FAIL: Alt+C unshifted binding'
  return 1
}

print -- "ok: $tests tests"
