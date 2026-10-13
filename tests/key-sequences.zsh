#!/usr/bin/env zsh

set -eu

source "${0:A:h}/../zsh-named-keybind.plugin.zsh"

# Start from the emacs keymap regardless of $EDITOR/$VISUAL.
bindkey -e

# Widgets used by the tests that a plain shell does not define.
_test_widget() {}
zle -N history-substring-search-up _test_widget
zle -N edit-command-line _test_widget

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
# ESC is a pure prefix in emacs but bound in viins.
bindkey -A viins main
check_binding backward-char Escape
bindkey -A emacs main
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
# ESC is a pure prefix in emacs but bound in viins.
bindkey -A viins main
check_binding backward-char 'Ctrl+['
bindkey -A emacs main
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
check_line 'Alt+\ round trip' 'Alt+\ -> backward-char' 1 "$(keybind -l)"
check_line 'Alt+^ round trip' 'Alt+^ -> backward-char' 1 "$(keybind -l)"

# Run in a fresh shell to see the default bindings.
fresh_listing=$(zsh -f -c 'source "$1"; bindkey -e; keybind -l
  bindkey -A vicmd main; bindkey v visual-mode; print -- --vicmd--; keybind -l' \
  zsh "${0:A:h}/../zsh-named-keybind.plugin.zsh")
emacs_listing=${fresh_listing%%$'\n'--vicmd--*}
vicmd_listing=${fresh_listing#*$'\n'--vicmd--$'\n'}
check_line 'range expanded to Space' 'Space -> self-insert' 1 "$emacs_listing"
check_output 'range does not list printable keys' '' "$(lines_matching 'a -> *' "$emacs_listing")"
check_line 'vicmd printable key' 'v -> visual-mode' 1 "$vicmd_listing"

# Chords.
bindkey -e
keybind edit-command-line 'Ctrl+x Ctrl+e'
check_output 'chord binding' '"^X^E" edit-command-line' "$(bindkey '^X^E')"
check_output 'chord query' 'Ctrl+x Ctrl+e -> edit-command-line' "$(keybind 'ctrl-x  ctrl-e')"
check_output 'widget query shows chord' 'edit-command-line -> Ctrl+x Ctrl+e' "$(keybind edit-command-line)"

keybind list-expand 'Ctrl+x g'
check_output 'printable chord element' '"^Xg" list-expand' "$(bindkey '^Xg')"

keybind backward-char 'Ctrl+x Up'
check_output 'chord with cursor key, CSI form' '"^X^[[A" backward-char' "$(bindkey '^X\e[A')"
check_output 'chord with cursor key, SS3 form' '"^X^[OA" backward-char' "$(bindkey '^X\eOA')"
check_output 'chord with cursor key query' 'Ctrl+x Up -> backward-char' "$(keybind 'ctrl-x up')"

keybind forward-char 'Escape f'
check_output 'Escape x is Alt+x' 'Alt+f -> forward-char' "$(keybind 'Escape f')"

check_rejected() {
  local description=$1 expected_error=$2 output
  shift 2
  (( ++tests ))
  if output=$(keybind "$@" 2>&1); then
    print -u2 -- "FAIL: $description: keybind $* must fail"
    return 1
  fi
  [[ $output == *"$expected_error"* ]] || {
    print -u2 -- "FAIL: $description: unexpected error: $output"
    return 1
  }
}

check_rejected 'unquoted chord' 'Ctrl+x is a prefix of existing bindings' \
  edit-command-line Ctrl+x Ctrl+e
check_output 'unquoted chord binds nothing' '"^X^E" edit-command-line' "$(bindkey '^X^E')"
check_rejected 'pure prefix in chord form' 'Ctrl+x is a prefix' backward-char 'Ctrl+x'
check_rejected 'printable first element' 'unsupported key: g' backward-char 'g x'
check_rejected 'empty key' 'empty key' backward-char ' '
check_rejected 'unsupported chord element' 'unsupported key: Nope' backward-char 'Ctrl+x Nope'

# -M selects a keymap.
keybind -M vicmd edit-command-line v
check_output '-M binds in that keymap' '"v" edit-command-line' "$(bindkey -M vicmd v)"
check_output '-M query' 'v -> edit-command-line' "$(keybind -M vicmd v)"
check_line '-M list' 'v -> edit-command-line' 1 "$(keybind -M vicmd -l)"
check_output '-M does not change the current keymap' 'Ctrl+a -> beginning-of-line' "$(keybind ctrl-a)"
check_output '-M main is the current keymap' 'Ctrl+a -> beginning-of-line' "$(keybind -M main ctrl-a)"
check_rejected 'unknown keymap' 'no such keymap: nope' -M nope -l
check_rejected 'printable key outside vicmd' 'unsupported key: v' -M viins edit-command-line v
bindkey -A vicmd main
keybind edit-command-line V
bindkey -A emacs main
check_output 'printable key when main is vicmd' '"V" edit-command-line' "$(bindkey -M vicmd V)"

check_usage() {
  local description=$1
  shift
  local actual_status=0
  (( ++tests ))
  keybind "$@" >/dev/null 2>&1 || actual_status=$?
  (( actual_status == 2 )) || {
    print -u2 -- "FAIL: $description: keybind $* must return 2"
    return 1
  }
}
check_usage 'no arguments'
check_usage '-M without keymap' -M
check_usage '-M without command' -M vicmd
check_usage '-r without keys' -r
check_usage '-l with arguments' -l x
check_usage 'unknown option' -x

# -r removes bindings.
keybind backward-char 'Ctrl+x Ctrl+r' Alt+m
keybind -r 'Ctrl+x Ctrl+r' Alt+m
check_output '-r removes a chord' '"^X^R" undefined-key' "$(bindkey '^X^R')"
check_output '-r removes a key' '"^[m" undefined-key' "$(bindkey '\em')"
(( ++tests ))
keybind -r Alt+m || { print -u2 -- 'FAIL: removing an unbound key must succeed'; return 1 }
keybind up-line-or-history Up
keybind -r Up
check_output '-r removes the CSI cursor form' '"^[[A" undefined-key' "$(bindkey '\e[A')"
check_output '-r removes the SS3 cursor form' '"^[OA" undefined-key' "$(bindkey '\eOA')"
keybind backward-char Alt+m
check_rejected '-r with an invalid key' 'unsupported key: Nope' -r Alt+m Nope
check_output '-r with an invalid key removes nothing' '"^[m" backward-char' "$(bindkey '\em')"
keybind -M vicmd -r v
check_output '-M -r' '"v" undefined-key' "$(bindkey -M vicmd v)"

# -k identifies a key press read from standard input.
check_identify() {
  local description=$1 input=$2 expected=$3 expected_status=$4 output actual_status=0
  (( ++tests ))
  output=$(print -rn -- "$input" | keybind "${@[5,-1]}" -k) || actual_status=$?
  [[ $output == "$expected" && $actual_status == $expected_status ]] || {
    print -u2 -- "FAIL: -k $description: got ${(qqqq)output} (status $actual_status)"
    return 1
  }
}
keybind backward-word Ctrl+Left
keybind edit-command-line 'Ctrl+x Ctrl+e'
check_identify 'modified key' $'\e[1;5D' 'Ctrl+Left (^[[1;5D) -> backward-word' 0
check_identify 'chord' $'\x18\x05' 'Ctrl+x Ctrl+e (^X^E) -> edit-command-line' 0
check_identify 'unbound key' $'\e[1;5A' 'Ctrl+Up (^[[1;5A) -> (unbound)' 1
check_identify 'unnamed sequence' $'\e[99~' '^[[99~ -> (unbound)' 1
check_identify 'vicmd printable' 'l' 'l (l) -> vi-forward-char' 0 -M vicmd

# Undefined widgets are marked, with a hint when a function exists in fpath.
test_fpath=$(mktemp -d)
trap 'rm -rf -- "$test_fpath"' EXIT
print -r -- 'zle -M loaded' > $test_fpath/nk-test-autoloadable
fpath=($test_fpath $fpath)
keybind nk-test-autoloadable 'Ctrl+x 1'
keybind nk-test-missing 'Ctrl+x 2'
check_output 'undefined widget in key query' 'Ctrl+x 2 -> nk-test-missing (not defined)' \
  "$(keybind 'ctrl-x 2' 2>/dev/null)"
check_output 'undefined widget in widget query' 'nk-test-missing (not defined) -> Ctrl+x 2' \
  "$(keybind nk-test-missing 2>/dev/null)"
check_output 'no hint without a function' '' "$(keybind 'ctrl-x 2' 2>&1 >/dev/null)"
check_output 'hint for a function in fpath' \
  $'keybind: nk-test-autoloadable is not a widget, but a function with that name exists in fpath:\nkeybind:   autoload -Uz nk-test-autoloadable && zle -N nk-test-autoloadable' \
  "$(keybind -l 2>&1 >/dev/null)"
check_line 'undefined widget in list' 'Ctrl+x 1 -> nk-test-autoloadable (not defined)' 1 \
  "$(keybind -l 2>/dev/null)"
check_identify 'undefined widget' $'\x182' 'Ctrl+x 2 (^X2) -> nk-test-missing (not defined)' 0
zle -N nk-test-autoloadable _test_widget
check_output 'defined widget is not marked' 'Ctrl+x 1 -> nk-test-autoloadable' "$(keybind 'ctrl-x 1' 2>&1)"

# Alt with digits and punctuation.
keybind insert-last-word Alt+. 'alt-_'
check_output 'Alt+. binds ESC .' '"^[." insert-last-word' "$(bindkey '\e.')"
check_output 'Alt+. query' 'Alt+. -> insert-last-word' "$(keybind alt-.)"
check_output 'Alt+- with dash separator' '"^[-" neg-argument' "$(keybind neg-argument alt--; bindkey '\e-')"
check_rejected 'Alt+[ is a prefix of CSI keys' 'Alt+[ is a prefix' backward-char 'Alt+['
bindkey '\e[' backward-char
keybind up-line-or-history Up
check_line 'bound Alt+[ is named' 'Alt+[ -> backward-char' 1 "$(keybind -l)"
check_line 'bound Alt+[ does not swallow CSI keys' 'Up -> up-line-or-history' 1 "$(keybind -l)"
check_output 'bound Alt+[ does not swallow unknown CSI' '' \
  "$(bindkey '\e[200~' bracketed-paste; keybind bracketed-paste)"
bindkey -r '\e['

check_output 'Escape . is Alt+.' 'insert-last-word -> Alt+., Alt+_' "$(keybind insert-last-word)"
check_output 'Alt+A is Alt+a' '"^[a" accept-and-hold' "$(keybind accept-and-hold Alt+A; bindkey '\ea')"
check_line 'shifted Alt letter is not named' 'Escape A -> accept-and-hold' 1 \
  "$(bindkey '\eA' accept-and-hold; keybind -l)"
check_output 'ctrl-alt-shift-up' '"^[[1;8A" backward-char' "$(keybind backward-char ctrl-alt-shift-up; bindkey '\e[1;8A')"

# Review fixes.
bindkey -e
# A prefix query compares bytes, so Escape finds the Alt+x bindings too.
check_line 'Escape prefix query includes Alt keys' 'Alt+b -> backward-word' 1 "$(keybind Escape)"
check_line 'Escape prefix query includes cursor keys' 'Up -> up-line-or-history' 1 "$(keybind Escape)"
check_line 'Alt+[ prefix query lists CSI keys' 'Up -> up-line-or-history' 1 "$(keybind 'Alt+[')"

# Printable keys are detected by "a" not being self-insert, not by name.
check_output 'printable key in visual' '"o" exchange-point-and-mark' \
  "$(keybind -M visual exchange-point-and-mark o; bindkey -M visual o)"
bindkey -N nk-test-cmd vicmd
check_line 'printable key in a copy of vicmd' 'l -> vi-forward-char' 1 "$(keybind -M nk-test-cmd -l)"
check_rejected 'no printable key in emacs' 'unsupported key: o' -M emacs backward-char o

# -k takes the target from the parsed line, even with a quote and a space.
bindkey -M vicmd '" ' vi-add-eol
check_identify 'quote and space' '" ' '" Space (" ) -> vi-add-eol' 0 -M vicmd

# After a bound prefix times out, a key that continues no binding is not
# part of the sequence, as in ZLE.
bindkey -M viins '\ej' undefined-key
bindkey -M viins '\e' vi-cmd-mode
(( ++tests ))
identify_output=$({ print -n '\e'; sleep 0.15; print -n j } | KEYTIMEOUT=100 keybind -M viins -k) || true
[[ $identify_output == 'Escape (^[) -> vi-cmd-mode' ]] || {
  print -u2 -- "FAIL: -k bound prefix then unrelated key: got ${(qqqq)identify_output}"
  return 1
}
check_identify 'Alt+j sent at once' $'\ej' 'Alt+j (^[j) -> (unbound)' 1 -M viins
check_identify 'unbound prefix then any key' $'\x18q' 'Ctrl+x q (^Xq) -> (unbound)' 1

# Output is captured through a temporary file that is removed at once, or
# through a subshell if no file can be created.
capture_dir=$(mktemp -d)
(( ++tests ))
TMPDIR=$capture_dir keybind -l >/dev/null
TMPDIR=$capture_dir keybind backward-char Ctrl+g
captured=($capture_dir/*(DN))
rmdir -- $capture_dir
(( $#captured == 0 )) || { print -u2 -- "FAIL: temporary files left: $captured"; return 1 }
check_output 'capture falls back without a usable TMPDIR' 'Ctrl+g -> backward-char' \
  "$(TMPDIR=/nonexistent keybind ctrl-g)"
TMPDIR=/nonexistent check_rejected 'prefix check falls back without a usable TMPDIR' 'Ctrl+x is a prefix' \
  backward-char Ctrl+x

# Ctrl+Alt with classic Ctrl characters, and Alt with Tab, Enter, Escape.
check_sequence Ctrl+Alt+k      $'\e\x0b'
check_sequence Ctrl+Alt+Space  $'\e\0'
check_sequence 'Ctrl+Alt+\'    $'\e\x1c'
check_sequence 'Ctrl+Alt+?'    $'\e\x7f'
check_sequence Alt+Tab         $'\e\t'
check_sequence Alt+Enter       $'\e\r'
check_sequence Alt+Escape      $'\e\e'
(( ++tests ))
_named_keybind_normalize_name ctrl-alt-K
[[ $REPLY == Ctrl+Alt+k ]] || { print -u2 -- "FAIL: normalize ctrl-alt-K: $REPLY"; return 1 }
bindkey -e
keybind kill-region Ctrl+Alt+k
check_output 'Ctrl+Alt+k binds ESC ^K' '"^[^K" kill-region' "$(bindkey '\e^K')"
check_identify 'Ctrl+Alt+k' $'\e\x0b' 'Ctrl+Alt+k (^[^K) -> kill-region' 0
check_output 'ESC ^H is Ctrl+Alt+h' 'Ctrl+Alt+h -> backward-kill-word' \
  "$(bindkey '\e^H' backward-kill-word; keybind ctrl-alt-backspace)"
check_output 'ESC ^? is Alt+Backspace' 'Alt+Backspace -> backward-kill-word' \
  "$(bindkey '\e^?' backward-kill-word; keybind 'ctrl-alt-?')"
check_output 'ESC Tab is Alt+Tab' 'Alt+Tab -> self-insert-unmeta' \
  "$(bindkey '\e^I' self-insert-unmeta; keybind ctrl-alt-i)"
check_output 'Alt+Escape binds ESC ESC' 'Alt+Escape -> backward-char' \
  "$(keybind backward-char Alt+Escape; keybind alt-escape)"

print -- "ok: $tests tests"
