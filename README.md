# cocoon-layout-fix-notes

WordPress（Cocoon）の本文で起きやすい表示崩れを、**検証用の HTML** で再現し、追加 CSS による最小の修正と、修正前後の確認手順を残したメモです。

**これは自作の検証用ページに基づく公開メモであり、顧客案件の実績ではありません。** 特定の公開サイトの不具合を直した記録でもありません。 [ayushio.blog](https://ayushio.blog) の現状を写したものではなく、この作業で同サイトを変更してもいません。

Cocoon は標準でも画像のはみ出しなどにかなり対策があります。ここでは、「幅を指定した画像」「折り返されない長い URL」「列の多い表」が本文幅を超える、という典型を意図的に再現し、**追加 CSS でどこまで戻せるか** を確認しています。

確認に使った環境:

- ブラウザ: Google Chrome（headless を含む）
- OS: Linux（Debian 系）
- 幅: 375px（スマートフォンを見立てた枠）と 1280px（パソコン）

## 1. 症状

検証用ページは `examples/repro-before.html` です。本文エリアの幅は、デスクトップでおよそ 720px に見立てています。

この状態では、次の3つが本文（または画面）の右へはみ出します。

1. **幅 1200px を指定した画像**（`width: 1200px` / `max-width: none`）
2. **空白のない長い URL**（実在しない `example.com` のパス）
3. **列が多く、セルで折り返さない表**（表の幅 980px）

375px の枠で見ると、画像と表が赤い破線の外へ出ます。ページ全体の横スクロールも発生します。1280px 幅でも、1200px の画像と表は本文幅を超え、ページ全体の `scrollWidth` が 1480px まで広がりました（この環境での実測）。

## 2. 切り分け

実際の WordPress サイトでは、次を順に疑うことが多いです。

- テーマの追加 CSS、またはインラインの `width` 指定
- 画像そのもののピクセル幅（メディアに上がっている原寸）
- グローバルメニューやプラグインが出力した表・埋め込み
- キャッシュが古い CSS を返していないか

このメモの検証用ページでは、プラグインもキャッシュも使いません。はみ出しの原因は、上の3つのマークアップと、それを抑える CSS が無いことに限定しています。Cocoon 本体のファイルは使っておらず、本文幅と `.entry-content` というクラス名だけを、同テーマの投稿本文に近づけています。

## 3. 採用した最小の修正

修正は `examples/fix.css` だけです。検証用の「修正後」ページ `examples/repro-after.html` は、同じ HTML にこの CSS を足したものです（表だけ、横スクロール用のラッパーを1つ足しています）。

```css
/* 1. 幅指定の大きい画像を、本文幅に収める */
.entry-content img,
.entry-content .wide-img {
  max-width: 100%;
  height: auto;
}

/* 2. 空白のない長い文字列（長いURLなど）を折り返す */
.entry-content a,
.entry-content p {
  overflow-wrap: anywhere;
  word-break: break-word;
}

/* 3. 広い表は、ページ全体を押さず、枠の中だけ横スクロールする */
.entry-content .table-scroll {
  display: block;
  width: 100%;
  max-width: 100%;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
```

WordPress（Cocoon）に適用する場合の想定場所は、「外観 > カスタマイズ > 追加 CSS」です。**このリポジトリの CSS を、公開サイトへそのまま貼った事実はありません。** 本番では、既存の追加 CSS との相克や、特定ページだけに効かせる必要があるかを、先に確認してください。

表については、CSS だけでは「ページを押さない横スクロール」が安定しにくいことがあります。修正後の HTML では、表を `<div class="table-scroll">` で囲んでいます。Cocoon の投稿なら、カスタム HTML ブロックで同様のラッパーを足す想定です。

## 4. 修正前後のスクリーンショット

いずれも検証用ページを、この環境の Chrome で撮ったものです。顧客サイトの画面ではありません。375px の図は、はみ出しが見えるよう、赤い破線で 375px の枠を描いています。

| 幅 | 修正前 | 修正後 |
| --- | --- | --- |
| 375px | [docs/screenshots/before-375.png](docs/screenshots/before-375.png) | [docs/screenshots/after-375.png](docs/screenshots/after-375.png) |
| 1280px | [docs/screenshots/before-1280.png](docs/screenshots/before-1280.png) | [docs/screenshots/after-1280.png](docs/screenshots/after-1280.png) |

この環境での測定結果（ページ内の測定欄と同じ）:

| 条件 | 基準幅 | 内容の幅（scrollWidth） | ページ全体の横スクロール |
| --- | --- | --- | --- |
| 修正前・375px 枠 | 375px | 1236px | あり |
| 修正後・375px 枠 | 375px | 375px | なし |
| 修正前・1280px | 1280px | 1480px | あり |
| 修正後・1280px | 1280px | 1280px | なし |

修正後の 375px では、表の右端が枠の内側で切れ、**表の中だけ** 横に動かせます。ページ全体は横に動きません。

図の再生成:

```bash
python3 docs/screenshots/render.py
```

（Google Chrome が必要です。撮影用に `?frame=375` を付けると、375px の枠からはみ出す様子を撮れます。）

## 5. 確認方法

1. `examples/repro-before.html` をブラウザで開く
2. 開発者ツールで幅を 375px と 1280px にする（またはウィンドウを狭める）
3. 画像・長い URL・表が本文の右へ出て、ページ全体が横にスクロールすることを見る
4. 同じ幅で `examples/repro-after.html` を開き、画像と URL が収まり、表だけ内側で横スクロールすることを見る
5. ページ下部の測定欄で、`scrollWidth` と「横スクロール=なし / あり」を確認する

本番の WordPress で同様の確認をする場合は、問題の出ているページをパソコンとスマートフォン（または幅を狭めたウィンドウ）の両方で見ます。キャッシュを使っているときは、修正の反映前にキャッシュのクリアも確認します。

## 6. このメモの位置づけ

- 検証用の公開メモであり、顧客案件の実績ではない
- 自サイト ayushio.blog の改修記録でもない（同サイトは変更していない）
- 「即日で必ず直る」とは書いていない。原因が追加 CSS や画像幅で、再現できる範囲の話に限る

## ファイル構成

- `examples/repro-before.html` … 崩れを再現した検証用ページ
- `examples/repro-after.html` … 同じ内容に `fix.css`（と表のラッパー）を足したページ
- `examples/base.css` / `examples/fix.css`
- `assets/dummy-1200.png` … 検証用のダミー画像
- `docs/screenshots/` … 修正前後の図

## ライセンス

MIT License（`LICENSE` を参照）。
