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
)

_named_keybind_sequence() {
  emulate -L zsh

  local key=$1 capability char

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
    Ctrl+?)
      char=${key#Ctrl+}
      local -i code=#char
      (( code >= 64 && code <= 95 )) || (( code >= 97 && code <= 122 )) || {
        print -u2 -- "keybind: unsupported control key: $key"
        return 1
      }
      char=${(U)char}
      print -v REPLY -b -- "\\C-$char"
      ;;
    Alt+?)
      REPLY=$'\e'${key#Alt+}
      ;;
    *)
      print -u2 -- "keybind: unsupported key: $key"
      return 1
      ;;
  esac
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
  done
}
