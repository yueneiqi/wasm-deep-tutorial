# 第11章 调试技巧

WebAssembly 应用的调试是开发过程中的重要环节。本章将详细介绍各种调试工具、技术和最佳实践，帮助你高效地诊断和解决 WebAssembly 应用中的问题。

## 11.1 调试环境搭建

### 11.1.1 浏览器开发者工具

现代浏览器都提供了强大的 WebAssembly 调试支持，Chrome DevTools 是其中最成熟的工具之一。

#### Chrome DevTools 配置

**启用 WebAssembly 调试功能**：

1. 打开 Chrome DevTools (F12)
2. 进入 Settings → Experiments
3. 启用以下功能：
   - "WebAssembly Debugging: Enable DWARF support"
   - "WebAssembly Debugging: Enable scope inspection"
   - "WebAssembly Debugging: Enable stack inspection"

**调试界面说明**：

```javascript
// 加载带调试信息的 WASM 模块
async function loadWasmWithDebugInfo() {
  try {
    // 确保 WASM 文件包含调试符号
    const response = await fetch('debug_module.wasm');
    const wasmBytes = await response.arrayBuffer();
    
    // 加载时保留调试信息
    const wasmModule = await WebAssembly.instantiate(wasmBytes, {
      env: {
        debug_log: (value) => {
          console.log('WASM Debug:', value);
          // 在控制台中设置断点便于调试
          debugger;
        }
      }
    });
    
    return wasmModule.instance.exports;
  } catch (error) {
    console.error('WASM 加载失败:', error);
    throw error;
  }
}

// 调试辅助函数
function setupWasmDebugging(wasmExports) {
  // 包装 WASM 函数以添加调试信息
  const originalFunction = wasmExports.compute;
  
  wasmExports.compute = function(...args) {
    console.group('WASM Function Call: compute');
    console.log('Arguments:', args);
    console.time('execution_time');
    
    try {
      const result = originalFunction.apply(this, args);
      console.log('Result:', result);
      return result;
    } catch (error) {
      console.error('WASM Error:', error);
      throw error;
    } finally {
      console.timeEnd('execution_time');
      console.groupEnd();
    }
  };
}
```

#### Firefox Developer Edition

Firefox 也提供了出色的 WebAssembly 调试支持：

```javascript
// Firefox 特定的调试配置
function setupFirefoxWasmDebugging() {
  // 启用 WebAssembly 基线编译器（便于调试）
  if (typeof WebAssembly !== 'undefined') {
    console.log('WebAssembly 支持检测:');
    console.log('- 基础支持:', !!WebAssembly.Module);
    console.log('- 流式编译:', !!WebAssembly.compileStreaming);
    console.log('- 实例化:', !!WebAssembly.instantiateStreaming);
    
    // 检查调试符号支持
    if (WebAssembly.Module.exports) {
      console.log('- 导出函数检查: 支持');
    }
  }
}

// 内存调试辅助
function debugWasmMemory(wasmInstance) {
  const memory = wasmInstance.exports.memory;
  
  return {
    // 查看内存使用情况
    getMemoryInfo() {
      const buffer = memory.buffer;
      return {
        byteLength: buffer.byteLength,
        pages: buffer.byteLength / 65536,
        maxPages: memory.maximum || 'unlimited'
      };
    },
    
    // 内存转储
    dumpMemory(offset = 0, length = 64) {
      const view = new Uint8Array(memory.buffer, offset, length);
      const hex = Array.from(view)
        .map(b => b.toString(16).padStart(2, '0'))
        .join(' ');
      console.log(`Memory dump at ${offset}:`, hex);
      return view;
    },
    
    // 监控内存增长
    watchMemoryGrowth() {
      let lastSize = memory.buffer.byteLength;
      
      const observer = setInterval(() => {
        const currentSize = memory.buffer.byteLength;
        if (currentSize !== lastSize) {
          console.log(`Memory grew: ${lastSize} → ${currentSize} bytes`);
          lastSize = currentSize;
        }
      }, 1000);
      
      return () => clearInterval(observer);
    }
  };
}
```

### 11.1.2 源码映射配置

源码映射让你能够在原始源代码级别进行调试，而不是在编译后的 WebAssembly 字节码级别。

#### DWARF 调试信息

**Rust 项目配置**：

```toml
# Cargo.toml
[package]
name = "wasm-debug-demo"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

# 调试配置
[profile.dev]
debug = true           # 启用调试符号
debug-assertions = true
overflow-checks = true
lto = false           # 调试时禁用 LTO
opt-level = 0         # 禁用优化便于调试

[profile.release-with-debug]
inherits = "release"
debug = true          # 发布版本也包含调试信息
strip = false         # 不剥离调试符号

[dependencies]
wasm-bindgen = { version = "0.2", features = ["serde-serialize"] }
console_error_panic_hook = "0.1"
wee_alloc = "0.4"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
  "Performance",
]
```

**构建脚本配置**：

```bash
#!/bin/bash
# build-debug.sh - 构建带调试信息的 WASM

# 设置 Rust 标志
export RUSTFLAGS="-C debuginfo=2 -C force-frame-pointers=yes"

# 使用 wasm-pack 构建
wasm-pack build \
  --target web \
  --out-dir pkg \
  --dev \
  --scope myorg \
  --debug

# 或者使用 cargo 直接构建
# cargo build --target wasm32-unknown-unknown --profile dev

# 验证调试信息
if command -v wasm-objdump &> /dev/null; then
  echo "检查调试段..."
  wasm-objdump -h pkg/wasm_debug_demo.wasm | grep -E "(debug|name)"
fi

# 生成人类可读的 WAT 文件
if command -v wasm2wat &> /dev/null; then
  echo "生成 WAT 文件..."
  wasm2wat pkg/wasm_debug_demo.wasm -o pkg/wasm_debug_demo.wat
fi
```

#### C/C++ 调试配置

**Emscripten 调试构建**：

```bash
# 调试版本编译
emcc -O0 -g4 \
     -s WASM=1 \
     -s MODULARIZE=1 \
     -s EXPORT_NAME="DebugModule" \
     -s ASSERTIONS=1 \
     -s SAFE_HEAP=1 \
     -s STACK_OVERFLOW_CHECK=2 \
     -s DEMANGLE_SUPPORT=1 \
     -s EXPORTED_FUNCTIONS='["_main", "_debug_function"]' \
     -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
     --source-map-base http://localhost:8080/ \
     input.c -o debug_output.js

# 高级调试选项
emcc -O0 -g4 \
     -s WASM=1 \
     -s ASSERTIONS=2 \
     -s SAFE_HEAP=1 \
     -s STACK_OVERFLOW_CHECK=2 \
     -s RUNTIME_DEBUG=1 \
     -s GL_DEBUG=1 \
     --profiling \
     --profiling-funcs \
     --emit-symbol-map \
     input.c -o advanced_debug.js
```

**源码文件示例**：

```c
// debug_example.c
#include <stdio.h>
#include <stdlib.h>
#include <emscripten.h>

// 调试宏定义
#ifdef DEBUG
#define DBG_LOG(fmt, ...) printf("[DEBUG] " fmt "\n", ##__VA_ARGS__)
#else
#define DBG_LOG(fmt, ...)
#endif

// 带调试信息的函数
EMSCRIPTEN_KEEPALIVE
int debug_function(int a, int b) {
    DBG_LOG("debug_function called with a=%d, b=%d", a, b);
    
    // 人为添加断点位置
    int result = 0;
    
    if (a > 0) {
        DBG_LOG("a is positive");
        result += a * 2;
    }
    
    if (b > 0) {
        DBG_LOG("b is positive");  
        result += b * 3;
    }
    
    DBG_LOG("result = %d", result);
    return result;
}

// 内存调试辅助函数
EMSCRIPTEN_KEEPALIVE
void debug_memory_info() {
    size_t heap_size = EM_ASM_INT({
        return HEAP8.length;
    });
    
    printf("Heap size: %zu bytes\n", heap_size);
    
    // 显示栈信息
    EM_ASM({
        console.log('Stack pointer:', stackPointer);
        console.log('Stack max:', STACK_MAX);
    });
}

int main() {
    printf("Debug demo initialized\n");
    debug_memory_info();
    return 0;
}
```

### 11.1.3 调试工具扩展

#### VS Code WebAssembly 扩展

**安装和配置**：

```json
// .vscode/settings.json
{
  "wasm.wabt.path": "/usr/local/bin",
  "wasm.showBinaryView": true,
  "wasm.showTextView": true,
  "files.associations": {
    "*.wat": "wasm",
    "*.wast": "wasm"
  },
  "debug.toolBarLocation": "docked",
  "debug.inlineValues": true
}

// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch WebAssembly Debug",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/debug_server.js",
      "console": "integratedTerminal",
      "env": {
        "NODE_ENV": "development"
      }
    },
    {
      "name": "Attach to Chrome",
      "port": 9222,
      "request": "attach",
      "type": "chrome",
      "webRoot": "${workspaceFolder}",
      "urlFilter": "http://localhost:*",
      "sourceMapPathOverrides": {
        "webpack:///./src/*": "${webRoot}/src/*"
      }
    }
  ]
}

// .vscode/tasks.json  
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build WASM Debug",
      "type": "shell",
      "command": "./build-debug.sh",
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "problemMatcher": []
    },
    {
      "label": "Start Debug Server",
      "type": "shell", 
      "command": "node",
      "args": ["debug_server.js"],
      "group": "test",
      "isBackground": true
    }
  ]
}
```

## 11.2 断点调试技术

### 11.2.1 设置和管理断点

#### 源码级别断点

在支持源码映射的环境中，你可以直接在原始代码中设置断点：

```rust
// src/lib.rs - Rust 源码示例
use wasm_bindgen::prelude::*;

// 导入 console.log 用于调试输出
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 调试宏
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub struct DebugCounter {
    value: i32,
    step: i32,
}

#[wasm_bindgen]
impl DebugCounter {
    #[wasm_bindgen(constructor)]
    pub fn new(initial: i32, step: i32) -> DebugCounter {
        console_log!("Creating DebugCounter: initial={}, step={}", initial, step);
        
        // 这里可以设置断点
        DebugCounter {
            value: initial,
            step,
        }
    }
    
    #[wasm_bindgen]
    pub fn increment(&mut self) -> i32 {
        console_log!("Before increment: value={}", self.value);
        
        // 断点位置 - 检查状态变化
        self.value += self.step;
        
        console_log!("After increment: value={}", self.value);
        
        // 条件断点示例
        if self.value > 100 {
            console_log!("Warning: value exceeded 100!");
            // 在这里设置条件断点
        }
        
        self.value
    }
    
    #[wasm_bindgen]
    pub fn reset(&mut self) {
        console_log!("Resetting counter from {} to 0", self.value);
        self.value = 0;
    }
    
    #[wasm_bindgen(getter)]
    pub fn value(&self) -> i32 {
        self.value
    }
}

// 复杂计算函数，便于调试
#[wasm_bindgen]
pub fn debug_complex_calculation(input: &[f32]) -> Vec<f32> {
    console_log!("Starting complex calculation with {} elements", input.len());
    
    let mut result = Vec::with_capacity(input.len());
    
    for (i, &value) in input.iter().enumerate() {
        // 逐步调试每个元素的处理
        console_log!("Processing element {}: {}", i, value);
        
        let processed = if value < 0.0 {
            console_log!("Negative value detected: {}", value);
            value.abs()
        } else if value > 1.0 {
            console_log!("Large value detected: {}", value);
            value.sqrt()
        } else {
            value * value
        };
        
        result.push(processed);
        
        // 检查异常值
        if processed.is_nan() || processed.is_infinite() {
            console_log!("WARNING: Invalid result at index {}: {}", i, processed);
        }
    }
    
    console_log!("Calculation completed, {} results", result.len());
    result
}
```

#### JavaScript 端断点辅助

```javascript
// debug_helpers.js
class WasmDebugger {
    constructor(wasmInstance) {
        this.instance = wasmInstance;
        this.breakpoints = new Map();
        this.callStack = [];
        this.variableWatches = new Map();
    }
    
    // 函数调用跟踪
    traceFunction(functionName) {
        const originalFunction = this.instance[functionName];
        
        this.instance[functionName] = (...args) => {
            const callId = Date.now();
            
            console.group(`🔍 WASM Call: ${functionName} (${callId})`);
            console.log('Arguments:', args);
            console.time(`execution-${callId}`);
            
            this.callStack.push({
                name: functionName,
                args: args,
                timestamp: callId
            });
            
            try {
                const result = originalFunction.apply(this.instance, args);
                console.log('Result:', result);
                return result;
            } catch (error) {
                console.error('Error:', error);
                throw error;
            } finally {
                console.timeEnd(`execution-${callId}`);
                console.groupEnd();
                this.callStack.pop();
            }
        };
    }
    
    // 内存监控断点
    setMemoryBreakpoint(address, size, type = 'write') {
        const memory = this.instance.memory;
        const id = `mem_${address}_${size}`;
        
        // 创建内存视图
        const originalView = new Uint8Array(memory.buffer, address, size);
        const snapshot = new Uint8Array(originalView);
        
        const checkMemory = () => {
            const currentView = new Uint8Array(memory.buffer, address, size);
            
            for (let i = 0; i < size; i++) {
                if (currentView[i] !== snapshot[i]) {
                    console.log(`🚨 Memory ${type} at address ${address + i}:`);
                    console.log(`  Old value: 0x${snapshot[i].toString(16)}`);
                    console.log(`  New value: 0x${currentView[i].toString(16)}`);
                    
                    // 触发断点
                    debugger;
                    
                    // 更新快照
                    snapshot[i] = currentView[i];
                }
            }
        };
        
        this.breakpoints.set(id, setInterval(checkMemory, 100));
        console.log(`Memory breakpoint set at 0x${address.toString(16)}, size: ${size}`);
        
        return id;
    }
    
    // 变量监控
    watchVariable(getter, name) {
        let lastValue = getter();
        
        const watchId = setInterval(() => {
            const currentValue = getter();
            if (currentValue !== lastValue) {
                console.log(`📊 Variable '${name}' changed:`);
                console.log(`  From: ${lastValue}`);
                console.log(`  To: ${currentValue}`);
                
                // 记录变化历史
                if (!this.variableWatches.has(name)) {
                    this.variableWatches.set(name, []);
                }
                
                this.variableWatches.get(name).push({
                    timestamp: Date.now(),
                    oldValue: lastValue,
                    newValue: currentValue,
                    callStack: [...this.callStack]
                });
                
                lastValue = currentValue;
            }
        }, 50);
        
        return watchId;
    }
    
    // 清除断点
    clearBreakpoint(id) {
        if (this.breakpoints.has(id)) {
            clearInterval(this.breakpoints.get(id));
            this.breakpoints.delete(id);
            console.log(`Breakpoint ${id} cleared`);
        }
    }
    
    // 获取调试报告
    getDebugReport() {
        return {
            activeBreakpoints: Array.from(this.breakpoints.keys()),
            callStack: this.callStack,
            variableHistory: Object.fromEntries(this.variableWatches),
            memoryInfo: this.getMemoryInfo()
        };
    }
    
    getMemoryInfo() {
        if (!this.instance.memory) return null;
        
        const buffer = this.instance.memory.buffer;
        return {
            byteLength: buffer.byteLength,
            pages: buffer.byteLength / 65536,
            detached: buffer.detached || false
        };
    }
}

// 使用示例
async function setupDebugging() {
    const wasmModule = await import('./pkg/wasm_debug_demo.js');
    await wasmModule.default();
    
    const debugger = new WasmDebugger(wasmModule);
    
    // 跟踪特定函数
    debugger.traceFunction('debug_complex_calculation');
    
    // 创建计数器实例
    const counter = new wasmModule.DebugCounter(0, 5);
    
    // 监控计数器值
    const watchId = debugger.watchVariable(
        () => counter.value, 
        'counter.value'
    );
    
    // 设置内存断点（如果知道内存地址）
    // const memBreakpoint = debugger.setMemoryBreakpoint(0x1000, 16);
    
    // 测试代码
    console.log('Starting debug test...');
    
    for (let i = 0; i < 10; i++) {
        counter.increment();
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // 复杂计算测试
    const testData = [0.5, -2.3, 1.8, 0.1, -0.9];
    const result = wasmModule.debug_complex_calculation(new Float32Array(testData));
    
    console.log('Debug test completed');
    console.log('Final report:', debugger.getDebugReport());
    
    return debugger;
}
```

### 11.2.2 条件断点和日志点

#### 高级断点技术

```rust
// 带条件的调试代码
#[wasm_bindgen]
pub struct AdvancedDebugger {
    debug_enabled: bool,
    log_level: u32,
    breakpoint_conditions: std::collections::HashMap<String, bool>,
}

#[wasm_bindgen]
impl AdvancedDebugger {
    #[wasm_bindgen(constructor)]
    pub fn new(debug_enabled: bool) -> AdvancedDebugger {
        AdvancedDebugger {
            debug_enabled,
            log_level: 1,
            breakpoint_conditions: std::collections::HashMap::new(),
        }
    }
    
    // 条件调试日志
    fn debug_log(&self, level: u32, message: &str) {
        if self.debug_enabled && level >= self.log_level {
            let level_str = match level {
                0 => "TRACE",
                1 => "DEBUG", 
                2 => "INFO",
                3 => "WARN",
                4 => "ERROR",
                _ => "UNKNOWN",
            };
            console_log!("[{}] {}", level_str, message);
        }
    }
    
    // 条件断点辅助
    fn should_break(&self, condition_name: &str) -> bool {
        if !self.debug_enabled {
            return false;
        }
        
        // 检查断点条件
        self.breakpoint_conditions.get(condition_name)
            .copied()
            .unwrap_or(false)
    }
    
    #[wasm_bindgen]
    pub fn process_array(&mut self, data: &[i32]) -> Vec<i32> {
        self.debug_log(1, &format!("Processing array of {} elements", data.len()));
        
        let mut result = Vec::new();
        let mut error_count = 0;
        
        for (index, &value) in data.iter().enumerate() {
            self.debug_log(0, &format!("Processing element {}: {}", index, value));
            
            let processed = match value {
                v if v < 0 => {
                    self.debug_log(2, &format!("Negative value: {}", v));
                    
                    // 条件断点：遇到负数时
                    if self.should_break("negative_value") {
                        console_log!("🛑 Breakpoint: Negative value encountered at index {}", index);
                        // 这里会在浏览器中触发断点
                    }
                    
                    -v
                },
                v if v > 1000 => {
                    error_count += 1;
                    self.debug_log(3, &format!("Large value warning: {}", v));
                    
                    // 条件断点：错误计数达到阈值
                    if error_count > 3 && self.should_break("error_threshold") {
                        console_log!("🛑 Breakpoint: Error count exceeded threshold");
                    }
                    
                    1000
                },
                v => {
                    self.debug_log(0, &format!("Normal value: {}", v));
                    v * 2
                }
            };
            
            result.push(processed);
            
            // 性能监控断点
            if index % 100 == 0 && index > 0 {
                self.debug_log(1, &format!("Progress: {} elements processed", index));
                
                if self.should_break("progress_check") {
                    console_log!("🛑 Breakpoint: Progress checkpoint at {}", index);
                }
            }
        }
        
        self.debug_log(1, &format!("Array processing completed. {} errors encountered", error_count));
        result
    }
    
    #[wasm_bindgen]
    pub fn set_breakpoint_condition(&mut self, name: String, enabled: bool) {
        self.breakpoint_conditions.insert(name, enabled);
    }
    
    #[wasm_bindgen]
    pub fn set_log_level(&mut self, level: u32) {
        self.log_level = level;
        self.debug_log(1, &format!("Log level set to {}", level));
    }
}
```

#### JavaScript 条件断点管理

```javascript
// 条件断点管理器
class ConditionalBreakpointManager {
    constructor() {
        this.conditions = new Map();
        this.logPoints = new Map();
        this.hitCounts = new Map();
    }
    
    // 设置条件断点
    setConditionalBreakpoint(name, condition, options = {}) {
        const config = {
            condition: condition,
            hitCountTarget: options.hitCountTarget || null,
            enabled: options.enabled !== false,
            logMessage: options.logMessage || null,
            onHit: options.onHit || (() => debugger)
        };
        
        this.conditions.set(name, config);
        this.hitCounts.set(name, 0);
        
        console.log(`Conditional breakpoint '${name}' set:`, config);
    }
    
    // 检查断点条件
    checkBreakpoint(name, context = {}) {
        const config = this.conditions.get(name);
        if (!config || !config.enabled) return false;
        
        // 增加命中次数
        const hitCount = this.hitCounts.get(name) + 1;
        this.hitCounts.set(name, hitCount);
        
        // 检查命中次数条件
        if (config.hitCountTarget && hitCount !== config.hitCountTarget) {
            return false;
        }
        
        // 检查条件表达式
        let conditionMet = true;
        if (config.condition) {
            try {
                // 安全地评估条件
                conditionMet = this.evaluateCondition(config.condition, context);
            } catch (error) {
                console.error(`Breakpoint condition error for '${name}':`, error);
                return false;
            }
        }
        
        if (conditionMet) {
            // 记录日志信息
            if (config.logMessage) {
                console.log(`🔍 Breakpoint '${name}' hit:`, 
                    this.interpolateLogMessage(config.logMessage, context));
            }
            
            // 执行命中处理
            config.onHit(context, hitCount);
            return true;
        }
        
        return false;
    }
    
    // 安全的条件评估
    evaluateCondition(condition, context) {
        // 创建安全的评估环境
        const safeContext = {
            ...context,
            // 添加常用的辅助函数
            Math: Math,
            console: console,
            Date: Date
        };
        
        // 简单的条件解析（生产环境应使用更安全的方式）
        const func = new Function(...Object.keys(safeContext), `return ${condition}`);
        return func(...Object.values(safeContext));
    }
    
    // 日志消息插值
    interpolateLogMessage(message, context) {
        return message.replace(/\{(\w+)\}/g, (match, key) => {
            return context[key] !== undefined ? context[key] : match;
        });
    }
    
    // 设置日志点（不中断执行）
    setLogPoint(name, message, condition = null) {
        this.logPoints.set(name, {
            message: message,
            condition: condition,
            enabled: true
        });
    }
    
    // 检查日志点
    checkLogPoint(name, context = {}) {
        const logPoint = this.logPoints.get(name);
        if (!logPoint || !logPoint.enabled) return;
        
        let shouldLog = true;
        if (logPoint.condition) {
            try {
                shouldLog = this.evaluateCondition(logPoint.condition, context);
            } catch (error) {
                console.error(`Log point condition error for '${name}':`, error);
                return;
            }
        }
        
        if (shouldLog) {
            console.log(`📝 LogPoint '${name}':`, 
                this.interpolateLogMessage(logPoint.message, context));
        }
    }
    
    // 获取断点统计
    getStatistics() {
        const stats = {
            breakpoints: {},
            logPoints: {},
            totalHits: 0
        };
        
        for (const [name, hitCount] of this.hitCounts) {
            stats.breakpoints[name] = {
                hitCount: hitCount,
                enabled: this.conditions.get(name)?.enabled || false
            };
            stats.totalHits += hitCount;
        }
        
        for (const [name, config] of this.logPoints) {
            stats.logPoints[name] = {
                enabled: config.enabled,
                message: config.message
            };
        }
        
        return stats;
    }
    
    // 清除所有断点
    clearAll() {
        this.conditions.clear();
        this.logPoints.clear();
        this.hitCounts.clear();
        console.log('All breakpoints and log points cleared');
    }
}

// 集成示例
async function demonstrateConditionalDebugging() {
    const breakpointManager = new ConditionalBreakpointManager();
    
    // 设置各种条件断点
    breakpointManager.setConditionalBreakpoint('negative_numbers', 'value < 0', {
        logMessage: 'Negative number detected: {value} at index {index}',
        onHit: (context) => {
            console.warn('Processing negative number:', context);
            debugger; // 实际断点
        }
    });
    
    breakpointManager.setConditionalBreakpoint('every_10th', 'index % 10 === 0 && index > 0', {
        hitCountTarget: 3, // 只在第3次命中时停止
        logMessage: 'Every 10th element checkpoint: index {index}'
    });
    
    breakpointManager.setLogPoint('processing_log', 
        'Processing element {index}: {value} -> {result}');
    
    // 模拟数据处理
    const testData = [-5, 3, -8, 12, 7, -1, 9, 15, -3, 6, 8, -2];
    
    for (let index = 0; index < testData.length; index++) {
        const value = testData[index];
        const result = Math.abs(value) * 2;
        
        const context = { index, value, result };
        
        // 检查断点
        breakpointManager.checkBreakpoint('negative_numbers', context);
        breakpointManager.checkBreakpoint('every_10th', context);
        
        // 检查日志点
        breakpointManager.checkLogPoint('processing_log', context);
        
        // 模拟处理延迟
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log('Final statistics:', breakpointManager.getStatistics());
}
```

## 11.3 内存调试技术

### 11.3.1 内存泄漏检测

内存泄漏是 WebAssembly 应用中常见的问题，特别是在处理大量数据或长时间运行的应用中。

#### 内存使用监控

```rust
// 内存监控和泄漏检测
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

static ALLOCATION_COUNT: AtomicUsize = AtomicUsize::new(0);
static TOTAL_ALLOCATED: AtomicUsize = AtomicUsize::new(0);
static TOTAL_FREED: AtomicUsize = AtomicUsize::new(0);

#[wasm_bindgen]
pub struct MemoryLeakDetector {
    allocations: HashMap<usize, AllocationInfo>,
    next_id: usize,
    threshold_bytes: usize,
    monitoring_enabled: bool,
}

#[derive(Clone)]
struct AllocationInfo {
    size: usize,
    timestamp: f64,
    stack_trace: String,
}

#[wasm_bindgen]
impl MemoryLeakDetector {
    #[wasm_bindgen(constructor)]
    pub fn new(threshold_bytes: usize) -> MemoryLeakDetector {
        console_log!("Memory leak detector initialized with threshold: {} bytes", threshold_bytes);
        
        MemoryLeakDetector {
            allocations: HashMap::new(),
            next_id: 1,
            threshold_bytes,
            monitoring_enabled: true,
        }
    }
    
    // 记录内存分配
    #[wasm_bindgen]
    pub fn track_allocation(&mut self, size: usize) -> usize {
        if !self.monitoring_enabled {
            return 0;
        }
        
        let id = self.next_id;
        self.next_id += 1;
        
        let timestamp = js_sys::Date::now();
        let stack_trace = self.get_stack_trace();
        
        self.allocations.insert(id, AllocationInfo {
            size,
            timestamp,
            stack_trace,
        });
        
        ALLOCATION_COUNT.fetch_add(1, Ordering::Relaxed);
        TOTAL_ALLOCATED.fetch_add(size, Ordering::Relaxed);
        
        console_log!("Allocation tracked: ID={}, size={} bytes", id, size);
        
        // 检查是否超过阈值
        if self.get_current_usage() > self.threshold_bytes {
            console_log!("⚠️  Memory usage exceeded threshold: {} bytes", self.get_current_usage());
        }
        
        id
    }
    
    // 记录内存释放
    #[wasm_bindgen]
    pub fn track_deallocation(&mut self, id: usize) -> bool {
        if let Some(info) = self.allocations.remove(&id) {
            TOTAL_FREED.fetch_add(info.size, Ordering::Relaxed);
            console_log!("Deallocation tracked: ID={}, size={} bytes", id, info.size);
            true
        } else {
            console_log!("⚠️  Invalid deallocation attempt: ID={}", id);
            false
        }
    }
    
    // 获取当前内存使用量
    #[wasm_bindgen]
    pub fn get_current_usage(&self) -> usize {
        self.allocations.values().map(|info| info.size).sum()
    }
    
    // 检测潜在的内存泄漏
    #[wasm_bindgen]
    pub fn detect_leaks(&self, max_age_ms: f64) -> String {
        let current_time = js_sys::Date::now();
        let mut leak_report = String::new();
        let mut total_leaked = 0;
        let mut leak_count = 0;
        
        leak_report.push_str("🔍 Memory Leak Detection Report\n");
        leak_report.push_str(&format!("Current usage: {} bytes\n", self.get_current_usage()));
        leak_report.push_str(&format!("Total allocations: {}\n", ALLOCATION_COUNT.load(Ordering::Relaxed)));
        leak_report.push_str(&format!("Total allocated: {} bytes\n", TOTAL_ALLOCATED.load(Ordering::Relaxed)));
        leak_report.push_str(&format!("Total freed: {} bytes\n", TOTAL_FREED.load(Ordering::Relaxed)));
        leak_report.push_str("\n");
        
        for (id, info) in &self.allocations {
            let age = current_time - info.timestamp;
            if age > max_age_ms {
                leak_report.push_str(&format!(
                    "🚨 Potential leak - ID: {}, Size: {} bytes, Age: {:.1}s\n",
                    id, info.size, age / 1000.0
                ));
                leak_report.push_str(&format!("   Stack trace: {}\n", info.stack_trace));
                total_leaked += info.size;
                leak_count += 1;
            }
        }
        
        if leak_count > 0 {
            leak_report.push_str(&format!("\n💥 {} potential leaks found, {} bytes total\n", leak_count, total_leaked));
        } else {
            leak_report.push_str("\n✅ No memory leaks detected\n");
        }
        
        leak_report
    }
    
    // 获取内存使用统计
    #[wasm_bindgen]
    pub fn get_statistics(&self) -> String {
        let current_usage = self.get_current_usage();
        let allocation_count = self.allocations.len();
        
        // 按大小分组统计
        let mut size_buckets = HashMap::new();
        for info in self.allocations.values() {
            let bucket = match info.size {
                0..=1024 => "< 1KB",
                1025..=10240 => "1-10KB", 
                10241..=102400 => "10-100KB",
                _ => "> 100KB",
            };
            *size_buckets.entry(bucket).or_insert(0) += 1;
        }
        
        let mut stats = String::new();
        stats.push_str("📊 Memory Usage Statistics\n");
        stats.push_str(&format!("Active allocations: {}\n", allocation_count));
        stats.push_str(&format!("Current usage: {} bytes ({:.2} MB)\n", 
            current_usage, current_usage as f64 / 1024.0 / 1024.0));
        stats.push_str("\nSize distribution:\n");
        
        for (bucket, count) in size_buckets {
            stats.push_str(&format!("  {}: {} allocations\n", bucket, count));
        }
        
        stats
    }
    
    // 强制垃圾收集
    #[wasm_bindgen]
    pub fn force_cleanup(&mut self) {
        let before_count = self.allocations.len();
        let before_size = self.get_current_usage();
        
        // 移除所有分配记录（仅用于测试）
        self.allocations.clear();
        
        console_log!("Forced cleanup: {} allocations removed, {} bytes freed", 
            before_count, before_size);
    }
    
    fn get_stack_trace(&self) -> String {
        // 在真实应用中，这里会获取实际的调用栈
        // JavaScript 端可以提供更详细的栈跟踪
        format!("stack_trace_{}", js_sys::Date::now() as u64)
    }
    
    #[wasm_bindgen]
    pub fn enable_monitoring(&mut self, enabled: bool) {
        self.monitoring_enabled = enabled;
        console_log!("Memory monitoring {}", if enabled { "enabled" } else { "disabled" });
    }
}
```

#### JavaScript 端内存监控

```javascript
// 内存监控工具
class WasmMemoryProfiler {
    constructor(wasmInstance) {
        this.instance = wasmInstance;
        this.samples = [];
        this.isMonitoring = false;
        this.sampleInterval = null;
        this.leakDetector = null;
        
        // 初始化内存泄漏检测器
        if (wasmInstance.MemoryLeakDetector) {
            this.leakDetector = new wasmInstance.MemoryLeakDetector(10 * 1024 * 1024); // 10MB 阈值
        }
    }
    
    // 开始内存监控
    startMonitoring(intervalMs = 1000) {
        if (this.isMonitoring) {
            console.warn('Memory monitoring already active');
            return;
        }
        
        this.isMonitoring = true;
        this.samples = [];
        
        console.log('🔍 Starting memory monitoring...');
        
        this.sampleInterval = setInterval(() => {
            this.takeSample();
        }, intervalMs);
        
        // 立即取一个样本
        this.takeSample();
    }
    
    // 停止内存监控
    stopMonitoring() {
        if (!this.isMonitoring) return;
        
        this.isMonitoring = false;
        
        if (this.sampleInterval) {
            clearInterval(this.sampleInterval);
            this.sampleInterval = null;
        }
        
        console.log('🛑 Memory monitoring stopped');
        console.log('Total samples collected:', this.samples.length);
    }
    
    // 获取内存样本
    takeSample() {
        const timestamp = performance.now();
        
        // JavaScript 堆信息
        const jsMemory = this.getJSMemoryInfo();
        
        // WebAssembly 内存信息
        const wasmMemory = this.getWasmMemoryInfo();
        
        // 系统内存信息（如果可用）
        const systemMemory = this.getSystemMemoryInfo();
        
        const sample = {
            timestamp,
            jsMemory,
            wasmMemory,
            systemMemory
        };
        
        this.samples.push(sample);
        
        // 检测内存泄漏
        this.checkForLeaks(sample);
        
        return sample;
    }
    
    // 获取 JavaScript 内存信息
    getJSMemoryInfo() {
        if (!performance.memory) {
            return null;
        }
        
        return {
            used: performance.memory.usedJSHeapSize,
            total: performance.memory.totalJSHeapSize,
            limit: performance.memory.jsHeapSizeLimit
        };
    }
    
    // 获取 WebAssembly 内存信息
    getWasmMemoryInfo() {
        if (!this.instance.memory) {
            return null;
        }
        
        const buffer = this.instance.memory.buffer;
        const pages = buffer.byteLength / 65536;
        
        return {
            byteLength: buffer.byteLength,
            pages: pages,
            maxPages: this.instance.memory.maximum || null,
            detached: buffer.detached || false
        };
    }
    
    // 获取系统内存信息
    getSystemMemoryInfo() {
        // 使用 Performance Observer API（如果可用）
        if ('memory' in navigator) {
            return {
                deviceMemory: navigator.deviceMemory, // GB
                available: navigator.deviceMemory * 1024 * 1024 * 1024 // 转换为字节
            };
        }
        
        return null;
    }
    
    // 内存泄漏检测
    checkForLeaks(currentSample) {
        if (this.samples.length < 10) return; // 需要足够的样本
        
        const recentSamples = this.samples.slice(-10);
        const growthRate = this.calculateGrowthRate(recentSamples);
        
        // 检测 JavaScript 内存增长
        if (currentSample.jsMemory && growthRate.js > 0.1) { // 10% 增长率阈值
            console.warn('🚨 Potential JS memory leak detected:', {
                growthRate: growthRate.js,
                currentUsage: currentSample.jsMemory.used
            });
        }
        
        // 检测 WebAssembly 内存增长
        if (currentSample.wasmMemory && growthRate.wasm > 0.1) {
            console.warn('🚨 Potential WASM memory leak detected:', {
                growthRate: growthRate.wasm,
                currentUsage: currentSample.wasmMemory.byteLength
            });
        }
    }
    
    // 计算内存增长率
    calculateGrowthRate(samples) {
        if (samples.length < 2) return { js: 0, wasm: 0 };
        
        const first = samples[0];
        const last = samples[samples.length - 1];
        const timeSpan = last.timestamp - first.timestamp;
        
        if (timeSpan <= 0) return { js: 0, wasm: 0 };
        
        let jsGrowthRate = 0;
        let wasmGrowthRate = 0;
        
        if (first.jsMemory && last.jsMemory) {
            const jsGrowth = last.jsMemory.used - first.jsMemory.used;
            jsGrowthRate = jsGrowth / first.jsMemory.used;
        }
        
        if (first.wasmMemory && last.wasmMemory) {
            const wasmGrowth = last.wasmMemory.byteLength - first.wasmMemory.byteLength;
            wasmGrowthRate = wasmGrowth / first.wasmMemory.byteLength;
        }
        
        return { js: jsGrowthRate, wasm: wasmGrowthRate };
    }
    
    // 生成内存报告
    generateReport() {
        if (this.samples.length === 0) {
            return 'No memory samples collected';
        }
        
        const report = {
            summary: this.generateSummary(),
            trends: this.analyzeTrends(),
            leaks: this.detectLeaks(),
            recommendations: this.generateRecommendations()
        };
        
        return report;
    }
    
    generateSummary() {
        const first = this.samples[0];
        const last = this.samples[this.samples.length - 1];
        const duration = (last.timestamp - first.timestamp) / 1000; // 秒
        
        return {
            duration: `${duration.toFixed(1)}s`,
            samples: this.samples.length,
            jsMemoryChange: this.calculateMemoryChange(first.jsMemory, last.jsMemory),
            wasmMemoryChange: this.calculateMemoryChange(first.wasmMemory, last.wasmMemory)
        };
    }
    
    calculateMemoryChange(first, last) {
        if (!first || !last) return null;
        
        const change = {
            absolute: last.used - first.used || last.byteLength - first.byteLength,
            percentage: ((last.used || last.byteLength) / (first.used || first.byteLength) - 1) * 100
        };
        
        return change;
    }
    
    analyzeTrends() {
        // 分析内存使用趋势
        const jsUsage = this.samples.map(s => s.jsMemory?.used || 0);
        const wasmUsage = this.samples.map(s => s.wasmMemory?.byteLength || 0);
        
        return {
            jsMemory: {
                min: Math.min(...jsUsage),
                max: Math.max(...jsUsage),
                avg: jsUsage.reduce((a, b) => a + b, 0) / jsUsage.length,
                trend: this.calculateTrend(jsUsage)
            },
            wasmMemory: {
                min: Math.min(...wasmUsage),
                max: Math.max(...wasmUsage),
                avg: wasmUsage.reduce((a, b) => a + b, 0) / wasmUsage.length,
                trend: this.calculateTrend(wasmUsage)
            }
        };
    }
    
    calculateTrend(values) {
        if (values.length < 2) return 'insufficient_data';
        
        const first = values[0];
        const last = values[values.length - 1];
        const change = (last - first) / first;
        
        if (change > 0.1) return 'increasing';
        if (change < -0.1) return 'decreasing';
        return 'stable';
    }
    
    detectLeaks() {
        // 使用 WASM 泄漏检测器
        if (this.leakDetector) {
            return this.leakDetector.detect_leaks(30000); // 30秒阈值
        }
        
        return 'Leak detector not available';
    }
    
    generateRecommendations() {
        const recommendations = [];
        const trends = this.analyzeTrends();
        
        if (trends.jsMemory.trend === 'increasing') {
            recommendations.push('Consider implementing object pooling for JavaScript objects');
            recommendations.push('Review event listener cleanup and closure usage');
        }
        
        if (trends.wasmMemory.trend === 'increasing') {
            recommendations.push('Check for memory leaks in WASM allocation/deallocation');
            recommendations.push('Consider implementing custom memory management');
        }
        
        const lastSample = this.samples[this.samples.length - 1];
        if (lastSample.jsMemory && lastSample.jsMemory.used / lastSample.jsMemory.limit > 0.8) {
            recommendations.push('JavaScript memory usage is approaching limit');
        }
        
        if (recommendations.length === 0) {
            recommendations.push('Memory usage appears healthy');
        }
        
        return recommendations;
    }
    
    // 导出数据为 CSV
    exportToCsv() {
        const headers = ['timestamp', 'js_used', 'js_total', 'wasm_bytes', 'wasm_pages'];
        const rows = [headers.join(',')];
        
        this.samples.forEach(sample => {
            const row = [
                sample.timestamp,
                sample.jsMemory?.used || 0,
                sample.jsMemory?.total || 0,
                sample.wasmMemory?.byteLength || 0,
                sample.wasmMemory?.pages || 0
            ];
            rows.push(row.join(','));
        });
        
        return rows.join('\n');
    }
}

// 使用示例
async function demonstrateMemoryProfiling() {
    const wasmModule = await import('./pkg/wasm_debug_demo.js');
    await wasmModule.default();
    
    const profiler = new WasmMemoryProfiler(wasmModule);
    
    // 开始监控
    profiler.startMonitoring(500); // 每500ms采样一次
    
    // 模拟内存使用
    const arrays = [];
    
    for (let i = 0; i < 20; i++) {
        // 创建大数组模拟内存分配
        const size = 100000 + Math.random() * 50000;
        const array = new Float32Array(size);
        array.fill(Math.random());
        
        arrays.push(array);
        
        console.log(`Created array ${i + 1} with ${size} elements`);
        
        // 偶尔释放一些数组
        if (i > 10 && Math.random() > 0.7) {
            arrays.splice(0, 1);
            console.log('Released an array');
        }
        
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // 停止监控并生成报告
    setTimeout(() => {
        profiler.stopMonitoring();
        
        const report = profiler.generateReport();
        console.log('📊 Memory Profiling Report:', report);
        
        // 导出 CSV 数据
        const csvData = profiler.exportToCsv();
        console.log('📄 CSV Export:', csvData);
        
    }, 25000);
}
```

### 11.3.2 堆栈溢出检测

```rust
// 堆栈监控和溢出检测
#[wasm_bindgen]
pub struct StackMonitor {
    max_depth: u32,
    current_depth: u32,
    max_observed_depth: u32,
    stack_traces: Vec<String>,
    overflow_threshold: u32,
}

#[wasm_bindgen]
impl StackMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new(max_depth: u32) -> StackMonitor {
        StackMonitor {
            max_depth,
            current_depth: 0,
            max_observed_depth: 0,
            stack_traces: Vec::new(),
            overflow_threshold: (max_depth as f32 * 0.9) as u32, // 90% 阈值
        }
    }
    
    // 进入函数时调用
    #[wasm_bindgen]
    pub fn enter_function(&mut self, function_name: &str) -> bool {
        self.current_depth += 1;
        
        if self.current_depth > self.max_observed_depth {
            self.max_observed_depth = self.current_depth;
        }
        
        // 记录函数调用
        self.stack_traces.push(function_name.to_string());
        
        // 检查是否接近溢出
        if self.current_depth >= self.overflow_threshold {
            console_log!("⚠️  Stack depth warning: {} (threshold: {})", 
                self.current_depth, self.overflow_threshold);
            
            if self.current_depth >= self.max_depth {
                console_log!("🚨 Stack overflow detected at depth: {}", self.current_depth);
                self.print_stack_trace();
                return false; // 表示应该停止递归
            }
        }
        
        true
    }
    
    // 退出函数时调用
    #[wasm_bindgen]
    pub fn exit_function(&mut self) {
        if self.current_depth > 0 {
            self.current_depth -= 1;
            self.stack_traces.pop();
        }
    }
    
    // 打印堆栈跟踪
    #[wasm_bindgen]
    pub fn print_stack_trace(&self) {
        console_log!("📋 Stack trace (depth: {}):", self.current_depth);
        for (i, func_name) in self.stack_traces.iter().enumerate() {
            console_log!("  {}: {}", i + 1, func_name);
        }
    }
    
    // 获取堆栈统计信息
    #[wasm_bindgen]
    pub fn get_stack_stats(&self) -> String {
        format!(
            "Current depth: {}, Max observed: {}, Max allowed: {}, Threshold: {}",
            self.current_depth, self.max_observed_depth, self.max_depth, self.overflow_threshold
        )
    }
    
    // 重置监控状态
    #[wasm_bindgen]
    pub fn reset(&mut self) {
        self.current_depth = 0;
        self.max_observed_depth = 0;
        self.stack_traces.clear();
    }
}

// 递归函数示例（带堆栈监控）
#[wasm_bindgen]
pub fn monitored_fibonacci(n: u32, monitor: &mut StackMonitor) -> u64 {
    if !monitor.enter_function(&format!("fibonacci({})", n)) {
        console_log!("🛑 Stopping recursion due to stack overflow risk");
        return 0; // 错误值
    }
    
    let result = if n <= 1 {
        n as u64
    } else {
        let a = monitored_fibonacci(n - 1, monitor);
        let b = monitored_fibonacci(n - 2, monitor);
        a + b
    };
    
    monitor.exit_function();
    result
}

// 栈使用优化示例
#[wasm_bindgen]
pub fn iterative_fibonacci(n: u32) -> u64 {
    if n <= 1 {
        return n as u64;
    }
    
    let mut a = 0u64;
    let mut b = 1u64;
    
    for _ in 2..=n {
        let temp = a + b;
        a = b;
        b = temp;
    }
    
    b
}

// 尾递归优化示例
#[wasm_bindgen]
pub fn tail_recursive_factorial(n: u64, accumulator: u64, monitor: &mut StackMonitor) -> u64 {
    if !monitor.enter_function(&format!("factorial({}, acc={})", n, accumulator)) {
        return accumulator; // 返回当前累积值
    }
    
    let result = if n <= 1 {
        accumulator
    } else {
        tail_recursive_factorial(n - 1, n * accumulator, monitor)
    };
    
    monitor.exit_function();
    result
}
```

## 11.4 性能调试和分析

### 11.4.1 性能瓶颈识别

性能问题往往是最难调试的问题类型。我们需要专门的工具和技术来识别和解决性能瓶颈。

#### 性能测量工具

```rust
// 性能分析器
use std::collections::HashMap;
use std::time::Instant;

#[wasm_bindgen]
pub struct PerformanceProfiler {
    timers: HashMap<String, f64>,
    counters: HashMap<String, u64>,
    measurements: HashMap<String, Vec<f64>>,
    memory_snapshots: Vec<MemorySnapshot>,
    profiling_enabled: bool,
}

#[derive(Clone)]
struct MemorySnapshot {
    timestamp: f64,
    heap_size: usize,
    stack_usage: usize,
}

#[wasm_bindgen]
impl PerformanceProfiler {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceProfiler {
        PerformanceProfiler {
            timers: HashMap::new(),
            counters: HashMap::new(),
            measurements: HashMap::new(),
            memory_snapshots: Vec::new(),
            profiling_enabled: true,
        }
    }
    
    // 开始计时
    #[wasm_bindgen]
    pub fn start_timer(&mut self, name: &str) {
        if !self.profiling_enabled { return; }
        
        let timestamp = js_sys::Date::now();
        self.timers.insert(name.to_string(), timestamp);
    }
    
    // 结束计时并记录
    #[wasm_bindgen]
    pub fn end_timer(&mut self, name: &str) -> f64 {
        if !self.profiling_enabled { return 0.0; }
        
        let end_time = js_sys::Date::now();
        if let Some(&start_time) = self.timers.get(name) {
            let duration = end_time - start_time;
            
            // 记录测量结果
            self.measurements
                .entry(name.to_string())
                .or_insert_with(Vec::new)
                .push(duration);
            
            self.timers.remove(name);
            duration
        } else {
            console_log!("⚠️  Timer '{}' was not started", name);
            0.0
        }
    }
    
    // 增加计数器
    #[wasm_bindgen]
    pub fn increment_counter(&mut self, name: &str, value: u64) {
        if !self.profiling_enabled { return; }
        
        *self.counters.entry(name.to_string()).or_insert(0) += value;
    }
    
    // 记录内存快照
    #[wasm_bindgen]
    pub fn take_memory_snapshot(&mut self, heap_size: usize, stack_usage: usize) {
        if !self.profiling_enabled { return; }
        
        let snapshot = MemorySnapshot {
            timestamp: js_sys::Date::now(),
            heap_size,
            stack_usage,
        };
        
        self.memory_snapshots.push(snapshot);
    }
    
    // 生成性能报告
    #[wasm_bindgen]
    pub fn generate_report(&self) -> String {
        let mut report = String::new();
        
        report.push_str("🔬 Performance Analysis Report\n");
        report.push_str("================================\n\n");
        
        // 计时器统计
        if !self.measurements.is_empty() {
            report.push_str("⏱️  Timing Statistics:\n");
            for (name, measurements) in &self.measurements {
                if !measurements.is_empty() {
                    let count = measurements.len();
                    let total: f64 = measurements.iter().sum();
                    let avg = total / count as f64;
                    let min = measurements.iter().fold(f64::INFINITY, |a, &b| a.min(b));
                    let max = measurements.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
                    
                    // 计算百分位数
                    let mut sorted = measurements.clone();
                    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
                    let p50 = sorted[count / 2];
                    let p95 = sorted[(count as f64 * 0.95) as usize];
                    let p99 = sorted[(count as f64 * 0.99) as usize];
                    
                    report.push_str(&format!(
                        "  {}: {} samples, avg: {:.2}ms, min: {:.2}ms, max: {:.2}ms, p50: {:.2}ms, p95: {:.2}ms, p99: {:.2}ms\n",
                        name, count, avg, min, max, p50, p95, p99
                    ));
                }
            }
            report.push_str("\n");
        }
        
        // 计数器统计
        if !self.counters.is_empty() {
            report.push_str("📊 Counter Statistics:\n");
            for (name, count) in &self.counters {
                report.push_str(&format!("  {}: {}\n", name, count));
            }
            report.push_str("\n");
        }
        
        // 内存使用分析
        if !self.memory_snapshots.is_empty() {
            report.push_str("💾 Memory Usage Analysis:\n");
            let heap_sizes: Vec<usize> = self.memory_snapshots.iter().map(|s| s.heap_size).collect();
            let stack_usages: Vec<usize> = self.memory_snapshots.iter().map(|s| s.stack_usage).collect();
            
            let heap_min = *heap_sizes.iter().min().unwrap();
            let heap_max = *heap_sizes.iter().max().unwrap();
            let heap_avg = heap_sizes.iter().sum::<usize>() / heap_sizes.len();
            
            let stack_min = *stack_usages.iter().min().unwrap();
            let stack_max = *stack_usages.iter().max().unwrap();
            let stack_avg = stack_usages.iter().sum::<usize>() / stack_usages.len();
            
            report.push_str(&format!(
                "  Heap: min: {} bytes, max: {} bytes, avg: {} bytes\n",
                heap_min, heap_max, heap_avg
            ));
            report.push_str(&format!(
                "  Stack: min: {} bytes, max: {} bytes, avg: {} bytes\n",
                stack_min, stack_max, stack_avg
            ));
            report.push_str("\n");
        }
        
        // 性能建议
        report.push_str("💡 Performance Recommendations:\n");
        report.push_str(&self.generate_recommendations());
        
        report
    }
    
    fn generate_recommendations(&self) -> String {
        let mut recommendations = String::new();
        
        // 分析计时数据给出建议
        for (name, measurements) in &self.measurements {
            if measurements.is_empty() { continue; }
            
            let avg = measurements.iter().sum::<f64>() / measurements.len() as f64;
            let mut sorted = measurements.clone();
            sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
            let p95 = sorted[(measurements.len() as f64 * 0.95) as usize];
            
            if avg > 100.0 {
                recommendations.push_str(&format!(
                    "  - '{}' has high average execution time ({:.2}ms). Consider optimization.\n",
                    name, avg
                ));
            }
            
            if p95 > avg * 2.0 {
                recommendations.push_str(&format!(
                    "  - '{}' shows high variance (P95: {:.2}ms vs Avg: {:.2}ms). Check for edge cases.\n",
                    name, p95, avg
                ));
            }
        }
        
        // 内存建议
        if !self.memory_snapshots.is_empty() {
            let heap_sizes: Vec<usize> = self.memory_snapshots.iter().map(|s| s.heap_size).collect();
            let first_heap = heap_sizes[0];
            let last_heap = heap_sizes[heap_sizes.len() - 1];
            
            if last_heap > first_heap * 2 {
                recommendations.push_str("  - Memory usage doubled during profiling. Check for memory leaks.\n");
            }
        }
        
        if recommendations.is_empty() {
            recommendations.push_str("  - No obvious performance issues detected.\n");
        }
        
        recommendations
    }
    
    // 清除所有数据
    #[wasm_bindgen]
    pub fn clear(&mut self) {
        self.timers.clear();
        self.counters.clear();
        self.measurements.clear();
        self.memory_snapshots.clear();
    }
    
    // 启用/禁用分析
    #[wasm_bindgen]
    pub fn set_enabled(&mut self, enabled: bool) {
        self.profiling_enabled = enabled;
    }
}

// 性能测试示例函数
#[wasm_bindgen]
pub fn performance_test_suite(profiler: &mut PerformanceProfiler) {
    // 测试1: 简单循环
    profiler.start_timer("simple_loop");
    let mut sum = 0;
    for i in 0..1000000 {
        sum += i;
    }
    profiler.end_timer("simple_loop");
    profiler.increment_counter("loop_iterations", 1000000);
    
    // 测试2: 内存分配
    profiler.start_timer("memory_allocation");
    let mut vectors = Vec::new();
    for _ in 0..1000 {
        vectors.push(vec![0; 1000]);
    }
    profiler.end_timer("memory_allocation");
    profiler.increment_counter("allocations", 1000);
    
    // 测试3: 数学计算
    profiler.start_timer("math_operations");
    let mut result = 1.0;
    for i in 1..10000 {
        result = (result * i as f64).sqrt();
    }
    profiler.end_timer("math_operations");
    profiler.increment_counter("math_ops", 10000);
    
    console_log!("Performance test completed. Sum: {}, Result: {:.6}", sum, result);
}
```

#### JavaScript 性能分析集成

```javascript
// JavaScript 端性能分析
class WasmPerformanceAnalyzer {
    constructor(wasmModule) {
        this.wasmModule = wasmModule;
        this.profiler = null;
        this.observer = null;
        this.marks = new Map();
        this.isRecording = false;
    }
    
    // 初始化分析器
    async initialize() {
        if (this.wasmModule.PerformanceProfiler) {
            this.profiler = new this.wasmModule.PerformanceProfiler();
        }
        
        // 设置 Performance Observer
        if ('PerformanceObserver' in window) {
            this.observer = new PerformanceObserver((list) => {
                this.handlePerformanceEntries(list.getEntries());
            });
            
            this.observer.observe({ entryTypes: ['measure', 'navigation', 'paint'] });
        }
        
        console.log('🔬 Performance analyzer initialized');
    }
    
    // 开始性能记录
    startRecording() {
        this.isRecording = true;
        this.marks.clear();
        
        if (this.profiler) {
            this.profiler.clear();
        }
        
        // 标记开始
        performance.mark('wasm-analysis-start');
        console.log('🎬 Performance recording started');
    }
    
    // 停止性能记录
    stopRecording() {
        if (!this.isRecording) return;
        
        this.isRecording = false;
        performance.mark('wasm-analysis-end');
        performance.measure('total-analysis', 'wasm-analysis-start', 'wasm-analysis-end');
        
        console.log('🛑 Performance recording stopped');
    }
    
    // 处理性能条目
    handlePerformanceEntries(entries) {
        entries.forEach(entry => {
            if (entry.name.startsWith('wasm-')) {
                console.log(`📊 Performance entry: ${entry.name} - ${entry.duration}ms`);
            }
        });
    }
    
    // 包装函数进行性能测量
    wrapFunction(obj, funcName, category = 'general') {
        const originalFunc = obj[funcName];
        const analyzer = this;
        
        obj[funcName] = function(...args) {
            if (!analyzer.isRecording) {
                return originalFunc.apply(this, args);
            }
            
            const markName = `${category}-${funcName}`;
            const startMark = `${markName}-start`;
            const endMark = `${markName}-end`;
            
            // Performance API 标记
            performance.mark(startMark);
            
            // WASM 分析器计时
            if (analyzer.profiler) {
                analyzer.profiler.start_timer(markName);
            }
            
            try {
                const result = originalFunc.apply(this, args);
                
                // 如果是 Promise，等待完成
                if (result && typeof result.then === 'function') {
                    return result.finally(() => {
                        analyzer.endMeasurement(markName, startMark, endMark);
                    });
                } else {
                    analyzer.endMeasurement(markName, startMark, endMark);
                    return result;
                }
            } catch (error) {
                analyzer.endMeasurement(markName, startMark, endMark);
                throw error;
            }
        };
    }
    
    endMeasurement(markName, startMark, endMark) {
        performance.mark(endMark);
        performance.measure(markName, startMark, endMark);
        
        if (this.profiler) {
            this.profiler.end_timer(markName);
        }
    }
    
    // 自动包装所有导出函数
    wrapAllExports() {
        const exports = Object.keys(this.wasmModule);
        
        exports.forEach(exportName => {
            const exportValue = this.wasmModule[exportName];
            
            if (typeof exportValue === 'function') {
                this.wrapFunction(this.wasmModule, exportName, 'export');
                console.log(`🔧 Wrapped function: ${exportName}`);
            }
        });
    }
    
    // 运行性能基准测试
    async runBenchmark(testName, testFunction, iterations = 100) {
        console.log(`🏃 Running benchmark: ${testName} (${iterations} iterations)`);
        
        const results = [];
        
        for (let i = 0; i < iterations; i++) {
            const startTime = performance.now();
            
            try {
                await testFunction();
            } catch (error) {
                console.error(`Benchmark error in iteration ${i}:`, error);
                continue;
            }
            
            const endTime = performance.now();
            const duration = endTime - startTime;
            results.push(duration);
            
            // 每10次迭代记录一次进度
            if ((i + 1) % 10 === 0) {
                console.log(`Progress: ${i + 1}/${iterations} iterations completed`);
            }
        }
        
        // 计算统计信息
        const stats = this.calculateStats(results);
        console.log(`📈 Benchmark '${testName}' completed:`, stats);
        
        return stats;
    }
    
    calculateStats(values) {
        if (values.length === 0) return null;
        
        const sorted = [...values].sort((a, b) => a - b);
        const sum = values.reduce((a, b) => a + b, 0);
        
        return {
            count: values.length,
            min: sorted[0],
            max: sorted[sorted.length - 1],
            mean: sum / values.length,
            median: sorted[Math.floor(sorted.length / 2)],
            p95: sorted[Math.floor(sorted.length * 0.95)],
            p99: sorted[Math.floor(sorted.length * 0.99)],
            stdDev: this.calculateStdDev(values, sum / values.length)
        };
    }
    
    calculateStdDev(values, mean) {
        const squaredDiffs = values.map(value => Math.pow(value - mean, 2));
        const avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b, 0) / values.length;
        return Math.sqrt(avgSquaredDiff);
    }
    
    // 生成综合性能报告
    generateReport() {
        const report = {
            timestamp: new Date().toISOString(),
            wasmReport: null,
            browserMetrics: this.getBrowserMetrics(),
            performanceEntries: this.getPerformanceEntries()
        };
        
        // 获取 WASM 性能报告
        if (this.profiler) {
            report.wasmReport = this.profiler.generate_report();
        }
        
        return report;
    }
    
    getBrowserMetrics() {
        const metrics = {};
        
        // 内存信息
        if (performance.memory) {
            metrics.memory = {
                used: performance.memory.usedJSHeapSize,
                total: performance.memory.totalJSHeapSize,
                limit: performance.memory.jsHeapSizeLimit
            };
        }
        
        // 导航时机
        if (performance.timing) {
            const timing = performance.timing;
            metrics.navigation = {
                domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
                loadComplete: timing.loadEventEnd - timing.navigationStart,
                domInteractive: timing.domInteractive - timing.navigationStart
            };
        }
        
        return metrics;
    }
    
    getPerformanceEntries() {
        const entries = performance.getEntriesByType('measure')
            .filter(entry => entry.name.includes('wasm') || entry.name.includes('test'))
            .map(entry => ({
                name: entry.name,
                duration: entry.duration,
                startTime: entry.startTime
            }));
        
        return entries;
    }
    
    // 清理资源
    cleanup() {
        if (this.observer) {
            this.observer.disconnect();
        }
        
        if (this.profiler) {
            this.profiler.clear();
        }
        
        performance.clearMarks();
        performance.clearMeasures();
        
        console.log('🧹 Performance analyzer cleaned up');
    }
}

// 使用示例
async function demonstratePerformanceAnalysis() {
    const wasmModule = await import('./pkg/wasm_debug_demo.js');
    await wasmModule.default();
    
    const analyzer = new WasmPerformanceAnalyzer(wasmModule);
    await analyzer.initialize();
    
    // 包装所有导出函数
    analyzer.wrapAllExports();
    
    // 开始记录
    analyzer.startRecording();
    
    // 运行性能测试套件
    if (wasmModule.PerformanceProfiler) {
        const profiler = new wasmModule.PerformanceProfiler();
        wasmModule.performance_test_suite(profiler);
    }
    
    // 运行自定义基准测试
    await analyzer.runBenchmark('array_processing', async () => {
        const data = new Float32Array(1000);
        for (let i = 0; i < data.length; i++) {
            data[i] = Math.random();
        }
        
        if (wasmModule.debug_complex_calculation) {
            wasmModule.debug_complex_calculation(data);
        }
    }, 50);
    
    // 停止记录并生成报告
    analyzer.stopRecording();
    
    setTimeout(() => {
        const report = analyzer.generateReport();
        console.log('📊 Final Performance Report:', report);
        
        analyzer.cleanup();
    }, 1000);
}
```

### 11.4.2 热点分析

热点分析帮助我们找到程序中最消耗时间的部分，从而针对性地进行优化。

```rust
// 热点分析工具
#[wasm_bindgen]
pub struct HotspotAnalyzer {
    function_calls: std::collections::HashMap<String, FunctionStats>,
    call_stack: Vec<String>,
    sampling_rate: u32,
    sample_count: u32,
}

#[derive(Clone)]
struct FunctionStats {
    call_count: u64,
    total_time: f64,
    self_time: f64,
    child_time: f64,
    min_time: f64,
    max_time: f64,
}

impl FunctionStats {
    fn new() -> Self {
        FunctionStats {
            call_count: 0,
            total_time: 0.0,
            self_time: 0.0,
            child_time: 0.0,
            min_time: f64::INFINITY,
            max_time: 0.0,
        }
    }
}

#[wasm_bindgen]
impl HotspotAnalyzer {
    #[wasm_bindgen(constructor)]
    pub fn new(sampling_rate: u32) -> HotspotAnalyzer {
        HotspotAnalyzer {
            function_calls: std::collections::HashMap::new(),
            call_stack: Vec::new(),
            sampling_rate,
            sample_count: 0,
        }
    }
    
    // 进入函数
    #[wasm_bindgen]
    pub fn enter_function(&mut self, function_name: &str) -> f64 {
        self.call_stack.push(function_name.to_string());
        
        // 更新函数统计
        let stats = self.function_calls
            .entry(function_name.to_string())
            .or_insert_with(FunctionStats::new);
        stats.call_count += 1;
        
        js_sys::Date::now()
    }
    
    // 退出函数
    #[wasm_bindgen]
    pub fn exit_function(&mut self, function_name: &str, start_time: f64) {
        let end_time = js_sys::Date::now();
        let duration = end_time - start_time;
        
        if let Some(popped) = self.call_stack.pop() {
            if popped != function_name {
                console_log!("⚠️  Function stack mismatch: expected {}, got {}", function_name, popped);
            }
        }
        
        // 更新统计信息
        if let Some(stats) = self.function_calls.get_mut(function_name) {
            stats.total_time += duration;
            stats.min_time = stats.min_time.min(duration);
            stats.max_time = stats.max_time.max(duration);
            
            // 计算自身时间（不包括子函数调用）
            stats.self_time += duration;
        }
        
        // 从父函数的自身时间中减去这次调用的时间
        if let Some(parent_name) = self.call_stack.last() {
            if let Some(parent_stats) = self.function_calls.get_mut(parent_name) {
                parent_stats.self_time -= duration;
                parent_stats.child_time += duration;
            }
        }
        
        // 采样记录
        self.sample_count += 1;
        if self.sample_count % self.sampling_rate == 0 {
            self.record_sample();
        }
    }
    
    fn record_sample(&self) {
        if !self.call_stack.is_empty() {
            console_log!("📊 Sample #{}: Stack depth: {}, Top function: {}", 
                self.sample_count, self.call_stack.len(), self.call_stack.last().unwrap());
        }
    }
    
    // 生成热点报告
    #[wasm_bindgen]
    pub fn generate_hotspot_report(&self) -> String {
        let mut report = String::new();
        
        report.push_str("🔥 Hotspot Analysis Report\n");
        report.push_str("==========================\n\n");
        
        // 按总时间排序
        let mut sorted_functions: Vec<_> = self.function_calls.iter().collect();
        sorted_functions.sort_by(|a, b| b.1.total_time.partial_cmp(&a.1.total_time).unwrap());
        
        report.push_str("📈 Functions by Total Time:\n");
        report.push_str("Function Name                | Calls    | Total Time | Self Time  | Avg Time   | Min Time   | Max Time\n");
        report.push_str("----------------------------|----------|------------|------------|------------|------------|----------\n");
        
        for (name, stats) in &sorted_functions[..10.min(sorted_functions.len())] {
            let avg_time = stats.total_time / stats.call_count as f64;
            report.push_str(&format!(
                "{:<27} | {:>8} | {:>9.2}ms | {:>9.2}ms | {:>9.2}ms | {:>9.2}ms | {:>9.2}ms\n",
                name, stats.call_count, stats.total_time, stats.self_time, 
                avg_time, stats.min_time, stats.max_time
            ));
        }
        
        // 按调用次数排序
        sorted_functions.sort_by(|a, b| b.1.call_count.cmp(&a.1.call_count));
        
        report.push_str("\n📞 Functions by Call Count:\n");
        for (name, stats) in &sorted_functions[..5.min(sorted_functions.len())] {
            report.push_str(&format!(
                "  {}: {} calls, {:.2}ms total\n",
                name, stats.call_count, stats.total_time
            ));
        }
        
        // 按平均时间排序
        sorted_functions.sort_by(|a, b| {
            let avg_a = a.1.total_time / a.1.call_count as f64;
            let avg_b = b.1.total_time / b.1.call_count as f64;
            avg_b.partial_cmp(&avg_a).unwrap()
        });
        
        report.push_str("\n⏱️  Functions by Average Time:\n");
        for (name, stats) in &sorted_functions[..5.min(sorted_functions.len())] {
            let avg_time = stats.total_time / stats.call_count as f64;
            report.push_str(&format!(
                "  {}: {:.2}ms avg ({} calls)\n",
                name, avg_time, stats.call_count
            ));
        }
        
        // 优化建议
        report.push_str("\n💡 Optimization Suggestions:\n");
        report.push_str(&self.generate_optimization_suggestions());
        
        report
    }
    
    fn generate_optimization_suggestions(&self) -> String {
        let mut suggestions = String::new();
        
        // 找出总时间最长的函数
        if let Some((hottest_func, hottest_stats)) = self.function_calls.iter()
            .max_by(|a, b| a.1.total_time.partial_cmp(&b.1.total_time).unwrap()) {
            
            suggestions.push_str(&format!(
                "  1. '{}' consumes {:.1}% of total execution time. Consider optimizing this function.\n",
                hottest_func, 
                (hottest_stats.total_time / self.get_total_execution_time()) * 100.0
            ));
        }
        
        // 找出调用次数过多的函数
        if let Some((most_called_func, most_called_stats)) = self.function_calls.iter()
            .max_by(|a, b| a.1.call_count.cmp(&b.1.call_count)) {
            
            if most_called_stats.call_count > 10000 {
                suggestions.push_str(&format!(
                    "  2. '{}' is called {} times. Consider caching or reducing call frequency.\n",
                    most_called_func, most_called_stats.call_count
                ));
            }
        }
        
        // 找出平均时间过长的函数
        for (name, stats) in &self.function_calls {
            let avg_time = stats.total_time / stats.call_count as f64;
            if avg_time > 10.0 && stats.call_count > 10 {
                suggestions.push_str(&format!(
                    "  3. '{}' has high average execution time ({:.2}ms). Consider algorithmic optimization.\n",
                    name, avg_time
                ));
            }
        }
        
        if suggestions.is_empty() {
            suggestions.push_str("  - No obvious optimization opportunities detected.\n");
        }
        
        suggestions
    }
    
    fn get_total_execution_time(&self) -> f64 {
        self.function_calls.values().map(|stats| stats.self_time).sum()
    }
    
    // 重置统计
    #[wasm_bindgen]
    pub fn reset(&mut self) {
        self.function_calls.clear();
        self.call_stack.clear();
        self.sample_count = 0;
    }
    
    // 获取当前调用栈
    #[wasm_bindgen]
    pub fn get_call_stack(&self) -> String {
        self.call_stack.join(" -> ")
    }
}

// 宏：自动添加函数调用跟踪
macro_rules! profile_function {
    ($analyzer:expr, $func_name:expr, $block:block) => {
        {
            let start_time = $analyzer.enter_function($func_name);
            let result = $block;
            $analyzer.exit_function($func_name, start_time);
            result
        }
    };
}

// 热点分析示例函数
#[wasm_bindgen]
pub fn hotspot_test_suite(analyzer: &mut HotspotAnalyzer) {
    // 模拟不同性能特征的函数
    
    // 高频率调用的快速函数
    for i in 0..1000 {
        profile_function!(analyzer, "fast_function", {
            let mut sum = 0;
            for j in 0..10 {
                sum += i + j;
            }
            sum
        });
    }
    
    // 低频率调用的慢速函数
    for _i in 0..5 {
        profile_function!(analyzer, "slow_function", {
            let mut result = 1.0;
            for j in 0..100000 {
                result = (result + j as f64).sqrt();
            }
            result
        });
    }
    
    // 递归函数测试
    fn recursive_test(analyzer: &mut HotspotAnalyzer, n: u32) -> u32 {
        profile_function!(analyzer, "recursive_function", {
            if n <= 1 {
                n
            } else {
                recursive_test(analyzer, n - 1) + recursive_test(analyzer, n - 2)
            }
        })
    }
    
    recursive_test(analyzer, 10);
    
    // 嵌套函数调用测试
    profile_function!(analyzer, "outer_function", {
        for _i in 0..100 {
            profile_function!(analyzer, "inner_function_a", {
                let mut temp = 0;
                for j in 0..50 {
                    temp += j;
                }
                temp
            });
            
            profile_function!(analyzer, "inner_function_b", {
                let mut temp = 1.0;
                for j in 1..20 {
                    temp *= j as f64;
                }
                temp
            });
        }
    });
}
```

通过本章的学习，你现在掌握了 WebAssembly 应用调试的全套技术：

1. **调试环境搭建**：配置浏览器开发者工具、源码映射和调试扩展
2. **断点调试**：设置各种类型的断点，包括条件断点和日志点
3. **内存调试**：检测内存泄漏、监控内存使用和堆栈溢出
4. **性能调试**：识别性能瓶颈、进行热点分析和性能优化

这些调试技术将帮助你：
- 快速定位和修复 WebAssembly 应用中的错误
- 优化应用性能，提升用户体验
- 建立健壮的调试和监控体系
- 提高开发效率和代码质量

在下一章中，我们将把所学的知识应用到实际项目中，通过构建完整的 WebAssembly 应用来巩固和深化理解。
