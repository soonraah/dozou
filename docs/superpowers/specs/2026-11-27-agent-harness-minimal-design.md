# agent harness の最小構成の設計

| 項目 | 内容 |
|---|---|
| ステータス | 承認済み (2026-11-27) |
| 作成日 | 2026-11-27 |
| 規模 | 小さな変更 (1 branch) |
| 関連文書 | [03-refinement.md](../../strategies/agent-harness/03-refinement.md) / [02-diagnosis.md](../../strategies/agent-harness/02-diagnosis.md) |

## 目的

agent-harness の洗練ステップでは、戦略テストを計画している。
1 つの機能を、spec の承認から PR 作成まで人間の介入なしで通せるかを確かめる。
本設計の目的は、そのテストを walkinglabs の最小構成の上で始められるようにすることである。
最小構成に加えて、L2 (介入の回数と種類) と L1 (完了判定) を後から振り返れる記録の置き場を用意する。

walkinglabs の最小構成は、root に置く次の 4 file である。

- 入口の指示書
- `init.sh`
- `claude-progress.md`
- `feature_list.json`

出典: <https://walkinglabs.github.io/learn-harness-engineering/ja/resources/templates/>

## 目標と非目標

目標は次のとおりである。

- repo root に `AGENTS.md`、`init.sh`、`claude-progress.md`、`feature_list.json` を置く。
- agent が、session の開始から終了までの手順と Definition of Done を `AGENTS.md` から読み取れるようにする。
- agent が、必要な file に迷わずたどり着けるよう、`AGENTS.md` にプロジェクト構成を書く。
- 03-refinement.md の「最初の構成」を、4 file を入れた形に更新する。

次のものは対象にしない。

- hooks、evaluator、walkinglabs の残りの template (session-handoff、clean-state-checklist、evaluator-rubric、quality-document)。失敗が観測されてから足す。
- data の正しさの DoD。L1 で観測する対象なので、feature ごとに spec の中で定義する。
- CI (GitHub Actions)、security の見直し。

アンチゴールは、harness の構築そのものが戦略テストの時間を食うことである (診断の視点 ①)。
この変更は 1 branch で終える。

## 検討した方式

| 方式 | 利点 | 欠点 | 判定 |
|---|---|---|---|
| a. 4 file をすべて入れる。`feature_list.json` は戦略テストの「機能」の単位にし、細かい手順は superpowers の plan に任せる | walkinglabs に忠実。完了判定の根拠 (`evidence`) を記録する場所があり、L1 を振り返りやすい | superpowers の spec/plan と二重管理になりやすい。03-refinement.md の「JSON の feature list はテスト開始前に入れない」を覆す | **採用 (本人が選択)** |
| b. 入口の指示書と `init.sh` だけを入れ、進捗と完了状況は superpowers の spec/plan で代用する | 二重管理が無い。03-refinement.md の決定と揃う | walkinglabs の最小構成から外れる | 不採用 |

二重管理は、役割を分けて抑える。
`feature_list.json` は機能単位の状態と証拠だけを持つ。
`claude-progress.md` は session 単位のログだけを持つ。
作業手順の詳細は superpowers の plan に置く。

## 設計

### `AGENTS.md` (80 行以内)

入口の指示書のファイル名は `AGENTS.md` にする (本人が選択)。
Claude Code は v2.1.277 から project root の `AGENTS.md` を読み込む (<https://code.claude.com/docs/en/memory.md>)。
ただし `CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` のいずれかがあると、既定の設定では `AGENTS.md` は読まれない。
そのため `AGENTS.md` に「これらの file を作らない」と明記する。

節の構成は次のとおりである。

- **起動手順**: `bash init.sh` を実行し、失敗したら新しい作業の前に直す。`claude-progress.md` の最新の session と `feature_list.json` を読む。
- **プロジェクト構成**: top-level の directory と主要な file を、役割 1 行ずつの表にする。対象は次のとおり。
  - `docs/strategies/`、`docs/superpowers/specs/`、`docs/superpowers/plans/`
  - harness の 4 file
  - `pyproject.toml`、`uv.lock`、`.pre-commit-config.yaml`、`.github/`
  - 深い階層や個々の file は書かない。dlt や dbt の directory は、作った時点で agent が追記する。
- **作業の進め方**: 1 session で扱う feature は 1 つにする。設計と計画は superpowers の flow (spec → plan → 実装) に従う。spec は人間が承認する。
- **Definition of Done**: 次をすべて満たしたときだけ完了とする。
  - `bash init.sh` が通る。
  - spec に書いた完了基準を満たし、それを示す証拠がある。
  - `feature_list.json` の該当 feature に `evidence` と `testedAt` を書き、`status` を `pass` にしている。
  - top-level の directory を追加・変更した場合は、プロジェクト構成の表を更新している。
- **終了手順**: `claude-progress.md` に session の記録を追記し、作業ツリーを clean state にして commit する。
- **feature list の規則**:
  - `status` は `not-started`、`in-progress`、`pass`、`fail` のいずれかにする。
  - 詰まったら `fail` にして理由を書く。
  - feature を削除しない。

### `init.sh`

`#!/usr/bin/env bash` と `set -euo pipefail` を使い、次を順に実行する。

1. `uv sync --frozen`
2. `uv run --frozen pre-commit install`
3. `uv run --frozen pre-commit run --all-files`
4. `tests/` に test がある場合だけ `uv run --frozen pytest`

最後に、次に読む file (`claude-progress.md`、`feature_list.json`) を表示する。
network を使う処理は `uv sync` だけにする。agent の sandbox の中で実行できる必要がある。

### `claude-progress.md`

walkinglabs の session ログ形式に、介入の記録の欄を足す。
1 session ごとに、次の項目を持つ entry を追記する。

- `### Session N — YYYY-MM-DD`
- Feature: `feature_list.json` の id
- Goal / What was done / Decisions / Issues / Next
- Interventions: 人間の介入の一覧。各項目に種類 (`permission` / `decision` / `rework`) と内容を書く。無ければ `none`。

Interventions は、日曜の振り返りで L2 の指標 (介入の回数と種類) を集計するために使う。
agent が自分で気づけない介入 (人間が会話で修正を指示した、など) も、agent が session の終わりに書く。

### `feature_list.json`

top-level の key は `project`、`description`、`features` にする。
`features` の各要素は次の key を持つ。

- `id`
- `name`
- `description`
- `spec` (superpowers の spec への相対 path。spec が無い間は `null`)
- `status`
- `evidence` (完了を示す command と結果の要約。未完了の間は `null`)
- `testedAt` (ISO 8601。未完了の間は `null`)

初期の entry は、切り口 (i) の MoneyForward CSV の取り込み 1 件だけにし、`status` は `not-started` にする (私の判断)。
切り口 (ii) の補助 script は内容が未定なので、spec を承認した時点で agent が追加する。

### 03-refinement.md の更新

- 「戦略テストの記録」の「最初の構成」を、superpowers、pre-commit、PR template、walkinglabs の 4 file (`AGENTS.md`、`init.sh`、`claude-progress.md`、`feature_list.json`) に改める。
- 「保留した解決策案」の L1 への打ち手から、「JSON の feature list」を外す。代わりに、最小構成に含めたことを記す。
- 週次の振り返りで使う介入の記録を、`claude-progress.md` の Interventions から取ると書く。この項目は「分からないままのこと」に挙がっていた。

## 検証

- `bash init.sh` が、clean な worktree で exit 0 で終わる。
- `python -m json.tool feature_list.json` が通る。
- `AGENTS.md` が 80 行以内である。
- 新しい session で `/context` を開き、`AGENTS.md` が Memory files に含まれる。これは人間が確認する。

## builder に任せること

- `AGENTS.md` の文面と、プロジェクト構成の表の役割の書き方。
- `init.sh` の出力 message の書き方。
- `claude-progress.md` に最初の session (この変更そのもの) の entry を書くかどうか。
