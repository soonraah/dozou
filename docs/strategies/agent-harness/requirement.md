# agent harness の方針策定

## 作りたい戦略

agent harness をどのように実装するかのおおまかな方針を策定する。

## 背景

dozou の開発はなるべく Claude Code にまかせて、人間の作業コストを減らしたい。
できるだけ agent が自立的に作業できるような harness を用意したい。

https://walkinglabs.github.io/learn-harness-engineering/ja/ のサイト内容をベースに agent harness の方針を決めたい。
https://claude.com/ja/resources/articles/building-always-on-agents 等からも取り込めそうな箇所があれば取り込むが、あまり大げさ・複雑な harness にはしたくない。

## 要件

- 使用する agent は Claude Code
- 最初の時点で何もかも完全に用意する必要はなく、harness を進化させていく土台ができていればよい
- branch `chore/claude-code-security` では今回の戦略策定に先駆けてセキュリティまわりの設計・実装を進めていたが、いったんその内容は無視してよい
  - セキュリティ制約が前提として強すぎると期待する自立性が得られないため
