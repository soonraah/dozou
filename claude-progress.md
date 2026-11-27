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
