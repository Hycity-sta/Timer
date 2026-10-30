# AGENTS.md

## 自动化工作流与约定规范

### 1. 自动提交代码更改 (Auto Commit on Task Completion)
- **要求**：在每次用户提出的任务需求开发与调试验证完毕后，Agent 必须**自动将所有变更提交到 Git 仓库**。
- **提交规范**：
  - 暂存所有必要的新增与变更文件（遵循 `.gitignore`）。
  - 使用规范的 Conventional Commits 格式撰写清晰明了的 Commit Message（如 `feat:`, `fix:`, `refactor:`, `style:` 等）。
  - 确认提交状态干净（working tree clean）。

### 2. UI 检查与验证规范 (UI Verification)
- **要求**：任务完成之后由用户手动检查，除非特别要求，否则不要直接截图来看 UI 实现效果。

### 3. 运行与验证规范 (Execution and Verification)
- **要求**：
  - 如果没有特别说明，那么在任务完成之后只进行编译和打包，不运行程序进行验证。
  - **每次构建与打包之前，必须先检查是否有正在运行的本应用进程（`TimerApp`）**，防止运行中的进程与新版本或构建过程产生数据冲突；若存在运行中的进程，需先终止进程或确认退出后再执行构建。

