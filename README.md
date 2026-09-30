# zsh-named-keybind

Readable, named key bindings for Zsh's line editor (ZLE).

`zsh-named-keybind` lets a Zsh configuration describe keys by name instead of embedding terminal escape sequences:

```zsh
keybind history-substring-search-up   Up Ctrl+p
keybind history-substring-search-down Down Ctrl+n
keybind copy-prev-shell-word          Alt+c
keybind backward-word                 Alt+Left Ctrl+Left
```

It also provides a small inspection interface for active bindings.

## Installation

With zinit:

```zsh
zinit light lmjogback/zsh-named-keybind
```

Or source `zsh-named-keybind.plugin.zsh` directly.

## API

### Bind keys

```text
keybind <widget> <key> [<key> ...]
```

Example:

```zsh
keybind history-substring-search-up Up Ctrl+p
```

### Query a key

```zsh
keybind ctrl-p
```

Example output:

```text
Ctrl+p -> history-substring-search-up
```

Key-name input is case-insensitive for v1 printable Ctrl/Alt keys, and `-` can be used instead of `+` on input in both bind and query modes. For example, `Ctrl+P`, `ctrl+p`, and `ctrl-p` all refer to the classic Ctrl-P control character. Canonical output uses `Ctrl+p`.

### Query a widget

```zsh
keybind history-substring-search-up
```

Example output:

```text
history-substring-search-up -> Ctrl+p, Up
```

Only bindings that can be represented by the v1 named-key vocabulary are reported by widget queries. Aliases that resolve to the same terminal sequence may both be shown, for example `Ctrl+Space` and `Ctrl+@`.

### List named bindings

```zsh
keybind -l
```

This lists active bindings for keys known to the plugin, using canonical key names:

```text
Ctrl+p -> history-substring-search-up
Up -> history-substring-search-up
Alt+c -> copy-prev-shell-word
```

It is intentionally not a replacement for raw `bindkey`: bindings outside the plugin's v1 key vocabulary are omitted. Aliases may appear as separate entries when multiple v1 names resolve to the same terminal sequence.

## v1 key-name contract

Version 1 deliberately targets traditional terminal/ZLE input. It does not implement an extended keyboard protocol such as CSI-u.

### Named terminal keys

These unmodified keys are resolved through terminfo:

```text
Up Down Left Right
Home End
Insert Delete
PageUp PageDown
Backspace
F1 ... F12
```

The plugin therefore follows the active terminal's terminfo definition instead of hard-coding the unmodified escape sequences.

For example:

```zsh
keybind some-widget F5
```

### Basic keys

```text
Tab Enter Escape Space
```

### Classic Ctrl characters

The traditional ASCII control-character mappings are supported:

```text
Ctrl+Space / Ctrl+@  -> NUL
Ctrl+a ... Ctrl+z    -> 0x01 ... 0x1a
Ctrl+[               -> 0x1b
Ctrl+\               -> 0x1c
Ctrl+]               -> 0x1d
Ctrl+^               -> 0x1e
Ctrl+_               -> 0x1f
Ctrl+?               -> 0x7f
```

Examples:

```zsh
keybind some-widget Ctrl+Space
keybind some-widget 'Ctrl+]'
```

For printable Ctrl letters, input case is ignored in v1. Thus `Ctrl+p` and `Ctrl+P` both mean the classic Ctrl-P character. Canonical output is lowercase.

### Alt characters

`Alt+Space` and `Alt+<letter>` use the traditional Escape-prefix representation:

```text
Alt+Space -> ESC Space
Alt+c     -> ESC c
```

As with Ctrl letters, letter case is ignored in v1: `Alt+C` and `Alt+c` both mean `ESC c`, and canonical output is `Alt+c`.

Your terminal must be configured to send Alt/Meta as an Escape-prefixed sequence. On macOS this is a terminal configuration choice; the plugin does not translate macOS Option-generated characters.

### Modified special keys

Cursor/navigation/editing special keys support:

```text
Shift
Alt
Alt+Shift
Ctrl
Ctrl+Shift
Ctrl+Alt
Ctrl+Alt+Shift
```

for:

```text
Up Down Left Right
Home End
Insert Delete
PageUp PageDown
Backspace
```

Cursor/Home/End and Insert/Delete/PageUp/PageDown use the conventional xterm CSI modifier encoding.

Backspace is handled separately with traditional control/meta encodings. Shift does not create a distinct Backspace sequence in v1:

```text
Shift+Backspace          = Backspace
Alt+Shift+Backspace      = Alt+Backspace
Ctrl+Shift+Backspace     = Ctrl+Backspace
Ctrl+Alt+Shift+Backspace = Ctrl+Alt+Backspace
```

Examples:

```zsh
keybind backward-word     Alt+Left Ctrl+Left
keybind forward-word      Alt+Right Ctrl+Right
keybind beginning-of-line Home Ctrl+Home
keybind end-of-line       End Ctrl+End
keybind delete-char       Delete
```

All operations use Zsh's current keymap; v1 does not provide a `-M` option for selecting another keymap. Change the active keymap with ZLE/`bindkey` facilities if needed.

Not every terminal or intermediary can distinguish every modifier combination. The terminal and tools such as tmux must pass compatible sequences through to ZLE.

## Explicitly outside v1

Shifted printable characters and printable combinations that require an extended keyboard protocol are not represented in v1. Examples include:

```text
Ctrl+Shift+p
Alt+Shift+c
Ctrl+-
```

Modern terminals can represent combinations such as these with CSI-u or related extended keyboard protocols. Support for that belongs to a future v2 so that v1 remains predictable and compatible with traditional ZLE input.

An unsupported key name produces an error and a non-zero status. A one-argument query that is not recognized as a key name is treated as a widget query; if that widget has no representable v1 bindings, the command returns status 1 without output.

## Tests

Run:

```sh
./tests/run.sh
```

The test suite runs under real Zsh and covers key-sequence generation, terminfo keys, modified special keys, classic control characters, actual ZLE bindings, v1 normalization, and the query/list interface.

GitHub Actions runs the same suite with `TERM=xterm-256color` for deterministic terminfo behavior.

## Inspiration

Inspired by the named key binding interface in [zsh4humans](https://github.com/romkatv/zsh4humans). This project is an independent implementation with a deliberately smaller and explicit v1 contract.

## License

MIT.
