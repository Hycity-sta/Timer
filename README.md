# Timer (倒计时应用)

基于 Swift & SwiftUI 构建的轻量级原生 macOS 倒计时单窗口应用。

## 规格与标识符规范

- **Bundle Identifier**:
  - Release 版：`com.hycity.timer`
  - Debug 版：`com.hycity.timer.debug`（数据独立隔离）

## 功能特性

- **6 格数字倒计时**：
  - 时（2位）、分（2位）、秒（2位），清晰分隔并带有标签提示。
- **灵活输入与交互**：
  - 点击任意格子可直接键盘输入数字，输入后光标自动跳至下一格。
  - 鼠标悬浮格子时提供上下箭头快速微调（+1 / -1）。
- **运行控制**：
  - **开始 / 暂停 / 继续**：一键控制倒计时。
  - **重置 / 归零**：可一键重置至设定时长或全部归零。
  - **倒计时结束提示**：结束时触发系统提示音与界面提醒。

## 运行与开发

### 方式 1：打包并运行 macOS 原生应用（推荐）
```bash
# 构建 Release 版本 (输出 dist/Timer.app，系统自动本地化为“倒计时”)
./build_app.sh release
open dist/Timer.app

# 构建 Debug 版本 (输出 dist/Timer-Debug.app，系统自动本地化为“倒计时 (Debug)”，数据与 Release 完全隔离)
./build_app.sh debug
open dist/Timer-Debug.app

# 同时构建 Release 与 Debug 版本
./build_app.sh all
```

### 方式 2：终端命令行直接运行
```bash
swift run
```

### 方式 3：使用 Xcode 打开
```bash
xed .
```
或者在 Xcode 中选择 `File` -> `Open...` 打开当前项目目录即可。
