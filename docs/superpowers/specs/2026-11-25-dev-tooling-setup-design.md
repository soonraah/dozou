# dozou の開発用 tooling 整備の設計

| 項目 | 内容 |
|---|---|
| ステータス | 承認待ち |
| 作成日 | 2026-11-25 |
| 規模 | 小さな変更 (雑務 1 branch) |
| 関連文書 | [03-refinement.md](../../strategies/personal-data-platform/03-refinement.md) |

## 目的

戦略では CI/CD を初期に作る前提としている。
その土台として、Python project (uv)、取り込みと変換の依存関係、pre-commit、PR template を 1 つの branch でまとめて入れる。
agent が書いた code と docs を、agent 自身が sandbox 内で lint できる状態にすることを重視する。

## 目標と非目標

目標は次のとおりである。

- uv project を作り、runtime と dev の依存関係を `uv.lock` で固定する。
- pre-commit で commit message (Conventional Commits)、Python (black、flake8)、markdown を check する。
- hook は agent の sandbox (github.com と npm への通信なし) の中でも実行できる。
- PR template を置く。

次のものは対象にしない。

- GitHub Actions での pre-commit 実行 (CI 本体は別の作業とする)。
- dbt project と dlt pipeline の作成、SQLFluff の設定 (対象の code がまだないため、依存関係の追加だけにとどめる)。
- 既存の markdown の lint 違反の修正のうち、設定で吸収できないもの (件数が多い場合は別 commit か別作業に分ける)。

## 検討した方式

| 方式 | 利点 | 欠点 | 判定 |
|---|---|---|---|
| A. 標準どおり remote repo の hook を参照する | 一般的で設定が短い | sandbox が github.com と npm を遮断しているため、agent が hook を install も実行もできない | 不採用 |
| B. `repo: local` にして、uv の dev 依存関係から hook を実行する | `uv.lock` で version を固定でき、agent・手元・CI で同じものが動く | 本家 markdownlint (Node 製) は使えない | **採用 (本人が選択)** |

markdown の linter は、Python 製で markdownlint と rule ID が共通の pymarkdownlnt を使う (本人が選択)。
本家 markdownlint-cli2 は remote hook でしか使えず、agent が実行できないため見送った。

## 設計

### uv project

- Python は 3.12 に固定する (`.python-version` と `requires-python`)。dbt-core と dlt の対応範囲で無難なため (agent の判断)。
- package としては build しない (`[tool.uv] package = false`)。application の置き場所としての project である。
- runtime の依存関係: `dlt[duckdb]`、`duckdb`、`dbt-core`、`dbt-duckdb`。
- dev の依存関係 (`[dependency-groups] dev`): `pre-commit`、`black`、`flake8`、`conventional-pre-commit`、`pymarkdownlnt`、`sqlfluff`、`sqlfluff-templater-dbt`、`pytest`。
- dbt-core 1.12 の依存関係 `dbt-core-experimental-parser` は、build 時に github.com から wheel を取得する。そのため、本人が `.claude/settings.local.json` (git 管理外) で `github.com` と `release-assets.githubusercontent.com`、`objects.githubusercontent.com` への通信を許可した (2026-11-25)。`*.github.com` と `registry.npmjs.org` は引き続き拒否する。
- version 指定は下限のみとし、実際の固定は `uv.lock` に任せる (agent の判断)。
- `.tool-versions` は commit しない。以前の plan で「commit しない」と決めており、agent からの編集も禁止されているため。Python の version は `.python-version` で固定する。

### pre-commit

`.pre-commit-config.yaml` はすべて `repo: local`、`language: system` とし、`uv run` 経由で dev 依存関係の tool を呼ぶ。

| hook | stage | 対象 |
|---|---|---|
| conventional-pre-commit | `commit-msg` | commit message |
| black | `pre-commit` | `*.py` |
| flake8 | `pre-commit` | `*.py` |
| pymarkdown scan | `pre-commit` | `*.md` |

- `default_install_hook_types` に `pre-commit` と `commit-msg` を入れ、`pre-commit install` 1 回で両方が入るようにする。
- flake8 は black に合わせ、`max-line-length = 88`、`extend-ignore = E203,E701` とする。flake8 は `pyproject.toml` を読まないので `.flake8` に書く。
- pymarkdownlnt は、一文一行の日本語の文章に合わせて行長 (`MD013`) を無効にする。他に既存 docs と衝突する rule があれば、実装時に既存 docs を scan して無効化の要否を判断する。
- `.git/hooks` は agent が編集できないため、`uv run pre-commit install` は本人が実行する。

### PR template

`.github/pull_request_template.md` に、次の 3 節を置く (agent の判断)。

- 概要 (何を、なぜ)
- 変更内容
- 確認したこと (pre-commit の通過、手元での動作確認など)

### branch

`chore/claude-code-security` の merge は後回しにし、現在の `main` から `chore/dev-tooling` を切って作業する (本人の判断、2026-11-25)。
その結果、次の 2 点に対応する。

- `main` には `.gitignore` がないので、この branch で最小限の `.gitignore` (`.venv/`、`.cache/`、`__pycache__/`) を追加する。security branch を merge するときに `.gitignore` が衝突するので、その際に両方の内容を統合する。
- `.claude/settings.json` は sandbox が削除を拒んだため、未追跡 file として作業ツリーに残っている。`.claude/` は commit しない。`git add` は path を明示し、`-A` や `.` は使わない。

## builder に任せること

- 各 package の下限 version の具体的な値。
- pymarkdownlnt の設定 file の形式 (`pyproject.toml` の `[tool.pymarkdown]` か独立 file か)。
- 既存 docs の lint 違反の扱い (設定で吸収するか、修正するか)。
