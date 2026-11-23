#!/usr/bin/env bash
# Verify the Claude Code sandbox boundary from inside a sandboxed Bash command.
# Prints only check names and results, never file contents or secret values.
# Outside the sandbox this script is expected to report FAIL.
set -u

cd "$(dirname "$0")/.." || exit 2
command -v perl >/dev/null 2>&1 || { echo "FAIL: perl is required"; exit 2; }

failures=0
link_dir="$(mktemp -d "$PWD/.verify-sandbox.XXXXXX")" || exit 2
ln -s "$HOME/.ssh" "$link_dir/ssh" || exit 2

cleanup() {
  rm -f "$link_dir/ssh"
  rmdir "$link_dir"
}
trap cleanup EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

# Passes only when the OS sandbox itself refuses the operation.
expect_denied() {
  local err
  if err="$(perl -e 'alarm shift; exec @ARGV' 10 bash -c "$2" 2>&1 >/dev/null)"; then
    fail "$1"
  elif printf '%s' "$err" | grep -q 'Operation not permitted'; then
    pass "$1"
  else
    fail "$1 (failed without a sandbox denial)"
  fi
}

# Certificate checks are off so that a proxied connection counts as reachable.
expect_unreachable() {
  if curl -ksS -o /dev/null --max-time 8 "https://$2" >/dev/null 2>&1; then
    fail "$1"
  else
    pass "$1"
  fi
}

# Probes a path that must not be creatable, and removes it if creation succeeds.
expect_create_denied() {
  if [ -e "$2" ]; then
    echo "SKIP: $1 (already exists)"
    return
  fi
  expect_denied "$1" ": > '$2'"
  if [ -f "$2" ] && [ ! -s "$2" ]; then rm -f "$2"; fi
}

expect_denied read-ssh 'ls "$HOME/.ssh"'
expect_denied read-aws 'ls "$HOME/.aws"'
expect_denied read-gh 'ls "$HOME/.config/gh"'
expect_denied read-keychain 'ls "$HOME/Library/Keychains"'

if python3 -c 'pass' >/dev/null 2>&1; then
  expect_denied python-read-ssh 'python3 -c "import os; os.listdir(os.path.expanduser(\"~/.ssh\"))"'
else
  echo "SKIP: python-read-ssh (python3 not available)"
fi

expect_denied symlink-read-ssh "ls '$link_dir/ssh/'"

if [ -e "$HOME/dozou-data" ]; then
  expect_denied read-real-data 'ls "$HOME/dozou-data"'
else
  echo "SKIP: read-real-data (~/dozou-data does not exist)"
fi

expect_unreachable net-github github.com

if perl -e 'alarm shift; exec @ARGV' 10 git ls-remote origin >/dev/null 2>&1; then
  fail git-remote
else
  pass git-remote
fi
if perl -e 'alarm shift; exec @ARGV' 10 nslookup -timeout=3 example.com >/dev/null 2>&1; then
  fail dns-exfil
else
  pass dns-exfil
fi
if curl -fsS -o /dev/null --max-time 8 https://pypi.org/simple/pip/ >/dev/null 2>&1; then
  pass net-pypi
else
  fail net-pypi
fi

if python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0))' >/dev/null 2>&1; then
  pass local-bind
else
  fail local-bind
fi

expect_denied write-settings ': >> .claude/settings.json'
expect_denied write-hook ': >> .git/hooks/pre-commit'
expect_denied write-git-config ': >> .git/config'
expect_denied write-tool-versions ': >> .tool-versions'
expect_create_denied create-git-commondir .git/commondir
expect_create_denied create-mcp .mcp.json
expect_create_denied create-gitleaks-config .gitleaks.toml
expect_create_denied create-gitleaks-ignore .gitleaksignore
expect_create_denied create-envrc .envrc

if [ -e .vscode ]; then
  echo "SKIP: create-vscode (already exists)"
else
  expect_denied create-vscode 'mkdir .vscode'
  if [ -d .vscode ]; then rmdir .vscode; fi
fi

# The agent must never run op. Only a person sets VERIFY_OP=1, inside the sandbox.
if [ "${VERIFY_OP:-0}" != "1" ]; then
  echo "SKIP: op-blocked (person-only check, set VERIFY_OP=1)"
elif command -v op >/dev/null 2>&1; then
  expect_denied op-blocked 'op vault list'
else
  echo "SKIP: op-blocked (op not installed)"
fi

if [ "$failures" -gt 0 ]; then
  echo "RESULT: $failures check(s) failed"
  exit 1
fi
echo "RESULT: all checks passed"
