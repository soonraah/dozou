# dozou 開発用 tooling 整備 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** uv project、依存関係、`repo: local` の pre-commit、PR template を 1 つの branch で入れる。

**Architecture:** uv の application project (`package = false`) に runtime と dev の依存関係を置く。pre-commit の hook はすべて `repo: local` + `language: system` で `uv run <tool>` を呼び、sandbox (github.com と npm の通信なし) の中でも動かす。

**Tech Stack:** uv 0.13.9、Python 3.12、dlt、duckdb、dbt-core、dbt-duckdb、pre-commit、black、flake8、conventional-pre-commit、pymarkdownlnt、sqlfluff、pytest

**Spec:** `docs/superpowers/specs/2026-11-25-dev-tooling-setup-design.md`

## Global Constraints

- 作業 branch は `chore/dev-tooling`。現在の `main` から作成済み (`chore/claude-code-security` は未 merge)。
- `AGENTS.md`、`prompts.md`、`.tool-versions`、`.claude/` は commit しない。`git add` は path を明示し、`-A` や `.` は使わない。
- Python は 3.12 (`.python-version` と `requires-python = ">=3.12,<3.13"`)。
- version 指定は下限 (`>=`) のみ。固定は `uv.lock` に任せる。
- pre-commit の hook はすべて `repo: local`。remote repo の hook は使わない。
- flake8: `max-line-length = 88`、`extend-ignore = E203,E701`、設定は `.flake8`。
- pymarkdownlnt: `MD013` を無効にする。
- `.git/hooks` は agent が編集できない。`uv run pre-commit install` は本人が実行する。
- uv の cache は環境変数 `UV_CACHE_DIR` (`./.cache/uv`) を使う。`.cache/` は ignore 済み。
- commit message は Conventional Commits 形式にする。

## Review Focus

1. merge commit (`Merge pull request #N ...`、`Merge branch ...`) が commit-msg hook で拒否されない。→ Task 2 Step 4 で確認する。
2. `.py` file が 1 つもない状態で `pre-commit run --all-files` が black / flake8 で失敗しない。→ Task 2 Step 3 で確認する。
3. 既存の日本語 docs (一文一行、表、`<!-- -->` なし) が pymarkdown で大量に違反にならない。→ Task 2 Step 2 で既存 docs を scan して判断する。
4. `.venv/` や `.cache/` の中の file が lint 対象にならない。→ hook に `exclude` を置かなくても、pre-commit は git 管理下の file しか見ないことを Task 2 Step 3 の出力で確認する。
5. `uv run` が pre-commit から呼ばれたとき、lock と食い違う依存関係を勝手に更新しない。→ hook の entry は `uv run --frozen` とする。

---

### Task 1: uv project と依存関係

**Files:**

- Create: `pyproject.toml`, `.python-version`, `uv.lock`, `.gitignore` (`.venv/`、`.cache/`、`__pycache__/` の 3 行)
- Commit も: `docs/superpowers/specs/2026-11-25-dev-tooling-setup-design.md`, `docs/superpowers/plans/2026-11-25-dev-tooling-setup.md`

**Interfaces:**

- Produces: `uv run --frozen <tool>` で `pre-commit`、`black`、`flake8`、`conventional-pre-commit`、`pymarkdown`、`sqlfluff`、`pytest`、`dbt` が呼べる。`pyproject.toml` に `[tool.black]` と `[tool.pymarkdown]` を後続 Task が足す。

- [ ] **Step 1: project を作る**

`uv init --bare --python 3.12` で `pyproject.toml` を作り、`.python-version` に `3.12` を書く。
`pyproject.toml` は `name = "dozou"`、`requires-python = ">=3.12,<3.13"`、`[tool.uv] package = false` とする。

- [ ] **Step 2: 依存関係を追加する**

```bash
uv add "dlt[duckdb]" duckdb dbt-core dbt-duckdb
uv add --dev pre-commit black flake8 conventional-pre-commit pymarkdownlnt sqlfluff sqlfluff-templater-dbt pytest
```

`uv add` が書く下限 (`>=x.y.z`) はそのまま残す。

- [ ] **Step 3: 動作を確認する**

Run: `uv run --frozen python -c "import dlt, duckdb; print(dlt.__version__, duckdb.__version__)" && uv run --frozen dbt --version`
Expected: dlt と duckdb の version が表示され、`dbt --version` の出力に `duckdb` plugin が含まれる。

Run: `uv run --frozen python --version`
Expected: `Python 3.12.x`

- [ ] **Step 4: Commit**

```bash
git add .gitignore pyproject.toml .python-version uv.lock docs/superpowers/specs/2026-11-25-dev-tooling-setup-design.md docs/superpowers/plans/2026-11-25-dev-tooling-setup.md
git commit -m "build: add uv project with ingestion and transform dependencies"
```

### Task 2: pre-commit

**Files:**

- Create: `.pre-commit-config.yaml`, `.flake8`
- Modify: `pyproject.toml` (`[tool.black]`、`[tool.pymarkdown]` を追加)
- Modify (必要な場合のみ): 既存の `*.md`

**Interfaces:**

- Consumes: Task 1 の `uv run --frozen <tool>`。
- Produces: hook id `conventional-pre-commit` (stage `commit-msg`)、`black`、`flake8`、`pymarkdown` (stage `pre-commit`)。

- [ ] **Step 1: 設定 file を書く**

`.pre-commit-config.yaml`:

- `default_install_hook_types: [pre-commit, commit-msg]`
- `default_stages: [pre-commit]`
- `repos:` は `- repo: local` 1 つで、次の 4 hook を持つ。すべて `language: system`。

| id | entry | 対象の指定 | その他 |
|---|---|---|---|
| `conventional-pre-commit` | `uv run --frozen conventional-pre-commit` | — | `stages: [commit-msg]` |
| `black` | `uv run --frozen black` | `types_or: [python, pyi]` | `require_serial: true` |
| `flake8` | `uv run --frozen flake8` | `types: [python]` | |
| `pymarkdown` | `uv run --frozen pymarkdown scan` | `types: [markdown]` | |

`.flake8`: `[flake8]` に `max-line-length = 88`、`extend-ignore = E203,E701`。
`pyproject.toml`: `[tool.black]` に `target-version = ["py312"]`。`[tool.pymarkdown]` に `plugins.md013.enabled = false`。

- [ ] **Step 2: 既存 docs を scan して rule を決める**

Run: `uv run --frozen pymarkdown scan -r docs README.md tools`
Expected: `MD013` 以外の違反が一覧で出る (0 件でもよい)。

判断基準は次のとおり:

- 同じ rule の違反が多数の file にまたがり、日本語の文体や既存の書き方 (表、一文一行など) に由来するもの → `[tool.pymarkdown]` で無効化し、理由を 1 行コメントで書く。
- 個別の誤り (見出しレベルの飛び、末尾空白など) → file を修正する。
- 修正が 20 file を超える場合は、ここで止めて本人に扱いを確認する (spec の非目標)。

- [ ] **Step 3: 全 file に hook をかける**

Run: `uv run --frozen pre-commit run --all-files`
Expected: 全 hook が `Passed` か `(no files to check)Skipped`。black と flake8 は `.py` がないため `Skipped`。`.venv/` や `.cache/` の file が出力に現れない。

- [ ] **Step 4: commit-msg hook を確認する**

一時 file を `$TMPDIR` に作って次を実行する。

Run: `printf 'chore: test\n' > "$TMPDIR/ok.txt" && uv run --frozen pre-commit run conventional-pre-commit --hook-stage commit-msg --commit-msg-filename "$TMPDIR/ok.txt"`
Expected: `Passed`

Run: `printf 'add something\n' > "$TMPDIR/ng.txt" && uv run --frozen pre-commit run conventional-pre-commit --hook-stage commit-msg --commit-msg-filename "$TMPDIR/ng.txt"`
Expected: `Failed`

Run: `printf "Merge pull request #2 from soonraah/chore/x\n" > "$TMPDIR/merge.txt"` に対して同じ command。
Expected: `Passed`。`Failed` になる場合は conventional-pre-commit の merge commit 扱いの option を調べて hook の `args` に足す。

- [ ] **Step 5: black と flake8 が実際に動くことを確認する**

`$TMPDIR` ではなく repo 直下に一時 file `tmp_lint_check.py` (中身 `x=1`) を作り、`git add` せずに次を実行する。

Run: `uv run --frozen pre-commit run black --files tmp_lint_check.py; uv run --frozen pre-commit run flake8 --files tmp_lint_check.py`
Expected: black は `Failed` (file を整形した)、整形後の flake8 は `Passed`。
確認後に `tmp_lint_check.py` を削除する。

- [ ] **Step 6: Commit**

```bash
git add .pre-commit-config.yaml .flake8 pyproject.toml <修正した md>
git commit -m "build: add local pre-commit hooks for commit messages, Python and markdown"
```

### Task 3: PR template

**Files:**

- Create: `.github/pull_request_template.md`

- [ ] **Step 1: template を書く**

見出しは `## 概要`、`## 変更内容`、`## 確認したこと` の 3 つ。
`## 概要` には「何を、なぜ変えるか」の HTML コメントによる記入の手引きを置く。
`## 確認したこと` には checkbox `- [ ] pre-commit が通る` を置く。

- [ ] **Step 2: lint を通す**

Run: `uv run --frozen pre-commit run --files .github/pull_request_template.md`
Expected: pymarkdown が `Passed`。

- [ ] **Step 3: Commit**

```bash
git add .github/pull_request_template.md
git commit -m "docs: add pull request template"
```

### Task 4: hook の install と最終確認 (本人)

- [ ] **Step 1: 本人が hook を install する**

```bash
uv run pre-commit install
```

Expected: `pre-commit installed at .git/hooks/pre-commit` と `.git/hooks/commit-msg` の 2 行。

- [ ] **Step 2: 最終確認**

Run: `uv run --frozen pre-commit run --all-files && git log --oneline main..HEAD`
Expected: 全 hook が通り、Task 1〜3 の 3 commit が並ぶ。
`git status` に `AGENTS.md`、`prompts.md`、`.tool-versions`、`.claude/` 以外の未追跡 file がない。
