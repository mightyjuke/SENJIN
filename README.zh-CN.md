[English](README.md) | **简体中文** | [日本語](README.ja.md)

# Voxel Musou — 赵云（趙雲）

一款可在浏览器中直接游玩的体素风动作游戏，玩法致敬《真·三国无双》，基于 Three.js 开发。操控赵云，手持长枪，在数百名魏军中杀出一条血路。

无需构建：纯 ES 模块，Three.js r186 已内置于 `vendor/three/`，逻辑以固定 60 Hz 确定性步进运行。

## 特色

- 流畅的普通连招（N1–N6）与蓄力攻击（C1–C6）
- 跳跃、跳跃攻击与闪避
- 打击停顿（hit-stop）与命中特效
- 密集的体素魏军（约 300 人，InstancedMesh），被击飞后碎成体素碎块
- 敌将头顶显示姓名与血条
- 无双乱舞：神龙演出与画面调色
- 黄昏时分的城池战场，火光与旌旗
- 自定义后处理：大气雾霭、景深、泛光、复古像素风
- 程序化生成的 WebAudio 音效
- 书法风格 HUD

## 运行

ES 模块无法通过 `file://` 加载，请用任意静态服务器托管此目录：

```sh
python3 -m http.server 8000
```

然后打开 http://localhost:8000 。需要支持 WebGL2 的浏览器，推荐使用独立显卡的桌面电脑。首次按键或点击后开始播放声音。

## 操作

键盘加鼠标，也可使用手柄。

| 动作 | 按键 |
| --- | --- |
| 移动（相对镜头方向） | WASD / 方向键 |
| 普通攻击 | J / 鼠标左键 |
| 蓄力攻击 | K / 鼠标右键 |
| 跳跃 | 空格 |
| 闪避 | L / Shift |
| 无双 | I |
| 旋转镜头 | 鼠标拖动 / Q E |

## 选项

| URL 参数 | 说明 |
| --- | --- |
| `?enemies=N` | 敌兵数量，0–2000（默认 300） |

## 目录结构

```
index.html      入口、importmap、HUD 样式
src/            core、hero、combat、crowd、musou、camera、vfx、post、world、audio、ui
vendor/three/   Three.js r186
```

## 致谢与许可

- 代码：MIT 许可，见 [LICENSE](LICENSE)。
- [three.js](https://threejs.org/)：MIT 许可。
- HUD 备用字体 `src/ui/brush.woff2` 是 Yuji Boku（Kinuta Font Factory）的子集，采用 SIL Open Font License 1.1 授权。

本项目为同人作品，与 KOEI TECMO 无关，也未获其认可。“Dynasty Warriors”（真·三国无双）是 KOEI TECMO 的商标。本项目不包含任何原作游戏素材。
