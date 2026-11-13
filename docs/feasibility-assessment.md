# 可行性与隔离

## 当前结论

静态针织图案已接入原版 Pattern 系统，复用毛线材质、窗口发现、生命周期和事件同步。九款节日和花草图案是全局图案选项；By App 保留原应用毛衣。没有新增依赖、动画线程或独立覆盖层。

开发测试在 Apple Silicon Mac 上进行。测试与探针证据见[实现报告](implementation-report.md)，不能推广到所有应用、Space 或显示器。

## 独立开发版身份

上游 CONTRIBUTING 特别说明 `local.knitborders.app` 曾修复菜单 hosting 问题，不能当成纯文案重命名。本轮为避免与已有安装相互控制，分析后统一更改下面的关联点；未自动迁移旧数据。

| 项目 | 上游 | Window Festival |
|---|---|---|
| Bundle ID / 默认偏好域 | local.knitborders.app | local.windowfestival.app |
| 包名 / executable | Window Sweaters.app / WindowSweaters | Window Festival.app / WindowFestival |
| Mach bootstrap 服务 | com.saragordic.window-sweaters | local.windowfestival.ipc |
| Application Support | Knit Borders | Window Festival |
| 启动配置 | .config/window-sweaters/sweatersrc / .sweatersrc | .config/window-festival/festivalrc / .festivalrc |
| installer 的替换范围 | 包括旧 Knit Borders.app | 仅 Window Festival.app，校验对应 Bundle ID |

本地构建可直接运行。安装脚本可选，替换前会备份同标识的旧版本。保留上游内部 C 函数名称、Mach 消息格式和取色队列标签（队列标签不是跨进程注册名）。开发版不自动读取原配置；未来迁移必须显式选择、备份并验证。

## 尚未验证

原生图案库和菜单构建已有自动测试。独立 Bundle ID 的菜单 hosting 仍需实机确认。进程运行、IPC 成功和状态项可见标志都不能替代实际操作。

Finder/Chrome/WebStorm 交互、最小化/恢复、Mission Control、全屏、多显示器和睡眠唤醒仍待验收。通用二进制的两个架构切片不等于已实测 Intel 或其他 macOS。

如果实机无法显示菜单或边框，优先定位 SkyLight/hosting 兼容性。窄边框的针脚数量有限，复杂文字需要更宽的边框；目前只提供手工编排的「春」字，没有任意文字输入功能。
