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
    Ctrl+Space|Ctrl+@)
      REPLY=$'\\x00'
      return
      ;;
    Ctrl+?)
      char=${key#Ctrl+}
      local -i char_code=#char
      if (( char_code >= 97 && char_code <= 122 )); then
        char=${(U)char}
        char_code=#char
      fi
      if (( char_code >= 64 && char_code <= 95 )); then
        print -v REPLY -b -- "\\C-$char"
      elif [[ $char == '?' ]]; then
        REPLY=$'\\x7f'
      else
        print -u2 -- "keybind: unsupported control key: $key"
        return 1
      fi
      return
      ;;
    Alt+Space)
      REPLY=$'\\e '
      return
      ;;
    Alt+?)
      REPLY=$'\\e'${key#Alt+}
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

  (( $# >= 2 )) || {
    print -u2 -- 'usage: keybind <widget> <key> [<key> ...]'
    return 2
  }

  local widget=$1 key sequence
  shift

  for key in "$@"; do
    _named_keybind_sequence "$key" || return
    sequence=$REPLY
    builtin bindkey -- "$sequence" "$widget" || return

    # Match zsh4humans' convenient named-key semantics: an uppercase
    # Alt+letter name binds both shifted and unshifted variants.
    if [[ $key == Alt+[A-Z] ]]; then
      _named_keybind_sequence "Alt+${(L)key[-1]}" || return
      builtin bindkey -- "$REPLY" "$widget" || return
    fi
  done
}
