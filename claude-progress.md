# claude-progress.md

agent が session ごとに作業を記録するログである。
新しい session は、最初に最新の entry を読んで前回の続きから始める。
entry は session の終わりに、新しいものを下に追記する。

Interventions は、日曜の振り返りで人間の介入の回数と種類を数えるために使う。
人間が会話で修正や判断を指示した場合も、agent が session の終わりに記録する。
種類は `permission` (許可の確認で止まった)、`decision` (判断を人間に求めた)、`rework` (品質不足でやり直した) のいずれかにする。

## Entry の書式

```markdown
### Session N — YYYY-MM-DD

- Feature: <feature_list.json の id>
- Goal: <この session で目指したこと>
- What was done: <やったこと>
- Decisions: <決めたことと理由>
- Issues: <残った問題>
- Next: <次の session で最初にやること>
- Interventions:
  - <permission | decision | rework>: <内容> (無ければ none)
```

## Sessions
