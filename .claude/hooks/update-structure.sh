#!/bin/bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

git -C "$PROJECT_DIR" ls-files \
  | grep -v '^\.claude/' \
  | tree --fromfile --dirsfirst -L 5 --noreport
