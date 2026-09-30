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
```

Named terminal keys are resolved through terminfo, so `Up` means the terminal's actual cursor-up sequence rather than a hard-coded escape sequence.

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

Initial supported names:

- `Up`, `Down`, `Left`, `Right`
- `Home`, `End`, `Insert`, `Delete`
- `PageUp`, `PageDown`, `Backspace`
- `Tab`, `Enter`, `Escape`, `Space`
- `Ctrl+<character>`
- `Alt+<character>`

Modified special keys such as `Ctrl+Left` are intentionally not guessed. They can be added once their terminal semantics are defined explicitly.

## macOS

There is no macOS-specific Option-key translation. Configure your terminal to send Alt/Meta as an Escape-prefixed key sequence if you want `Alt+<character>` bindings.

## Inspiration

Inspired by the named key binding interface in [zsh4humans](https://github.com/romkatv/zsh4humans). This project is an independent implementation with a deliberately smaller scope.

## License

MIT.
