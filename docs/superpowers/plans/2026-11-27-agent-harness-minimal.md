# agent harness の最小構成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** cache の sandbox 設定を直したうえで、repo root に walkinglabs の最小構成 4 file (`AGENTS.md`、`init.sh`、`claude-progress.md`、`feature_list.json`) を置き、03-refinement.md を更新する。

**Architecture:** 4 file はすべて repo root に置く。`init.sh` が環境の検証を、`feature_list.json` が機能単位の状態と証拠を、`claude-progress.md` が session 単位のログを担う。`AGENTS.md` はそれらへの入口と Definition of Done をまとめる。

**Tech Stack:** bash、uv、pre-commit、JSON、Markdown

**Spec:** [docs/superpowers/specs/2026-11-27-agent-harness-minimal-design.md](../specs/2026-11-27-agent-harness-minimal-design.md)

## Global Constraints

- 入口の指示書のファイル名は `AGENTS.md` にする。`CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` は作らない。
- `AGENTS.md` は 80 行以内にする。
- `init.sh` の中で network を使うのは `uv sync` だけにする。agent の sandbox の中で実行できる必要がある。
- feature の `status` は `not-started`、`in-progress`、`pass`、`fail` のいずれかにする。
- 介入の種類は `permission` / `decision` / `rework` の 3 つにする。
- Markdown は pymarkdown を通す。日本語の文は一文一行で書く。
- commit message は Conventional Commits にし、末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` を付ける。

## Review Focus

- uv または pre-commit の cache directory に書き込めない場合。worktree の sandbox からは書き込み許可の外にある cache に書けず、`uv run` が `Could not acquire lock` で失敗することを確認済みである。`init.sh` は自動で切り替えず、spec の「cache の置き場所」の設定を案内して非 0 で終わる。(Task 1)
- `init.sh` を repo root 以外の directory から実行した場合も、repo root で動く。(Task 1)
- `tests/` が無い、または test file が 0 件の場合は、pytest を skip して exit 0 で終わる。(Task 1)
- pre-commit が file を書き換えて失敗した場合は、`init.sh` も非 0 で終わる。`set -e` に任せ、成功扱いにしない。(Task 1)
- agent が `CLAUDE.md` を作ってしまい、`AGENTS.md` が読まれなくなる。`AGENTS.md` の明記で防ぎ、最後に `ls` で不在を確認する。(Task 3)

---

### Task 0: cache の sandbox 設定を commit する

**Files:**

- Create: `.claude/settings.json` (保護された path なので本人が作る。agent は中身の確認と commit だけ行う)

- [ ] **Step 1: 中身を確認する**

Run: `cat .claude/settings.json`
Expected: `sandbox.filesystem.allowWrite` が `["~/.cache/uv", "~/.cache/pre-commit"]` である。

- [ ] **Step 2: Commit**

```bash
git add .claude/settings.json
git commit -m "chore(claude): allow sandbox writes to uv and pre-commit caches"
```

### Task 1: `init.sh`

**Files:**

- Create: `init.sh` (実行権限を付ける)

**Interfaces:**

- Produces: `bash init.sh` は、成功したら exit 0、失敗したら非 0 で終わる。Task 3 の起動手順と DoD はこの command を参照する。

- [ ] **Step 1: 現状で失敗することを確認する**

Run: `bash init.sh`
Expected: `No such file or directory`

- [ ] **Step 2: `init.sh` を実装する**

`#!/usr/bin/env bash` と `set -euo pipefail` で始め、最初に `cd "$(dirname "$0")"` で repo root に移動する。
次の 5 段を `[n/5]` 付きで表示しながら実行する。

1. cache の確認。対象は `uv cache dir` が返す path と、`${PRE_COMMIT_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/pre-commit}` の 2 つ。それぞれ `mkdir -p` と一時 file の作成・削除で書き込めるかを確かめる。書き込めなければ、その path と「`.claude/settings.json` の `sandbox.filesystem.allowWrite` に含まれているか、`settings.local.json` の `env` で別の場所に向けていないかを確認する」旨を stderr に出して `exit 1` する。
2. `uv sync --frozen`
3. `uv run --frozen pre-commit install`
4. `uv run --frozen pre-commit run --all-files`
5. pytest。`tests/` の下に `test_*.py` または `*_test.py` があるときだけ `uv run --frozen pytest` を実行し、無ければ `skip (no tests)` と表示する。

最後に `Next: read claude-progress.md (latest session) and feature_list.json` を表示する。

- [ ] **Step 3: 通ることを確認する**

Run: `chmod +x init.sh && bash init.sh; echo "exit=$?"`
Expected: 5 段がすべて表示され、`skip (no tests)` が出て、`exit=0` で終わる。
cache の設定を反映する前の session で実行する場合は、`UV_CACHE_DIR="$TMPDIR/uv" PRE_COMMIT_HOME="$TMPDIR/pre-commit" bash init.sh` で代用し、そのことを progress に記録する。

- [ ] **Step 4: 書き込めない cache と、subdirectory からの実行を確認する**

Run: `(cd docs && UV_CACHE_DIR=/nonexistent-root/uv bash ../init.sh); echo "exit=$?"`
Expected: `/nonexistent-root/uv` と案内の message が stderr に出て、`exit=1` で終わる。

- [ ] **Step 5: Commit**

```bash
git add init.sh
git commit -m "chore(harness): add init.sh for session bootstrap"
```

### Task 2: `feature_list.json` と `claude-progress.md`

**Files:**

- Create: `feature_list.json`
- Create: `claude-progress.md`

**Interfaces:**

- Produces: `feature_list.json` の key は次のとおりで、Task 3 の「feature list の規則」が参照する。
  - top-level: `project`、`description`、`features`
  - 各 feature: `id`、`name`、`description`、`spec`、`status`、`evidence`、`testedAt`
- Produces: `claude-progress.md` の entry の書式は次のとおりで、Task 3 の終了手順が参照する。
  - 見出し: `### Session N — YYYY-MM-DD`
  - 項目: Feature / Goal / What was done / Decisions / Issues / Next / Interventions

- [ ] **Step 1: `feature_list.json` を書く**

`project` は `"dozou"`、`description` は 1 文にする。
`features` には、次の 1 件だけを入れる。

- `id`: `"mf-csv-ingest"`
- `name`: `"MoneyForward CSV ingestion"`
- `description`: MoneyForward の CSV 1 ファイルを dlt で取り込む
- `status`: `"not-started"`
- `spec`、`evidence`、`testedAt`: `null`

- [ ] **Step 2: JSON として正しいことを確認する**

Run: `uv run --frozen python -c "import json; d=json.load(open('feature_list.json')); f=d['features'][0]; assert set(f)=={'id','name','description','spec','status','evidence','testedAt'} and f['status']=='not-started'; print('ok')"`
Expected: `ok`

- [ ] **Step 3: `claude-progress.md` を書く**

先頭に `# claude-progress.md` を置き、file の目的を 2〜3 文で書く。
次に、entry の書式を template として載せる。
Interventions には、種類 (`permission` / `decision` / `rework`) と内容を 1 行ずつ書き、無ければ `none` と書く。
人間が会話で修正を指示した場合も、agent が session の終わりに記録するよう注記する。
entry は新しいものを下に追記する。

- [ ] **Step 4: lint を通す**

Run: `uv run --frozen pre-commit run --files feature_list.json claude-progress.md`
Expected: すべて `Passed` または `Skipped`

- [ ] **Step 5: Commit**

```bash
git add feature_list.json claude-progress.md
git commit -m "chore(harness): add feature list and progress log"
```

### Task 3: `AGENTS.md`

**Files:**

- Create: `AGENTS.md`

**Interfaces:**

- Consumes: Task 1 の `bash init.sh`、Task 2 の key と entry の書式

- [ ] **Step 1: `AGENTS.md` を書く**

節は spec の「`AGENTS.md`」の項のとおり、次の順に並べる。

1. 起動手順
2. プロジェクト構成
3. 作業の進め方
4. Definition of Done
5. 終了手順
6. feature list の規則

あわせて、次の 2 点を守る。

- 冒頭で、`CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` を作らないことと、その理由 (作ると `AGENTS.md` が読まれなくなる) を書く。
- プロジェクト構成は表にする。対象は spec が挙げる directory と file に限る。

- [ ] **Step 2: 制約を確認する**

Run: `wc -l < AGENTS.md; grep -c '^## ' AGENTS.md; ls CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md 2>&1 | grep -c 'No such file'`
Expected: 1 行目は 80 以下、2 行目は 6、3 行目は 3

- [ ] **Step 3: lint を通す**

Run: `uv run --frozen pre-commit run --files AGENTS.md`
Expected: pymarkdown が `Passed`

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "docs(harness): add AGENTS.md as agent entry point"
```

### Task 4: 03-refinement.md の更新

**Files:**

- Modify: `docs/strategies/agent-harness/03-refinement.md`

- [ ] **Step 1: 3 か所を更新する**

spec の「03-refinement.md の更新」のとおり、次の 3 か所を変える。

- 「戦略テストの記録」の「最初の構成」に、4 file を追加する。
- 「保留した解決策案」の L1 への打ち手から「JSON の feature list」の行を外し、最小構成に含めたことを書く。
- 「分からないままのこと」の「介入の記録をどこからどう取るか」に、`claude-progress.md` の Interventions から取ると書く。

あわせて、表の「最終更新日」を 2026-11-27 にする。

- [ ] **Step 2: 確認する**

Run: `grep -n 'feature_list.json\|Interventions' docs/strategies/agent-harness/03-refinement.md && uv run --frozen pre-commit run --files docs/strategies/agent-harness/03-refinement.md`
Expected: 両方の語が見つかり、pymarkdown が `Passed`

- [ ] **Step 3: Commit**

```bash
git add docs/strategies/agent-harness/03-refinement.md
git commit -m "docs(strategy): reflect minimal harness in agent harness refinement"
```

### Task 5: 全体の確認

- [ ] **Step 1: clean な状態で全体を確認する**

Run: `git status --porcelain && bash init.sh; echo "exit=$?"`
Expected: `git status` の出力が空で、`exit=0`

- [ ] **Step 2: 人間に確認を頼む**

新しい session で `/context` を開き、`AGENTS.md` が Memory files に含まれることを確認してもらう。
PR の本文に、この確認項目を書く。
