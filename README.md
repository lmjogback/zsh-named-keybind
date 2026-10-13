# zsh-named-keybind

Readable, named key bindings for Zsh's line editor (ZLE).

`zsh-named-keybind` lets a Zsh configuration describe keys by name instead of embedding terminal escape sequences:

```zsh
keybind history-substring-search-up   Up Ctrl+p
keybind history-substring-search-down Down Ctrl+n
keybind copy-prev-shell-word          Alt+c
keybind backward-word                 Alt+Left Ctrl+Left
keybind edit-command-line             'Ctrl+x Ctrl+e'
```

It also provides a small inspection interface for active bindings.

## Installation

With zinit:

```zsh
zinit light lmjogback/zsh-named-keybind
```

Or source `zsh-named-keybind.plugin.zsh` directly.

The plugin adds its own directory to `fpath` so that the `_keybind` completion function is found. Load the plugin before running `compinit`, or let your plugin manager handle completions.

## API

```text
keybind [-M <keymap>] <widget> <key> [<key> ...]   bind keys
keybind [-M <keymap>] -r <key> [<key> ...]         remove bindings
keybind [-M <keymap>] <key>                        query a key
keybind [-M <keymap>] <widget>                     query a widget
keybind [-M <keymap>] -l                           list named bindings
keybind [-M <keymap>] -k                           identify a key press
```

Options must come before other arguments. Without `-M`, all operations use Zsh's current keymap; see [Keymaps](#keymaps).

### Bind keys

```text
keybind <widget> <key> [<key> ...]
```

Each argument after the widget is one key or one chord (see [Chords](#chords)). Example:

```zsh
keybind history-substring-search-up Up Ctrl+p
```

All arguments are validated before anything is bound. If any key is unsupported or rejected, `keybind` prints an error, binds nothing, and returns a non-zero status.

### Remove bindings

```zsh
keybind -r 'Ctrl+x Ctrl+e' Alt+c
```

This removes the bindings for the given keys or chords, using the same names and validation as binding: if any argument is unsupported, nothing is removed. Removing a cursor key removes all the sequences that binding it would create (see [Cursor-key modes](#cursor-key-modes)), including Zsh's default bindings for those sequences. Removing a key that is not bound is not an error.

Removal only affects the exact sequence. Removing `Ctrl+x` does not remove chords that begin with `Ctrl+x`.

### Query a key

```zsh
keybind ctrl-p
```

Example output:

```text
Ctrl+p -> history-substring-search-up
```

If the key is not bound but is a prefix of one or more chords, those chords are listed instead:

```zsh
keybind ctrl-x
```

```text
Ctrl+x Ctrl+e -> edit-command-line
Ctrl+x Ctrl+u -> undo
...
```

If the key is neither bound nor a prefix, `keybind` prints nothing and returns status 1.

Key-name input is case-insensitive for printable Ctrl/Alt keys, and `-` can be used instead of `+` on input in both bind and query modes. For example, `Ctrl+P`, `ctrl+p`, and `ctrl-p` all refer to the classic Ctrl-P control character. Canonical output uses `Ctrl+p`.

### Query a widget

```zsh
keybind history-substring-search-up
```

Example output:

```text
history-substring-search-up -> Ctrl+p, Up
```

A one-argument query that cannot be parsed as a key or chord is treated as a widget query. If the widget has no bindings that can be named, the command returns status 1 without output.

### List named bindings

```zsh
keybind -l
```

This lists the bindings in the current keymap, using canonical key names:

```text
Ctrl+p -> history-substring-search-up
Ctrl+x Ctrl+e -> edit-command-line
Up -> history-substring-search-up
Alt+c -> copy-prev-shell-word
```

Only keys that are actually bound are listed; `undefined-key` entries and pure prefix keys are omitted. Bindings whose sequence cannot be fully expressed with the named-key vocabulary are omitted as well, so `keybind -l` is intentionally not a replacement for raw `bindkey`.

Ranges reported by `bindkey` (such as `" "-"~" self-insert`) are expanded to the named keys they contain.

### Identify a key press

```zsh
keybind -k
```

This waits for a key press and prints its name, the raw sequence, and the widget it is bound to:

```text
$ keybind -k
Ctrl+Left (^[[1;5D) -> backward-word
```

It is meant for finding out what the terminal (and tmux, if used) actually sends. Reading continues while the keys read so far are a prefix of bindings in the keymap, as ZLE does, so a chord is reported as a whole:

```text
$ keybind -k
Ctrl+x Ctrl+e (^X^E) -> edit-command-line
```

Each key in a chord must arrive within `$KEYTIMEOUT`, as in ZLE; the first key has no timeout.

If the sequence can be named but is not bound, the output ends in `-> (unbound)` and the status is 1. If the sequence cannot be named, only the raw sequence is printed, followed by `-> <widget>` if bound, and the status is 1.

`keybind -k` runs outside ZLE, where configurations that enable application cursor-key mode only for ZLE have already switched it off again. Both cursor-key modes decode to the same names, so this does not change the output.

### How listing and queries work

Queries and listings read the current keymap's bindings from `bindkey` and decode each bound sequence into key names, from left to right. A sequence that decodes to several keys is shown as a chord. Each sequence is shown with exactly one canonical name; see [Canonical names](#canonical-names).

At each position the longest known key wins, so `ESC c` is `Alt+c` rather than `Escape c`. Plain printable characters are accepted as later elements of a chord, as in `Ctrl+x g` or `Escape .`. An unknown control sequence starting with `ESC [` or `ESC O`, such as `ESC [ 200 ~` for bracketed paste, cannot be named and is omitted rather than shown as `Escape [ 2 0 0 ~`.

### Undefined widgets

`bindkey`, and therefore `keybind`, accepts a widget name that is not defined yet, because widgets are often defined after the line that binds them, for example by a plugin loaded later. `keybind` therefore does not check widgets when binding.

Inspection does check them. `-l`, key queries, widget queries, and `-k` mark a binding whose widget is not currently defined:

```text
Ctrl+x Ctrl+e -> edit-command-line (not defined)
```

A widget query for an undefined widget marks the widget instead:

```text
edit-command-line (not defined) -> Ctrl+x Ctrl+e
```

If a function with the widget's name exists in `fpath`, a hint is also printed to standard error, once per widget per command:

```text
keybind: edit-command-line is not a widget, but a function with that name exists in fpath:
keybind:   autoload -Uz edit-command-line && zle -N edit-command-line
```

The marker and the hint do not change the exit status. Only widgets in bindings that the plugin can name are checked.

### Completion

The `_keybind` completion function completes:

- options, and keymap names after `-M`;
- widget names (from `zle -la`) in the widget position;
- key names in key positions, case-preserving as typed, with `-` or `+` as the separator;
- further chord elements after a space inside a quoted chord argument;
- for queries, both key names and widget names.

## Key-name contract

The plugin targets traditional terminal/ZLE input. It does not implement an extended keyboard protocol such as CSI-u.

### Named terminal keys

```text
Up Down Left Right
Home End
Insert Delete
PageUp PageDown
Backspace
F1 ... F12
```

These unmodified keys are resolved through terminfo, so the plugin follows the active terminal's terminfo definition instead of hard-coding the sequences.

Cursor keys and Home/End are additionally bound in both cursor-key modes; see [Cursor-key modes](#cursor-key-modes).

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
keybind some-widget 'Ctrl+\'
```

For printable Ctrl letters, input case is ignored. Thus `Ctrl+p` and `Ctrl+P` both mean the classic Ctrl-P character. Canonical output is lowercase.

### Alt characters

`Alt+Space` and `Alt+<letter>` use the traditional Escape-prefix representation:

```text
Alt+Space -> ESC Space
Alt+c     -> ESC c
```

As with Ctrl letters, letter case is ignored: `Alt+C` and `Alt+c` both mean `ESC c`, and canonical output is `Alt+c`.

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

Cursor/Home/End and Insert/Delete/PageUp/PageDown use the conventional xterm CSI modifier encoding. These sequences are the same in both cursor-key modes.

Backspace is handled separately with traditional control/meta encodings. Shift does not create a distinct Backspace sequence:

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

### Cursor-key modes

Terminals send different sequences for unmodified cursor keys depending on whether application cursor-key mode (DECCKM, usually enabled with terminfo `smkx`) is active:

```text
Key    Normal mode   Application mode
Up     ESC [ A       ESC O A
Down   ESC [ B       ESC O B
Right  ESC [ C       ESC O C
Left   ESC [ D       ESC O D
Home   ESC [ H       ESC O H
End    ESC [ F       ESC O F
```

Terminfo describes the keys as sent in application mode. Many configurations enable that mode while ZLE is active:

```zsh
function _keypad-xmit  { echoti smkx }
function _keypad-local { echoti rmkx }
zle -N _keypad-xmit
zle -N _keypad-local
add-zle-hook-widget line-init   _keypad-xmit
add-zle-hook-widget line-finish _keypad-local
```

Others do not. So that bindings work in either setup, binding `Up`, `Down`, `Left`, `Right`, `Home`, or `End` binds:

1. the terminfo sequence,
2. the normal-mode sequence, and
3. the application-mode sequence.

Duplicates are bound once. All of these sequences decode to the same name in queries and listings. If they are bound to different widgets, each sequence is listed separately with the raw sequence appended, for example:

```text
Up (^[OA) -> up-line-or-history
Up (^[[A) -> history-substring-search-up
```

Other unmodified named keys (Insert, Delete, PageUp, PageDown, Backspace, F1–F12) are bound using terminfo only.

### Chords

A chord is a sequence of keys pressed one after another, such as Emacs-style `Ctrl+x Ctrl+e`. Write it as one argument with the keys separated by whitespace:

```zsh
keybind edit-command-line 'Ctrl+x Ctrl+e'
keybind some-widget       'Ctrl+x g'
```

Each element must be a valid key name from this contract. Plain printable characters are allowed as elements after the first key. Canonical output separates the elements with a single space.

The quotes matter: without them, `Ctrl+x` and `Ctrl+e` are two separate keys to bind. To catch that mistake, `keybind` refuses to bind a key or chord that is currently a pure prefix, that is, one that is unbound itself but begins other bindings in the current keymap:

```text
keybind: Ctrl+x is a prefix of existing bindings (e.g. Ctrl+x Ctrl+u); quote a chord as 'Ctrl+x ...'
```

Use `bindkey` directly if you really want to replace a prefix.

When a key is bound on its own and also begins a chord, ZLE waits up to `$KEYTIMEOUT` (hundredths of a second) for the next key before running the shorter binding.

`Escape x` and `Alt+x` are the same byte sequence. Both are accepted on input; output uses `Alt+x`.

### Canonical names

Some names resolve to the same sequence. Queries and listings use one canonical name per sequence:

```text
Sequence   Canonical      Also accepted on input
^@         Ctrl+Space     Ctrl+@
^I         Tab            Ctrl+i
^M         Enter          Ctrl+m
^[         Escape         Ctrl+[
^?         Backspace      Ctrl+?           (when terminfo kbs is ^?)
^H         Ctrl+h         Ctrl+Backspace, Ctrl+Shift+Backspace
^[^?       Alt+Backspace  Alt+Shift+Backspace
^[ x       Alt+x          Escape x
```

### Keymaps

Without `-M`, all operations use Zsh's current keymap. With `-M <keymap>`, they use the named keymap, as with `bindkey -M`:

```zsh
keybind -M viins edit-command-line 'Ctrl+x Ctrl+e'
keybind -M vicmd edit-command-line v
keybind -M vicmd -l
```

An unknown keymap produces an error and a non-zero status. In the `vicmd` keymap, plain printable characters are also accepted as single keys, since they are commands there rather than text input.

## Terminal compatibility

Not every terminal or intermediary can distinguish every modifier combination. The terminal and tools such as tmux must pass compatible sequences through to ZLE.

## Changes from v1

- Chords are supported in binding, queries, and listings.
- `Up`, `Down`, `Left`, `Right`, `Home`, and `End` bind both cursor-key modes in addition to terminfo.
- `keybind -l` lists only keys that are actually bound, and shows each sequence once with its canonical name.
- Querying an unbound key returns status 1 without output instead of printing `undefined-key`; querying a prefix lists its chords.
- `keybind` validates all keys before binding any, and refuses to replace a pure prefix key.
- New `-k` identifies a key press, `-r` removes bindings, and `-M` selects a keymap.
- A `_keybind` completion function is included.
- Inspection marks bindings to undefined widgets and suggests `autoload`/`zle -N` when a matching function exists in `fpath`.
- `Ctrl+\` is printed and accepted correctly (v1 used a doubled backslash).

## Outside v2

- Numeric keypad keys (`KP_Enter`, `KP_0`, …). Their sequences depend on keypad mode (DECKPAM), NumLock, and terminal settings, and terminfo coverage is incomplete (for example, `tmux-256color` has no `kent`).
- Shifted printable characters and printable combinations that require an extended keyboard protocol, such as `Ctrl+Shift+p`, `Alt+Shift+c`, or `Ctrl+-`. Modern terminals can represent these with CSI-u or related protocols.
- An opt-in startup warning for bindings to undefined widgets (for example, checked once at the first `zle-line-init`). Inspection already marks them; a startup check would give false alarms with deferred plugin loading such as zinit turbo mode.
- Exporting bindings as `keybind` commands.

An unsupported key name produces an error and a non-zero status.

## Tests

Run:

```sh
./tests/run.sh
```

The test suite runs under real Zsh and covers key-sequence generation, terminfo keys, modified special keys, classic control characters, actual ZLE bindings, normalization, and the query/list interface.

GitHub Actions runs the same suite under several `TERM` values, from `xterm-256color` and `tmux-256color` to older entries such as `screen` and `linux`, and minimal ones such as `vt100` and `dumb` that lack some terminfo keys.

## Inspiration

Inspired by the named key binding interface in [zsh4humans](https://github.com/romkatv/zsh4humans). This project is an independent implementation with a deliberately small and explicit contract.

## License

MIT.
