# dozou 向け Claude Code security 設定 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dozou の Claude Code から認証情報を読めず、外部へ持ち出しにくい状態を project 設定で作る。

**Architecture:** `.claude/settings.json` に sandbox と deny rule を集約し、個人環境固有の rule は git 管理外の `.claude/settings.local.json` に置く。誤公開は `.gitignore`、gitleaks、GitHub push protection で防ぐ。境界の検証は、sandbox 内で実行する script で行う。

**Tech Stack:** Claude Code 2.1.330、macOS Seatbelt、bash、jq、gitleaks

**Spec:** `docs/superpowers/specs/2026-11-23-claude-code-security-design.md`

## Global Constraints

- user scope の `~/.claude/settings.json` は変更しない。
- `excludedCommands`、`allowUnixSockets`、`allowMachLookup` は設定しない。
- `mcp__*` の一括 deny は使わない。
- Bash の network 許可先は `pypi.org` と `files.pythonhosted.org` のみとする。
- 認証情報の値を読まない、表示しない。検証は存在確認と接続可否だけで行う。
- 作業 branch は `chore/claude-code-security` とする。`AGENTS.md` と `prompts.md` は commit に含めない。
- push と PR 作成は本人が行う。

## Review Focus

1. Python など、deny rule が認識しない command から `~/.ssh` を開く場合も、sandbox が拒否する。
2. repo 内に `~/.ssh` への symlink を作って読む場合も、sandbox が拒否する。
3. sandbox 内の Bash から `.git/hooks/pre-commit` を改変できない。この hook は本人の commit 時に sandbox 外で実行されるためである。
4. sandbox 内の Bash から `.git/config` を変更して `core.hooksPath` を差し替えられない。
5. DNS 問い合わせを使った持ち出しが通らない。

---

### Task 1: 誤公開の防止

**Files:**
- Create: `.gitignore`
- Create (git 管理外): `.git/hooks/pre-commit`

**Interfaces:**
- Produces: staged な secret を検出すると非 0 で終了する pre-commit hook

- [ ] **Step 1: branch を作成する**

Run: `git switch -c chore/claude-code-security`
Expected: `Switched to a new branch`

- [ ] **Step 2: 失敗する確認を行う**

Run: `git check-ignore .env .claude/settings.local.json data/raw/a.csv dozou.duckdb dozou.ducklake`
Expected: 何も出力されず exit 1

- [ ] **Step 3: `.gitignore` を作成する**

次を ignore する: `.env`、`.env.*` (`!.env.example` は除外)、`secrets/`、`.claude/settings.local.json`、`data/*` (`!data/sample/` は除外する)、`*.duckdb`、`*.duckdb.wal`、`*.ducklake`、`*.ducklake.wal`、`.venv/`、`__pycache__/`、`target/`、`logs/`、`.dlt/secrets.toml`。

- [ ] **Step 4: ignore を確認する**

Run: `git check-ignore .env .claude/settings.local.json data/raw/a.csv dozou.duckdb dozou.ducklake && ! git check-ignore data/sample/a.csv`
Expected: 5 path が出力され exit 0

- [ ] **Step 5: gitleaks と hook を導入する**

`brew install gitleaks` を実行する。`.git/hooks/pre-commit` を実行可能 file として作成し、内容は `exec gitleaks git --staged --redact --no-banner` とする。gitleaks がない場合は commit を止める。

- [ ] **Step 6: dummy secret で hook を確認する**

一時 file に gitleaks の検出対象となる架空の AWS access key 形式の文字列を書いて stage し、`git commit -m test` を実行する。
Expected: commit が失敗する。確認後に `git restore --staged` で戻し、一時 file を削除する。

- [ ] **Step 7: commit する**

```bash
git add .gitignore
git commit -m "chore: ignore local secrets and data"
```

### Task 2: sandbox と permission の設定

**Files:**
- Create: `scripts/verify-agent-sandbox.sh`
- Modify: `.claude/settings.json`
- Modify (git 管理外): `.claude/settings.local.json`

**Interfaces:**
- Consumes: Task 1 の `.gitignore` と `.git/hooks/pre-commit`
- Produces: `scripts/verify-agent-sandbox.sh`。全項目が期待どおりなら exit 0、1 つでも外れれば exit 1 で、項目ごとに `PASS: <name>` または `FAIL: <name>` を出力する

- [ ] **Step 1: 検証 script を作成する**

各 command は値を出力しないよう stdout と stderr を捨て、timeout を 10 秒とする。

| name | command | 期待 |
|---|---|---|
| `read-ssh` | `ls ~/.ssh` | 失敗 |
| `read-aws` | `ls ~/.aws` | 失敗 |
| `read-gh` | `ls ~/.config/gh` | 失敗 |
| `read-keychain` | `ls ~/Library/Keychains` | 失敗 |
| `python-read-ssh` | `python3 -c` で `os.listdir` を `~/.ssh` に実行 | 失敗 |
| `symlink-read-ssh` | 一時 directory に `~/.ssh` への symlink を作り `ls` | 失敗 |
| `net-example` | `curl -fsS https://example.com` | 失敗 |
| `net-github` | `curl -fsS https://github.com` | 失敗 |
| `git-remote` | `git ls-remote origin` | 失敗 |
| `dns-exfil` | `nslookup example.com` | 失敗 |
| `net-pypi` | `curl -fsS https://pypi.org/simple/pip/` | 成功 |
| `write-settings` | `: >> .claude/settings.json` | 失敗 |
| `write-hook` | `: >> .git/hooks/pre-commit` | 失敗 |
| `write-git-config` | `: >> .git/config` | 失敗 |
| `op-blocked` | `op` がある場合のみ `op vault list` | 失敗 (未 install なら `SKIP`) |

- [ ] **Step 2: 設定前に script が失敗することを確認する**

Run: `bash scripts/verify-agent-sandbox.sh`
Expected: `FAIL` を含み exit 1

- [ ] **Step 3: `.claude/settings.local.json` に個人環境の rule を追加する**

既存の key を保持したまま、`permissions.deny` に `mcp__gbrain` と `Read(~/.gbrain/**)` を追加する。次の step の deny rule が即時に反映されると、この file を編集できなくなるため、先に行う。

- [ ] **Step 4: `.claude/settings.json` を次の内容にする**

```json
{
  "enabledPlugins": { "superpowers@claude-plugins-official": true },
  "disableAutoMode": "disable",
  "disableClaudeAiConnectors": true,
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "allow": [
      "WebFetch(domain:code.claude.com)",
      "WebFetch(domain:duckdb.org)",
      "WebFetch(domain:ducklake.select)",
      "WebFetch(domain:docs.getdbt.com)",
      "WebFetch(domain:dlthub.com)",
      "WebFetch(domain:developer.todoist.com)"
    ],
    "deny": [
      "Read(~/.ssh/**)", "Read(~/.gnupg/**)", "Read(~/.aws/**)",
      "Read(~/.config/gh/**)", "Read(~/.config/gcloud/**)", "Read(~/.config/op/**)",
      "Read(~/.kube/**)", "Read(~/.docker/config.json)",
      "Read(~/.dbt/**)", "Read(~/.dlt/**)", "Read(~/.duckdb/**)",
      "Read(~/Library/Keychains/**)",
      "Read(~/Library/Group Containers/2BUA8C4S2C.com.1password/**)",
      "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)",
      "Edit(./.claude/settings.json)", "Edit(./.claude/settings.local.json)",
      "Edit(./.mcp.json)", "Edit(./.git/config)", "Edit(./.git/hooks/**)",
      "mcp__terminal", "mcp__Claude_Browser", "mcp__claude-in-chrome",
      "mcp__scheduled-tasks"
    ]
  },
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "autoAllowBashIfSandboxed": true,
    "network": {
      "allowedDomains": ["pypi.org", "files.pythonhosted.org"]
    },
    "credentials": {
      "envVars": [
        { "name": "GH_TOKEN", "mode": "deny" },
        { "name": "GITHUB_TOKEN", "mode": "deny" },
        { "name": "AWS_ACCESS_KEY_ID", "mode": "deny" },
        { "name": "AWS_SECRET_ACCESS_KEY", "mode": "deny" },
        { "name": "AWS_SESSION_TOKEN", "mode": "deny" }
      ]
    }
  }
}
```

- [ ] **Step 5: JSON と ignore を確認する**

Run: `jq empty .claude/settings.json .claude/settings.local.json && git check-ignore .claude/settings.local.json`
Expected: `.claude/settings.local.json` のみ出力され exit 0

- [ ] **Step 6: commit する**

```bash
git add .claude/settings.json scripts/verify-agent-sandbox.sh docs/superpowers
git commit -m "chore: add Claude Code sandbox and permission boundary"
```

### Task 3: 新しい session での受け入れ確認

設定を確実に読み込ませるため、**新しい Claude Code session** で実施する。

**Files:**
- Modify: `docs/superpowers/specs/2026-11-23-claude-code-security-design.md` (未確認の事項に結果を追記)

**Interfaces:**
- Consumes: Task 2 の `scripts/verify-agent-sandbox.sh`

- [ ] **Step 1: desktop app の新しい session で script を実行する**

Run: `bash scripts/verify-agent-sandbox.sh`
Expected: `FAIL` なしで exit 0。sandbox が効かない、または起動しない場合は作業を止め、方式 B への切り替えを本人に相談する。

- [ ] **Step 2: Bash 以外の境界を確認する**

Read tool で `~/.ssh/config`、Edit tool で `.claude/settings.json` を試し、どちらも拒否されることを確認する。tool 一覧に connector、Chrome、built-in browser、Terminal panel、gbrain の tool がないことも確認する。

- [ ] **Step 3: 本人が GitHub push protection を有効にする**

本人の terminal で実行する。

```bash
gh api -X PATCH repos/soonraah/dozou --input - <<< '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
```

Expected: response の `security_and_analysis` で 2 項目が `enabled`

- [ ] **Step 4: 結果を記録して commit する**

design doc の「未確認の事項」に、sandbox、Keychain、環境変数の確認結果を追記する。

```bash
git add docs/superpowers/specs/2026-11-23-claude-code-security-design.md
git commit -m "docs: record Claude Code security verification"
```

- [ ] **Step 5: 本人が push して PR を作成する**

agent は push できないため、本人の terminal で実行する。

```bash
git push -u origin chore/claude-code-security
```

- [ ] **Step 6: `op` の install 後に本人が再確認する**

`op` の install 後、sandbox 内で `bash scripts/verify-agent-sandbox.sh` を再実行し、`op-blocked` が `PASS` になることを確認する。
