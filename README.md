# ローグライク

ブラウザで遊べる、ドット絵のローグライクゲームです。Godot 4 で作っています。
仕様は [docs/spec.md](docs/spec.md) にあります。

## 遊び方（開発中）

1. [Godot 4.7](https://godotengine.org/download/) をダウンロードする（インストール不要、解凍して起動するだけ）
2. Godot を起動し、「インポート」でこのフォルダの `project.godot` を選ぶ
3. 最初の1回は「編集」で開き、画像やフォントの読み込み（インポート）が終わるのを待つ
4. 右上の ▶（F5）で起動

| 操作 | キー |
| --- | --- |
| 移動 | 矢印キー / WASD / テンキー |
| 斜め移動 | Q・E・Z・C / テンキー 7・9・1・3 |
| 攻撃 | 敵のいる方向へ移動 |
| その場で1ターン待つ | スペース / テンキー 5 |
| 階段を降りる | Enter |

## フォルダ構成

- `scenes/` 画面（シーン）
- `scripts/` ゲームの処理（GDScript）
- `assets/placeholder/` 仮のドット絵。同じ名前の PNG に置き換えれば見た目が変わる
- `fonts/` ドット風フォント DotGothic16（SIL Open Font License、`fonts/OFL.txt`）
- `tests/` 自動テスト

## テスト

```
godot --headless --path . -s tests/run_tests.gd
```
