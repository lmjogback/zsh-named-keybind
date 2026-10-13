#!/bin/sh
set -eu
dir=$(dirname "$0")
zsh "$dir/key-sequences.zsh"
zsh "$dir/completion.zsh"
