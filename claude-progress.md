# claude-progress.md

agent が session ごとに作業を記録するログである。
新しい session は、最初に最新の entry を読んで前回の続きから始める。
entry は session の終わりに、新しいものを下に追記する。
見出しは日付と branch 名にする。連番にすると、並行する worktree の間で番号が衝突するためである。

Verification には、その session で実際に実行した検証の command と結果を書く。
Commits には、その session で作った commit の短い hash を書き、起動時に `git log` と突き合わせられるようにする。

Interventions は、日曜の振り返りで人間の介入の回数と種類を数えるために使う。
人間が会話で修正や判断を指示した場合も、agent が session の終わりに記録する。
種類は `permission` (許可の確認で止まった)、`decision` (判断を人間に求めた)、`rework` (品質不足でやり直した) のいずれかにする。
介入が無かった場合は `- none` と書く。

## Entry の書式

```markdown
### YYYY-MM-DD — <branch 名>

- Feature: <feature_list.json の id>
- Goal: <この session で目指したこと>
- What was done: <やったこと>
- Verification: <実行した検証の command と結果>
- Commits: <短い hash の一覧>
- Decisions: <決めたことと理由>
- Issues: <残った問題、リスク、ブロッカー>
- Next: <次の session で最初にやること>
- Interventions:
  - <permission | decision | rework>: <内容>
```

## Sessions

### 2026-11-28 — feat/agent-data-tooling

- Feature: agent-data-tooling
- Goal: dlt の pipeline を agent が実装できるよう、dlt 向けの MCP server、docs の入口、DuckDB の skill を Claude Code から使えるようにする。
- What was done:
  - deep-research で dlt 向けの Claude Code tooling を調べた。
  - dltHub AI Harness を scratchpad で試したうえで、license を理由に見送った。
  - dlt-mcp を dev 依存と `.mcp.json` に入れた。`search_docs` のため `lancedb<0.26` と `chonkie==1.4.2` を固定した。
  - `.dlt/config.toml` で telemetry を止め、`.gitignore` に `.dlt/secrets.toml` を足した。
  - AGENTS.md の構成の表と、dlt の docs の引き方を更新した。
  - 完了基準 3 と 4 は、新しい session (verify-tooling) で確かめた。
- Verification:
  - `bash init.sh` → exit 0
  - `uv tree --frozen | grep -c dlthub` → 0
  - 新しい session で `/mcp` の `dlt` が connected (人間が確認)。`list_pipelines` と `search_docs("read_csv encoding")` が成功した。
  - 新しい session で duckdb-skills の skill 9 個が読み込まれた。Shift_JIS の sample CSV を `read_csv(..., encoding='shift_jis')` で読み、3 列 3 行が返った。
  - `python3 -m json.tool` で `.mcp.json` と `feature_list.json` が通った。
- Commits: 4080fbb, 437fe8c, e917419, および本 entry を含む commit
- Decisions:
  - AI Harness を見送り、dlt-mcp、`llms.txt`、duckdb-skills にした。AI Source Available License は dltHub Services の外での利用を認めず、EULA の本文は 404 だった (本人が選択)。
  - dlt の telemetry を止めた。
  - DuckDB の CLI は brew で入れた。
- Issues:
  - `search_docs` の index は dlt 1.18.1 のもので、repo の 1.32.0 より古い。
  - dlt-mcp は 2026-02 から release がない。
  - duckdb-skills の `read-file` は、既定のままでは Shift_JIS の CSV を読めない。`encoding='shift_jis'` の指定が要る。
  - `~/.dlt/pipelines/` に、以前の repo の `money_forward` pipeline がある。
- Next: `mf-csv-ingest` の spec を書く。encoding と pipeline 名 (既存の `money_forward` と衝突しないもの) を決める。
- Interventions:
  - decision: `init.sh` の再実行、deep-research の実施、duckdb-skills の採用、feature の追加を指示した。
  - decision: EULA の本文の捜索を指示した。
  - rework: 最初の spec (AI Harness 構成) を、dlt-mcp 構成に書き直した。
  - decision: 書き直した spec を承認した。
  - permission: `.claude/settings.json` に `enabledMcpjsonServers` を追加した (sandbox で保護された file のため)。
  - permission: duckdb-skills を claude.ai から導入した。
  - permission: `brew install duckdb` を実行した。
  - permission: 新しい session で `/mcp` の接続を目視で確認した。
