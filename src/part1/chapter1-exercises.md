# 第1章 练习题

## 理论题

### 1. 基础概念 (10分)

**题目**：请简述 WebAssembly 的四个核心设计目标，并解释每个目标的重要性。

<details>
<summary>🔍 参考答案</summary>

WebAssembly 的四个核心设计目标：

1. **快速（Fast）**
   - 重要性：提供接近原生代码的执行性能，解决 JavaScript 在计算密集型任务上的性能瓶颈
   - 实现方式：紧凑的二进制格式、高效的验证算法、优化的执行引擎

2. **安全（Safe）**
   - 重要性：继承 Web 平台的安全特性，防止恶意代码对系统造成损害
   - 实现方式：沙箱执行环境、内存隔离、类型安全、验证机制

3. **开放（Open）**
   - 重要性：作为 Web 标准确保跨平台兼容性和长期可用性
   - 实现方式：W3C 标准化、开源实现、厂商无关的设计

4. **可调试（Debuggable）**
   - 重要性：支持开发者进行调试和优化，降低开发门槛
   - 实现方式：文本格式 WAT、源码映射、调试符号支持
</details>

### 2. 架构理解 (15分)

**题目**：WebAssembly 采用栈式虚拟机架构。请解释栈式虚拟机与寄存器虚拟机的区别，并分析 WebAssembly 选择栈式架构的原因。

<details>
<summary>🔍 参考答案</summary>

**栈式虚拟机 vs 寄存器虚拟机：**

| 特性 | 栈式虚拟机 | 寄存器虚拟机 |
|------|-----------|-------------|
| 指令格式 | 操作数隐式在栈上 | 显式指定寄存器地址 |
| 指令长度 | 较短，紧凑 | 较长，包含地址信息 |
| 实现复杂度 | 简单 | 复杂 |
| 验证难度 | 容易 | 困难 |
| 性能 | 需要频繁栈操作 | 减少内存访问 |

**WebAssembly 选择栈式架构的原因：**

1. **简化验证**：栈式指令更容易进行静态分析和类型检查
2. **紧凑编码**：减少指令大小，降低网络传输成本
3. **快速解析**：简化解码过程，提高加载速度
4. **实现简单**：降低虚拟机实现的复杂度
5. **安全性**：栈操作的可预测性有利于安全分析
</details>

### 3. 历史发展 (10分)

**题目**：WebAssembly 的发展经历了哪些重要里程碑？请列出至少5个关键时间点及其意义。

<details>
<summary>🔍 参考答案</summary>

**WebAssembly 发展历程：**

1. **2015年** - 项目启动
   - 意义：四大浏览器厂商联合发起，奠定了跨平台基础

2. **2017年** - MVP 发布
   - 意义：首个可用版本，基本功能完善，开始实际应用

3. **2018年** - W3C 工作组成立
   - 意义：标准化进程启动，确保长期发展

4. **2019年** - 1.0 成为推荐标准
   - 意义：正式成为 Web 标准，获得官方认可

5. **2020年** - WASI 规范发布
   - 意义：扩展到服务器端，不再局限于浏览器环境

6. **2021年** - 2.0 规范制定
   - 意义：引入更多高级特性，如 GC、线程、SIMD 等
</details>

## 实践题

### 4. 性能分析 (20分)

**题目**：创建一个 HTML 页面，实现 JavaScript 和 WebAssembly 版本的阶乘计算函数，并比较其性能差异。

**要求**：
- 计算 factorial(20)
- 使用 `performance.now()` 测量执行时间
- 重复执行 10000 次取平均值
- 显示性能对比结果

<details>
<summary>🔍 参考答案</summary>

**HTML 页面结构：**

```html
<!DOCTYPE html>
<html>
<head>
    <title>WebAssembly vs JavaScript 性能对比</title>
</head>
<body>
    <h1>阶乘计算性能对比</h1>
    <button onclick="runPerformanceTest()">开始测试</button>
    <div id="results"></div>

    <script>
        // JavaScript 版本
        function factorialJS(n) {
            if (n <= 1) return 1;
            return n * factorialJS(n - 1);
        }

        // WebAssembly 版本（需要先加载模块）
        let wasmModule;

        async function loadWasm() {
            // 这里应该加载实际的 WASM 文件
            // 为了演示，我们使用 WAT 格式的内联代码
            const wasmCode = `
                (module
                  (func $factorial (param $n i32) (result i32)
                    (if (result i32)
                      (i32.le_s (local.get $n) (i32.const 1))
                      (then (i32.const 1))
                      (else
                        (i32.mul
                          (local.get $n)
                          (call $factorial
                            (i32.sub (local.get $n) (i32.const 1)))))))
                  (export "factorial" (func $factorial)))
            `;
            
            // 编译 WAT 到 WASM（实际开发中应使用预编译的 .wasm 文件）
            const wasmBuffer = wabtModule.parseWat('inline', wasmCode);
            const wasmBinary = wasmBuffer.toBinary({}).buffer;
            wasmModule = await WebAssembly.instantiate(wasmBinary);
        }

        async function runPerformanceTest() {
            if (!wasmModule) {
                await loadWasm();
            }

            const iterations = 10000;
            const n = 20;

            // 测试 JavaScript 版本
            const jsStart = performance.now();
            for (let i = 0; i < iterations; i++) {
                factorialJS(n);
            }
            const jsEnd = performance.now();
            const jsTime = (jsEnd - jsStart) / iterations;

            // 测试 WebAssembly 版本
            const wasmStart = performance.now();
            for (let i = 0; i < iterations; i++) {
                wasmModule.instance.exports.factorial(n);
            }
            const wasmEnd = performance.now();
            const wasmTime = (wasmEnd - wasmStart) / iterations;

            // 显示结果
            const speedup = jsTime / wasmTime;
            document.getElementById('results').innerHTML = `
                <h2>性能测试结果（${iterations} 次迭代）</h2>
                <p>JavaScript 平均时间: ${jsTime.toFixed(4)} ms</p>
                <p>WebAssembly 平均时间: ${wasmTime.toFixed(4)} ms</p>
                <p>性能提升: ${speedup.toFixed(2)}x</p>
                <p>计算结果: ${factorialJS(n)}</p>
            `;
        }
    </script>
</body>
</html>
```

**对应的 WAT 文件（factorial.wat）：**

```wat
(module
  (func $factorial (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (i32.const 1))
      (else
        (i32.mul
          (local.get $n)
          (call $factorial
            (i32.sub (local.get $n) (i32.const 1)))))))
  (export "factorial" (func $factorial)))
```

**编译命令：**
```bash
wat2wasm factorial.wat -o factorial.wasm
```

**预期结果：**
- WebAssembly 版本通常比 JavaScript 版本快 1.5-3 倍
- 具体性能提升取决于浏览器和硬件平台
</details>

### 5. 应用场景分析 (15分)

**题目**：给定以下几个应用场景，分析每个场景是否适合使用 WebAssembly，并说明理由：

1. 实时聊天应用的消息展示
2. 在线图片编辑器的滤镜处理
3. 电商网站的商品搜索
4. 在线代码编辑器的语法高亮
5. 3D 游戏的物理引擎

<details>
<summary>🔍 参考答案</summary>

**场景分析：**

1. **实时聊天应用的消息展示** - ❌ 不适合
   - 理由：主要涉及 DOM 操作和用户界面更新
   - 建议：使用 JavaScript，配合虚拟 DOM 或高效的更新策略

2. **在线图片编辑器的滤镜处理** - ✅ 非常适合
   - 理由：图像处理是计算密集型任务，涉及大量数值运算
   - 优势：显著的性能提升，现有 C++ 图像库可直接移植

3. **电商网站的商品搜索** - ⚠️ 部分适合
   - 搜索算法部分：如果使用复杂的相似度计算，可以考虑 WASM
   - UI 交互部分：仍需 JavaScript 处理
   - 建议：混合使用，核心算法用 WASM，界面用 JS

4. **在线代码编辑器的语法高亮** - ⚠️ 部分适合
   - 词法分析：可以使用 WASM 提升解析性能
   - DOM 更新：必须使用 JavaScript
   - 建议：语法解析器用 WASM，渲染用 JS

5. **3D 游戏的物理引擎** - ✅ 非常适合
   - 理由：物理模拟涉及大量浮点运算和碰撞检测
   - 优势：接近原生性能，现有物理引擎可移植
</details>

### 6. 工具链调研 (15分)

**题目**：调研并比较至少3种将高级语言编译到 WebAssembly 的工具链，包括支持的语言、特点、使用场景等。

<details>
<summary>🔍 参考答案</summary>

**主要工具链对比：**

| 工具链 | 支持语言 | 主要特点 | 适用场景 |
|--------|----------|----------|----------|
| **Emscripten** | C/C++ | 成熟稳定、生态完善、大型项目支持 | 移植现有 C/C++ 代码库 |
| **wasm-pack** | Rust | 现代化工具、包管理集成、类型安全 | 新项目开发、Web 前端 |
| **TinyGo** | Go | 轻量级、内存占用小、快速编译 | 微服务、云函数 |

**详细分析：**

1. **Emscripten**
   ```bash
   # 安装
   git clone https://github.com/emscripten-core/emsdk.git
   cd emsdk && ./emsdk install latest && ./emsdk activate latest
   
   # 编译示例
   emcc hello.c -o hello.html
   ```
   - 优势：最成熟的工具链，支持大部分 C/C++ 特性
   - 劣势：产生的文件较大，学习曲线陡峭

2. **wasm-pack**
   ```bash
   # 安装
   curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
   
   # 使用示例
   wasm-pack build --target web
   ```
   - 优势：现代化开发体验，优秀的工具集成
   - 劣势：仅支持 Rust，生态相对较新

3. **TinyGo**
   ```bash
   # 安装
   tinygo build -o main.wasm -target wasm main.go
   ```
   - 优势：编译速度快，生成文件小
   - 劣势：功能子集，不支持所有 Go 特性

**推荐选择策略：**
- 有现有 C/C++ 代码：选择 Emscripten
- 新项目追求性能和安全：选择 Rust + wasm-pack
- 简单逻辑快速开发：选择 TinyGo
</details>

### 7. 思考题 (15分)

**题目**：假设你正在开发一个在线视频编辑应用，需要实现视频帧的实时滤镜效果。请设计一个 WebAssembly 和 JavaScript 协作的架构方案，并说明各自的职责分工。

<details>
<summary>🔍 参考答案</summary>

**架构设计方案：**

```
┌─────────────────────────────────────────────────────────┐
│                     用户界面层                          │
│  JavaScript: DOM 操作、用户交互、播放控制                │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────────────┐
│                 业务逻辑层                              │
│  JavaScript: 视频加载、时间轴管理、效果参数调整           │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────────────┐
│                 计算处理层                              │
│  WebAssembly: 图像滤镜算法、像素处理、数值计算           │
└─────────────────────┼───────────────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────────────┐
│                  数据存储层                             │
│  共享内存: 视频帧数据、处理结果缓存                      │
└─────────────────────────────────────────────────────────┘
```

**具体实现方案：**

**1. JavaScript 职责**
```javascript
class VideoEditor {
    constructor() {
        this.wasmModule = null;
        this.videoElement = document.getElementById('video');
        this.canvas = document.getElementById('preview');
        this.ctx = this.canvas.getContext('2d');
    }

    async initWasm() {
        // 加载 WebAssembly 滤镜模块
        this.wasmModule = await WebAssembly.instantiateStreaming(
            fetch('video-filters.wasm')
        );
    }

    // 用户交互处理
    onFilterSelect(filterType, params) {
        this.currentFilter = { type: filterType, params };
        this.applyFilterToCurrentFrame();
    }

    // 视频播放控制
    onTimeUpdate() {
        this.captureCurrentFrame();
        this.applyFilterToCurrentFrame();
        this.renderToCanvas();
    }

    // 帧数据管理
    captureCurrentFrame() {
        this.ctx.drawImage(this.videoElement, 0, 0);
        this.imageData = this.ctx.getImageData(0, 0, 
            this.canvas.width, this.canvas.height);
    }
}
```

**2. WebAssembly 职责**
```wat
(module
  (memory (export "memory") 100)
  
  ;; 亮度调节滤镜
  (func $brightness (param $data i32) (param $length i32) (param $factor f32)
    (local $i i32)
    (local $pixel i32)
    
    (loop $pixel_loop
      ;; 处理每个像素的 RGB 值
      (local.set $pixel (i32.load (local.get $data)))
      
      ;; 应用亮度调节算法
      ;; ... 具体像素处理逻辑
      
      (local.set $i (i32.add (local.get $i) (i32.const 4)))
      (br_if $pixel_loop (i32.lt_u (local.get $i) (local.get $length)))
    ))
  
  ;; 模糊滤镜
  (func $blur (param $data i32) (param $width i32) (param $height i32) 
             (param $radius i32)
    ;; 高斯模糊算法实现
    ;; ...
  )
  
  (export "brightness" (func $brightness))
  (export "blur" (func $blur)))
```

**3. 数据流设计**
```javascript
class FilterProcessor {
    applyFilterToCurrentFrame() {
        // 将图像数据传递给 WebAssembly
        const memory = new Uint8Array(this.wasmModule.instance.exports.memory.buffer);
        const dataPtr = this.allocateMemory(this.imageData.data.length);
        memory.set(this.imageData.data, dataPtr);

        // 调用 WebAssembly 滤镜函数
        switch(this.currentFilter.type) {
            case 'brightness':
                this.wasmModule.instance.exports.brightness(
                    dataPtr, 
                    this.imageData.data.length, 
                    this.currentFilter.params.value
                );
                break;
            case 'blur':
                this.wasmModule.instance.exports.blur(
                    dataPtr,
                    this.canvas.width,
                    this.canvas.height,
                    this.currentFilter.params.radius
                );
                break;
        }

        // 获取处理结果
        this.imageData.data.set(
            memory.subarray(dataPtr, dataPtr + this.imageData.data.length)
        );
    }
}
```

**4. 性能优化策略**
- **内存预分配**：避免频繁内存分配
- **批量处理**：一次处理多帧以减少调用开销
- **Web Workers**：在后台线程处理，避免阻塞 UI
- **缓存机制**：缓存常用滤镜的计算结果

**5. 职责总结**

| 组件 | 职责 | 优势 |
|------|------|------|
| JavaScript | UI 交互、视频控制、数据管理 | DOM 操作便利、丰富的 API |
| WebAssembly | 图像处理算法、数值计算 | 高性能计算、算法复用 |
| 共享内存 | 高效数据传递 | 避免序列化开销 |

这种架构充分发挥了两种技术的优势，实现了高性能的实时视频处理。
</details>

## 评分标准

- **理论题 (40分)**：概念理解准确性、分析深度
- **实践题 (40分)**：代码实现正确性、性能测试有效性
- **思考题 (20分)**：架构设计合理性、技术选型正确性

**总分：100分**
**及格线：60分**

---

**📚 学习提示**：
- 完成练习后，建议实际动手验证答案
- 可以尝试修改参数观察性能变化
- 思考题的答案没有标准，重点在于分析过程