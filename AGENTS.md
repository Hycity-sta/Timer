# AGENTS.md

## 自动化工作流与约定规范

### 1. 自动提交代码更改 (Auto Commit on Task Completion)
- **要求**：在每次用户提出的任务需求开发与调试验证完毕后，Agent 必须**自动将所有变更提交到 Git 仓库**。
- **提交规范**：
  - 暂存所有必要的新增与变更文件（遵循 `.gitignore`）。
  - 使用规范的 Conventional Commits 格式撰写清晰明了的 Commit Message（如 `feat:`, `fix:`, `refactor:`, `style:` 等）。
  - 确认提交状态干净（working tree clean）。
