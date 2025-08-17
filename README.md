# WebAssembly 深入教程

[![Built with Nix](https://img.shields.io/badge/Built_With-Nix-5277C3.svg?logo=nixos&labelColor=73C3D5)](https://nixos.org)
[![Made with mdBook](https://img.shields.io/badge/Made%20with-mdBook-orange)](https://rust-lang.github.io/mdBook/)

一份由浅入深的 WebAssembly 完整教程，包含大量习题和参考答案。**全面覆盖从基础概念到生产实践的各个方面，包含 12 个核心章节和 4 个实用附录，超过 100 个练习题目。**

> 本项目受到 [知乎文章](https://zhuanlan.zhihu.com/p/1932021734954997646) 的启发。

## 🌟 项目特色

- **📖 内容全面**: 从基础概念到高级优化，涵盖 WebAssembly 技术栈的方方面面
- **🎯 实践导向**: 每章配套练习题，理论与实践相结合
- **🔧 工程化**: 完整的开发环境、构建流程和部署方案
- **⚡ 性能优化**: 深入 SIMD、多线程、内存管理等高级主题
- **🚀 生产就绪**: 真实项目案例分析，包含调试、测试和部署

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
- ✅ **第1章**：WebAssembly 简介 + 练习题
- ✅ **第2章**：开发环境搭建 + 练习题
- ✅ **第3章**：第一个 WASM 程序 + 练习题

### 第二部分：核心技术深入
- ✅ **第4章**：WebAssembly 文本格式 (WAT) + 练习题
- ✅ **第5章**：内存管理 + 练习题
- ✅ **第6章**：控制流 + 练习题
- ✅ **第7章**：JavaScript 交互 + 练习题

### 第三部分：实践应用
- ✅ **第8章**：从 C/C++ 编译 + 练习题
- ✅ **第9章**：从 Rust 编译 + 练习题
- ✅ **第10章**：性能优化 + 练习题
- ✅ **第11章**：调试技巧 + 练习题
- ✅ **第12章**：实战项目 + 练习题

### 附录
- ✅ **附录A**：常用 WAT 指令参考
- ✅ **附录B**：工具链完整指南
- ✅ **附录C**：性能基准测试
- 📝 **附录D**：常见问题解答

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
- 理论理解题（语法、概念、原理分析）
- 实践编程题（WAT 编写、算法实现、性能优化）
- 综合应用题（项目开发、架构设计、调试实战）
- 可折叠的详细参考答案（包含完整代码、测试用例、性能分析）

### 完整的工具链支持
- WAT/WASM 语法检查和编译验证
- 自动构建和热重载开发服务器
- 多语言编译支持（C/C++、Rust → WASM）
- 性能基准测试和优化分析
- 浏览器调试和开发者工具集成

### 现代化开发环境
- 一键环境搭建（Nix Flakes + direnv）
- 版本锁定和可重现构建
- VSCode 完整 IDE 支持（语法高亮、调试、任务）
- 自动化 CI/CD 流程和部署优化

### 深度技术覆盖
**基础技能**：WAT 语法、内存模型、JavaScript 互操作
**工程实践**：多语言编译、构建优化、测试策略
**性能优化**：SIMD 指令、多线程、内存池、缓存策略
**生产部署**：调试技巧、监控分析、真实项目案例

## 🎉 最新更新

### ✅ 教程内容完成情况（2025年1月）

**全部 12 章内容已完成**，包括：

- **📘 第1-3章 (基础篇)**: WebAssembly 简介、环境搭建、第一个程序
- **📗 第4-7章 (核心篇)**: WAT 语法、内存管理、控制流、JS 交互
- **📙 第8-12章 (实践篇)**: C/C++编译、Rust编译、性能优化、调试技巧、实战项目

**练习系统完整覆盖**:
- ✅ 100+ 道练习题，涵盖所有技术点
- ✅ 详细参考答案，包含完整代码实现
- ✅ 从基础语法到生产级项目的完整学习路径

**高级内容亮点**:
- 🎮 **游戏引擎开发**: 完整的 2D 游戏引擎实现（第12章）
- 🖼️ **图像处理应用**: SIMD 优化的图像滤波算法
- 🧮 **科学计算平台**: 矩阵运算、数值积分、统计分析
- 🔧 **性能优化综合**: 内存池、多线程、基准测试
- 🐛 **调试技术大全**: 浏览器工具、源码映射、性能分析

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

感谢所有为 WebAssembly 技术发展做出贡献的先驱者和实践者。本教程的完成离不开开源社区的支持和全球 WebAssembly 专业人士的智慧分享。

特别感谢：

- [mdBook](https://rust-lang.github.io/mdBook/) - 优秀的文档生成工具
- [WebAssembly](https://webassembly.org/) - 革命性的 Web 技术标准
- [Nix](https://nixos.org/) - 可重现的构建系统
- [Just](https://github.com/casey/just) - 简洁的任务运行器
- WebAssembly 社区和规范制定者们的不懈努力
- 所有贡献示例代码、问题反馈和改进建议的开发者们

---

**📚 开始学习**: 访问 [教程主页](http://localhost:8080) 开始你的 WebAssembly 之旅！

---

## 📊 项目统计

- **📖 章节数量**: 12 个核心章节 + 3 个完整附录 + 1 个待完成附录
- **💡 练习题目**: 100+ 道综合练习
- **📝 代码行数**: 20,000+ 行示例代码
- **🛠️ 支持语言**: WAT、JavaScript、Rust、C/C++
- **⚡ 技术栈**: WebAssembly、SIMD、Web Workers、Canvas API
- **🔧 开发工具**: Nix、mdBook、Just、WABT、Emscripten

**🎯 适合人群**: Web 开发者、系统程序员、性能优化工程师、技术学习者

> 💡 这是一份完整且深入的 WebAssembly 学习资源，从零基础到生产应用，助你掌握下一代 Web 技术！