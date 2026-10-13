# zsh-named-keybind
#
# Bind ZLE widgets using readable key names.

zmodload -F zsh/terminfo p:terminfo 2>/dev/null || return 1

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
    Alt+?)
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

keybind() {
  emulate -L zsh

  if (( $# == 1 )); then
    if [[ $1 == -l ]]; then
      _named_keybind_list
      return
    fi

    local query
    if _named_keybind_normalize_name "$1"; then
      query=$REPLY
      _named_keybind_query_key "$query"
    else
      _named_keybind_query_widget "$1"
    fi
    return
  fi

  (( $# >= 2 )) || {
    print -u2 -- 'usage: keybind <widget> <key> [<key> ...] | keybind <key|widget> | keybind -l'
    return 2
  }

  local widget=$1 key sequence
  local -a sequences=()
  shift

  # Resolve every key before binding any, so an invalid key binds nothing.
  for key in "$@"; do
    _named_keybind_normalize_name "$key" && key=$REPLY
    _named_keybind_sequences "$key" || return
    sequences+=("$reply[@]")
  done

  # bindkey interprets \ and ^ in its argument; pass them literally.
  for sequence in "$sequences[@]"; do
    sequence=${sequence//\\/\\\\}
    sequence=${sequence//\^/\\^}
    builtin bindkey -- "$sequence" "$widget" || return
  done
}

_named_keybind_candidates() {
  emulate -L zsh
  local key modifier base
  reply=(Tab Enter Escape Space Ctrl+Space Ctrl+@)
  reply+=('Ctrl+[' 'Ctrl+\' 'Ctrl+]' 'Ctrl+^' 'Ctrl+_')
  for key in {a..z}; do reply+=("Ctrl+$key"); done
  reply+=(Alt+Space)
  for key in {a..z}; do reply+=("Alt+$key"); done
  # Earlier names win when decoding, so Backspace is preferred over Ctrl+?
  # for ^?, while Ctrl+h is preferred over Backspace for ^H.
  reply+=(${(k)_named_keybind_terminfo} 'Ctrl+?')
  for modifier in Shift Alt Alt+Shift Ctrl Ctrl+Shift Ctrl+Alt Ctrl+Alt+Shift; do
    for base in Up Down Left Right Home End Insert Delete PageUp PageDown Backspace; do
      reply+=("$modifier+$base")
    done
  done
}

_named_keybind_normalize_name() {
  emulate -L zsh
  local input=${1//-/+} candidate char

  # v1 is a legacy terminal-key abstraction. Printable Ctrl/Alt letters are
  # case-insensitive and canonicalized to lowercase; shifted printable chords
  # require an extended keyboard protocol and are reserved for v2.
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

  _named_keybind_candidates
  for candidate in "$reply[@]"; do
    if [[ ${(L)candidate} == ${(L)input} ]]; then
      REPLY=$candidate
      return 0
    fi
  done
  return 1
}

# Map every sequence that a candidate name binds to its canonical name, the
# first candidate that produces it.
_named_keybind_name_table() {
  emulate -L zsh
  setopt no_multibyte
  local candidate sequence
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
      [[ $part == $'\e' && $sequence == $'\e'[\[O]?* ]] && return 1
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

# Read the bindings of the current keymap and decode them. Sets reply to
# triples of (name, sequence as printed by bindkey, widget or "string").
# Bindings that cannot be named are skipped; ranges are expanded.
_named_keybind_entries() {
  emulate -L zsh
  setopt extended_glob no_multibyte
  local line first last target raw keymap printable="" code
  local -a entries=()

  keymap=${${(z)"$(builtin bindkey -lL main)"}[3]}
  [[ $keymap == vicmd ]] && printable=1

  _named_keybind_name_table
  for line in ${(f)"$(builtin bindkey)"}; do
    [[ $line == (#b)\"((\\?|[^\\\"])#)\"(-\"((\\?|[^\\\"])#)\"|)\ (*) ]] || continue
    first=$match[1] last=$match[4] target=$match[6]
    # bindkey quotes its output for use inside double quotes, on top of its
    # own escapes: remove the double-quote escaping, then decode with print -b.
    first=${first//(#b)\\([\\\"\$\`])/$match[1]}
    last=${last//(#b)\\([\\\"\$\`])/$match[1]}
    if [[ -n $last ]]; then
      print -v first -b -- "$first"
      print -v last -b -- "$last"
      (( ${#first} == 1 && ${#last} == 1 )) || continue
      for (( code = #first; code <= #last; code++ )); do
        _named_keybind_decode "${(#)code}" "$printable" || continue
        entries+=("$REPLY" "${(V)${(#)code}}" "$target")
      done
    else
      print -v raw -b -- "$first"
      _named_keybind_decode "$raw" "$printable" || continue
      entries+=("$REPLY" "$first" "$target")
    fi
  done
  reply=("$entries[@]")
}

# Print entries (triples) as "name -> widget". A name bound to several
# sequences, such as the cursor-key forms, is printed once if all of them
# run the same widget; otherwise each line names its raw sequence.
_named_keybind_print_entries() {
  emulate -L zsh
  local -a entries=("$@")
  local -A widgets=() mixed=() printed=()
  local i name raw target

  for (( i = 1; i <= $#entries; i += 3 )); do
    name=$entries[i] target=$entries[i+2]
    if [[ -z ${widgets[$name]+x} ]]; then
      widgets[$name]=$target
    elif [[ ${widgets[$name]} != "$target" ]]; then
      mixed[$name]=1
    fi
  done

  for (( i = 1; i <= $#entries; i += 3 )); do
    name=$entries[i] raw=$entries[i+1] target=$entries[i+2]
    if [[ -n ${mixed[$name]-} ]]; then
      print -r -- "$name ($raw) -> $target"
    elif [[ -z ${printed[$name]-} ]]; then
      printed[$name]=1
      print -r -- "$name -> $target"
    fi
  done
}

_named_keybind_query_key() {
  emulate -L zsh
  local name=$1 i
  local -a matches=() prefixed=()

  _named_keybind_entries
  for (( i = 1; i <= $#reply; i += 3 )); do
    if [[ $reply[i] == "$name" ]]; then
      matches+=("${(@)reply[i,i+2]}")
    elif [[ $reply[i] == "$name "* ]]; then
      prefixed+=("${(@)reply[i,i+2]}")
    fi
  done

  (( $#matches )) || matches=("$prefixed[@]")
  (( $#matches )) || return 1
  _named_keybind_print_entries "$matches[@]"
}

_named_keybind_query_widget() {
  emulate -L zsh
  local widget=$1 i
  local -a names=()

  _named_keybind_entries
  for (( i = 1; i <= $#reply; i += 3 )); do
    [[ $reply[i+2] == "$widget" ]] || continue
    (( ${names[(Ie)$reply[i]]} )) || names+=("$reply[i]")
  done

  (( $#names )) || return 1
  print -r -- "$widget -> ${(j:, :)names}"
}

_named_keybind_list() {
  emulate -L zsh
  _named_keybind_entries
  _named_keybind_print_entries "$reply[@]"
}
