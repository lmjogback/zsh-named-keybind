#!/usr/bin/env zsh

# Drive _keybind in an interactive shell on a pseudo-terminal: type a line,
# press Tab, and record the completed buffer.

set -eu
zmodload zsh/zpty

plugin=${0:A:h}/../zsh-named-keybind.plugin.zsh
out=$(mktemp)
trap 'rm -f -- "$out"; zpty -d z 2>/dev/null || true' EXIT

typeset -a inputs expected
add() { inputs+=("$1"); expected+=("$2") }

add 'keybind -M vic'                      'keybind -M vicmd '
add 'keybind backward-word ctrl-lef'      'keybind backward-word Ctrl+Left '
add 'keybind backward-word CTRL+LEF'      'keybind backward-word Ctrl+Left '
add "keybind backward-word 'Ctrl+x ctrl-lef" "keybind backward-word 'Ctrl+x Ctrl+Left' "
add 'keybind edit-command-li'             'keybind edit-command-line '
add 'keybind -r alt-backs'                'keybind -r Alt+Backspace '
add 'keybind -M vicmd -r pageu'           'keybind -M vicmd -r PageUp '
add 'keybind -l '                         'keybind -l '
add 'keybind -M'                          'keybind -M '

zpty z 'zsh -f -i'
zpty -w z "source ${(q)plugin}; autoload -Uz compinit; compinit -u -D"
zpty -w z "dump() { print -r -- \"\$BUFFER\" >> ${(q)out} }; zle -N dump; bindkey '^T' dump"
zpty -w z 'autoload -Uz edit-command-line; zle -N edit-command-line'
sleep 1

for input in "$inputs[@]"; do
  zpty -w -n z "$input"$'\t'
  sleep 0.8
  zpty -w -n z $'\C-t\C-u'
  sleep 0.3
done

typeset -a actual=("${(@f)$(<$out)}")
typeset -i i failed=0
for (( i = 1; i <= $#inputs; i++ )); do
  [[ ${actual[i]-} == "$expected[i]" ]] && continue
  print -u2 -- "FAIL: completing ${(qqqq)inputs[i]}: expected ${(qqqq)expected[i]}, got ${(qqqq)actual[i]-}"
  failed=1
done
(( ! failed )) || exit 1
print -- "ok: $#inputs completion tests"
