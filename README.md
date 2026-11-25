# 《合炮大爆破 Fuse Smash!》V1.0 上架标准 60 关版（Beta 频道）

严格依照 **RD-SPEC-01 / RD-SPEC-02 / RD-SPEC-03** 与 `levels_v1_60_config.csv` / `level_001_sample.json` 全案规格打造的商业化可上架 V1.0 工程。

## 🌐 在线试玩地址（Beta）
- **GitHub Pages Beta**：https://ynot-labs.github.io/glaze-pop/beta/
- **Release 通道（`main`，待验收合并）**：https://ynot-labs.github.io/glaze-pop/

---

## V1.0 上架标准资产与系统清单

1. **全量 3D / 矢量 / 音频生产资产（总包体 `index.pck` 仅 889 KB）**
   - **7 个标准 glTF 2.0 (`.glb`) 3D 模型**（严格压线）：
     - `beveled_cube.glb`（**精确 92 tris ≤ 96 tris**，2 段圆角倒角 + 光滑权重法线，1 Draw Call `MultiMeshInstance3D`）
     - `pulse_core.glb`（120 tris）、`chain_lock_cage.glb`（144 tris）
     - `cannon_basic.glb`（108 tris）、`cannon_super.glb`（140 tris）
     - `island_ch1_sail.glb`（860 tris，含 5 独立可喷涂 3D 模块）& `island_ch2_dessert.glb`（828 tris，含 5 独立可喷涂 3D 模块）
   - **18 枚矢量 SVG UI 图标**（零 Emoji 模糊，支持全分辨率高清渲染）+ **6 种规范色盲微符号**（实心圆/正三角/菱形/正方形/五角星/十字星）。
   - **14 条核心脆爽音效（`.wav`）+ 2 首无缝循环章节 BGM（`.mp3`，-14 dB）**：Ch.1 108 BPM 电子 Marimba & Ch.2 102 BPM 暖甜 Lo-fi。

2. **全 60 关独立 JSON 蓝图 + 1,000 次蒙特卡洛 Auto-Solver 校验**
   - 严格对齐 `levels_v1_60_config.csv`：**Ch.1 积木启航岛（Lv.1–30）+ Ch.2 街头甜品坊（Lv.31–60）**，全 60 关精确 **15,416 块体素**（Normal 44 关 + Celebration 11 关 + Hard 4 关 + Lv.50 Super Hard 1 关）。
   - 60/60 全部通过 **1,000 次蒙特卡洛 0 道具求解器校验**（总计 60,000 次模拟，0 死局、0 弹药短缺）；打穿 Lv.60 后自动进入 **每日大师挑战无限池**（Lv.11–60 每日随机 20 关）。

3. **严格 7 状态核心引擎 + 前 30 关 FTUE + 混合变现 2.0 & 商店合规**
   - **7 互斥状态机** + 滑屏 210°/0.88 阻尼旋转 + 0.18s 贝塞尔入槽 + **1 阶 Super / 2 阶 Mega 连环合炮** + **360° AutoScan 1.2s 防呆扫描** + 40 刚体对象池。
   - **前 30 关 FTUE**：Lv.1 预置钴蓝炮 + 动画手指指引 5 秒合炮、Lv.2 360° 滑动指引、Lv.3 首次 3D 浮空岛喷涂、Lv.8 脉冲核、Lv.12/18 免费道具赠送、Lv.19 首个红标 Hard 关、Lv.20 自转层、Lv.35 磁吸合拢、Lv.43 电光紫解锁、Lv.55 铁链锁。
   - **6:1 公平经济 & 商业化合规**：5 颗心体力（25 分钟恢复、前 3 步免费重开）、4×50 每日任务、360 币续关、3 局内道具（`+1 槽` 二次确认 + 防连点锁）+ 2 开局前置道具、7 档 IAP SKU + 恢复购买、Lv.1–30 零插屏分层广告、8 类标准 BI 埋点、隐私政策 / ATT / 删除账号与清空存档、4+ 年龄分级、温柔五星好评触发红线。
