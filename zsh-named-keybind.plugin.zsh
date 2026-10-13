# zsh-named-keybind
#
# Bind ZLE widgets using readable key names.

zmodload -F zsh/terminfo p:terminfo 2>/dev/null || return 1
zmodload zsh/zleparameter 2>/dev/null || return 1
# Optional: without them, _named_keybind_capture falls back to a subshell.
zmodload -F zsh/system b:sysopen b:sysread b:sysseek 2>/dev/null
zmodload -F zsh/files b:zf_rm 2>/dev/null

# Make the _keybind completion function available. If compinit has already
# run, register it directly.
() {
  local dir=${${(%):-%x}:A:h}
  (( ${fpath[(Ie)$dir]} )) || fpath=($dir $fpath)
  if (( ${+functions[compdef]} )); then
    autoload -Uz _keybind
    compdef _keybind keybind
  fi
}

typeset -gA _named_keybind_terminfo=(
  Up        kcuu1
  Down      kcud1
  Left      kcub1
  Right     kcuf1
  Home      khome
  End       kend
  Insert    kich1
  Delete    kdch1
  PageUp    kpp
  PageDown  knp
  Backspace kbs
  F1        kf1
  F2        kf2
  F3        kf3
  F4        kf4
  F5        kf5
  F6        kf6
  F7        kf7
  F8        kf8
  F9        kf9
  F10       kf10
  F11       kf11
  F12       kf12
)

typeset -gA _named_keybind_csi_final=(
  Up    A
  Down  B
  Right C
  Left  D
  Home  H
  End   F
)

typeset -gA _named_keybind_csi_tilde=(
  Insert   2
  Delete   3
  PageUp   5
  PageDown 6
)

typeset -gA _named_keybind_modifier=(
  Shift          2
  Alt            3
  Alt+Shift      4
  Ctrl           5
  Ctrl+Shift     6
  Ctrl+Alt       7
  Ctrl+Alt+Shift 8
)

_named_keybind_sequence() {
  emulate -L zsh

  local key=$1 capability="" char="" base="" modifier="" code=""

  if [[ -n ${capability::=${_named_keybind_terminfo[$key]-}} ]]; then
    REPLY=${terminfo[$capability]-}
    [[ -n $REPLY ]] || {
      print -u2 -- "keybind: terminal has no sequence for key: $key"
      return 1
    }
    return
  fi

  case $key in
    Tab)       REPLY=$'\t'; return ;;
    Enter)     REPLY=$'\r'; return ;;
    Escape)    REPLY=$'\e'; return ;;
    # Shift+Tab (back tab) is ESC [ Z wherever terminfo has kcbt.
    Shift+Tab)
      REPLY=${terminfo[kcbt]-}
      [[ -n $REPLY ]] || REPLY=$'\e[Z'
      return
      ;;
    Space)     REPLY=' ';   return ;;

    # Classic ASCII control characters. Keep the punctuation cases
    # explicit so they cannot fall through to modified-special-key parsing.
    Ctrl+Space|Ctrl+@) REPLY=$'\0';   return ;;
    'Ctrl+[')          REPLY=$'\x1b'; return ;;
    'Ctrl+\')          REPLY=$'\x1c'; return ;;
    'Ctrl+]')          REPLY=$'\x1d'; return ;;
    'Ctrl+^')          REPLY=$'\x1e'; return ;;
    'Ctrl+_')          REPLY=$'\x1f'; return ;;
    'Ctrl+?')          REPLY=$'\x7f'; return ;;

    Ctrl+[A-Za-z])
      char=${key#Ctrl+}
      char=${(U)char}
      print -v REPLY -b -- "\\C-$char"
      return
      ;;

    Alt+Space)
      REPLY=$'\e '
      return
      ;;
    Alt+Tab)    REPLY=$'\e\t'; return ;;
    Alt+Enter)  REPLY=$'\e\r'; return ;;
    Alt+Escape) REPLY=$'\e\e'; return ;;

    # Ctrl+Alt with a classic Ctrl character: Escape followed by it.
    Ctrl+Alt+(Space|[@A-Za-z_?^]|'['|'\'|']'))
      _named_keybind_sequence "Ctrl+${key#Ctrl+Alt+}" || return
      REPLY=$'\e'$REPLY
      return
      ;;
    Alt+[\!-~])
      REPLY=$'\e'${key#Alt+}
      return
      ;;
  esac

  # Modified special keys use the xterm CSI modifier convention:
  # CSI 1 ; <modifier> <final> for cursor/Home/End keys, and
  # CSI <number> ; <modifier> ~ for Insert/Delete/PageUp/PageDown.
  for modifier in Ctrl+Alt+Shift Ctrl+Shift Ctrl+Alt Alt+Shift Shift Ctrl Alt; do
    [[ $key == $modifier+* ]] || continue
    base=${key#"$modifier+"}
    code=${_named_keybind_modifier[$modifier]}

    if [[ -n ${_named_keybind_csi_final[$base]-} ]]; then
      REPLY=$'\e['"1;${code}${_named_keybind_csi_final[$base]}"
      return
    fi
    if [[ -n ${_named_keybind_csi_tilde[$base]-} ]]; then
      REPLY=$'\e['"${_named_keybind_csi_tilde[$base]};${code}~"
      return
    fi
    if [[ $base == Backspace ]]; then
      case $modifier in
        Alt)       REPLY=$'\e\x7f' ;;
        Ctrl)      REPLY=$'\x08' ;;
        Ctrl+Alt)  REPLY=$'\e\x08' ;;
        Shift)     REPLY=$'\x7f' ;;
        Alt+Shift) REPLY=$'\e\x7f' ;;
        Ctrl+Shift) REPLY=$'\x08' ;;
        Ctrl+Alt+Shift) REPLY=$'\e\x08' ;;
      esac
      return
    fi

    print -u2 -- "keybind: unsupported modified key: $key"
    return 1
  done

  print -u2 -- "keybind: unsupported key: $key"
  return 1
}

# Unmodified cursor keys and Home/End send different sequences depending on
# whether application cursor-key mode (smkx) is active. Terminfo describes
# application mode; bind the terminfo sequence plus both CSI and SS3 forms so
# that bindings work either way. Other keys have a single sequence.
_named_keybind_sequences() {
  emulate -L zsh

  local key=$1 final=${_named_keybind_csi_final[$1]-} seq
  reply=()

  # Shift+Tab: the terminfo sequence (if any) and ESC [ Z.
  if [[ $key == Shift+Tab ]]; then
    reply=($'\e[Z')
    if [[ -n ${terminfo[kcbt]-} && $terminfo[kcbt] != $'\e[Z' ]]; then
      reply=("$terminfo[kcbt]" "$reply[@]")
    fi
    return 0
  fi

  if [[ -z $final ]]; then
    _named_keybind_sequence "$key" || return
    reply=("$REPLY")
    return
  fi

  for seq in "${terminfo[${_named_keybind_terminfo[$key]}]-}" $'\e['$final $'\eO'$final; do
    if [[ -n $seq ]] && (( ! ${reply[(Ie)$seq]} )); then
      reply+=("$seq")
    fi
  done
}

# Run a command and set REPLY to its output, with trailing newlines removed
# as in $(...). A subshell costs about half a millisecond, which adds up at
# shell startup, so the output instead goes to a temporary file. The file is
# created exclusively (it cannot be an existing file or a symlink) with mode
# 600 and close-on-exec, unlinked at once, and then used only through its
# file descriptor. If it cannot be created, fall back to a subshell.
_named_keybind_capture() {
  emulate -L zsh
  local file=${TMPDIR:-/tmp}/zsh-named-keybind.$$.$RANDOM$RANDOM fd chunk
  local -i rc=0
  REPLY=""
  if (( ! ${+builtins[sysopen]} || ! ${+builtins[zf_rm]} )) ||
     ! sysopen -r -w -o creat,excl,cloexec -m 600 -u fd -- $file 2>/dev/null; then
    REPLY=$("$@")
    return
  fi
  zf_rm -f -- $file
  {
    "$@" >&$fd || rc=$?
    sysseek -u $fd 0
    while sysread -i $fd chunk; do
      REPLY+=$chunk
    done
  } always {
    exec {fd}>&-
  }
  while [[ $REPLY == *$'\n' ]]; do
    REPLY=${REPLY%$'\n'}
  done
  return rc
}

# Run bindkey on the keymap that keybind operates on.
_named_keybind_bindkey() {
  if [[ -n ${_named_keybind_map-} ]]; then
    builtin bindkey -M "$_named_keybind_map" "$@"
  else
    builtin bindkey "$@"
  fi
}

# Set REPLY to 1 if plain printable characters are keys of their own in the
# keymap that keybind operates on, or to the empty string. They are in
# keymaps where they are commands rather than text input, such as vicmd,
# visual, and viopp; this is detected by "a" not being bound to self-insert.
_named_keybind_printable() {
  emulate -L zsh
  local binding
  _named_keybind_capture _named_keybind_bindkey -- a
  binding=$REPLY
  REPLY=""
  [[ ${binding##* } == self-insert ]] || REPLY=1
}

# bindkey interprets \ and ^ in its argument; pass them literally.
_named_keybind_quote() {
  emulate -L zsh
  REPLY=${1//\\/\\\\}
  REPLY=${REPLY//\^/\\^}
}

# Resolve a key or a whitespace-separated chord to its sequences. Sets reply
# to every combination of the elements' sequences (cursor keys have several).
# Plain printable characters are accepted after the first element, and as
# the first element when $2 is non-empty. If $2 is "auto", the keymap decides,
# which is only looked up when needed because it costs a subshell.
_named_keybind_parse() {
  emulate -L zsh
  local allow_printable=$2 element key prefix sequence
  local -a elements=(${=1}) result=('') next

  (( $#elements )) || {
    print -u2 -- 'keybind: empty key'
    return 1
  }

  for element in "$elements[@]"; do
    if _named_keybind_normalize_name "$element"; then
      _named_keybind_sequences "$REPLY" || return
    elif [[ ${#element} == 1 && $element == [[:print:]] ]] && (( #element < 128 )) &&
         { [[ -n ${result[1]} ]] || _named_keybind_allow_first "$allow_printable" }; then
      reply=("$element")
    else
      _named_keybind_sequences "$element" || return
    fi
    next=()
    for prefix in "$result[@]"; do
      for sequence in "$reply[@]"; do
        next+=("$prefix$sequence")
      done
    done
    result=("$next[@]")
  done

  reply=("$result[@]")
}

_named_keybind_allow_first() {
  [[ $1 == auto ]] || { [[ -n $1 ]]; return }
  _named_keybind_printable
  [[ -n $REPLY ]]
}

# Succeed if a sequence is unbound but begins other bindings, and set REPLY
# to one of those bindings' raw sequences.
_named_keybind_pure_prefix() {
  _named_keybind_lookup "$1"
  [[ $reply[1] == undefined-key ]] && (( reply[2] )) || return 1
  REPLY=$reply[3]
}

# Parse a line of bindkey output, such as "^X^E" edit-command-line or
# " "-"~" self-insert. Sets reply to (first sequence, last sequence of a
# range or empty, target). bindkey quotes its output for use inside double
# quotes, on top of its own escapes: remove the double-quote escaping, then
# decode with print -b.
_named_keybind_parse_line() {
  emulate -L zsh
  setopt extended_glob no_multibyte
  local first last target
  [[ $1 == (#b)\"((\\?|[^\\\"])#)\"(-\"((\\?|[^\\\"])#)\"|)\ (*) ]] || return 1
  first=$match[1] last=$match[4] target=$match[6]
  print -v first -b -- "${first//(#b)\\([\\\"\$\`])/$match[1]}"
  if [[ -n $last ]]; then
    print -v last -b -- "${last//(#b)\\([\\\"\$\`])/$match[1]}"
  fi
  reply=("$first" "$last" "$target")
}

# The canonical name of a sequence, or the raw sequence if it has none.
_named_keybind_name_of() {
  emulate -L zsh
  _named_keybind_name_table
  _named_keybind_decode "$1" "$2" || REPLY=${(V)1}
}

# Complete key names for _keybind. Inside a quoted chord, complete the
# element after the last space. Names match case-insensitively, and - matches
# +.
_named_keybind_complete_keys() {
  local expl
  local -a keys
  compset -P '* '
  _named_keybind_candidates
  keys=("$reply[@]")
  _wanted keys expl 'key name' compadd -M 'm:{a-zA-Z-}={A-Za-z+}' -a keys
}

keybind() {
  emulate -L zsh
  setopt extended_glob

  local _named_keybind_map="" mode=bind printable=""
  local -A _named_keybind_hinted=()
  local usage='usage: keybind [-M <keymap>] <widget> <key> [<key> ...]
       keybind [-M <keymap>] -r <key> [<key> ...]
       keybind [-M <keymap>] <key|widget>
       keybind [-M <keymap>] -l | -k'

  if [[ $1 == -M ]]; then
    (( $# >= 2 )) || { print -u2 -- $usage; return 2 }
    _named_keybind_map=$2
    shift 2
    [[ -n $_named_keybind_map ]] && (( $keymaps[(Ie)$_named_keybind_map] )) || {
      print -u2 -- "keybind: no such keymap: $_named_keybind_map"
      return 1
    }
  fi

  case $1 in
    -l) (( $# == 1 )) || { print -u2 -- $usage; return 2 }; mode=list ;;
    -k) (( $# == 1 )) || { print -u2 -- $usage; return 2 }; mode=identify ;;
    -r) (( $# >= 2 )) || { print -u2 -- $usage; return 2 }; mode=remove; shift ;;
    -*) print -u2 -- $usage; return 2 ;;
    *)
      (( $# )) || { print -u2 -- $usage; return 2 }
      (( $# == 1 )) && mode=query
      ;;
  esac

  if [[ $mode == (list|identify|query) ]]; then
    _named_keybind_printable
    printable=$REPLY
  fi
  case $mode in
    list)     _named_keybind_list "$printable"; return ;;
    identify) _named_keybind_identify "$printable"; return ;;
    query)
      if _named_keybind_parse "$1" "$printable" 2>/dev/null; then
        _named_keybind_query_key "$printable" "$reply[@]"
      else
        _named_keybind_query_widget "$1" "$printable"
      fi
      return
      ;;
  esac

  local widget="" key sequence example
  local -a sequences=()
  if [[ $mode == bind ]]; then
    widget=$1
    shift
  fi

  # Resolve and check every key before changing anything, so an invalid key
  # binds or removes nothing.
  for key in "$@"; do
    _named_keybind_parse "$key" auto || return
    if [[ $mode == remove ]]; then
      sequences+=("$reply[@]")
      continue
    fi
    for sequence in "$reply[@]"; do
      # Refuse to replace a pure prefix: an unbound sequence that begins other
      # bindings. This catches an unquoted chord such as Ctrl+x Ctrl+e, which
      # would otherwise bind Ctrl+x and disable the whole prefix. Only keys of
      # one or two bytes (Ctrl+x, Escape, Alt+x) are checked, as they are the
      # ones that begin chords; checking costs a subshell per sequence.
      if (( ${#sequence} <= 2 )) && _named_keybind_pure_prefix "$sequence"; then
        example=$REPLY
        _named_keybind_printable
        printable=$REPLY
        _named_keybind_name_of "$sequence" "$printable"
        key=$REPLY
        _named_keybind_name_of "$example" "$printable"
        example=$REPLY
        print -u2 -- "keybind: $key is a prefix of existing bindings (e.g. $example); quote a chord as '$key ...'"
        return 1
      fi
      sequences+=("$sequence")
    done
  done

  for sequence in "$sequences[@]"; do
    _named_keybind_quote "$sequence"
    if [[ $mode == remove ]]; then
      # Removing a key that is not bound is not an error.
      _named_keybind_bindkey -r -- "$REPLY" 2>/dev/null
    else
      _named_keybind_bindkey -- "$REPLY" "$widget" || return
    fi
  done
  return 0
}

_named_keybind_candidates() {
  emulate -L zsh
  local key modifier base code
  reply=(Tab Shift+Tab Enter Escape Space Ctrl+Space Ctrl+@)
  reply+=('Ctrl+[' 'Ctrl+\' 'Ctrl+]' 'Ctrl+^' 'Ctrl+_')
  for key in {a..z}; do reply+=("Ctrl+$key"); done
  reply+=(Alt+Space)
  for key in {a..z}; do reply+=("Alt+$key"); done
  # Alt with a digit or punctuation character. Shifted letters are outside
  # the vocabulary: Alt+A means the same as Alt+a.
  for (( code = 33; code <= 126; code++ )); do
    key=${(#)code}
    [[ $key == [[:alpha:]] ]] || reply+=("Alt+$key")
  done
  # Alt with the basic keys and Ctrl+Alt with the classic Ctrl characters,
  # in the same order as without Alt, so that Alt+Tab wins over Ctrl+Alt+i.
  reply+=(Alt+Tab Alt+Enter Alt+Escape Ctrl+Alt+Space Ctrl+Alt+@)
  reply+=('Ctrl+Alt+[' 'Ctrl+Alt+\' 'Ctrl+Alt+]' 'Ctrl+Alt+^' 'Ctrl+Alt+_')
  for key in {a..z}; do reply+=("Ctrl+Alt+$key"); done
  # Earlier names win when decoding, so Backspace is preferred over Ctrl+?
  # for ^?, while Ctrl+h is preferred over Backspace for ^H. Likewise
  # Alt+Backspace over Ctrl+Alt+?, and Ctrl+Alt+h over Ctrl+Alt+Backspace.
  reply+=(${(k)_named_keybind_terminfo} 'Ctrl+?')
  for modifier in Shift Alt Alt+Shift Ctrl Ctrl+Shift Ctrl+Alt Ctrl+Alt+Shift; do
    for base in Up Down Left Right Home End Insert Delete PageUp PageDown Backspace; do
      reply+=("$modifier+$base")
    done
  done
  reply+=('Ctrl+Alt+?')
}

_named_keybind_normalize_name() {
  emulate -L zsh
  setopt extended_glob
  local input=$1 candidate char

  # Accept - instead of + after a modifier name, as in ctrl-alt-left. Other
  # dashes are kept, so that alt-- means Alt+-.
  input=${input//(#bi)(ctrl|alt|shift)-/$match[1]+}

  # Printable Ctrl/Alt letters are case-insensitive and canonicalized to
  # lowercase; shifted printable keys require an extended keyboard protocol.
  if [[ ${(L)input} == ctrl+[a-z] && ${#input} == 6 ]]; then
    char=${(L)input[-1]}
    REPLY="Ctrl+$char"
    return 0
  fi
  if [[ ${(L)input} == alt+[a-z] && ${#input} == 5 ]]; then
    char=${(L)input[-1]}
    REPLY="Alt+$char"
    return 0
  fi

  # Candidate names do not depend on the terminal, so index them once.
  if (( ! ${+_named_keybind_lowercase} )); then
    typeset -gA _named_keybind_lowercase=()
    _named_keybind_candidates
    for candidate in "$reply[@]"; do
      _named_keybind_lowercase[${(L)candidate}]=$candidate
    done
  fi
  REPLY=${_named_keybind_lowercase[${(L)input}]-}
  [[ -n $REPLY ]]
}

# Map every sequence that a candidate name binds to its canonical name, the
# first candidate that produces it. Built once per $TERM.
_named_keybind_name_table() {
  emulate -L zsh
  setopt no_multibyte
  local candidate sequence
  # The table depends only on the candidates and terminfo.
  [[ ${_named_keybind_names_term-x} == ${TERM-} ]] && return
  typeset -g _named_keybind_names_term=${TERM-}
  typeset -gA _named_keybind_names=()
  typeset -gi _named_keybind_longest=1
  _named_keybind_candidates
  for candidate in "$reply[@]"; do
    _named_keybind_sequences "$candidate" 2>/dev/null || continue
    for sequence in "$reply[@]"; do
      [[ -n ${_named_keybind_names[$sequence]-} ]] && continue
      _named_keybind_names[$sequence]=$candidate
      if (( ${#sequence} > _named_keybind_longest )); then
        _named_keybind_longest=${#sequence}
      fi
    done
  done
}

# Decode a raw sequence into space-separated key names, from left to right,
# preferring the longest known key at each position. Plain printable
# characters are accepted as later chord elements, and as the first element
# when $2 is non-empty. Unknown control sequences (ESC [ or ESC O) cannot be
# named. Requires _named_keybind_name_table.
_named_keybind_decode() {
  emulate -L zsh
  setopt no_multibyte
  local sequence=$1 allow_printable=$2 part len
  local -a names=()

  while [[ -n $sequence ]]; do
    for (( len = ${#sequence} < _named_keybind_longest ? ${#sequence} : _named_keybind_longest; len > 0; len-- )); do
      part=${sequence[1,len]}
      [[ -n ${_named_keybind_names[$part]-} ]] && break
    done
    if (( len )); then
      # A known CSI or SS3 key matches in full. Otherwise ESC [ or ESC O
      # starts an unknown control sequence, which must not be split into
      # Escape or Alt+[ followed by characters.
      (( len <= 2 )) && [[ $sequence == $'\e'[\[O]?* ]] && return 1
      names+=(${_named_keybind_names[$part]})
    else
      part=${sequence[1]}
      [[ $part == [[:print:]] ]] && (( #part < 128 )) || return 1
      (( ${#names} )) || [[ -n $allow_printable ]] || return 1
      names+=("$part")
      len=1
    fi
    sequence=${sequence[len+1,-1]}
  done

  REPLY=${(j: :)names}
}

# Read the bindings of the keymap and decode them. Sets reply to triples of
# (name, raw sequence, widget or string). Bindings that cannot be named are
# skipped; ranges are expanded. Printable first keys are allowed if $1 is
# non-empty.
_named_keybind_entries() {
  emulate -L zsh
  setopt no_multibyte
  local printable=$1 line first last target code
  local -a entries=()

  _named_keybind_name_table
  _named_keybind_capture _named_keybind_bindkey
  for line in ${(f)REPLY}; do
    _named_keybind_parse_line "$line" || continue
    first=$reply[1] last=$reply[2] target=$reply[3]
    if [[ -n $last ]]; then
      (( ${#first} == 1 && ${#last} == 1 )) || continue
      for (( code = #first; code <= #last; code++ )); do
        _named_keybind_decode "${(#)code}" "$printable" || continue
        entries+=("$REPLY" "${(#)code}" "$target")
      done
    else
      _named_keybind_decode "$first" "$printable" || continue
      entries+=("$REPLY" "$first" "$target")
    fi
  done
  reply=("$entries[@]")
}

# Label a binding target for output. A widget that is not currently defined
# is marked, and if a function of that name exists in fpath, a hint is printed
# to stderr once per widget per keybind command (tracked in
# $_named_keybind_hinted, declared by keybind). String bindings
# (bindkey -s) are shown as printed by bindkey.
_named_keybind_label() {
  emulate -L zsh
  setopt extended_glob
  local target=$1
  local -a found
  REPLY=$target
  [[ $target == \"* || -n ${widgets[$target]-} ]] && return
  REPLY="$target (not defined)"
  [[ -n ${_named_keybind_hinted[$target]-} ]] && return
  _named_keybind_hinted[$target]=1
  found=(${^fpath}/$target(N.))
  (( $#found )) || return 0
  print -u2 -- "keybind: $target is not a widget, but a function with that name exists in fpath:"
  print -u2 -- "keybind:   autoload -Uz $target && zle -N $target"
}

# Print entries (triples) as "name -> widget". A name bound to several
# sequences, such as the cursor-key forms, is printed once if all of them
# run the same widget; otherwise each line names its raw sequence.
_named_keybind_print_entries() {
  emulate -L zsh
  local -a entries=("$@")
  local -A targets=() mixed=() printed=()
  local i name raw target

  for (( i = 1; i <= $#entries; i += 3 )); do
    name=$entries[i] target=$entries[i+2]
    if [[ -z ${targets[$name]+x} ]]; then
      targets[$name]=$target
    elif [[ ${targets[$name]} != "$target" ]]; then
      mixed[$name]=1
    fi
  done

  for (( i = 1; i <= $#entries; i += 3 )); do
    name=$entries[i] raw=$entries[i+1] target=$entries[i+2]
    _named_keybind_label "$target"
    if [[ -n ${mixed[$name]-} ]]; then
      print -r -- "$name (${(V)raw}) -> $REPLY"
    elif [[ -z ${printed[$name]-} ]]; then
      printed[$name]=1
      print -r -- "$name -> $REPLY"
    fi
  done
}

# Print the bindings of the given raw sequences (the forms of one key or
# chord). If none is bound, print the bindings that begin with one of them,
# so that querying a prefix such as Ctrl+x lists its chords.
_named_keybind_query_key() {
  emulate -L zsh
  setopt no_multibyte
  local printable=$1 i sequence
  local -a sequences=("${@[2,-1]}") matches=() prefixed=()

  _named_keybind_entries "$printable"
  for (( i = 1; i <= $#reply; i += 3 )); do
    for sequence in "$sequences[@]"; do
      if [[ $reply[i+1] == "$sequence" ]]; then
        matches+=("${(@)reply[i,i+2]}")
      elif [[ $reply[i+1] == "$sequence"?* ]]; then
        prefixed+=("${(@)reply[i,i+2]}")
      else
        continue
      fi
      break
    done
  done

  (( $#matches )) || matches=("$prefixed[@]")
  (( $#matches )) || return 1
  _named_keybind_print_entries "$matches[@]"
}

_named_keybind_query_widget() {
  emulate -L zsh
  local widget=$1 printable=$2 i
  local -a names=()

  _named_keybind_entries "$printable"
  for (( i = 1; i <= $#reply; i += 3 )); do
    [[ $reply[i+2] == "$widget" ]] || continue
    (( ${names[(Ie)$reply[i]]} )) || names+=("$reply[i]")
  done

  (( $#names )) || return 1
  _named_keybind_label "$widget"
  print -r -- "$REPLY -> ${(j:, :)names}"
}

# Read one key press, or a chord, from standard input and describe it.
# Reading follows ZLE: after a key, any bytes that arrive immediately belong
# to the same key press. While the keys read so far are a prefix of other
# bindings, wait for the next key: indefinitely if they are unbound, or up to
# $KEYTIMEOUT if they are also bound themselves. In the latter case, ZLE runs
# the shorter binding if the next key does not continue a binding, and so
# does this.
_named_keybind_identify() {
  emulate -L zsh
  local printable=$1 sequence="" next char target rc=0 timed=""
  local -F timeout=$(( ${KEYTIMEOUT:-40} / 100.0 ))
  local -a from=(-u 0)

  # On a terminal, read -k without -u reads in raw mode; otherwise read
  # standard input as is.
  if [[ -t 0 ]]; then
    from=()
    print -u2 -- 'Press a key (or a chord)...'
  fi

  read $from -sk 1 next || return 1
  while true; do
    while read $from -sk 1 -t 0.05 char; do
      next+=$char
    done
    if [[ -n $timed ]]; then
      # After waiting on a bound prefix, keep the next key only if it
      # continues a binding.
      _named_keybind_lookup "$sequence$next"
      [[ $reply[1] == undefined-key ]] && (( ! reply[2] )) && break
    fi
    sequence+=$next
    _named_keybind_lookup "$sequence"
    (( reply[2] )) || break
    if [[ $reply[1] == undefined-key ]]; then
      timed=""
      read $from -sk 1 next || break
    else
      timed=1
      read $from -sk 1 -t $timeout next || break
    fi
  done

  _named_keybind_lookup "$sequence"
  target=$reply[1]
  if [[ $target == undefined-key ]]; then
    target='(unbound)'
    rc=1
  else
    _named_keybind_label "$target"
    target=$REPLY
  fi

  _named_keybind_name_table
  if _named_keybind_decode "$sequence" "$printable"; then
    print -r -- "$REPLY (${(V)sequence}) -> $target"
  else
    print -r -- "${(V)sequence} -> $target"
    rc=1
  fi
  return rc
}

# Look up a raw sequence in the keymap. Sets reply to (target, number of
# bindings that begin with the sequence, the first of their sequences). The
# target is undefined-key if the sequence is not bound.
_named_keybind_lookup() {
  emulate -L zsh
  local quoted target=undefined-key
  local -a prefixed
  _named_keybind_quote "$1"
  quoted=$REPLY
  _named_keybind_capture _named_keybind_bindkey -- "$quoted"
  _named_keybind_parse_line "$REPLY" && target=$reply[3]
  _named_keybind_capture _named_keybind_bindkey -p -- "$quoted"
  prefixed=(${(f)REPLY})
  reply=()
  (( $#prefixed )) && _named_keybind_parse_line "$prefixed[1]"
  reply=("$target" $#prefixed "${reply[1]-}")
}

_named_keybind_list() {
  emulate -L zsh
  _named_keybind_entries "$1"
  _named_keybind_print_entries "$reply[@]"
}
