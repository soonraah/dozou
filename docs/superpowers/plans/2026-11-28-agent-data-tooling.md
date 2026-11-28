# dlt と DuckDB 向けの agent tooling Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dlt-mcp` を project の MCP server として登録し、`llms.txt` を docs の入口として AGENTS.md に書き、duckdb-skills を使える状態にする。

**Architecture:** `dlt-mcp` は `pyproject.toml` の `dev` group に入れ、`uv.lock` で固定した version を `.mcp.json` から `uv run --frozen` で起動する。duckdb-skills は人間が claude.ai から導入し、repo には設定を残さない。

**Tech Stack:** uv、dlt-mcp、DuckDB、JSON、TOML、Markdown

**Spec:** [docs/superpowers/specs/2026-11-27-agent-data-tooling-design.md](../specs/2026-11-27-agent-data-tooling-design.md)

## Global Constraints

- `dlt[hub]`、`dlthub`、AI workbench の file は入れない。
- `CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` は作らない。
- `.claude/settings.json` は sandbox で保護された path なので、agent は編集しない。変更の内容を示し、人間が編集する。
- MoneyForward の実データは読まない。sample CSV は repo の外に置く。
- commit message は Conventional Commits にし、末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` を付ける。

## Review Focus

- `search_docs` は `lancedb` と `chonkie` の version に敏感で、最新の version では失敗する。固定が `uv.lock` に入っていることを `uv tree` で確かめる。(Task 1)
- MCP server を `--frozen` なしで起動すると、lock から外れた version で動くおそれがある。(Task 2)
- 新しい session でしか確かめられない完了基準がある (MCP の接続、plugin の skill)。この session では pass にしない。(Task 5)

---

### Task 1: 依存関係

**Files:**

- Modify: `pyproject.toml`、`uv.lock`

- [ ] `uv add --dev "dlt-mcp[search]>=0.3.0,<0.4" "lancedb>=0.25.3,<0.26" "chonkie[code,model2vec]==1.4.2"` を実行する。
- [ ] `pyproject.toml` の `lancedb` と `chonkie` の行に、`search_docs` のために固定している旨の comment を付ける。
- [ ] `uv tree --frozen | grep -c dlthub` が 0 であることを確かめる。

### Task 2: MCP server の登録

**Files:**

- Create: `.mcp.json`
- Modify: `.claude/settings.json` (人間が編集する)

- [ ] spec のとおりに `.mcp.json` を書き、`python -m json.tool .mcp.json` を通す。
- [ ] stdio で server を起動し、`list_pipelines` と `search_docs` を呼ぶ probe を scratchpad で実行する。
- [ ] 人間に `.claude/settings.json` へ `"enabledMcpjsonServers": ["dlt"]` を足してもらう。

### Task 3: telemetry の停止

**Files:**

- Create: `.dlt/config.toml`

- [ ] `[runtime]` に `dlthub_telemetry = false` を書く。

### Task 4: AGENTS.md

**Files:**

- Modify: `AGENTS.md`

- [ ] プロジェクト構成の表に `.mcp.json` と `.dlt/` を足す。
- [ ] 「作業の進め方」に、dlt の docs は `search_docs` を先に使い、足りなければ `llms.txt` から読むことを書く。
- [ ] `bash init.sh` を通し、commit する。

### Task 5: 検証と記録

- [ ] この session で確かめられる完了基準 (1、2、5) を実行し、結果を記録する。
- [ ] 人間に duckdb-skills の導入と DuckDB の CLI の導入を依頼する。
- [ ] 新しい session で完了基準 3 と 4 を確かめる。すべて満たしたら `feature_list.json` を `pass` にする。
- [ ] `claude-progress.md` に session の entry を書き、push して PR を作る。
