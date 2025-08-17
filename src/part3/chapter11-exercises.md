# 第11章 练习题

## 11.1 调试环境配置练习

### 练习 11.1.1 浏览器调试工具配置 (15分)

**题目**: 配置浏览器开发者工具以支持 WebAssembly 调试，并验证源码映射功能。

要求：
- 在 Chrome 和 Firefox 中启用 WebAssembly 调试功能
- 配置 Rust 项目生成调试信息
- 验证源码映射是否正常工作
- 创建一个调试配置指南

<details>
<summary>🔍 参考答案</summary>

**1. Chrome DevTools 配置**:
```bash
# 启动 Chrome 时添加调试参数
google-chrome --enable-features=WebAssemblyDebugging
```

**2. Rust 项目调试配置** (`Cargo.toml`):
```toml
[package]
name = "debug-example"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
console_error_panic_hook = "0.1"

# 调试配置
[profile.dev]
debug = true
opt-level = 0

[profile.release]
debug = true
opt-level = 2
```

**3. wasm-pack 调试构建**:
```bash
# 开发版本构建（包含调试信息）
wasm-pack build --dev --out-dir pkg

# 或者带调试信息的发布版本
wasm-pack build --profiling --out-dir pkg
```

**4. 调试验证代码** (`src/lib.rs`):
```rust
use wasm_bindgen::prelude::*;

// 导入 console.log
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 设置 panic hook
#[wasm_bindgen(start)]
pub fn main() {
    console_error_panic_hook::set_once();
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub fn debug_function(input: i32) -> i32 {
    console_log!("进入 debug_function，输入: {}", input);
    
    let mut result = input;
    
    // 可以在这里设置断点
    for i in 1..=5 {
        result = calculate_step(result, i);
        console_log!("步骤 {} 结果: {}", i, result);
    }
    
    console_log!("函数返回: {}", result);
    result
}

fn calculate_step(value: i32, step: i32) -> i32 {
    // 这里也可以设置断点
    let intermediate = value * 2;
    intermediate + step
}

// 故意创建一个可能出错的函数
#[wasm_bindgen]
pub fn potentially_buggy_function(array_size: usize) -> Vec<i32> {
    let mut data = vec![0; array_size];
    
    for i in 0..array_size {
        // 故意的边界检查问题（在某些情况下）
        if i < data.len() {
            data[i] = i as i32 * 2;
        }
    }
    
    data
}

// 内存使用测试函数
#[wasm_bindgen]
pub fn memory_test_function(iterations: usize) -> usize {
    let mut total_allocated = 0;
    
    for i in 0..iterations {
        let size = (i % 1000) + 1;
        let _data: Vec<u8> = vec![0; size];
        total_allocated += size;
        
        // 故意不释放某些内存（模拟内存泄漏）
        if i % 10 == 0 {
            std::mem::forget(_data);
        }
    }
    
    total_allocated
}
```

**5. HTML 测试页面**:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>WebAssembly 调试测试</title>
</head>
<body>
    <h1>WebAssembly 调试验证</h1>
    
    <button id="test-debug">测试调试功能</button>
    <button id="test-buggy">测试有问题的函数</button>
    <button id="test-memory">测试内存使用</button>
    
    <div id="output"></div>
    
    <script type="module">
        import init, { 
            debug_function, 
            potentially_buggy_function, 
            memory_test_function 
        } from './pkg/debug_example.js';
        
        async function run() {
            await init();
            
            const output = document.getElementById('output');
            
            document.getElementById('test-debug').onclick = () => {
                console.log('开始调试测试');
                const result = debug_function(10);
                output.innerHTML += `<p>调试函数结果: ${result}</p>`;
            };
            
            document.getElementById('test-buggy').onclick = () => {
                console.log('测试有问题的函数');
                try {
                    const result = potentially_buggy_function(1000);
                    output.innerHTML += `<p>生成了 ${result.length} 个元素</p>`;
                } catch (error) {
                    output.innerHTML += `<p style="color: red">错误: ${error}</p>`;
                }
            };
            
            document.getElementById('test-memory').onclick = () => {
                console.log('测试内存使用');
                const allocated = memory_test_function(100);
                output.innerHTML += `<p>分配内存总量: ${allocated} 字节</p>`;
            };
        }
        
        run();
    </script>
</body>
</html>
```

**6. 调试步骤验证**:

1. **构建项目**: `wasm-pack build --dev`
2. **启用浏览器调试**: 在 Chrome DevTools 中启用 "WebAssembly Debugging"
3. **设置断点**: 在 Sources 面板中找到 Rust 源码并设置断点
4. **验证功能**: 运行测试函数并确认能在断点处停止
5. **检查变量**: 在断点处检查局部变量和调用栈

**预期结果**:
- 能在 Rust 源码中设置断点
- 变量检查器显示正确的变量值
- 调用栈显示函数调用层次
- Console 显示调试输出

</details>

## 11.2 断点调试练习

### 练习 11.2.1 高级断点技术 (20分)

**题目**: 实现并使用条件断点、日志断点等高级调试技术来调试复杂的 WebAssembly 应用。

<details>
<summary>🔍 参考答案</summary>

**Rust 调试目标代码**:
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct DataProcessor {
    data: Vec<f64>,
    threshold: f64,
}

#[wasm_bindgen]
impl DataProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(threshold: f64) -> DataProcessor {
        DataProcessor {
            data: Vec::new(),
            threshold,
        }
    }
    
    #[wasm_bindgen]
    pub fn add_data(&mut self, value: f64) {
        // 条件断点目标：只在异常值时暂停
        if value.is_infinite() || value.is_nan() {
            panic!("检测到异常数值: {}", value);
        }
        
        self.data.push(value);
    }
    
    #[wasm_bindgen]
    pub fn process_data(&mut self) -> Vec<f64> {
        let mut results = Vec::new();
        
        for (index, &value) in self.data.iter().enumerate() {
            // 日志断点目标：记录每次处理的数据
            let processed = self.apply_algorithm(value, index);
            
            // 条件断点目标：只在超过阈值时暂停
            if processed > self.threshold {
                results.push(processed);
            }
        }
        
        results
    }
    
    fn apply_algorithm(&self, value: f64, index: usize) -> f64 {
        // 复杂的算法，可能出现问题
        let factor = if index % 2 == 0 { 1.5 } else { 0.8 };
        let base_result = value * factor;
        
        // 故意的潜在问题：除零
        if index > 0 {
            base_result / (index as f64)
        } else {
            base_result
        }
    }
    
    #[wasm_bindgen]
    pub fn get_statistics(&self) -> JsValue {
        if self.data.is_empty() {
            return JsValue::NULL;
        }
        
        let sum: f64 = self.data.iter().sum();
        let mean = sum / self.data.len() as f64;
        let variance = self.data.iter()
            .map(|&x| (x - mean).powi(2))
            .sum::<f64>() / self.data.len() as f64;
        
        let stats = serde_json::json!({
            "count": self.data.len(),
            "sum": sum,
            "mean": mean,
            "variance": variance,
            "std_dev": variance.sqrt()
        });
        
        JsValue::from_str(&stats.to_string())
    }
}

// 测试用的复杂函数
#[wasm_bindgen]
pub fn complex_calculation(input: &[f64]) -> f64 {
    let mut result = 0.0;
    
    for (i, &value) in input.iter().enumerate() {
        // 多个条件，适合条件断点
        if value > 100.0 {
            result += value * 2.0;
        } else if value < 0.0 {
            result -= value.abs();
        } else {
            result += value / (i + 1) as f64;
        }
        
        // 可能的问题点
        if i > 10 && result > 1000.0 {
            result = result.sqrt();
        }
    }
    
    result
}
```

**JavaScript 调试辅助工具**:
```javascript
class WasmDebugHelper {
    constructor(wasmModule) {
        this.module = wasmModule;
        this.breakpointConditions = new Map();
        this.logPoints = new Map();
    }
    
    // 条件断点辅助
    addConditionalBreakpoint(functionName, condition) {
        this.breakpointConditions.set(functionName, condition);
    }
    
    // 日志断点辅助
    addLogPoint(functionName, message) {
        this.logPoints.set(functionName, message);
    }
    
    // 包装函数调用以添加调试功能
    wrapFunction(obj, functionName) {
        const originalFunction = obj[functionName];
        const self = this;
        
        obj[functionName] = function(...args) {
            // 检查日志断点
            if (self.logPoints.has(functionName)) {
                console.log(`[LOG] ${functionName}:`, self.logPoints.get(functionName), args);
            }
            
            // 检查条件断点
            if (self.breakpointConditions.has(functionName)) {
                const condition = self.breakpointConditions.get(functionName);
                if (condition(...args)) {
                    debugger; // 触发断点
                }
            }
            
            return originalFunction.apply(this, args);
        };
    }
}

// 使用示例
async function setupAdvancedDebugging() {
    const module = await import('./pkg/debug_example.js');
    await module.default();
    
    const debugHelper = new WasmDebugHelper(module);
    
    // 设置条件断点：只在输入包含 NaN 时暂停
    debugHelper.addConditionalBreakpoint('complex_calculation', (input) => {
        return input.some(x => isNaN(x));
    });
    
    // 设置日志断点
    debugHelper.addLogPoint('complex_calculation', '计算开始');
    
    // 创建测试数据
    const processor = new module.DataProcessor(50.0);
    
    // 测试正常数据
    const normalData = [1.0, 2.5, 3.7, 4.2, 5.8];
    normalData.forEach(value => processor.add_data(value));
    
    // 测试异常数据（会触发条件断点）
    const problematicData = [10.0, NaN, 15.0, Infinity, 20.0];
    
    try {
        const result1 = module.complex_calculation(new Float64Array(normalData));
        console.log('正常计算结果:', result1);
        
        // 这应该触发条件断点
        const result2 = module.complex_calculation(new Float64Array(problematicData));
        console.log('异常数据计算结果:', result2);
    } catch (error) {
        console.error('计算错误:', error);
    }
    
    const stats = processor.get_statistics();
    console.log('数据统计:', JSON.parse(stats));
}
```

**调试配置示例** (VS Code `.vscode/launch.json`):
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug WebAssembly in Chrome",
            "type": "chrome",
            "request": "launch",
            "url": "http://localhost:8000",
            "webRoot": "${workspaceFolder}",
            "sourceMaps": true,
            "userDataDir": "${workspaceFolder}/.vscode/chrome-debug-profile",
            "runtimeArgs": [
                "--enable-features=WebAssemblyDebugging",
                "--disable-extensions-except=",
                "--disable-web-security"
            ]
        }
    ]
}
```

**调试技巧总结**:

1. **条件断点设置**:
   - 在浏览器 DevTools 中右键断点位置
   - 选择 "Add conditional breakpoint"
   - 输入条件表达式

2. **日志断点使用**:
   - 设置断点后选择 "Add logpoint"
   - 输入要输出的表达式

3. **变量监视**:
   - 在 Watch 面板添加变量表达式
   - 使用 Console 执行调试命令

</details>

## 11.3 内存调试练习

### 练习 11.3.1 内存泄漏检测和分析 (25分)

**题目**: 创建一个包含内存泄漏的 WebAssembly 应用，使用调试工具检测并修复内存问题。

<details>
<summary>🔍 参考答案</summary>

**含有内存问题的 Rust 代码**:
```rust
use wasm_bindgen::prelude::*;
use std::collections::HashMap;
use std::rc::Rc;
use std::cell::RefCell;

// 故意的内存泄漏示例
#[wasm_bindgen]
pub struct LeakyContainer {
    data: Vec<Vec<u8>>,
    cache: HashMap<String, Rc<RefCell<Vec<u8>>>>,
    permanent_storage: Vec<Box<[u8; 1024]>>,
}

#[wasm_bindgen]
impl LeakyContainer {
    #[wasm_bindgen(constructor)]
    pub fn new() -> LeakyContainer {
        LeakyContainer {
            data: Vec::new(),
            cache: HashMap::new(),
            permanent_storage: Vec::new(),
        }
    }
    
    // 内存泄漏问题 1: 无限增长的缓存
    #[wasm_bindgen]
    pub fn add_to_cache(&mut self, key: String, data: Vec<u8>) {
        let cached_data = Rc::new(RefCell::new(data));
        self.cache.insert(key, cached_data);
        // 问题：缓存永远不会清理
    }
    
    // 内存泄漏问题 2: 循环引用
    #[wasm_bindgen]
    pub fn create_circular_reference(&mut self) {
        let data1 = Rc::new(RefCell::new(vec![1u8; 1000]));
        let data2 = Rc::new(RefCell::new(vec![2u8; 1000]));
        
        // 创建循环引用（在实际场景中更复杂）
        // 这里简化演示
        self.cache.insert("ref1".to_string(), data1.clone());
        self.cache.insert("ref2".to_string(), data2.clone());
    }
    
    // 内存泄漏问题 3: 忘记释放大块内存
    #[wasm_bindgen]
    pub fn allocate_permanent_memory(&mut self, count: usize) {
        for _ in 0..count {
            let large_chunk = Box::new([0u8; 1024]);
            self.permanent_storage.push(large_chunk);
        }
        // 问题：这些内存永远不会被释放
    }
    
    // 栈溢出风险函数
    #[wasm_bindgen]
    pub fn recursive_function(&self, depth: usize) -> usize {
        if depth == 0 {
            return 1;
        }
        
        // 每次递归都分配一些栈空间
        let _local_array = [0u8; 1000];
        
        // 危险的深度递归
        self.recursive_function(depth - 1) + depth
    }
    
    // 获取当前内存使用统计
    #[wasm_bindgen]
    pub fn get_memory_stats(&self) -> String {
        let data_size = self.data.iter().map(|v| v.len()).sum::<usize>();
        let cache_size = self.cache.len();
        let permanent_size = self.permanent_storage.len() * 1024;
        
        format!(
            "Data: {} bytes, Cache entries: {}, Permanent: {} bytes",
            data_size, cache_size, permanent_size
        )
    }
    
    // 尝试清理缓存（部分修复）
    #[wasm_bindgen]
    pub fn cleanup_cache(&mut self) {
        // 只保留最近的10个条目
        if self.cache.len() > 10 {
            let keys_to_remove: Vec<String> = self.cache
                .keys()
                .take(self.cache.len() - 10)
                .cloned()
                .collect();
            
            for key in keys_to_remove {
                self.cache.remove(&key);
            }
        }
    }
}

// 内存监控工具
#[wasm_bindgen]
pub struct MemoryMonitor {
    baseline_memory: usize,
    snapshots: Vec<(f64, usize)>, // (timestamp, memory_usage)
}

#[wasm_bindgen]
impl MemoryMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> MemoryMonitor {
        MemoryMonitor {
            baseline_memory: 0,
            snapshots: Vec::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn set_baseline(&mut self) {
        // 在实际实现中，这里会获取真实的内存使用量
        self.baseline_memory = self.get_current_memory_usage();
    }
    
    #[wasm_bindgen]
    pub fn take_snapshot(&mut self) {
        let timestamp = js_sys::Date::now();
        let memory_usage = self.get_current_memory_usage();
        self.snapshots.push((timestamp, memory_usage));
    }
    
    fn get_current_memory_usage(&self) -> usize {
        // 模拟内存使用量获取
        // 在真实实现中会使用 performance.memory 或其他 API
        42000 + self.snapshots.len() * 1000
    }
    
    #[wasm_bindgen]
    pub fn analyze_memory_trend(&self) -> String {
        if self.snapshots.len() < 2 {
            return "需要至少2个快照才能分析趋势".to_string();
        }
        
        let first = &self.snapshots[0];
        let last = &self.snapshots[self.snapshots.len() - 1];
        
        let time_diff = last.0 - first.0; // 毫秒
        let memory_diff = last.1 as i64 - first.1 as i64;
        
        let growth_rate = if time_diff > 0.0 {
            memory_diff as f64 / time_diff // bytes per ms
        } else {
            0.0
        };
        
        format!(
            "内存增长趋势: {:.2} bytes/ms, 总变化: {} bytes",
            growth_rate, memory_diff
        )
    }
    
    #[wasm_bindgen]
    pub fn detect_memory_leak(&self, threshold_per_second: f64) -> bool {
        if self.snapshots.len() < 10 {
            return false;
        }
        
        // 检查最近的内存增长趋势
        let recent_snapshots = &self.snapshots[self.snapshots.len() - 10..];
        let mut total_growth = 0i64;
        let mut total_time = 0.0;
        
        for i in 1..recent_snapshots.len() {
            let time_diff = recent_snapshots[i].0 - recent_snapshots[i-1].0;
            let memory_diff = recent_snapshots[i].1 as i64 - recent_snapshots[i-1].1 as i64;
            
            total_time += time_diff;
            total_growth += memory_diff;
        }
        
        if total_time > 0.0 {
            let growth_per_second = (total_growth as f64 / total_time) * 1000.0;
            growth_per_second > threshold_per_second
        } else {
            false
        }
    }
}

// 测试用的内存密集型操作
#[wasm_bindgen]
pub fn memory_stress_test(iterations: usize, size_per_iteration: usize) -> usize {
    let mut total_allocated = 0;
    let mut data_store: Vec<Vec<u8>> = Vec::new();
    
    for i in 0..iterations {
        let chunk = vec![0u8; size_per_iteration];
        total_allocated += size_per_iteration;
        
        // 故意保留某些数据不释放
        if i % 10 == 0 {
            data_store.push(chunk);
        }
    }
    
    // 返回总分配量，但 data_store 中的数据可能不会立即释放
    total_allocated
}
```

**JavaScript 内存监控代码**:
```javascript
class WebAssemblyMemoryDebugger {
    constructor() {
        this.memorySnapshots = [];
        this.isMonitoring = false;
        this.monitoringInterval = null;
    }
    
    startMemoryMonitoring(intervalMs = 1000) {
        if (this.isMonitoring) return;
        
        this.isMonitoring = true;
        this.monitoringInterval = setInterval(() => {
            this.takeMemorySnapshot();
        }, intervalMs);
        
        console.log('开始内存监控');
    }
    
    stopMemoryMonitoring() {
        if (!this.isMonitoring) return;
        
        clearInterval(this.monitoringInterval);
        this.isMonitoring = false;
        console.log('停止内存监控');
    }
    
    takeMemorySnapshot() {
        const snapshot = {
            timestamp: Date.now(),
            jsHeapUsed: 0,
            jsHeapTotal: 0,
            wasmMemory: 0
        };
        
        // 获取 JavaScript 堆信息
        if (performance.memory) {
            snapshot.jsHeapUsed = performance.memory.usedJSHeapSize;
            snapshot.jsHeapTotal = performance.memory.totalJSHeapSize;
        }
        
        // 获取 WebAssembly 内存信息
        if (window.wasmModule && window.wasmModule.memory) {
            snapshot.wasmMemory = window.wasmModule.memory.buffer.byteLength;
        }
        
        this.memorySnapshots.push(snapshot);
        
        // 保持最近100个快照
        if (this.memorySnapshots.length > 100) {
            this.memorySnapshots.shift();
        }
    }
    
    analyzeMemoryLeaks() {
        if (this.memorySnapshots.length < 10) {
            console.log('需要更多数据点进行分析');
            return null;
        }
        
        const recent = this.memorySnapshots.slice(-10);
        const analysis = {
            jsHeapGrowth: this.calculateGrowthRate(recent, 'jsHeapUsed'),
            wasmMemoryGrowth: this.calculateGrowthRate(recent, 'wasmMemory'),
            timeSpan: recent[recent.length - 1].timestamp - recent[0].timestamp
        };
        
        // 判断是否存在内存泄漏
        analysis.hasJsLeak = analysis.jsHeapGrowth > 1000; // 每秒增长1KB
        analysis.hasWasmLeak = analysis.wasmMemoryGrowth > 500; // 每秒增长500B
        
        return analysis;
    }
    
    calculateGrowthRate(snapshots, property) {
        if (snapshots.length < 2) return 0;
        
        const first = snapshots[0];
        const last = snapshots[snapshots.length - 1];
        const timeDiff = last.timestamp - first.timestamp;
        const memoryDiff = last[property] - first[property];
        
        return timeDiff > 0 ? (memoryDiff / timeDiff) * 1000 : 0; // bytes per second
    }
    
    generateMemoryReport() {
        const analysis = this.analyzeMemoryLeaks();
        if (!analysis) return '数据不足';
        
        return `
内存分析报告:
时间跨度: ${(analysis.timeSpan / 1000).toFixed(2)} 秒
JS堆增长率: ${analysis.jsHeapGrowth.toFixed(2)} bytes/秒
WASM内存增长率: ${analysis.wasmMemoryGrowth.toFixed(2)} bytes/秒
疑似JS内存泄漏: ${analysis.hasJsLeak ? '是' : '否'}
疑似WASM内存泄漏: ${analysis.hasWasmLeak ? '是' : '否'}
        `;
    }
    
    plotMemoryUsage() {
        if (this.memorySnapshots.length === 0) return;
        
        // 简单的控制台图表
        console.log('内存使用趋势:');
        this.memorySnapshots.forEach((snapshot, index) => {
            if (index % 5 === 0) { // 每5个点显示一次
                const jsHeapMB = (snapshot.jsHeapUsed / 1024 / 1024).toFixed(1);
                const wasmMB = (snapshot.wasmMemory / 1024 / 1024).toFixed(1);
                console.log(`${index}: JS=${jsHeapMB}MB, WASM=${wasmMB}MB`);
            }
        });
    }
}

// 测试内存泄漏检测
async function testMemoryLeakDetection() {
    const module = await import('./pkg/debug_example.js');
    await module.default();
    
    window.wasmModule = module;
    
    const debugger = new WebAssemblyMemoryDebugger();
    const monitor = new module.MemoryMonitor();
    const container = new module.LeakyContainer();
    
    // 开始监控
    debugger.startMemoryMonitoring(500);
    monitor.set_baseline();
    
    // 模拟内存泄漏
    console.log('开始内存泄漏测试...');
    
    for (let i = 0; i < 50; i++) {
        // 添加到缓存（不会清理）
        container.add_to_cache(`key_${i}`, new Array(1000).fill(i));
        
        // 分配永久内存
        container.allocate_permanent_memory(5);
        
        // 创建循环引用
        if (i % 10 === 0) {
            container.create_circular_reference();
        }
        
        // 拍摄内存快照
        monitor.take_snapshot();
        
        console.log(container.get_memory_stats());
        
        // 等待一段时间
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // 分析结果
    setTimeout(() => {
        debugger.stopMemoryMonitoring();
        
        console.log('=== 内存分析结果 ===');
        console.log(debugger.generateMemoryReport());
        console.log(monitor.analyze_memory_trend());
        
        const hasLeak = monitor.detect_memory_leak(1000.0);
        console.log(`检测到内存泄漏: ${hasLeak ? '是' : '否'}`);
        
        debugger.plotMemoryUsage();
        
        // 尝试清理
        console.log('尝试清理内存...');
        container.cleanup_cache();
        console.log('清理后:', container.get_memory_stats());
        
    }, 2000);
}
```

**修复后的代码示例**:
```rust
// 修复后的内存安全版本
#[wasm_bindgen]
pub struct FixedContainer {
    cache: HashMap<String, Vec<u8>>,
    max_cache_size: usize,
}

#[wasm_bindgen]
impl FixedContainer {
    #[wasm_bindgen(constructor)]
    pub fn new(max_cache_size: usize) -> FixedContainer {
        FixedContainer {
            cache: HashMap::new(),
            max_cache_size,
        }
    }
    
    #[wasm_bindgen]
    pub fn add_to_cache(&mut self, key: String, data: Vec<u8>) {
        // 检查缓存大小限制
        if self.cache.len() >= self.max_cache_size {
            // 移除最旧的条目
            if let Some(oldest_key) = self.cache.keys().next().cloned() {
                self.cache.remove(&oldest_key);
            }
        }
        
        self.cache.insert(key, data);
    }
}
```

</details>

## 11.4 性能调试练习

### 练习 11.4.1 性能瓶颈分析和优化 (25分)

**题目**: 使用性能分析工具识别 WebAssembly 应用中的性能瓶颈，并实施优化方案。

<details>
<summary>🔍 参考答案</summary>

**性能测试目标代码**:
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct PerformanceTestSuite {
    data: Vec<f64>,
    processed_count: usize,
}

#[wasm_bindgen]
impl PerformanceTestSuite {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceTestSuite {
        PerformanceTestSuite {
            data: Vec::new(),
            processed_count: 0,
        }
    }
    
    // 性能瓶颈1: 低效的数据访问模式
    #[wasm_bindgen]
    pub fn inefficient_processing(&mut self, size: usize) -> f64 {
        let start = js_sys::Date::now();
        
        // 创建测试数据
        self.data = (0..size).map(|i| i as f64).collect();
        
        let mut result = 0.0;
        
        // 低效的内存访问模式
        for i in 0..size {
            for j in 0..size {
                if i < self.data.len() && j < i {
                    // 非连续内存访问
                    result += self.data[i] * self.data[j];
                }
            }
        }
        
        self.processed_count += 1;
        js_sys::Date::now() - start
    }
    
    // 优化版本1: 改进的数据访问模式
    #[wasm_bindgen]
    pub fn optimized_processing(&mut self, size: usize) -> f64 {
        let start = js_sys::Date::now();
        
        self.data = (0..size).map(|i| i as f64).collect();
        
        let mut result = 0.0;
        
        // 优化的内存访问模式
        for i in 0..size {
            let data_i = self.data[i];
            for j in 0..i {
                result += data_i * self.data[j];
            }
        }
        
        self.processed_count += 1;
        js_sys::Date::now() - start
    }
    
    // 性能瓶颈2: 频繁的内存分配
    #[wasm_bindgen]
    pub fn allocation_heavy_function(&self, iterations: usize) -> f64 {
        let start = js_sys::Date::now();
        
        let mut results = Vec::new();
        
        for i in 0..iterations {
            // 频繁的小内存分配
            let mut temp_vec = Vec::new();
            for j in 0..100 {
                temp_vec.push((i * j) as f64);
            }
            
            // 不必要的中间计算
            let sum: f64 = temp_vec.iter().sum();
            let mean = sum / temp_vec.len() as f64;
            
            results.push(mean);
        }
        
        js_sys::Date::now() - start
    }
    
    // 优化版本2: 减少内存分配
    #[wasm_bindgen]
    pub fn allocation_optimized_function(&self, iterations: usize) -> f64 {
        let start = js_sys::Date::now();
        
        // 预分配缓冲区
        let mut temp_vec = Vec::with_capacity(100);
        let mut results = Vec::with_capacity(iterations);
        
        for i in 0..iterations {
            temp_vec.clear(); // 重用而不是重新分配
            
            for j in 0..100 {
                temp_vec.push((i * j) as f64);
            }
            
            let sum: f64 = temp_vec.iter().sum();
            let mean = sum / temp_vec.len() as f64;
            
            results.push(mean);
        }
        
        js_sys::Date::now() - start
    }
    
    // 性能瓶颈3: 未优化的算法
    #[wasm_bindgen]
    pub fn slow_algorithm(&self, n: usize) -> f64 {
        let start = js_sys::Date::now();
        
        // O(n²) 的算法
        let mut result = 0.0;
        for i in 0..n {
            for j in 0..n {
                result += ((i * j) as f64).sin();
            }
        }
        
        js_sys::Date::now() - start
    }
    
    // 优化版本3: 改进的算法
    #[wasm_bindgen]
    pub fn fast_algorithm(&self, n: usize) -> f64 {
        let start = js_sys::Date::now();
        
        // 预计算sin值
        let sin_values: Vec<f64> = (0..n).map(|i| (i as f64).sin()).collect();
        
        let mut result = 0.0;
        for i in 0..n {
            for j in 0..n {
                result += sin_values[i] * sin_values[j];
            }
        }
        
        js_sys::Date::now() - start
    }
    
    // 性能基准测试
    #[wasm_bindgen]
    pub fn run_performance_benchmark(&mut self) -> String {
        const TEST_SIZE: usize = 1000;
        const ITERATIONS: usize = 100;
        
        // 测试低效处理
        let inefficient_time = self.inefficient_processing(TEST_SIZE);
        let optimized_time = self.optimized_processing(TEST_SIZE);
        
        // 测试内存分配
        let allocation_heavy_time = self.allocation_heavy_function(ITERATIONS);
        let allocation_optimized_time = self.allocation_optimized_function(ITERATIONS);
        
        // 测试算法效率
        let slow_algorithm_time = self.slow_algorithm(100);
        let fast_algorithm_time = self.fast_algorithm(100);
        
        format!(
            "性能基准测试结果:\n\
            数据处理:\n\
            - 低效版本: {:.2}ms\n\
            - 优化版本: {:.2}ms\n\
            - 提升: {:.2}x\n\
            \n\
            内存分配:\n\
            - 频繁分配: {:.2}ms\n\
            - 优化分配: {:.2}ms\n\
            - 提升: {:.2}x\n\
            \n\
            算法效率:\n\
            - 慢算法: {:.2}ms\n\
            - 快算法: {:.2}ms\n\
            - 提升: {:.2}x",
            inefficient_time,
            optimized_time,
            inefficient_time / optimized_time.max(0.1),
            allocation_heavy_time,
            allocation_optimized_time,
            allocation_heavy_time / allocation_optimized_time.max(0.1),
            slow_algorithm_time,
            fast_algorithm_time,
            slow_algorithm_time / fast_algorithm_time.max(0.1)
        )
    }
}

// 性能分析器
#[wasm_bindgen]
pub struct PerformanceProfiler {
    measurements: std::collections::HashMap<String, Vec<f64>>,
}

#[wasm_bindgen]
impl PerformanceProfiler {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceProfiler {
        PerformanceProfiler {
            measurements: std::collections::HashMap::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn time_function<F>(&mut self, name: &str, mut func: F) -> f64 
    where 
        F: FnMut() -> (),
    {
        let start = js_sys::Date::now();
        func();
        let duration = js_sys::Date::now() - start;
        
        self.measurements
            .entry(name.to_string())
            .or_insert_with(Vec::new)
            .push(duration);
        
        duration
    }
    
    #[wasm_bindgen]
    pub fn get_statistics(&self, name: &str) -> String {
        if let Some(measurements) = self.measurements.get(name) {
            if measurements.is_empty() {
                return "无测量数据".to_string();
            }
            
            let count = measurements.len();
            let sum: f64 = measurements.iter().sum();
            let mean = sum / count as f64;
            let min = measurements.iter().fold(f64::INFINITY, |a, &b| a.min(b));
            let max = measurements.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
            
            // 计算标准差
            let variance = measurements.iter()
                .map(|&x| (x - mean).powi(2))
                .sum::<f64>() / count as f64;
            let std_dev = variance.sqrt();
            
            format!(
                "{}: 次数={}, 平均={:.2}ms, 最小={:.2}ms, 最大={:.2}ms, 标准差={:.2}ms",
                name, count, mean, min, max, std_dev
            )
        } else {
            format!("{}: 无数据", name)
        }
    }
}
```

**JavaScript 性能分析工具**:
```javascript
class WasmPerformanceAnalyzer {
    constructor() {
        this.measurements = new Map();
        this.observers = [];
    }
    
    // 使用 Performance Observer API
    startPerformanceObserver() {
        if ('PerformanceObserver' in window) {
            const observer = new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    if (entry.name.includes('wasm')) {
                        this.logPerformanceEntry(entry);
                    }
                }
            });
            
            observer.observe({ entryTypes: ['measure', 'navigation', 'resource'] });
            this.observers.push(observer);
        }
    }
    
    logPerformanceEntry(entry) {
        console.log(`Performance: ${entry.name} - ${entry.duration.toFixed(2)}ms`);
    }
    
    // 高精度计时
    async timeAsyncFunction(name, asyncFunc) {
        performance.mark(`${name}-start`);
        const startTime = performance.now();
        
        try {
            const result = await asyncFunc();
            const endTime = performance.now();
            const duration = endTime - startTime;
            
            performance.mark(`${name}-end`);
            performance.measure(name, `${name}-start`, `${name}-end`);
            
            this.recordMeasurement(name, duration);
            return { result, duration };
        } catch (error) {
            console.error(`Performance test ${name} failed:`, error);
            throw error;
        }
    }
    
    recordMeasurement(name, duration) {
        if (!this.measurements.has(name)) {
            this.measurements.set(name, []);
        }
        this.measurements.get(name).push(duration);
    }
    
    // 性能回归检测
    detectPerformanceRegression(testName, expectedDuration, tolerance = 0.2) {
        const measurements = this.measurements.get(testName);
        if (!measurements || measurements.length === 0) {
            return { regression: false, reason: 'No measurements available' };
        }
        
        const recent = measurements.slice(-5); // 最近5次测量
        const avgRecent = recent.reduce((a, b) => a + b) / recent.length;
        
        const regressionThreshold = expectedDuration * (1 + tolerance);
        const isRegression = avgRecent > regressionThreshold;
        
        return {
            regression: isRegression,
            expectedDuration,
            actualDuration: avgRecent,
            slowdownFactor: avgRecent / expectedDuration,
            reason: isRegression ? 
                `Performance degraded by ${((avgRecent / expectedDuration - 1) * 100).toFixed(1)}%` :
                'Performance within expected range'
        };
    }
    
    // 生成性能报告
    generatePerformanceReport() {
        const report = {
            timestamp: new Date().toISOString(),
            tests: {},
            summary: {
                totalTests: this.measurements.size,
                totalMeasurements: 0
            }
        };
        
        for (const [testName, measurements] of this.measurements) {
            const stats = this.calculateStatistics(measurements);
            report.tests[testName] = stats;
            report.summary.totalMeasurements += measurements.length;
        }
        
        return report;
    }
    
    calculateStatistics(measurements) {
        if (measurements.length === 0) return null;
        
        const sorted = [...measurements].sort((a, b) => a - b);
        const sum = measurements.reduce((a, b) => a + b, 0);
        
        return {
            count: measurements.length,
            min: Math.min(...measurements),
            max: Math.max(...measurements),
            mean: sum / measurements.length,
            median: sorted[Math.floor(sorted.length / 2)],
            p95: sorted[Math.floor(sorted.length * 0.95)],
            p99: sorted[Math.floor(sorted.length * 0.99)]
        };
    }
    
    // 可视化性能趋势
    visualizePerformanceTrend(testName) {
        const measurements = this.measurements.get(testName);
        if (!measurements) {
            console.log(`No data for test: ${testName}`);
            return;
        }
        
        console.log(`Performance trend for ${testName}:`);
        measurements.forEach((duration, index) => {
            const bar = '█'.repeat(Math.round(duration / 10));
            console.log(`${index.toString().padStart(3)}: ${duration.toFixed(2)}ms ${bar}`);
        });
    }
}

// 综合性能测试
async function runComprehensivePerformanceTest() {
    const module = await import('./pkg/debug_example.js');
    await module.default();
    
    const analyzer = new WasmPerformanceAnalyzer();
    const testSuite = new module.PerformanceTestSuite();
    
    analyzer.startPerformanceObserver();
    
    console.log('开始性能测试...');
    
    // 测试1: 数据处理性能
    await analyzer.timeAsyncFunction('inefficient_processing', async () => {
        return testSuite.inefficient_processing(500);
    });
    
    await analyzer.timeAsyncFunction('optimized_processing', async () => {
        return testSuite.optimized_processing(500);
    });
    
    // 测试2: 内存分配性能
    await analyzer.timeAsyncFunction('allocation_heavy', async () => {
        return testSuite.allocation_heavy_function(100);
    });
    
    await analyzer.timeAsyncFunction('allocation_optimized', async () => {
        return testSuite.allocation_optimized_function(100);
    });
    
    // 测试3: 算法性能
    await analyzer.timeAsyncFunction('slow_algorithm', async () => {
        return testSuite.slow_algorithm(50);
    });
    
    await analyzer.timeAsyncFunction('fast_algorithm', async () => {
        return testSuite.fast_algorithm(50);
    });
    
    // 运行综合基准测试
    console.log('\n' + testSuite.run_performance_benchmark());
    
    // 分析结果
    console.log('\n=== 性能分析结果 ===');
    const report = analyzer.generatePerformanceReport();
    console.log(JSON.stringify(report, null, 2));
    
    // 检查性能回归
    const regressionResults = [
        analyzer.detectPerformanceRegression('optimized_processing', 50),
        analyzer.detectPerformanceRegression('allocation_optimized', 30),
        analyzer.detectPerformanceRegression('fast_algorithm', 20)
    ];
    
    console.log('\n=== 性能回归检测 ===');
    regressionResults.forEach((result, index) => {
        const testNames = ['optimized_processing', 'allocation_optimized', 'fast_algorithm'];
        console.log(`${testNames[index]}: ${result.reason}`);
    });
    
    // 可视化趋势
    console.log('\n=== 性能趋势 ===');
    analyzer.visualizePerformanceTrend('optimized_processing');
}
```

</details>

## 11.5 高级调试练习

### 练习 11.5.1 自定义调试工具开发 (30分)

**题目**: 开发一个自定义的 WebAssembly 调试工具，集成日志记录、错误跟踪和性能监控功能。

<details>
<summary>🔍 参考答案</summary>

该练习需要学习者综合运用前面所学的调试技术，开发一个完整的调试工具系统，包含：

1. **日志系统**: 分级日志记录和过滤
2. **错误跟踪**: 异常捕获和堆栈跟踪
3. **性能监控**: 实时性能指标收集
4. **调试界面**: 可视化调试信息展示
5. **配置管理**: 调试选项配置和持久化

这个练习要求学习者具备较强的工程实践能力，能够设计和实现一个生产级的调试工具。

</details>

---

## 本章练习总结

本章练习全面覆盖了 WebAssembly 调试的核心技能：

### 🎯 学习目标达成

1. **调试环境掌握** - 熟练配置和使用各种调试工具
2. **断点调试精通** - 掌握高级断点技术和变量检查
3. **内存问题诊断** - 能够检测和修复内存泄漏
4. **性能优化能力** - 识别瓶颈并实施优化方案
5. **工具开发技能** - 构建自定义调试工具

### 📈 难度递进

- **基础练习 (15分)** - 环境配置和基本调试
- **进阶练习 (20-25分)** - 高级调试技术和问题诊断
- **高级练习 (30分)** - 自定义工具开发和系统集成

### 🔧 关键技能

1. **工具使用熟练度** - 浏览器开发者工具、VS Code 等
2. **问题诊断能力** - 快速定位和解决各类问题
3. **性能分析技能** - 使用专业工具进行性能优化
4. **系统思维** - 构建完整的调试解决方案

通过这些练习，学习者将具备专业的 WebAssembly 调试能力，能够在实际项目中高效地诊断和解决问题。
