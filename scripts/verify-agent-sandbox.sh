#!/usr/bin/env bash
# Verify the Claude Code sandbox boundary from inside a sandboxed Bash command.
# Prints only check names and results, never file contents or secret values.
# Outside the sandbox this script is expected to report FAIL.
set -u

cd "$(dirname "$0")/.." || exit 2

failures=0
link_dir="$(mktemp -d)" || exit 2
ln -s "$HOME/.ssh" "$link_dir/ssh"

cleanup() {
  rm -f "$link_dir/ssh"
  rmdir "$link_dir"
}
trap cleanup EXIT

attempt() {
  perl -e 'alarm shift; exec @ARGV' 10 bash -c "$1" >/dev/null 2>&1
}

report() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    failures=$((failures + 1))
  fi
}

expect_blocked() {
  if attempt "$2"; then report "$1" allowed blocked; else report "$1" blocked blocked; fi
}

expect_allowed() {
  if attempt "$2"; then report "$1" allowed allowed; else report "$1" blocked allowed; fi
}

expect_blocked read-ssh 'ls "$HOME/.ssh"'
expect_blocked read-aws 'ls "$HOME/.aws"'
expect_blocked read-gh 'ls "$HOME/.config/gh"'
expect_blocked read-keychain 'ls "$HOME/Library/Keychains"'

if python3 -c 'pass' >/dev/null 2>&1; then
  expect_blocked python-read-ssh 'python3 -c "import os; os.listdir(os.path.expanduser(\"~/.ssh\"))"'
else
  echo "SKIP: python-read-ssh (python3 not available)"
fi

expect_blocked symlink-read-ssh "ls '$link_dir/ssh/'"
expect_blocked net-example 'curl -fsS --max-time 8 https://example.com'
expect_blocked net-github 'curl -fsS --max-time 8 https://github.com'
expect_blocked git-remote 'GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" git ls-remote origin'
expect_blocked dns-exfil 'nslookup -timeout=3 example.com'
expect_allowed net-pypi 'curl -fsS --max-time 8 https://pypi.org/simple/pip/'
expect_blocked write-settings ': >> .claude/settings.json'
expect_blocked write-hook ': >> .git/hooks/pre-commit'
expect_blocked write-git-config ': >> .git/config'

# The agent must never run op. Only a person sets VERIFY_OP=1, inside the sandbox.
if [ "${VERIFY_OP:-0}" != "1" ]; then
  echo "SKIP: op-blocked (person-only check, set VERIFY_OP=1)"
elif command -v op >/dev/null 2>&1; then
  expect_blocked op-blocked 'op vault list'
else
  echo "SKIP: op-blocked (op not installed)"
fi

if [ "$failures" -gt 0 ]; then
  echo "RESULT: $failures check(s) failed"
  exit 1
fi
echo "RESULT: all checks passed"
