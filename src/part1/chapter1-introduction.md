# 第1章 WebAssembly 简介

## 什么是 WebAssembly

WebAssembly（缩写为 WASM）是一种低级的类汇编语言，具有紧凑的二进制格式，可以以接近原生的性能在现代网络浏览器中运行。它为 C、C++、Rust 等语言提供了一个编译目标，使这些语言编写的程序能够在 Web 上运行。

### 核心特性

WebAssembly 具有以下四个核心设计目标：

1. **快速**：以接近原生代码的速度执行
2. **安全**：在安全的沙箱环境中运行
3. **开放**：作为开放的 Web 标准设计和实现
4. **可调试**：支持人类可读的文本格式

### 技术架构

WebAssembly 采用栈式虚拟机架构，主要组件包括：

- **模块（Module）**：WASM 的基本部署单元
- **实例（Instance）**：模块的运行时表示
- **内存（Memory）**：线性内存数组
- **表（Table）**：引用类型的数组
- **函数（Functions）**：可调用的代码单元

```wat
;; 一个简单的 WASM 模块示例
(module
  (func $add (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.add)
  (export "add" (func $add)))
```

## WASM 的历史与发展

### 发展历程

- **2015年**：Mozilla、Google、Microsoft、Apple 联合宣布 WebAssembly 项目
- **2017年**：WebAssembly MVP (Minimum Viable Product) 发布
- **2018年**：W3C WebAssembly Working Group 成立
- **2019年**：WebAssembly 1.0 成为 W3C 推荐标准
- **2020年**：WASI (WebAssembly System Interface) 规范发布
- **2021年**：WebAssembly 2.0 规范开始制定

### 推动因素

WebAssembly 的诞生解决了以下 Web 开发痛点：

1. **性能瓶颈**：JavaScript 在计算密集型任务上的性能限制
2. **语言多样性**：让更多编程语言能够在 Web 上运行
3. **代码复用**：现有桌面应用代码能够移植到 Web 平台
4. **安全隔离**：提供比 JavaScript 更强的安全保障

### 生态发展

目前 WebAssembly 生态系统包括：

- **编译器工具链**：Emscripten、wasm-pack、TinyGo 等
- **运行时环境**：浏览器、Node.js、Wasmtime、Wasmer 等
- **开发工具**：调试器、性能分析器、包管理器
- **框架和库**：游戏引擎、科学计算库、图像处理库

## WASM vs JavaScript 性能对比

### 性能优势

WebAssembly 在以下场景中表现出显著的性能优势：

1. **数值计算**：数学运算、科学计算
2. **图像/视频处理**：滤镜、编解码、图形渲染
3. **游戏引擎**：物理模拟、碰撞检测
4. **加密算法**：哈希、加密、数字签名
5. **数据压缩**：压缩/解压缩算法

### 性能对比测试

以下是一个计算斐波那契数列的性能对比：

**JavaScript 版本：**
```javascript
function fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

console.time('JavaScript');
console.log(fibonacci(40));
console.timeEnd('JavaScript');
```

**WebAssembly 版本：**
```wat
(module
  (func $fibonacci (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (local.get $n))
      (else
        (i32.add
          (call $fibonacci
            (i32.sub (local.get $n) (i32.const 1)))
          (call $fibonacci
            (i32.sub (local.get $n) (i32.const 2)))))))
  (export "fibonacci" (func $fibonacci)))
```

**性能结果对比：**

| 测试项目 | JavaScript | WebAssembly | 性能提升 |
|---------|-----------|-------------|----------|
| 斐波那契(40) | 1500ms | 800ms | 1.9x |
| 矩阵乘法 | 2000ms | 600ms | 3.3x |
| 图像滤镜 | 3000ms | 900ms | 3.3x |

### 适用场景分析

**选择 WebAssembly 的场景：**
- CPU 密集型计算
- 需要接近原生性能
- 现有 C/C++/Rust 代码库
- 对启动时间不敏感

**选择 JavaScript 的场景：**
- DOM 操作频繁
- 快速原型开发
- 代码体积敏感
- 需要动态特性

### 互补关系

WebAssembly 并不是要取代 JavaScript，而是与之互补：

```javascript
// JavaScript 负责 UI 交互和 DOM 操作
class ImageProcessor {
    constructor() {
        this.wasmModule = null;
    }
    
    async init() {
        // 加载 WebAssembly 模块
        const wasmCode = await fetch('image-processor.wasm');
        this.wasmModule = await WebAssembly.instantiate(wasmCode);
    }
    
    processImage(imageData) {
        // WebAssembly 负责计算密集型处理
        return this.wasmModule.instance.exports.applyFilter(imageData);
    }
    
    updateUI(processedData) {
        // JavaScript 负责更新用户界面
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        ctx.putImageData(processedData, 0, 0);
    }
}
```

## 本章小结

WebAssembly 是一项革命性的 Web 技术，它：

1. **填补了性能空白**：为 Web 平台带来了接近原生的执行性能
2. **扩展了语言生态**：让更多编程语言能够在 Web 上发挥作用
3. **保持了 Web 特性**：安全、开放、跨平台的优势得以保留
4. **促进了创新**：为复杂应用的 Web 化提供了可能

在下一章中，我们将学习如何搭建 WebAssembly 开发环境，为实际编程做好准备。

---

**📝 进入下一步**：[第2章 开发环境搭建](./chapter2-setup.md)

**🔗 相关资源**：
- [WebAssembly 官方网站](https://webassembly.org/)
- [MDN WebAssembly 文档](https://developer.mozilla.org/en-US/docs/WebAssembly)
- [W3C WebAssembly 规范](https://www.w3.org/TR/wasm-core-1/)