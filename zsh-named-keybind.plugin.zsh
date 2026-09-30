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
    Tab)       REPLY=$'\t' ;;
    Enter)     REPLY=$'\r' ;;
    Escape)    REPLY=$'\e' ;;
    Space)     REPLY=' ' ;;

    # Classic ASCII control characters. Keep the punctuation cases
    # explicit so they cannot fall through to modified-special-key parsing.
    Ctrl+Space|Ctrl+@) REPLY='^@'; return ;;
    'Ctrl+[')          REPLY=$'\x1b'; return ;;
    'Ctrl+\\')         REPLY=$'\x1c'; return ;;
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

  local widget=$1 key sequence normalized
  shift

  for key in "$@"; do
    if _named_keybind_normalize_name "$key"; then
      normalized=$REPLY
    else
      normalized=$key
    fi
    _named_keybind_sequence "$normalized" || return
    sequence=$REPLY
    builtin bindkey -- "$sequence" "$widget" || return

  done
}

_named_keybind_candidates() {
  emulate -L zsh
  local key modifier base
  reply=(Tab Enter Escape Space Ctrl+Space Ctrl+@)
  reply+=('Ctrl+[' 'Ctrl+\\' 'Ctrl+]' 'Ctrl+^' 'Ctrl+_' 'Ctrl+?')
  for key in {a..z}; do reply+=("Ctrl+$key"); done
  reply+=(Alt+Space)
  for key in {a..z}; do reply+=("Alt+$key"); done
  reply+=(${(k)_named_keybind_terminfo})
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

_named_keybind_query_key() {
  emulate -L zsh
  local name=$1 sequence output
  _named_keybind_sequence "$name" || return
  sequence=$REPLY
  output=$(builtin bindkey "$sequence") || return
  print -r -- "$name -> ${output#* }"
}

_named_keybind_query_widget() {
  emulate -L zsh
  local widget=$1 candidate sequence output
  local -a names=()

  _named_keybind_candidates
  for candidate in "$reply[@]"; do
    _named_keybind_sequence "$candidate" 2>/dev/null || continue
    sequence=$REPLY
    output=$(builtin bindkey "$sequence") || continue
    [[ ${output##* } == "$widget" ]] || continue
    names+=("$candidate")
  done

  (( ${#names} )) || return 1
  print -r -- "$widget -> ${(j:, :)names}"
}

_named_keybind_list() {
  emulate -L zsh
  local candidate sequence output widget
  _named_keybind_candidates
  for candidate in "$reply[@]"; do
    _named_keybind_sequence "$candidate" 2>/dev/null || continue
    sequence=$REPLY
    output=$(builtin bindkey "$sequence") || continue
    widget=${output##* }
    print -r -- "$candidate -> $widget"
  done
}
