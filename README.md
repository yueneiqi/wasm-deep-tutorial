# WebAssembly 深入教程

[![Built with Nix](https://img.shields.io/badge/Built_With-Nix-5277C3.svg?logo=nixos&labelColor=73C3D5)](https://nixos.org)
[![Made with mdBook](https://img.shields.io/badge/Made%20with-mdBook-orange)](https://rust-lang.github.io/mdBook/)

一份由浅入深的 WebAssembly 完整教程，包含大量习题和参考答案。

## 🚀 快速开始

### 使用 Nix Flakes（推荐）

```bash
# 进入开发环境
nix develop

# 或者如果安装了 direnv
direnv allow

# 查看可用命令
just

# 启动开发服务器
just dev
```

### 传统安装方式

```bash
# 安装必要工具
# mdbook, wabt, emscripten, nodejs, just

# 启动开发服务器
mdbook serve --port 8080
```

## 📚 教程结构

### 第一部分：WebAssembly 基础
- ✅ **第1章**：WebAssembly 简介
- ✅ **第2章**：开发环境搭建  
- ✅ **第3章**：第一个 WASM 程序
- ✅ **第4章**：WebAssembly 文本格式 (WAT)

### 第二部分：核心技术深入
- 🚧 **第5章**：内存管理
- 🚧 **第6章**：控制流
- 🚧 **第7章**：JavaScript 交互

### 第三部分：实践应用
- 📝 **第8章**：从 C/C++ 编译
- 📝 **第9章**：从 Rust 编译
- 📝 **第10章**：性能优化
- 📝 **第11章**：调试技巧
- 📝 **第12章**：实战项目

## 🛠️ 开发工具

本项目使用现代化的开发工具链：

- **[Nix Flakes](https://nixos.wiki/wiki/Flakes)**: 可重现的开发环境
- **[Just](https://github.com/casey/just)**: 现代化的任务运行器
- **[mdBook](https://rust-lang.github.io/mdBook/)**: Rust 生态的文档生成工具
- **[direnv](https://direnv.net/)**: 自动环境变量管理

### 可用命令

```bash
# 📚 文档相关
just dev          # 启动开发服务器（自动重载）
just build         # 构建教程
just clean         # 清理构建文件
just rebuild       # 重新构建

# 🧪 测试和验证
just test          # 运行所有测试
just check-wat     # 检查 WAT 文件语法
just check-links   # 验证 markdown 链接

# 📝 内容管理
just new-chapter name    # 创建新章节
just new-example name    # 添加新的 WAT 示例
just stats              # 统计项目信息

# 🔨 工具
just compile-examples   # 编译所有 WAT 示例
just test-examples     # 测试 WASM 示例
just format           # 格式化代码
just health-check     # 项目健康检查
```

## 🎯 特色功能

### 丰富的练习系统
每章都包含：
- 理论理解题
- 实践编程题
- 综合应用题
- 可折叠的详细参考答案

### 完整的工具链支持
- WAT/WASM 语法检查
- 自动构建和热重载
- 代码示例编译验证
- 多种运行时测试

### 现代化开发环境
- 一键环境搭建
- 依赖版本锁定
- IDE 完整支持
- 自动化任务流程

## 📖 本地开发

### 环境要求

使用 Nix Flakes（零配置）:
- [Nix](https://nixos.org/download.html) 2.4+
- 启用 flakes 支持

或手动安装：
- [mdBook](https://rust-lang.github.io/mdBook/guide/installation.html)
- [WABT](https://github.com/WebAssembly/wabt)
- [Emscripten](https://emscripten.org/docs/getting_started/downloads.html)
- [Node.js](https://nodejs.org/)
- [Just](https://github.com/casey/just)

### VSCode 集成

打开 `wasm-tutorial.code-workspace` 获得完整的 IDE 支持：

- WAT 语法高亮
- 自动构建任务
- 调试配置
- 扩展推荐

### 添加新内容

```bash
# 创建新章节
just new-chapter "part2/chapter5-memory"

# 添加代码示例
just new-example "hello-world"

# 检查语法
just check-wat

# 测试构建
just test
```

## 🚀 部署

### 构建生产版本

```bash
just build-prod
```

### 本地预览

```bash
just preview-prod
```

### 持续集成

项目包含完整的 Nix 包定义，支持：
- 自动化构建
- 依赖缓存
- 多平台支持

## 🤝 贡献指南

1. Fork 本仓库
2. 创建功能分支
3. 使用 `just health-check` 验证更改
4. 提交 Pull Request

### 代码规范

- 使用 `just format` 格式化代码
- 确保 `just test` 通过
- 为新功能添加示例和练习
- 更新相关文档

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [mdBook](https://rust-lang.github.io/mdBook/) - 优秀的文档生成工具
- [WebAssembly](https://webassembly.org/) - 革命性的 Web 技术
- [Nix](https://nixos.org/) - 可重现的构建系统
- [Just](https://github.com/casey/just) - 简洁的任务运行器

---

**📚 开始学习**: 访问 [教程主页](http://localhost:8080) 开始你的 WebAssembly 之旅！