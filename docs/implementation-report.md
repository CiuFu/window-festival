# v0.1 针织图案与本地图案库实现报告

基线为 Window Sweaters `6fc58112ba8f93cabef80b23f2735b3c0533db46`。来源与改动日期见 [NOTICE](../NOTICE.md)。

## 当前实现

- Pattern 菜单提供梅花、灯笼、春、雏菊、竹叶、郁金香、祥云、菱花、柿子九款图案；每个图案由针脚换色构成，复用原版毛线材质、光照与缓存。
- 新图案四边正向、完整重复、同色针织转角，独立配色，默认相邻间隔为 0.75 个图案宽；固定网格，不覆盖原毛衣针脚设置。建议 28 pt 宽度观察文字细节。
- 新增原生 AppKit 图案库：实际针织卡片预览、全部/内置/我的图案筛选、名称/底色/线色/间距/宽度配置。草稿预览独立；保存副本并应用，不覆盖原版。针脚工作台支持从空白绘制或修改样例，共用原版宽度预设，并支持撤销重做、复用图案用色和管理常用色。自制包可移到废纸篓。
- 支持 `.knit.json` 图案包导入导出。校验版本、大小、网格、颜色和数值范围，重复导入创建独立副本；选中包时恢复包内宽度。示例见 `examples/mist-daisy.knit.json`。
- 原来的 By App、其他图案、应用筛选、宽度、灰色/变暗及窗口跟踪保留。窗口中央透明，边缘 tuck 沿用上游。
- 旧春节偏好迁移到灯笼图案；保留旧 theme CLI 别名。旧 JSON/角饰 PNG 不再使用，用户目录旧文件不自动删除。
- 保留开发版 Bundle ID / IPC / 配置目录隔离和显式 CLI 参数优先级。
- 已移除本轮原型引入的主题加载器、装饰 PNG、素材生成脚本和独立图块缓存。

## 修改位置

- `src/chart.c`、`src/misc/chart.h`：九个颜色网格、固定底色与正向标记、包元数据、图案目录隔离及重载。
- `src/knit.c`：局部固定网格、完整图案按可配置间距正向排列、同密度针织收口；独立草稿复用同一渲染器，其他图案沿用原路径。
- `src/library.m`、`src/patterns.m` 及对应头文件：原生图案库、草稿、图案包校验/编码/读取/安装。
- `src/menubar.m`：图案库入口、已有 Pattern 菜单与持久化、固定网格的 Stitch Size 状态、旧偏好迁移。
- `src/main.c`、`src/parse.c`：启动图表加载、CLI 优先级及旧命令别名。
- `src/apps.c`、`src/mach.h`、`src/misc/status_icon.h`、`AppInfo.plist`、构建/安装脚本：开发版身份与路径隔离。
- `tests/festival.m`、`tests/patterns.m`、`tests/library_ui.m`：真实渲染器/解析器、图案包边界、草稿隔离与原生窗口流程；现有 collection/menu/live_resize 测试同步调整。
- README、CONTRIBUTING、NOTICE 及架构/设计/可行性/路线文档：当前行为、来源和验收边界。

## 验证与重现

```sh
make test
make bin/library-ui-test
bin/library-ui-test --editor
./scripts/build-app.sh
codesign --verify --deep --strict "outputs/Window Festival.app"
```

`make test` 覆盖九款图案的渲染与往返编码、导入校验、菜单偏好和原有窗口行为。原生编辑器测试使用临时文件和测试窗口，验证预览、换色、复用图案用色、撤销重做、导入、另存和移除。构建目标为 macOS 13，包含 arm64 和 x86_64 切片。

## 待人工验收与限制

1. 实际点击状态栏菜单和系统文件选择/保存面板；窗口控制器动作、菜单回调、文件校验与读写已分别验证，尚未自动点击完整系统面板流程。
2. Finder/Chrome/WebStorm 多窗口移动、重叠、焦点切换、四边 resize、关闭/最小化/隐藏与恢复。
3. 点击内容、标题栏、窗口按钮和边缘，确认边框不吞鼠标事件。
4. Space、Mission Control、全屏、多显示器/不同缩放比例和睡眠唤醒。
5. 连续运行和批量开关窗口后的 CPU/RSS、闪烁与残留。

目前文字是手工编排的「春」字样例，不是任意文字编辑器；窄边框的辨识度有限。本地图案库不含在线商店、账户/支付或图片转针脚；格式、128 槽容量及文件管理方式见 [图案库说明](pattern-library.md)。没有动画、外凸挂饰或自动节日切换。保留 SkyLight 私有 API 的系统兼容风险。
