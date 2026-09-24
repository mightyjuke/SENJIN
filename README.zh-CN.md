[English](README.md) | **简体中文** | [日本語](README.ja.md)

# SENJIN — 先陣

SENJIN 是一款使用 Three.js 制作、可直接在浏览器运行的体素战场动作原型。玩家扮演冲锋在前的先锋战士，突破密集敌阵、击败敌将，并积累 Surge 能量发动大范围破阵技。

项目采用原创虚构战场设定，不使用第三方商业游戏作品中的角色名称、美术、音频、Logo、剧情素材或其他游戏资产。

## 特点

- 普通连击、蓄力攻击、跳跃攻击和闪避组成的长兵器战斗
- 使用 `InstancedMesh` 呈现数百名体素敌兵
- 带生命条的敌方将领
- Surge 能量槽与电影化破阵必杀技
- 程序化战场、城墙、火焰、军旗与 VFX
- WebAudio 程序化音效，不使用下载的商业游戏音频
- 固定 60 Hz 确定性模拟
- 纯 ES Modules，无需构建步骤

## 运行

```sh
python3 -m http.server 8000
```

打开 `http://localhost:8000`。需要支持 WebGL2 的浏览器。

## 许可

- 原项目代码：MIT — [LICENSE](LICENSE)
- Three.js：MIT — [LICENSES/three.js-MIT.txt](LICENSES/three.js-MIT.txt)
- `src/ui/brush.woff2`：Yuji Boku 子集 / SIL Open Font License 1.1 — [LICENSES/Yuji-Boku-OFL-1.1.txt](LICENSES/Yuji-Boku-OFL-1.1.txt)
- 详细归属：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
