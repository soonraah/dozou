# dozou

個人の data platform。
開発は Claude Code に任せ、人間は spec の承認と PR の review を行う。

## はじめに読むもの

- agent: [AGENTS.md](AGENTS.md)
- 戦略と判断の背景: [docs/strategies/](docs/strategies/)

## 新しい環境での setup

sandbox の外で、人間が 1 回だけ行う作業である。

1. uv を install する。
2. repo を clone し、`uv sync` と `uv run pre-commit install` を実行する。
   sandbox は `.git/hooks` への書き込みを拒否するため、hook の install は agent にはできない。
3. `bash init.sh` が exit 0 で終わることを確かめる。

## 進め方

- feature の状態と完了の証拠は [feature_list.json](feature_list.json) にある。
- session ごとの作業と人間の介入の記録は [claude-progress.md](claude-progress.md) にある。
