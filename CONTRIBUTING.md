# Contributing to WP Examples

Thank you for your interest in contributing to WP Examples! This document provides guidelines and instructions for contributing.

## Branch Strategy

This project uses three release branches with a progressive maturity model:

```
alpha  →  beta  →  main
```

### Branch Descriptions

| Branch | Stability | Description |
|--------|-----------|-------------|
| `alpha` | Experimental | New features and experimental changes. May contain breaking changes. |
| `beta` | Testing | Features that have passed initial testing. More stable than alpha. |
| `main` | Stable | Production-ready code. Fully tested and verified. |

### Maturity Path

1. **alpha**: All new features and experimental work start here
2. **beta**: After testing and stabilization, changes are promoted from alpha to beta
3. **main**: Once thoroughly tested, changes are merged from beta to main for release

## How to Contribute

### 1. Fork and Clone

```bash
git clone https://github.com/your-username/wp-examples.git
cd wp-examples
```

### 2. Create a Feature Branch

Create your feature branch from `alpha`:

```bash
git checkout alpha
git pull origin alpha
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes

- Write clear, concise code
- Follow existing code style and conventions
- Add tests for new functionality
- Update documentation as needed

### 4. Test Your Changes

Run the test suite to ensure your changes work correctly:

```bash
cd core
bash run_all.sh
```

### 5. Commit Your Changes

Write clear commit messages that describe what changed and why:

```bash
git add .
git commit -m "Add feature: brief description of changes"
```

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request targeting the `alpha` branch.

## Pull Request Guidelines

- Target the `alpha` branch for new features
- Provide a clear description of the changes
- Reference any related issues
- Ensure all tests pass
- Keep PRs focused and reasonably sized

## Code Style

- Follow existing patterns in the codebase
- Use meaningful variable and function names
- Keep functions small and focused
- Add comments for complex logic

## Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Provide clear reproduction steps for bugs
- Include relevant system information

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

# 贡献指南

感谢您对 WP Examples 项目的关注！本文档提供贡献指南和说明。

## 分支策略

本项目使用三个发布分支，采用渐进式成熟度模型：

```
alpha  →  beta  →  main
```

### 分支说明

| 分支 | 稳定性 | 描述 |
|------|--------|------|
| `alpha` | 实验性 | 新功能和实验性变更。可能包含破坏性更改。 |
| `beta` | 测试中 | 已通过初步测试的功能。比 alpha 更稳定。 |
| `main` | 稳定版 | 生产就绪的代码。经过完整测试和验证。 |

### 成熟度路径

1. **alpha**：所有新功能和实验性工作从这里开始
2. **beta**：经过测试和稳定后，变更从 alpha 提升到 beta
3. **main**：经过充分测试后，变更从 beta 合并到 main 进行发布

## 如何贡献

### 1. Fork 和克隆

```bash
git clone https://github.com/your-username/wp-examples.git
cd wp-examples
```

### 2. 创建功能分支

从 `alpha` 分支创建您的功能分支：

```bash
git checkout alpha
git pull origin alpha
git checkout -b feature/your-feature-name
```

### 3. 进行修改

- 编写清晰、简洁的代码
- 遵循现有的代码风格和规范
- 为新功能添加测试
- 根据需要更新文档

### 4. 测试您的修改

运行测试套件以确保您的修改正常工作：

```bash
cd core
bash run_all.sh
```

### 5. 提交您的修改

编写清晰的提交信息，描述更改内容和原因：

```bash
git add .
git commit -m "Add feature: 变更的简要描述"
```

### 6. 推送并创建 Pull Request

```bash
git push origin feature/your-feature-name
```

然后创建一个以 `alpha` 分支为目标的 Pull Request。

## Pull Request 指南

- 新功能请以 `alpha` 分支为目标
- 提供清晰的变更描述
- 引用相关的 Issue
- 确保所有测试通过
- 保持 PR 专注且大小合理

## 代码风格

- 遵循代码库中的现有模式
- 使用有意义的变量和函数名
- 保持函数小而专注
- 为复杂逻辑添加注释

## 报告问题

- 使用 GitHub Issues 报告 bug 或建议功能
- 为 bug 提供清晰的复现步骤
- 包含相关的系统信息

## 许可证

通过贡献代码，您同意您的贡献将在 Apache License 2.0 下许可。
