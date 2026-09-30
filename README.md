# zsh-named-keybind

Readable, named key bindings for Zsh's line editor.

Instead of embedding terminal escape sequences in `.zshrc`:

```zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[c' copy-prev-shell-word
```

write the intent directly:

```zsh
keybind history-substring-search-up Up Ctrl+P
keybind history-substring-search-down Down Ctrl+N
keybind copy-prev-shell-word Alt+C
keybind backward-word Alt+Left Ctrl+Left
```

Unmodified terminal keys are resolved through terminfo. Modified navigation and editing keys use the widely implemented xterm CSI modifier convention.

## Installation

With zinit:

```zsh
zinit light lmjogback/zsh-named-keybind
```

Or source `zsh-named-keybind.plugin.zsh` directly.

## Usage

```text
keybind <widget> <key> [<key> ...]
```

Supported base key names:

- `Up`, `Down`, `Left`, `Right`
- `Home`, `End`, `Insert`, `Delete`
- `PageUp`, `PageDown`, `Backspace`
- `Tab`, `Enter`, `Escape`, `Space`
- `Ctrl+<character>`
- `Alt+<character>`

The navigation/editing keys support these modifiers:

- `Shift`
- `Alt`
- `Alt+Shift`
- `Ctrl`
- `Ctrl+Shift`
- `Ctrl+Alt`
- `Ctrl+Alt+Shift`

Examples:

```zsh
keybind backward-word Alt+Left Ctrl+Left
keybind forward-word  Alt+Right Ctrl+Right
keybind beginning-of-line Home Ctrl+Home
keybind end-of-line End Ctrl+End
keybind delete-char Delete
```

Not every terminal can distinguish every modifier combination. The plugin maps modified special keys using the xterm CSI convention; the terminal and any intermediary such as tmux must emit compatible sequences.

## macOS

There is no macOS-specific Option-key translation. Configure your terminal to send Alt/Meta as an Escape-prefixed key sequence if you want `Alt+<character>` bindings. This also keeps the plugin independent of which physical Option key is configured as Alt.

## Tests

Run the test suite with:

```sh
./tests/run.sh
```

The tests execute under real Zsh and verify both byte-exact key sequences and installed ZLE bindings.

## Inspiration

Inspired by the named key binding interface in [zsh4humans](https://github.com/romkatv/zsh4humans). This project is an independent implementation with a deliberately smaller scope.

## License

MIT.
