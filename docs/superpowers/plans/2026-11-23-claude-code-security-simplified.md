# dozou 向け Claude Code security 設定 (簡素版) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 普段の checkout と project 設定だけで、認証情報と実データを守りながら auto mode で開発できる状態にする。

**Architecture:** 既存の `.claude/settings.json` に差分を適用し、検証 script を第 3 版の守る範囲に合わせる。保護された設定は agent から編集できないため、本人が command で適用する。

**Tech Stack:** Claude Code 2.1.330、macOS Seatbelt、bash、jq、gitleaks

**Spec:** `docs/superpowers/specs/2026-11-23-claude-code-security-design.md`

**前の計画:** `2026-11-23-claude-code-security.md` の Task 1 と Task 2 は実装済みで、この計画はその続きである。

## Global Constraints

- user scope の `~/.claude/settings.json` は変更しない。
- agent は `op` を実行しない。`VERIFY_OP=1` は本人だけが使う。
- 認証情報の値を読まない、表示しない。
- 作業 branch は `chore/claude-code-security` とする。`AGENTS.md`、`prompts.md`、`.tool-versions` は commit しない。
- tracked file に `/Users/` を含む絶対 path を書かない。
- push と PR 作成は本人が行う。

## Review Focus

1. `~/dozou-data` がまだ存在しない場合、検証が誤って FAIL や PASS にならず `SKIP` になる。
2. `.git/commondir` の書き込み確認が、禁止されていない場合でも repo を壊さない。設定の適用前には検証 script を実行しない。
3. 通常の `git commit` が、追加した書き込み禁止の下でも成功する。
4. 相対 path の cache 設定で、subdirectory から実行した tool が別の場所に cache を作らない (絶対 path を local 設定に置く)。
5. auto mode の再有効化後も、deny rule が優先される。

---

### Task 1: 検証 script と設定の更新

**Files:**
- Modify: `scripts/verify-agent-sandbox.sh`
- Modify: `.gitignore`
- Modify (本人が適用): `.claude/settings.json`
- Modify (本人が適用、git 管理外): `.claude/settings.local.json`

**Interfaces:**
- Produces: `scripts/verify-agent-sandbox.sh`。全項目が期待どおりなら exit 0

- [ ] **Step 1: `.gitignore` に `.cache/` を追加する**

- [ ] **Step 2: 検証 script を第 3 版の範囲に絞る**

削除する項目: `net-example`、`net-gitlab`、`net-huggingface`、`net-bitbucket`、`net-pypi-upload`、`net-docs-site`、`write-git-dir`、`create-git-file`。

追加する項目:

| name | 判定 |
|---|---|
| `read-real-data` | `~/dozou-data` があれば `expect_denied`、なければ `SKIP` |
| `create-git-commondir` | `expect_create_denied .git/commondir` |
| `local-bind` | Python で `127.0.0.1` の port 0 に bind でき、成功すれば PASS |

- [ ] **Step 3: script と `.gitignore` を commit する**

```bash
git add .gitignore scripts/verify-agent-sandbox.sh docs/superpowers
git commit -m "chore: align sandbox checks with simplified design"
```

- [ ] **Step 4: 本人が terminal で project 設定を適用する**

```bash
jq 'del(.disableAutoMode) | .permissions.deny += ["Read(~/dozou-data/**)","Read(./.dlt/secrets.toml)","Read(./**/.env)","Read(./**/.env.*)","Edit(./.git/commondir)","Edit(./.tool-versions)","Edit(./.envrc)","Edit(./.gitleaks.toml)","Edit(./.gitleaksignore)"] | .sandbox.network.allowedDomains += ["extensions.duckdb.org"] | .sandbox.network.allowLocalBinding = true' .claude/settings.json > .claude/settings.json.new && mv .claude/settings.json.new .claude/settings.json
```

- [ ] **Step 5: 本人が terminal で local 設定を適用する**

```bash
jq --arg r "$PWD" '.env = {UV_CACHE_DIR: ($r + "/.cache/uv"), PIP_CACHE_DIR: ($r + "/.cache/pip"), XDG_CACHE_HOME: ($r + "/.cache")}' .claude/settings.local.json > .claude/settings.local.json.new && mv .claude/settings.local.json.new .claude/settings.local.json
```

- [ ] **Step 6: 検証する**

Run: `bash scripts/verify-agent-sandbox.sh`
Expected: `RESULT: all checks passed`

- [ ] **Step 7: 設定を commit する**

```bash
git add .claude/settings.json
git commit -m "chore: simplify Claude Code boundary for auto mode"
```

Expected: 通常の commit が sandbox 内で成功する。

### Task 2: 受け入れ確認

- [ ] **Step 1: 新しい session で検証する**

Run: `bash scripts/verify-agent-sandbox.sh`
Expected: `RESULT: all checks passed`。Read tool で `~/.ssh/config` が拒否される。

- [ ] **Step 2: gitleaks を確認する**

index のみに dummy secret を置いて commit し、失敗することを確認して index から外す。

- [ ] **Step 3: 本人が確認と公開を行う**

sandbox 内の `op` の拒否を確認し、GitHub push protection を有効にして branch を push する。

```bash
gh api -X PATCH repos/soonraah/dozou --input - <<< '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
```

```bash
git push -u origin chore/claude-code-security
```

- [ ] **Step 4: 最初の長時間実行で auto mode を確認する**

確認待ちで止まった操作があれば記録し、設定を調整するかを本人が判断する。
