[English](README.md) | [简体中文](README.zh-CN.md) | **日本語**

# SENJIN — 先陣

SENJIN は Three.js で作られた、ブラウザで遊べるボクセル戦場アクションのプロトタイプです。先陣を切る戦士として大軍の陣形を突破し、敵将を倒し、Surge ゲージを溜めて広範囲の必殺技を発動します。

本作の戦場・人物・演出はオリジナルの架空設定です。第三者の商用ゲーム作品に由来するキャラクター名、アート、音声、ロゴ、物語素材、ゲームアセットは使用しません。

## 特徴

- 通常連撃、チャージ攻撃、ジャンプ攻撃、回避を備えたポールアーム戦闘
- `InstancedMesh` による数百体規模のボクセル敵兵
- 体力ゲージ付きの敵将
- Surge ゲージとシネマティックな Surge 必殺技
- プロシージャルな戦場、城郭、炎、旗、VFX
- ダウンロード音源を使わない WebAudio のプロシージャル音響
- 固定 60 Hz の決定論的シミュレーション
- ビルド不要の ES Modules 構成

## 起動

```sh
python3 -m http.server 8000
```

`http://localhost:8000` を開いてください。WebGL2 対応ブラウザが必要です。

## ライセンス

- オリジナルコード: MIT — [LICENSE](LICENSE)
- Three.js: MIT — [LICENSES/three.js-MIT.txt](LICENSES/three.js-MIT.txt)
- `src/ui/brush.woff2`: Yuji Boku subset / SIL Open Font License 1.1 — [LICENSES/Yuji-Boku-OFL-1.1.txt](LICENSES/Yuji-Boku-OFL-1.1.txt)
- 詳細: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
