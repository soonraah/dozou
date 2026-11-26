# 診断: agent-harness

- 戦略スラッグ: `agent-harness`
- ステータス: レビュー中
- 作成日: 2026-11-26
- 前段: [01-exploration.md](01-exploration.md) / 要件: [requirement.md](requirement.md)

## 1. 診断の要約

dozou で Claude Code に自律的に開発させるうえでの中心課題は、作業の「完了」を機械的に判定する手段がないことである。
業務でのやり直しの主因は完了基準が伝わっていないことであり、探究で集めた事例も、agent が自ら検証できない限り人間が確認役として残り続けることを示している。
dozou には format と lint の pre-commit しかなく、データの正しさを確かめる手段はまだない。
また、全開発要素の DoD や E2E を事前に揃えることはできない。

この課題は、人間の時間が極端に少ないという制約の下にある。
開発は 1 日 30〜60 分、運用は月 1 時間以内であり、人間は PR review と大きな設計判断に集中したい。

一方で、作り込みに向かう力が人間と agent の両方に働いている。
人間側では harness 構築そのものが楽しさの源であり、過去の my-data-platform は過剰設計で停滞した。
agent 側では、要件を満たそうとして複雑な解を提案する傾向がある。
戦略テスト期間の最初の 3 日は、data source ではなく基盤整備 (security と dev-tooling) に使われた。

security を先に置くか後に置くかについては、見方が割れている。
本診断ではどちらにも寄せず、両論を残す。

## 2. 観察されている事実

| 事実 | 時点 | 出典 |
|---|---|---|
| main にあるのは戦略ドキュメント、uv project、pre-commit (conventional-pre-commit / black / flake8 / pymarkdown)、PR template、superpowers の spec と plan 各 1 件 | 2026-11-25 | repo (main) |
| dlt と dbt の code、CI (GitHub Actions) はまだ無い | 2026-11-25 | repo (main) |
| personal-data-platform の戦略テストは 2026-11-23〜2027-01-04 の 6 週間。論点 A は「今の AI agent なら 1 source を短期間で可視化まで通せる」 | 2026-11-23 | [personal-data-platform/03-refinement.md](../personal-data-platform/03-refinement.md) |
| `chore/claude-code-security` に 19 commits (11-23: 10 / 11-24: 5 / 11-25: 4)。最後は unattended agent runs と Task 4 を「pending operating policy」で一時停止 | 2026-11-23〜25 | `git log main..chore/claude-code-security` |
| 同期間に main 側では dev-tooling (pre-commit、uv、PR template) を整備し PR #2 として merge | 2026-11-25 | `git log main` |
| 運用は月 1 時間以内、Mac は常時起動ではなく NAS や server も無い | 戦略策定時 | prompts.md |
| 業務で agent にやり直しをさせた主因は「完了基準が伝わっていない」 | 2026-11 | 本人の回答 |
| permission 確認で止まる事象 (主に SSO 起因) は業務で発生、dozou では未遭遇 | 2026-11 | 本人の回答 |

## 3. データ分析

| 分析 | 元データ | 手に入らなかったデータ |
|---|---|---|
| 戦略テスト開始から 3 日間の commit はすべて基盤整備 (security 19 件、dev-tooling)。data source の実装 commit は 0 件。harness や環境整備が戦略テストの時間を先に消費する傾向が、小さく既に現れている。ただし commit の日付は作業時間を表さない | `git log` (main と security branch) | 実際の作業時間 |
| dozou の検証手段は静的 check (format / lint / commit message) のみで、実行結果やデータの正しさを判定する sensor は 0 | `.pre-commit-config.yaml` | — |
| agent が dozou で止まった・失敗した記録は無い。業務の観察 (完了基準、SSO 起因の permission) を dozou に当てはめるのは推測を含む | 本人の回答 | dozou での失敗・停止のログ、permission 確認の発生回数 |

## 4. 関係者の視点

dozou は個人開発で、関係者は本人だけである。
そこで、本人の中にある異なる立場を関係者として扱う。
知人へのヒアリングは行わない方針のため、外部の人による検証はしていない。

| 立場 | 見方 | 本人の受け止め |
|---|---|---|
| 開発者としての現在の自分 | 確認や承認の依頼が多いと困る。agent には best practice を自分で調べ、詳細設計・coding・PR 前のローカル review・動作確認・push と PR 作成まで担ってほしい。PR review、Mac への tool install、最初の承認設定、大きな設計判断は当面人間に残す | 本人の見立て |
| ① 運用者としての将来の自分 | harness も保守対象になる。作るのが楽しいので作り込みすぎ、運用を月 1 時間以内に収める制約を自分で破る | 「言われそう」と選択 |
| ② 戦略テストの当事者 | 1 日 30〜60 分しかないのに harness に時間を取られると、1 つ目の source が可視化まで届かない | 反対視点としては選ばれなかったが、ブロッカー 2 と同内容のため条件側で扱う |
| ③ security 作業をしていた自分 | 緩い前提で自律性を作り込むと、後から security を締めたときに仕組みが壊れて作り直しになる | 「言われそう」と選択 |
| ④ model の進化を見ている人 | model と Claude Code は数か月で良くなり、今作る harness の多くはすぐ不要になる | 選ばれなかった |

### 意見が割れている点

- security の順序。
  - 一方の見方 (requirement.md、本人): security 制約ありきで作ると harness の方針が制限される。先に harness の方針を決め、その上で security を見直す。
  - もう一方の見方 (③): 緩い前提で作り込むと、後から締めたときに壊れる。
- 診断としてはどちらにも寄せない。方針策定で、選んだ方針が③の懸念にどう答えるかを評価する。

## 5. 制約と力学

- **人員**: 本人 1 人。harness の構築も review も本人が行う。
- **時間**: dozou の開発は趣味で、1 日 30〜60 分。運用は月 1 時間以内。
- **技術**:
  - Mac は常時起動ではなく、NAS や server も無い。
  - cloud での無人実行 (探究の E 案) は現時点で考えていない。
  - 検証手段は静的 check のみ。
- **組織・意思決定**: 決めるのは本人。動機の面では、楽しさの源が coding から harness 構築・agent の management・それで得られる product 機能に移っている。これは作り込みへの引力にもなる。
- **外部要因**: Claude Code と model の進化が速い。業務では Databricks 上の dbt / terraform 開発で、superpowers を中心にした harness を約 3 か月運用しており、その知見と癖を持ち込める。公開 registry の skill は 13.4% に critical な問題があるという調査がある (Snyk、2026-02 時点。[research-skills-plugins.md](research-skills-plugins.md))。外部の skill や plugin を取り込むことは security の論点に直結し、security を後回しにする順序とぶつかりうる。

## 6. この戦略が満たすべき条件

| ブロッカー (本人の発言) | 戦略が満たすべき条件 |
|---|---|
| あらゆる開発要素の DoD を定義し、E2E テストを用意することはできない | DoD や E2E が一部にしか無い状態でも、agent の完了判定が機能しなければならない |
| harness を作り込みすぎて、architecture の戦略テストが進まなくなる | harness にかける時間は、戦略テストの進捗を止めない範囲に収まらなければならない。期限は当初 2027-01-04 だったが、洗練で上限 2027-03-31 まで延長可とした |
| 環境に依存しすぎて、Mac を新調したときに開発を続けられなくなる | harness は特定の Mac の状態に依存せず、repo とわずかな手作業で再現できなければならない |
| agent に任せすぎた結果、人手の定期運用作業が簡単に増えてしまう | agent が増やす運用作業も、月 1 時間以内という運用予算の内側に収まらなければならない。また、増えたことに人間が気づける必要がある |

## 7. これまでに試したこと

| 取り組み | 時期 | 結果 |
|---|---|---|
| my-data-platform (前身) | dozou 以前 | dlt の実装と Data Vault modeling で停滞。enterprise level の運用を目標にしたことと Data Vault の採用は過剰だった可能性があると本人が認めている |
| `chore/claude-code-security` で sandbox / permission 境界、unattended agent launcher を設計・実装 | 2026-11-23〜25 | 想定より複雑になり、「pending operating policy」で一時停止。requirement.md で内容はいったん無視すると決定 |
| dev-tooling (pre-commit、uv、agent が作る PR 向けの PR template) | 2026-11-25 | main に merge 済み |
| 業務での harness (superpowers の thin wrapper skill、domain 知識、dbt modeling rule、PR review skill、commit/branch rule) | 約 3 か月前から | superpowers の開発 flow、domain 知識の wrap、dbt modeling rule は効いている。PR 前のローカル review が弱いことがあり、security も不十分 |

### 自分自身の関与

以下は本人の判断であり、責任追及ではなく事実として記録する。

- harness の方針を決める前に、security の設計・実装から手をつけた。security が重要だと考え、比較的簡単に構築できると見込んでいたが、想定より複雑だった。
- 戦略テストの開始と同時に、基盤整備 (security と dev-tooling) を優先した。戦略テストには AI 開発の効率性を見ることが含まれるため、ある程度安心して AI 開発を行える環境を先に整えたかった。

## 8. 探究との突き合わせ

### そのまま当てはまる

- **A. 長い作業で文脈を失う** (Anthropic の長時間 agent 記事、walkinglabs): agent は 1 session で全部やろうとして途中で文脈を失う。作業を小さく区切り、進捗を file に残す必要がある。dozou 固有の失敗データはまだ無い。
- **B. 指示書を厚くしても効かない** (HumanLayer、ETH の AGENTS.md 研究): 指示書を厚くしても成果は上がらずコストが増える。指示は実際に失敗した箇所にだけ足すほうが効く。要約の「作り込みへの力」と同じ向きの警告である。
- **C. sensor が無いと人間が確認役に残る** (Fowler/Böckeler、dbt Wizard): agent が自ら結果を検証できないと人間が確認役に残り続ける。data 基盤では数字が静かに間違う不具合が見つかりにくい。業務でのやり直しの主因 (完了基準) と同じ根である。

### 調整が必要

- **業務の harness の構図**: superpowers 中心の flow は効いているが、業務の harness は既存の CI/CD と staging の上に乗っている。dozou にはそのどちらも無い (01-exploration「過去の経験は今も有効か」で「一部しか成立しない」と判定済み)。

### 当てはまらない

- 今回は判定していない。

## 9. 未解決の論点

- dozou における E2E (動作確認) の定義。可視化まで通ったことを何で判定するか。
- 目標とする自律性の水準。「確認・承認依頼が多いと困る」の許容ラインが数値になっていない。
- dozou で agent が実際にどこで止まり、どこで失敗するか。業務の観察が dozou にも当てはまるかは未確認。
- security の見直しをいつ、どの条件で行うか。③の懸念にどう答えるか。
- ④ (model の進化で harness が不要になる) を診断から外してよいか。本人は選ばなかったが、探究では Anthropic 自身が component を 1 つずつ外すことを勧めている。補足調査では、ある model で必要だった context reset が次の model では「dead weight」になった例も見つかっており (Lance Martin、2026-04-02)、外す前に再検討する材料がある。

## 10. 検証ログ

- 2026-11-25〜26: 本人との対話で、見立ての列挙、探究事例 3 件のタグ付け、反対視点の選択、ブロッカーの言い換えの合意、自分の関与の確認を行った。
- git log で戦略テスト開始以降の commit を確認した。
- 省略したステップ:
  - センシティブな表現の言い換え: 個人開発で、書きにくい要素は無いと判断した。
  - 反対者本人への検証: 知人に聞かない方針のため行っていない。反対視点はすべて本人による代弁であり、外部の目は通っていない。

### 洗練からの追記 (2026-11-26)

- superpowers の brainstorming は人間との対話を前提にしており、「spec の作成から介入なし」という当てとぶつかる可能性がある。
- spec は人間の意図と完了基準が agent に渡る唯一の場所であり、spec の作成から人間が抜けると中心課題 (完了基準が伝わらない) が悪化する可能性がある。
- 詳細は [03-refinement.md](03-refinement.md) を参照。

## 11. 保留した解決策案

- 現時点では無い。
