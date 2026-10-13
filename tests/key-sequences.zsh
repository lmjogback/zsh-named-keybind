#!/usr/bin/env zsh

set -eu

source "${0:A:h}/../zsh-named-keybind.plugin.zsh"

# Start from the emacs keymap regardless of $EDITOR/$VISUAL.
bindkey -e

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
  local widget=$1 key=$2 normalized
  (( ++tests ))
  keybind "$widget" "$key"
  if _named_keybind_normalize_name "$key"; then
    normalized=$REPLY
  else
    normalized=$key
  fi
  _named_keybind_sequences "$normalized"
  local actual=$(bindkey "$reply[1]")
  [[ $actual == *" $widget" ]] || {
    print -u2 -- "FAIL: binding $key: expected $widget, got $actual"
    return 1
  }
}

# Basic keys.
check_sequence Tab    $'\t'
check_sequence Enter  $'\r'
check_sequence Escape $'\e'
check_sequence Space  ' '
check_binding backward-char Tab
check_binding backward-char Enter
check_binding backward-char Escape
check_binding magic-space space

# Classic control characters.
check_sequence Ctrl+Space $'\0'
check_sequence Ctrl+@     $'\0'
check_sequence Ctrl+A     $'\x01'
check_sequence Ctrl+p     $'\x10'
check_sequence Ctrl+Z     $'\x1a'
check_sequence 'Ctrl+['   $'\x1b'
check_sequence 'Ctrl+\'   $'\x1c'
check_sequence 'Ctrl+]'   $'\x1d'
check_sequence 'Ctrl+^'   $'\x1e'
check_sequence 'Ctrl+_'   $'\x1f'
check_sequence 'Ctrl+?'   $'\x7f'

# Meta characters.
check_sequence Alt+Space $'\e '
check_sequence Alt+c     $'\ec'

# Named keys resolved through terminfo. Terminals such as vt100 lack some
# of them: cursor keys and Home/End then fall back to their CSI and SS3
# forms, while other keys are rejected.
check_terminfo_key() {
  local key=$1 capability=$2 final=${_named_keybind_csi_final[$1]-}
  if (( ${+terminfo[$capability]} )); then
    check_sequence "$key" "$terminfo[$capability]"
    return
  fi
  (( ++tests ))
  if [[ -n $final ]]; then
    _named_keybind_sequences "$key"
    [[ "$reply[*]" == $'\e['$final' '$'\eO'$final ]] || {
      print -u2 -- "FAIL: $key without $capability: got ${(qqqq)reply}"
      return 1
    }
  elif _named_keybind_sequences "$key" 2>/dev/null; then
    print -u2 -- "FAIL: $key without $capability must be rejected"
    return 1
  fi
}

for key capability in ${(kv)_named_keybind_terminfo}; do
  check_terminfo_key "$key" "$capability"
done

# Modified cursor/navigation keys use the xterm CSI modifier convention.
check_sequence Shift+Up            $'\e[1;2A'
check_sequence Alt+Left            $'\e[1;3D'
check_sequence Alt+Shift+Right     $'\e[1;4C'
check_sequence Ctrl+Down           $'\e[1;5B'
check_sequence Ctrl+Shift+Home     $'\e[1;6H'
check_sequence Ctrl+Alt+End        $'\e[1;7F'
check_sequence Ctrl+Alt+Shift+Up   $'\e[1;8A'
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
check_binding history-substring-search-up Ctrl+p
check_binding backward-char 'Ctrl+['
check_binding backward-char 'Ctrl+\'
check_binding backward-char 'Ctrl+]'
check_binding backward-char 'Ctrl+^'
check_binding backward-char 'Ctrl+_'
check_binding backward-char 'Ctrl+?'
check_binding copy-prev-shell-word Alt+C

# v1 printable names are case-insensitive and canonicalized to lowercase.
(( ++tests ))
_named_keybind_normalize_name Alt+C
[[ $REPLY == Alt+c ]] || { print -u2 -- "FAIL: normalize Alt+C: $REPLY"; return 1; }

(( ++tests ))
_named_keybind_normalize_name ALT+c
[[ $REPLY == Alt+c ]] || { print -u2 -- "FAIL: normalize ALT+c: $REPLY"; return 1; }

(( ++tests ))
_named_keybind_normalize_name Ctrl+P
[[ $REPLY == Ctrl+p ]] || { print -u2 -- "FAIL: normalize Ctrl+P: $REPLY"; return 1; }

(( ++tests ))
_named_keybind_normalize_name CTRL+p
[[ $REPLY == Ctrl+p ]] || { print -u2 -- "FAIL: normalize CTRL+p: $REPLY"; return 1; }

# Shifted printable chords require an extended keyboard protocol and are v2.
(( ++tests ))
if _named_keybind_normalize_name Ctrl+Shift+p; then
  print -u2 -- "FAIL: Ctrl+Shift+p must be unsupported in v1"
  return 1
fi

(( ++tests ))
if _named_keybind_normalize_name Alt+Shift+c; then
  print -u2 -- "FAIL: Alt+Shift+c must be unsupported in v1"
  return 1
fi

# Query interface.
(( ++tests ))
[[ $(keybind ctrl-p) == 'Ctrl+p -> history-substring-search-up' ]] || {
  print -u2 -- "FAIL: key query: $(keybind ctrl-p)"
  return 1
}

(( ++tests ))
[[ $(keybind history-substring-search-up) == *'Ctrl+p'* ]] || {
  print -u2 -- "FAIL: widget query: $(keybind history-substring-search-up)"
  return 1
}

(( ++tests ))
[[ $(keybind -l) == *'Ctrl+p -> history-substring-search-up'* ]] || {
  print -u2 -- 'FAIL: binding list missing Ctrl+p'
  return 1
}

# Aliases are shown with their canonical name only.
keybind backward-char Ctrl+Space

(( ++tests ))
nul_query=$(keybind backward-char)
[[ $nul_query == *'Ctrl+Space'* && $nul_query != *'Ctrl+@'* ]] || {
  print -u2 -- "FAIL: expected Ctrl+Space but not Ctrl+@: $nul_query"
  return 1
}

(( ++tests ))
if keybind definitely-not-a-widget >/dev/null 2>&1; then
  print -u2 -- 'FAIL: unknown widget query must return non-zero'
  return 1
fi

(( ++tests ))
if keybind backward-char Ctrl+Shift+p >/dev/null 2>&1; then
  print -u2 -- 'FAIL: unsupported v2 key must return non-zero'
  return 1
fi

# Ctrl+\ is a single backslash on input and output.
(( ++tests ))
_named_keybind_normalize_name 'ctrl-\'
[[ $REPLY == 'Ctrl+\' ]] || { print -u2 -- "FAIL: normalize ctrl-\\: $REPLY"; return 1; }

(( ++tests ))
[[ $(keybind 'Ctrl+\') == 'Ctrl+\ -> backward-char' ]] || {
  print -u2 -- "FAIL: Ctrl+\\ query: $(keybind 'Ctrl+\')"
  return 1
}

# Cursor keys and Home/End are bound in terminfo, CSI, and SS3 forms.
check_all_forms() {
  local widget=$1 key=$2 final=$3 sequence actual
  keybind "$widget" "$key"
  for sequence in ${terminfo[${_named_keybind_terminfo[$key]}]-} $'\e['$final $'\eO'$final; do
    (( ++tests ))
    actual=$(bindkey "$sequence")
    [[ $actual == *" $widget" ]] || {
      print -u2 -- "FAIL: $key form ${(qqqq)sequence}: expected $widget, got $actual"
      return 1
    }
  done
}
check_all_forms up-line-or-history   Up    A
check_all_forms down-line-or-history Down  B
check_all_forms forward-char         Right C
check_all_forms backward-char        Left  D
check_all_forms beginning-of-line    Home  H
check_all_forms end-of-line          End   F

# Without terminfo entries, the CSI and SS3 forms are still bound.
(( ++tests ))
dumb_output=$(TERM=dumb zsh -f -c '
  source "$1"
  keybind beginning-of-line Home || exit 1
  bindkey $'"'"'\e[H'"'"'; bindkey $'"'"'\eOH'"'"'
' zsh "${0:A:h}/../zsh-named-keybind.plugin.zsh" 2>&1)
[[ $dumb_output == $'"^[[H" beginning-of-line\n"^[OH" beginning-of-line' ]] || {
  print -u2 -- "FAIL: Home without terminfo: $dumb_output"
  return 1
}

# An invalid key binds nothing, not even the valid keys before it.
(( ++tests ))
bindkey '^G' send-break
if keybind backward-char Ctrl+g Ctrl+Shift+p >/dev/null 2>&1; then
  print -u2 -- 'FAIL: binding with an unsupported key must return non-zero'
  return 1
fi
[[ $(bindkey '^G') == *' send-break' ]] || {
  print -u2 -- "FAIL: Ctrl+g was bound despite an invalid key: $(bindkey '^G')"
  return 1
}

# The list omits keys that are not bound.
(( ++tests ))
bindkey -r '^G'
[[ $(keybind -l) != *undefined-key* ]] || {
  print -u2 -- 'FAIL: binding list contains undefined-key'
  return 1
}

# Listings and queries decode bindkey output.
check_output() {
  local description=$1 expected=$2 actual=$3
  (( ++tests ))
  [[ $actual == "$expected" ]] || {
    print -u2 -- "FAIL: $description:"
    print -u2 -- "  expected: ${(qqqq)expected}"
    print -u2 -- "  actual:   ${(qqqq)actual}"
    return 1
  }
}

# Succeeds if the output has the given line ($3 = 1) or lacks it ($3 = 0).
check_line() {
  local description=$1 line=$2 wanted=$3 output=$4
  (( ++tests ))
  (( ${${(f)output}[(Ie)$line]} ? wanted : !wanted )) || {
    print -u2 -- "FAIL: $description: line ${(qqqq)line} ${${wanted:#1}:+not }expected in:"
    print -u2 -- "$output"
    return 1
  }
}

# Lines in the output matching a pattern.
lines_matching() {
  print -r -- "${(F)${(M)${(f)2}:#${~1}}}"
}

bindkey -e
bindkey '^X^U' undo
bindkey '^Xg' list-expand
bindkey -r '^I'
bindkey '^I' expand-or-complete

listing=$(keybind -l)
check_line 'chord in list' 'Ctrl+x Ctrl+u -> undo' 1 "$listing"
check_line 'chord with printable element' 'Ctrl+x g -> list-expand' 1 "$listing"
check_line 'Tab is canonical for ^I' 'Tab -> expand-or-complete' 1 "$listing"
check_line 'no Ctrl+i alias' 'Ctrl+i -> expand-or-complete' 0 "$listing"
check_output 'no pure prefix' '' "$(lines_matching 'Ctrl+x -> *' "$listing")"

bindkey $'\e[200~' bracketed-paste
check_output 'unknown CSI sequence omitted' '' "$(lines_matching '*bracketed-paste*' "$(keybind -l)")"
check_output 'unknown CSI sequence in widget query' '' "$(keybind bracketed-paste)"

check_line 'prefix query lists chords' 'Ctrl+x Ctrl+u -> undo' 1 "$(keybind ctrl-x)"
check_output 'prefix query has only chords' '' "$(lines_matching '^Ctrl+x *' "$(keybind ctrl-x)")"

(( ++tests ))
bindkey -r '^Q'
if unbound_output=$(keybind ctrl-q); then
  print -u2 -- "FAIL: unbound key query must return non-zero"
  return 1
fi
check_output 'unbound key query prints nothing' '' "$unbound_output"

keybind up-line-or-history Up
check_output 'cursor-key forms collapse' 'Up -> up-line-or-history' "$(keybind up)"
bindkey $'\e[A' history-search-backward
check_output 'differing cursor-key forms' \
  $'Up (^[OA) -> up-line-or-history\nUp (^[[A) -> history-search-backward' \
  "$(keybind up)"
check_output 'widget query names a key once' 'history-search-backward -> Up' \
  "$(bindkey -r '\ep'; bindkey -r '\eP'; keybind history-search-backward)"

# Sequences containing characters that bindkey quotes survive the round trip.
keybind backward-char 'Alt+\' 'Alt+^'
check_output 'Alt+\ binds ESC backslash' '"^[\\\\" backward-char' "$(bindkey '\e\\')"
check_output 'Alt+^ binds ESC caret' '"^[\^" backward-char' "$(bindkey '\e\^')"
check_line 'Alt+\ round trip' 'Escape \ -> backward-char' 1 "$(keybind -l)"
check_line 'Alt+^ round trip' 'Escape ^ -> backward-char' 1 "$(keybind -l)"

# Run in a fresh shell to see the default bindings.
fresh_listing=$(zsh -f -c 'source "$1"; bindkey -e; keybind -l
  bindkey -A vicmd main; bindkey v visual-mode; print -- --vicmd--; keybind -l' \
  zsh "${0:A:h}/../zsh-named-keybind.plugin.zsh")
emacs_listing=${fresh_listing%%$'\n'--vicmd--*}
vicmd_listing=${fresh_listing#*$'\n'--vicmd--$'\n'}
check_line 'range expanded to Space' 'Space -> self-insert' 1 "$emacs_listing"
check_output 'range does not list printable keys' '' "$(lines_matching 'a -> *' "$emacs_listing")"
check_line 'vicmd printable key' 'v -> visual-mode' 1 "$vicmd_listing"

print -- "ok: $tests tests"
