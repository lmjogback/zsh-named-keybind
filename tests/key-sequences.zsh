#!/usr/bin/env zsh

set -eu

source "${0:A:h}/../zsh-named-keybind.plugin.zsh"

check_sequence() {
  local key=$1 expected=$2

  _named_keybind_sequence "$key"
  if [[ $REPLY != $expected ]]; then
    print -u2 -- "FAIL: $key: expected ${(q)expected}, got ${(q)REPLY}"
    return 1
  fi
}

check_sequence Ctrl+P $'\x10'
check_sequence Ctrl+A $'\x01'
check_sequence Ctrl+Z $'\x1a'
check_sequence Alt+C  $'\ec'

print -- "ok"
