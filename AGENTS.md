# AGENTS.md

dozou (個人の data platform) で作業する agent への入口である。
`CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` は作らない。
どれか 1 つでもあると、Claude Code はこの `AGENTS.md` を読まなくなる。

## 起動手順

1. `bash init.sh` を実行する。失敗したら、新しい作業の前に原因を直す。
   cache や git hooks の設定が原因で失敗したときは、cache の env を上書きして回避せず、作業を止めて人間に依頼する。これは Interventions に `permission` として記録する。
2. `claude-progress.md` の最新の session を読み、前回の続きを把握する。
3. `feature_list.json` を読み、扱う feature を 1 つ決める。

## プロジェクト構成

| path | 役割 |
|---|---|
| `AGENTS.md` | agent への入口。この file |
| `init.sh` | 環境の準備と検証。session の最初に実行する |
| `claude-progress.md` | session ごとの作業ログと介入の記録 |
| `feature_list.json` | feature ごとの状態と、完了を示す証拠 |
| `docs/strategies/` | 戦略ドキュメント。方針や判断の背景を探すときに読む |
| `docs/superpowers/specs/` | feature ごとの設計 (spec)。完了基準はここに書く |
| `docs/superpowers/plans/` | spec を実装する計画 |
| `pyproject.toml` / `uv.lock` | Python の依存関係。uv で管理する |
| `.pre-commit-config.yaml` | commit 時の check (Conventional Commits、black、flake8、pymarkdown) |
| `.github/` | PR template |
| `.claude/settings.json` | Claude Code の project 設定 (sandbox の書き込み許可など) |

top-level の directory を追加・変更したら、この表も更新する。

## 作業の進め方

- 1 session で扱う feature は 1 つにする。
- 設計と計画は superpowers の flow (spec → plan → 実装) に従う。
- spec は人間が承認する。承認された spec の完了基準が、その feature の完了の定義になる。
- spec を承認したら、`feature_list.json` に feature を追加するか、既存の entry に `spec` の path を書き、`status` を `in-progress` にする。

## Definition of Done

次をすべて満たしたときだけ、完了とする。

- `bash init.sh` が exit 0 で終わる。
- spec に書いた完了基準を満たし、それを示す証拠 (実行した command と結果) がある。
- `feature_list.json` の該当 feature に `evidence` と `testedAt` を書き、`status` を `pass` にしている。
- top-level の directory を追加・変更した場合は、プロジェクト構成の表を更新している。

## 終了手順

1. `claude-progress.md` に、書式に従って session の entry を追記する。人間の介入は Interventions に漏れなく書く。
2. 作業ツリーを clean state にして commit する。
3. feature の作業は main ではなく branch で行い、完了したら push して PR を作成する。

## feature list の規則

- `status` は `not-started`、`in-progress`、`pass`、`fail` のいずれかにする。
- 詰まったら `status` を `fail` にし、`evidence` に理由を書く。
- feature を削除しない。
- `pass` にできるのは、Definition of Done を満たしたときだけである。
