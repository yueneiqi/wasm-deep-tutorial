# 第10章 性能优化

本章将深入探讨 WebAssembly 应用的性能优化技术，从编译时优化到运行时性能调优，帮助你构建高性能的 WebAssembly 应用。

## 10.1 编译时优化

### 10.1.1 编译器优化选项

不同的编译器和目标平台提供了丰富的优化选项，正确配置这些选项是性能优化的第一步。

#### Rust 优化配置

**Cargo.toml 优化配置**:
```toml
[package]
name = "wasm-optimization-demo"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

# 发布版本优化
[profile.release]
# 优化级别
opt-level = 3          # 最高优化级别 (0-3, s, z)
debug = false          # 禁用调试信息
overflow-checks = false # 禁用整数溢出检查
lto = true            # 启用链接时优化 (Link Time Optimization)
codegen-units = 1     # 减少代码生成单元，提高优化效果
panic = "abort"       # 使用 abort 而不是 unwind，减小文件大小

# 针对 WebAssembly 的特殊优化
[profile.release.package."*"]
opt-level = 3
debug-assertions = false

# 依赖项优化
[dependencies]
wasm-bindgen = { version = "0.2", features = ["serde-serialize"] }

[dependencies.web-sys]
version = "0.3"
default-features = false
features = [
  "console",
  "Performance",
]
```

**优化级别详解**:
```rust
// opt-level 的不同级别
// 0: 无优化，快速编译
// 1: 基本优化
// 2: 默认优化级别
// 3: 最高优化级别，编译时间长但性能最佳
// "s": 优化代码大小
// "z": 更激进的代码大小优化

// 示例：性能关键的函数
#[inline(always)]  // 强制内联
pub fn critical_calculation(data: &[f64]) -> f64 {
    // 使用 SIMD 指令进行向量化计算
    data.iter().map(|&x| x * x).sum()
}

// 示例：减少内存分配
#[no_mangle]  // 防止名称混淆
pub extern "C" fn efficient_string_processing(
    input: *const u8, 
    len: usize
) -> u32 {
    // 直接操作原始指针，避免字符串分配
    let slice = unsafe { std::slice::from_raw_parts(input, len) };
    slice.iter().map(|&b| b as u32).sum()
}
```

#### C/C++ 优化配置

**Emscripten 优化参数**:
```bash
# 基本优化
emcc -O3 -s WASM=1 \
     -s EXPORTED_FUNCTIONS='["_add", "_multiply"]' \
     -s MODULARIZE=1 \
     -s EXPORT_NAME="MathModule" \
     input.c -o output.js

# 高级优化
emcc -O3 -flto \
     -s WASM=1 \
     -s ALLOW_MEMORY_GROWTH=1 \
     -s INITIAL_MEMORY=16777216 \
     -s MAXIMUM_MEMORY=33554432 \
     -s STACK_SIZE=1048576 \
     -s MODULARIZE=1 \
     -s EXPORT_NAME="OptimizedModule" \
     -s EXPORTED_FUNCTIONS='["_main", "_malloc", "_free"]' \
     -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
     --closure 1 \
     input.c -o optimized.js

# 大小优化
emcc -Oz -flto \
     -s WASM=1 \
     -s MODULARIZE=1 \
     -s EXPORT_NAME="MinimalModule" \
     -s NO_FILESYSTEM=1 \
     -s DISABLE_EXCEPTION_CATCHING=1 \
     -s AGGRESSIVE_VARIABLE_ELIMINATION=1 \
     --closure 1 \
     input.c -o minimal.js
```

**优化选项说明**:
```bash
# 性能优化选项
-O3                    # 最高优化级别
-flto                  # 链接时优化
--closure 1            # Google Closure Compiler 优化

# 内存管理优化
-s INITIAL_MEMORY=16MB    # 初始内存大小
-s ALLOW_MEMORY_GROWTH=1  # 允许内存增长
-s MAXIMUM_MEMORY=32MB    # 最大内存限制

# 代码大小优化
-s NO_FILESYSTEM=1                    # 禁用文件系统
-s DISABLE_EXCEPTION_CATCHING=1       # 禁用异常处理
-s AGGRESSIVE_VARIABLE_ELIMINATION=1  # 激进的变量消除
```

### 10.1.2 构建工具优化

#### wasm-pack 优化

**wasm-pack 构建选项**:
```bash
# 发布版本构建
wasm-pack build \
  --target web \
  --out-dir pkg \
  --release \
  --scope myorg

# 优化构建
wasm-pack build \
  --target web \
  --out-dir pkg \
  --release \
  --scope myorg \
  -- \
  --features "simd"

# 自定义优化
RUSTFLAGS="-C target-cpu=native -C target-feature=+simd128" \
wasm-pack build \
  --target web \
  --out-dir pkg \
  --release
```

#### Binaryen 工具链优化

**wasm-opt 优化**:
```bash
# 基本优化
wasm-opt -O3 input.wasm -o optimized.wasm

# 高级优化
wasm-opt -O4 --enable-simd --enable-bulk-memory \
         --enable-multivalue \
         input.wasm -o highly_optimized.wasm

# 大小优化
wasm-opt -Oz --strip-debug --strip-producers \
         input.wasm -o size_optimized.wasm

# 自定义优化管道
wasm-opt --inline-functions-with-loops \
         --optimize-instructions \
         --vacuum \
         --remove-unused-brs \
         --remove-unused-names \
         --merge-blocks \
         input.wasm -o custom_optimized.wasm
```

### 10.1.3 代码优化技术

#### 内存布局优化

```rust
// 结构体字段重排序，减少内存填充
#[repr(C)]  // 使用 C 内存布局
pub struct OptimizedStruct {
    // 按照大小递减排列，减少内存填充
    data: u64,        // 8 字节
    count: u32,       // 4 字节
    flags: u16,       // 2 字节
    active: bool,     // 1 字节
    // 编译器会添加 1 字节填充以对齐到 8 字节
}

// 使用 packed 属性紧凑存储
#[repr(packed)]
pub struct PackedStruct {
    value: u32,
    flag: u8,
    // 无填充，但访问可能较慢
}

// 缓存友好的数据结构
pub struct SoAData {
    // Structure of Arrays (SoA) 模式
    // 提高缓存局部性
    x_coords: Vec<f32>,
    y_coords: Vec<f32>,
    z_coords: Vec<f32>,
}

impl SoAData {
    pub fn process_all_x(&mut self) {
        // 顺序访问提高缓存命中率
        for x in &mut self.x_coords {
            *x *= 2.0;
        }
    }
}
```

#### 循环优化

```rust
// 循环展开
pub fn unrolled_sum(data: &[f32]) -> f32 {
    let mut sum = 0.0;
    let chunks = data.chunks_exact(4);
    let remainder = chunks.remainder();
    
    // 手动展开循环，减少分支开销
    for chunk in chunks {
        sum += chunk[0] + chunk[1] + chunk[2] + chunk[3];
    }
    
    // 处理剩余元素
    for &value in remainder {
        sum += value;
    }
    
    sum
}

// SIMD 优化（需要 nightly Rust）
#[cfg(target_arch = "wasm32")]
use std::arch::wasm32::*;

pub fn simd_sum(data: &[f32]) -> f32 {
    let mut sum = f32x4_splat(0.0);
    let chunks = data.chunks_exact(4);
    let remainder = chunks.remainder();
    
    for chunk in chunks {
        let vec = f32x4(chunk[0], chunk[1], chunk[2], chunk[3]);
        sum = f32x4_add(sum, vec);
    }
    
    // 水平求和
    let array = [f32x4_extract_lane::<0>(sum),
                 f32x4_extract_lane::<1>(sum),
                 f32x4_extract_lane::<2>(sum),
                 f32x4_extract_lane::<3>(sum)];
    
    array.iter().sum::<f32>() + remainder.iter().sum::<f32>()
}

// 缓存友好的矩阵乘法
pub fn cache_friendly_matrix_multiply(
    a: &[f32], 
    b: &[f32], 
    c: &mut [f32], 
    n: usize
) {
    const BLOCK_SIZE: usize = 64;
    
    for ii in (0..n).step_by(BLOCK_SIZE) {
        for jj in (0..n).step_by(BLOCK_SIZE) {
            for kk in (0..n).step_by(BLOCK_SIZE) {
                // 块内计算，提高缓存局部性
                let i_end = std::cmp::min(ii + BLOCK_SIZE, n);
                let j_end = std::cmp::min(jj + BLOCK_SIZE, n);
                let k_end = std::cmp::min(kk + BLOCK_SIZE, n);
                
                for i in ii..i_end {
                    for j in jj..j_end {
                        let mut sum = 0.0;
                        for k in kk..k_end {
                            sum += a[i * n + k] * b[k * n + j];
                        }
                        c[i * n + j] += sum;
                    }
                }
            }
        }
    }
}
```

## 10.2 运行时优化

### 10.2.1 内存管理优化

#### 自定义内存分配器

```rust
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};

// 简单的内存使用统计分配器
pub struct StatsAllocator {
    allocated: AtomicUsize,
    deallocated: AtomicUsize,
}

impl StatsAllocator {
    pub const fn new() -> Self {
        StatsAllocator {
            allocated: AtomicUsize::new(0),
            deallocated: AtomicUsize::new(0),
        }
    }
    
    pub fn bytes_allocated(&self) -> usize {
        self.allocated.load(Ordering::Relaxed)
    }
    
    pub fn bytes_deallocated(&self) -> usize {
        self.deallocated.load(Ordering::Relaxed)
    }
    
    pub fn bytes_in_use(&self) -> usize {
        self.bytes_allocated() - self.bytes_deallocated()
    }
}

unsafe impl GlobalAlloc for StatsAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = System.alloc(layout);
        if !ptr.is_null() {
            self.allocated.fetch_add(layout.size(), Ordering::Relaxed);
        }
        ptr
    }
    
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        System.dealloc(ptr, layout);
        self.deallocated.fetch_add(layout.size(), Ordering::Relaxed);
    }
}

// 全局分配器
#[global_allocator]
static ALLOCATOR: StatsAllocator = StatsAllocator::new();

// 内存池分配器
pub struct MemoryPool {
    pool: Vec<u8>,
    current: usize,
}

impl MemoryPool {
    pub fn new(size: usize) -> Self {
        MemoryPool {
            pool: vec![0; size],
            current: 0,
        }
    }
    
    pub fn allocate(&mut self, size: usize, align: usize) -> Option<*mut u8> {
        // 对齐到指定边界
        let aligned_start = (self.current + align - 1) & !(align - 1);
        let end = aligned_start + size;
        
        if end <= self.pool.len() {
            self.current = end;
            Some(self.pool.as_mut_ptr().wrapping_add(aligned_start))
        } else {
            None
        }
    }
    
    pub fn reset(&mut self) {
        self.current = 0;
    }
    
    pub fn usage(&self) -> f64 {
        self.current as f64 / self.pool.len() as f64
    }
}

// 使用示例
#[wasm_bindgen]
pub struct OptimizedProcessor {
    pool: MemoryPool,
    temp_buffers: Vec<Vec<f32>>,
}

#[wasm_bindgen]
impl OptimizedProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(pool_size: usize) -> OptimizedProcessor {
        OptimizedProcessor {
            pool: MemoryPool::new(pool_size),
            temp_buffers: Vec::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn process_data(&mut self, data: &[f32]) -> Vec<f32> {
        // 重用缓冲区避免重复分配
        if self.temp_buffers.is_empty() {
            self.temp_buffers.push(Vec::with_capacity(data.len()));
        }
        
        let buffer = &mut self.temp_buffers[0];
        buffer.clear();
        buffer.extend_from_slice(data);
        
        // 就地处理，避免额外分配
        for value in buffer.iter_mut() {
            *value = value.sqrt();
        }
        
        buffer.clone()
    }
    
    #[wasm_bindgen]
    pub fn get_memory_stats(&self) -> String {
        format!(
            "Pool usage: {:.2}%, Allocated: {} bytes, In use: {} bytes",
            self.pool.usage() * 100.0,
            ALLOCATOR.bytes_allocated(),
            ALLOCATOR.bytes_in_use()
        )
    }
}
```

#### 对象池模式

```rust
use std::collections::VecDeque;

// 对象池实现
pub struct ObjectPool<T> {
    objects: VecDeque<T>,
    create_fn: Box<dyn Fn() -> T>,
}

impl<T> ObjectPool<T> {
    pub fn new<F>(create_fn: F) -> Self 
    where 
        F: Fn() -> T + 'static,
    {
        ObjectPool {
            objects: VecDeque::new(),
            create_fn: Box::new(create_fn),
        }
    }
    
    pub fn acquire(&mut self) -> T {
        self.objects.pop_front().unwrap_or_else(|| (self.create_fn)())
    }
    
    pub fn release(&mut self, obj: T) {
        self.objects.push_back(obj);
    }
    
    pub fn size(&self) -> usize {
        self.objects.len()
    }
}

// 可重用的计算上下文
pub struct ComputeContext {
    temp_array: Vec<f32>,
    result_buffer: Vec<f32>,
}

impl ComputeContext {
    pub fn new() -> Self {
        ComputeContext {
            temp_array: Vec::new(),
            result_buffer: Vec::new(),
        }
    }
    
    pub fn reset(&mut self) {
        self.temp_array.clear();
        self.result_buffer.clear();
    }
    
    pub fn compute(&mut self, input: &[f32]) -> &[f32] {
        self.temp_array.extend_from_slice(input);
        
        // 执行计算
        self.result_buffer.clear();
        for &value in &self.temp_array {
            self.result_buffer.push(value * 2.0 + 1.0);
        }
        
        &self.result_buffer
    }
}

#[wasm_bindgen]
pub struct PoolManager {
    context_pool: ObjectPool<ComputeContext>,
}

#[wasm_bindgen]
impl PoolManager {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PoolManager {
        PoolManager {
            context_pool: ObjectPool::new(|| ComputeContext::new()),
        }
    }
    
    #[wasm_bindgen]
    pub fn process_batch(&mut self, data: &[f32]) -> Vec<f32> {
        let mut context = self.context_pool.acquire();
        context.reset();
        
        let result = context.compute(data).to_vec();
        
        self.context_pool.release(context);
        result
    }
    
    #[wasm_bindgen]
    pub fn pool_size(&self) -> usize {
        self.context_pool.size()
    }
}
```

### 10.2.2 计算优化

#### 算法复杂度优化

```rust
// 快速排序 vs 基数排序
pub mod sorting {
    // 传统快速排序 O(n log n)
    pub fn quicksort(arr: &mut [i32]) {
        if arr.len() <= 1 {
            return;
        }
        
        let pivot = partition(arr);
        quicksort(&mut arr[0..pivot]);
        quicksort(&mut arr[pivot + 1..]);
    }
    
    fn partition(arr: &mut [i32]) -> usize {
        let pivot = arr.len() - 1;
        let mut i = 0;
        
        for j in 0..pivot {
            if arr[j] <= arr[pivot] {
                arr.swap(i, j);
                i += 1;
            }
        }
        
        arr.swap(i, pivot);
        i
    }
    
    // 基数排序 O(d * n)，对整数更高效
    pub fn radix_sort(arr: &mut [u32]) {
        if arr.is_empty() {
            return;
        }
        
        let max_val = *arr.iter().max().unwrap();
        let mut exp = 1;
        
        while max_val / exp > 0 {
            counting_sort(arr, exp);
            exp *= 10;
        }
    }
    
    fn counting_sort(arr: &mut [u32], exp: u32) {
        let n = arr.len();
        let mut output = vec![0; n];
        let mut count = [0; 10];
        
        // 计算每个数字的出现次数
        for &num in arr.iter() {
            count[((num / exp) % 10) as usize] += 1;
        }
        
        // 转换为实际位置
        for i in 1..10 {
            count[i] += count[i - 1];
        }
        
        // 构建输出数组
        for &num in arr.iter().rev() {
            let digit = ((num / exp) % 10) as usize;
            output[count[digit] - 1] = num;
            count[digit] -= 1;
        }
        
        // 复制回原数组
        for (i, &val) in output.iter().enumerate() {
            arr[i] = val;
        }
    }
}

// 哈希表 vs 排序数组查找
pub mod lookup {
    use std::collections::HashMap;
    
    pub struct OptimizedLookup {
        // 小数据集使用排序数组
        sorted_pairs: Vec<(u32, String)>,
        // 大数据集使用哈希表
        hash_map: HashMap<u32, String>,
        threshold: usize,
    }
    
    impl OptimizedLookup {
        pub fn new(threshold: usize) -> Self {
            OptimizedLookup {
                sorted_pairs: Vec::new(),
                hash_map: HashMap::new(),
                threshold,
            }
        }
        
        pub fn insert(&mut self, key: u32, value: String) {
            if self.sorted_pairs.len() < self.threshold {
                // 使用排序数组
                match self.sorted_pairs.binary_search_by_key(&key, |&(k, _)| k) {
                    Ok(pos) => self.sorted_pairs[pos].1 = value,
                    Err(pos) => self.sorted_pairs.insert(pos, (key, value)),
                }
            } else {
                // 切换到哈希表
                if !self.sorted_pairs.is_empty() {
                    for (k, v) in self.sorted_pairs.drain(..) {
                        self.hash_map.insert(k, v);
                    }
                }
                self.hash_map.insert(key, value);
            }
        }
        
        pub fn get(&self, key: u32) -> Option<&String> {
            if self.sorted_pairs.is_empty() {
                self.hash_map.get(&key)
            } else {
                self.sorted_pairs
                    .binary_search_by_key(&key, |&(k, _)| k)
                    .ok()
                    .map(|i| &self.sorted_pairs[i].1)
            }
        }
    }
}
```

#### 缓存友好的数据访问

```rust
// 缓存友好的图像处理
pub struct ImageProcessor {
    width: usize,
    height: usize,
    data: Vec<u8>,
}

impl ImageProcessor {
    pub fn new(width: usize, height: usize) -> Self {
        ImageProcessor {
            width,
            height,
            data: vec![0; width * height * 4], // RGBA
        }
    }
    
    // 缓存友好的行优先访问
    pub fn process_rows(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                let idx = (y * self.width + x) * 4;
                // 顺序访问，缓存友好
                self.data[idx] = self.data[idx].saturating_add(10);     // R
                self.data[idx + 1] = self.data[idx + 1].saturating_add(10); // G
                self.data[idx + 2] = self.data[idx + 2].saturating_add(10); // B
                // Alpha 通道不变
            }
        }
    }
    
    // 分块处理，提高缓存局部性
    pub fn process_blocks(&mut self, block_size: usize) {
        for block_y in (0..self.height).step_by(block_size) {
            for block_x in (0..self.width).step_by(block_size) {
                let end_y = std::cmp::min(block_y + block_size, self.height);
                let end_x = std::cmp::min(block_x + block_size, self.width);
                
                // 处理块内数据
                for y in block_y..end_y {
                    for x in block_x..end_x {
                        let idx = (y * self.width + x) * 4;
                        self.data[idx] = self.data[idx].saturating_mul(2);
                    }
                }
            }
        }
    }
    
    // 向量化处理
    pub fn vectorized_process(&mut self) {
        // 批量处理，利用 CPU 向量指令
        for chunk in self.data.chunks_exact_mut(16) {
            for byte in chunk {
                *byte = byte.saturating_add(5);
            }
        }
    }
}
```

### 10.2.3 JavaScript 互操作优化

#### 减少边界开销

```rust
// 批量数据传输
#[wasm_bindgen]
pub struct BatchProcessor {
    input_buffer: Vec<f32>,
    output_buffer: Vec<f32>,
}

#[wasm_bindgen]
impl BatchProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> BatchProcessor {
        BatchProcessor {
            input_buffer: Vec::new(),
            output_buffer: Vec::new(),
        }
    }
    
    // 批量添加数据，减少调用次数
    #[wasm_bindgen]
    pub fn add_batch(&mut self, data: &[f32]) {
        self.input_buffer.extend_from_slice(data);
    }
    
    // 批量处理所有数据
    #[wasm_bindgen]
    pub fn process_all(&mut self) -> Vec<f32> {
        self.output_buffer.clear();
        self.output_buffer.reserve(self.input_buffer.len());
        
        for &value in &self.input_buffer {
            self.output_buffer.push(value * value + 1.0);
        }
        
        self.input_buffer.clear();
        std::mem::take(&mut self.output_buffer)
    }
    
    // 直接内存访问，避免数据复制
    #[wasm_bindgen]
    pub fn get_input_ptr(&self) -> *const f32 {
        self.input_buffer.as_ptr()
    }
    
    #[wasm_bindgen]
    pub fn get_input_len(&self) -> usize {
        self.input_buffer.len()
    }
}
```

**JavaScript 端优化**:
```javascript
class OptimizedWasmInterface {
    constructor(wasmModule) {
        this.module = wasmModule;
        this.processor = new wasmModule.BatchProcessor();
        this.inputBuffer = new Float32Array(1024);
        this.bufferIndex = 0;
    }
    
    // 批量处理，减少 WASM 调用开销
    addValue(value) {
        this.inputBuffer[this.bufferIndex++] = value;
        
        // 缓冲区满时批量发送
        if (this.bufferIndex >= this.inputBuffer.length) {
            this.flush();
        }
    }
    
    flush() {
        if (this.bufferIndex > 0) {
            const data = this.inputBuffer.subarray(0, this.bufferIndex);
            this.processor.add_batch(data);
            this.bufferIndex = 0;
        }
    }
    
    // 直接内存访问，避免数据复制
    getResults() {
        this.flush();
        
        // 使用 WASM 内存视图直接访问数据
        const ptr = this.processor.get_input_ptr();
        const len = this.processor.get_input_len();
        const memory = new Float32Array(
            this.module.memory.buffer, 
            ptr, 
            len
        );
        
        return this.processor.process_all();
    }
    
    // 使用 Web Workers 进行并行处理
    async processInWorker(data) {
        return new Promise((resolve, reject) => {
            const worker = new Worker('wasm-worker.js');
            
            worker.postMessage({
                type: 'process',
                data: data
            });
            
            worker.onmessage = (e) => {
                if (e.data.type === 'result') {
                    resolve(e.data.result);
                    worker.terminate();
                } else if (e.data.type === 'error') {
                    reject(new Error(e.data.message));
                    worker.terminate();
                }
            };
        });
    }
}
```

## 10.3 性能监控与分析

### 10.3.1 性能测量工具

#### 内置性能计数器

```rust
use std::time::Instant;

#[wasm_bindgen]
pub struct PerformanceMonitor {
    start_times: std::collections::HashMap<String, f64>,
    measurements: std::collections::HashMap<String, Vec<f64>>,
}

#[wasm_bindgen]
impl PerformanceMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceMonitor {
        PerformanceMonitor {
            start_times: std::collections::HashMap::new(),
            measurements: std::collections::HashMap::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn start_timer(&mut self, name: &str) {
        let timestamp = js_sys::Date::now();
        self.start_times.insert(name.to_string(), timestamp);
    }
    
    #[wasm_bindgen]
    pub fn end_timer(&mut self, name: &str) -> f64 {
        let end_time = js_sys::Date::now();
        if let Some(&start_time) = self.start_times.get(name) {
            let duration = end_time - start_time;
            
            self.measurements
                .entry(name.to_string())
                .or_insert_with(Vec::new)
                .push(duration);
            
            duration
        } else {
            0.0
        }
    }
    
    #[wasm_bindgen]
    pub fn get_average(&self, name: &str) -> f64 {
        if let Some(measurements) = self.measurements.get(name) {
            if measurements.is_empty() {
                0.0
            } else {
                measurements.iter().sum::<f64>() / measurements.len() as f64
            }
        } else {
            0.0
        }
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self, name: &str) -> String {
        if let Some(measurements) = self.measurements.get(name) {
            if measurements.is_empty() {
                return "No measurements".to_string();
            }
            
            let count = measurements.len();
            let sum: f64 = measurements.iter().sum();
            let avg = sum / count as f64;
            let min = measurements.iter().fold(f64::INFINITY, |a, &b| a.min(b));
            let max = measurements.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
            
            // 计算标准差
            let variance = measurements.iter()
                .map(|&x| (x - avg).powi(2))
                .sum::<f64>() / count as f64;
            let std_dev = variance.sqrt();
            
            format!(
                "Count: {}, Avg: {:.2}ms, Min: {:.2}ms, Max: {:.2}ms, StdDev: {:.2}ms",
                count, avg, min, max, std_dev
            )
        } else {
            "No data".to_string()
        }
    }
    
    #[wasm_bindgen]
    pub fn reset(&mut self) {
        self.start_times.clear();
        self.measurements.clear();
    }
}

// 自动计时宏
macro_rules! time_it {
    ($monitor:expr, $name:expr, $block:block) => {
        $monitor.start_timer($name);
        let result = $block;
        $monitor.end_timer($name);
        result
    };
}

// 使用示例
#[wasm_bindgen]
pub fn benchmark_algorithms(monitor: &mut PerformanceMonitor, data: &[i32]) -> String {
    let mut data_copy = data.to_vec();
    
    // 测试快速排序
    let mut quick_data = data_copy.clone();
    time_it!(monitor, "quicksort", {
        sorting::quicksort(&mut quick_data);
    });
    
    // 测试基数排序
    if data.iter().all(|&x| x >= 0) {
        let mut radix_data: Vec<u32> = data.iter().map(|&x| x as u32).collect();
        time_it!(monitor, "radix_sort", {
            sorting::radix_sort(&mut radix_data);
        });
    }
    
    format!(
        "QuickSort: {}\nRadixSort: {}",
        monitor.get_stats("quicksort"),
        monitor.get_stats("radix_sort")
    )
}
```

#### 内存使用监控

```rust
#[wasm_bindgen]
pub struct MemoryMonitor {
    baseline: usize,
    samples: Vec<(f64, usize)>, // (timestamp, memory_usage)
}

#[wasm_bindgen]
impl MemoryMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> MemoryMonitor {
        MemoryMonitor {
            baseline: ALLOCATOR.bytes_in_use(),
            samples: Vec::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn sample(&mut self) {
        let timestamp = js_sys::Date::now();
        let memory_usage = ALLOCATOR.bytes_in_use();
        self.samples.push((timestamp, memory_usage));
    }
    
    #[wasm_bindgen]
    pub fn get_peak_usage(&self) -> usize {
        self.samples.iter().map(|&(_, usage)| usage).max().unwrap_or(0)
    }
    
    #[wasm_bindgen]
    pub fn get_memory_growth(&self) -> i64 {
        if let Some(&(_, current)) = self.samples.last() {
            current as i64 - self.baseline as i64
        } else {
            0
        }
    }
    
    #[wasm_bindgen]
    pub fn detect_leaks(&self, threshold: f64) -> String {
        if self.samples.len() < 2 {
            return "Insufficient data".to_string();
        }
        
        let start = &self.samples[0];
        let end = &self.samples[self.samples.len() - 1];
        
        let time_diff = end.0 - start.0; // milliseconds
        let memory_diff = end.1 as i64 - start.1 as i64; // bytes
        
        if time_diff > 0.0 {
            let growth_rate = memory_diff as f64 / time_diff; // bytes per ms
            
            if growth_rate > threshold {
                format!(
                    "Potential memory leak detected! Growth rate: {:.2} bytes/ms",
                    growth_rate
                )
            } else {
                format!(
                    "Memory usage stable. Growth rate: {:.2} bytes/ms",
                    growth_rate
                )
            }
        } else {
            "Invalid time range".to_string()
        }
    }
    
    #[wasm_bindgen]
    pub fn clear_samples(&mut self) {
        self.samples.clear();
        self.baseline = ALLOCATOR.bytes_in_use();
    }
}
```

### 10.3.2 浏览器性能工具集成

#### Performance API 集成

```javascript
class WasmPerformanceProfiler {
    constructor(wasmModule) {
        this.module = wasmModule;
        this.marks = new Map();
        this.measures = new Map();
    }
    
    // 使用 Performance API 进行精确测量
    mark(name) {
        const markName = `wasm-${name}`;
        performance.mark(markName);
        this.marks.set(name, markName);
    }
    
    measure(name, startName) {
        const measureName = `measure-${name}`;
        const startMarkName = this.marks.get(startName);
        
        if (startMarkName) {
            performance.measure(measureName, startMarkName);
            
            const entries = performance.getEntriesByName(measureName);
            if (entries.length > 0) {
                const duration = entries[entries.length - 1].duration;
                
                if (!this.measures.has(name)) {
                    this.measures.set(name, []);
                }
                this.measures.get(name).push(duration);
                
                return duration;
            }
        }
        return 0;
    }
    
    // 详细的性能报告
    getDetailedReport() {
        const report = {
            timing: {},
            memory: this.getMemoryInfo(),
            wasm: this.getWasmInfo()
        };
        
        // 收集所有测量数据
        for (const [name, measurements] of this.measures) {
            if (measurements.length > 0) {
                const sorted = [...measurements].sort((a, b) => a - b);
                report.timing[name] = {
                    count: measurements.length,
                    min: Math.min(...measurements),
                    max: Math.max(...measurements),
                    mean: measurements.reduce((a, b) => a + b) / measurements.length,
                    median: sorted[Math.floor(sorted.length / 2)],
                    p95: sorted[Math.floor(sorted.length * 0.95)],
                    p99: sorted[Math.floor(sorted.length * 0.99)]
                };
            }
        }
        
        return report;
    }
    
    // 内存信息
    getMemoryInfo() {
        const info = {
            jsHeapSizeLimit: 0,
            totalJSHeapSize: 0,
            usedJSHeapSize: 0,
            wasmMemoryPages: 0,
            wasmMemoryBytes: 0
        };
        
        // JavaScript 堆信息
        if (performance.memory) {
            info.jsHeapSizeLimit = performance.memory.jsHeapSizeLimit;
            info.totalJSHeapSize = performance.memory.totalJSHeapSize;
            info.usedJSHeapSize = performance.memory.usedJSHeapSize;
        }
        
        // WebAssembly 内存信息
        if (this.module.memory) {
            const pages = this.module.memory.buffer.byteLength / 65536;
            info.wasmMemoryPages = pages;
            info.wasmMemoryBytes = this.module.memory.buffer.byteLength;
        }
        
        return info;
    }
    
    // WebAssembly 特定信息
    getWasmInfo() {
        return {
            supportedFeatures: this.getSupportedFeatures(),
            compilationTime: this.getCompilationTime(),
            instantiationTime: this.getInstantiationTime()
        };
    }
    
    getSupportedFeatures() {
        const features = {
            bigInt: typeof BigInt !== 'undefined',
            bulkMemory: this.checkBulkMemorySupport(),
            multiValue: this.checkMultiValueSupport(),
            referenceTypes: this.checkReferenceTypesSupport(),
            simd: this.checkSimdSupport(),
            threads: this.checkThreadsSupport()
        };
        
        return features;
    }
    
    checkBulkMemorySupport() {
        try {
            new WebAssembly.Module(new Uint8Array([
                0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
                0x05, 0x03, 0x01, 0x00, 0x01, 0x0b, 0x07, 0x01,
                0x05, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x0b
            ]));
            return true;
        } catch {
            return false;
        }
    }
    
    checkSimdSupport() {
        try {
            new WebAssembly.Module(new Uint8Array([
                0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
                0x01, 0x04, 0x01, 0x60, 0x00, 0x00, 0x03, 0x02,
                0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00, 0xfd,
                0x0c, 0x00, 0x00, 0x00, 0x00, 0x0b
            ]));
            return true;
        } catch {
            return false;
        }
    }
    
    // 更多特性检测方法...
    checkMultiValueSupport() { return false; }
    checkReferenceTypesSupport() { return false; }
    checkThreadsSupport() { return typeof SharedArrayBuffer !== 'undefined'; }
    
    getCompilationTime() {
        // 实际实现中需要在编译时测量
        return performance.getEntriesByType('measure')
            .filter(entry => entry.name.includes('wasm-compile'))
            .map(entry => entry.duration);
    }
    
    getInstantiationTime() {
        // 实际实现中需要在实例化时测量
        return performance.getEntriesByType('measure')
            .filter(entry => entry.name.includes('wasm-instantiate'))
            .map(entry => entry.duration);
    }
    
    // 生成性能报告
    generateReport(format = 'json') {
        const report = this.getDetailedReport();
        
        if (format === 'json') {
            return JSON.stringify(report, null, 2);
        } else if (format === 'html') {
            return this.generateHtmlReport(report);
        } else if (format === 'csv') {
            return this.generateCsvReport(report);
        }
        
        return report;
    }
    
    generateHtmlReport(report) {
        let html = `
        <h2>WebAssembly 性能报告</h2>
        <h3>执行时间统计</h3>
        <table border="1">
            <tr><th>操作</th><th>次数</th><th>平均时间</th><th>最小时间</th><th>最大时间</th><th>P95</th></tr>
        `;
        
        for (const [name, stats] of Object.entries(report.timing)) {
            html += `
            <tr>
                <td>${name}</td>
                <td>${stats.count}</td>
                <td>${stats.mean.toFixed(2)}ms</td>
                <td>${stats.min.toFixed(2)}ms</td>
                <td>${stats.max.toFixed(2)}ms</td>
                <td>${stats.p95.toFixed(2)}ms</td>
            </tr>
            `;
        }
        
        html += `
        </table>
        <h3>内存使用情况</h3>
        <ul>
            <li>JS 堆大小限制: ${(report.memory.jsHeapSizeLimit / 1024 / 1024).toFixed(2)} MB</li>
            <li>总 JS 堆大小: ${(report.memory.totalJSHeapSize / 1024 / 1024).toFixed(2)} MB</li>
            <li>已用 JS 堆大小: ${(report.memory.usedJSHeapSize / 1024 / 1024).toFixed(2)} MB</li>
            <li>WASM 内存页数: ${report.memory.wasmMemoryPages}</li>
            <li>WASM 内存大小: ${(report.memory.wasmMemoryBytes / 1024 / 1024).toFixed(2)} MB</li>
        </ul>
        `;
        
        return html;
    }
    
    // 清理性能数据
    clear() {
        this.marks.clear();
        this.measures.clear();
        performance.clearMarks();
        performance.clearMeasures();
    }
}
```

## 10.4 最佳实践

### 10.4.1 性能优化检查清单

#### 编译时优化清单

- [ ] **编译器优化级别**: 使用 `-O3` 或 `opt-level = 3`
- [ ] **链接时优化**: 启用 LTO (Link Time Optimization)
- [ ] **代码大小优化**: 根据需要使用 `-Oz` 或 `opt-level = "z"`
- [ ] **死代码消除**: 确保启用 dead code elimination
- [ ] **内联优化**: 适当使用 `#[inline]` 标记
- [ ] **SIMD 指令**: 启用目标 CPU 特性
- [ ] **数学优化**: 使用快速数学选项（如适用）

#### 运行时优化清单

- [ ] **内存分配**: 最小化动态内存分配
- [ ] **对象池**: 重用大对象避免频繁分配
- [ ] **缓存局部性**: 优化数据访问模式
- [ ] **分支预测**: 减少不可预测的分支
- [ ] **函数调用开销**: 批量处理减少跨边界调用
- [ ] **数据布局**: 优化结构体字段排序
- [ ] **算法复杂度**: 选择最适合的算法和数据结构

#### 监控和调试清单

- [ ] **性能测量**: 集成性能监控代码
- [ ] **内存泄漏检测**: 监控内存使用趋势
- [ ] **回归测试**: 建立性能基准测试
- [ ] **浏览器兼容性**: 测试不同浏览器的性能差异
- [ ] **移动设备优化**: 在低性能设备上测试

### 10.4.2 常见性能陷阱

#### 避免频繁的类型转换

```rust
// ❌ 错误示例：频繁转换
#[wasm_bindgen]
pub fn bad_string_processing(input: &str) -> String {
    let mut result = String::new();
    for c in input.chars() {
        // 每次循环都有字符串分配
        result = format!("{}{}", result, c.to_uppercase().collect::<String>());
    }
    result
}

// ✅ 正确示例：减少分配
#[wasm_bindgen]
pub fn good_string_processing(input: &str) -> String {
    let mut result = String::with_capacity(input.len());
    for c in input.chars() {
        // 直接追加到现有字符串
        result.extend(c.to_uppercase());
    }
    result
}
```

#### 避免不必要的数据复制

```rust
// ❌ 错误示例：多次复制数据
#[wasm_bindgen]
pub fn bad_array_processing(data: Vec<f32>) -> Vec<f32> {
    let mut temp1 = data.clone(); // 不必要的复制
    let mut temp2 = temp1.clone(); // 又一次复制
    
    for value in &mut temp2 {
        *value *= 2.0;
    }
    
    temp2
}

// ✅ 正确示例：就地修改
#[wasm_bindgen]
pub fn good_array_processing(mut data: Vec<f32>) -> Vec<f32> {
    for value in &mut data {
        *value *= 2.0;
    }
    data // 移动而不是复制
}
```

#### 合理使用缓存

```rust
use std::collections::HashMap;

// ❌ 错误示例：每次都重新计算
pub fn bad_fibonacci(n: u32) -> u64 {
    if n <= 1 {
        n as u64
    } else {
        bad_fibonacci(n - 1) + bad_fibonacci(n - 2)
    }
}

// ✅ 正确示例：使用记忆化
pub struct FibonacciCache {
    cache: HashMap<u32, u64>,
}

impl FibonacciCache {
    pub fn new() -> Self {
        let mut cache = HashMap::new();
        cache.insert(0, 0);
        cache.insert(1, 1);
        FibonacciCache { cache }
    }
    
    pub fn fibonacci(&mut self, n: u32) -> u64 {
        if let Some(&result) = self.cache.get(&n) {
            return result;
        }
        
        let result = self.fibonacci(n - 1) + self.fibonacci(n - 2);
        self.cache.insert(n, result);
        result
    }
}
```

### 10.4.3 性能优化案例研究

#### 图像处理优化案例

```rust
// 案例：图像滤镜优化
pub struct OptimizedImageFilter {
    width: usize,
    height: usize,
    temp_buffer: Vec<f32>,
}

impl OptimizedImageFilter {
    pub fn new(width: usize, height: usize) -> Self {
        OptimizedImageFilter {
            width,
            height,
            temp_buffer: vec![0.0; width * height],
        }
    }
    
    // 优化的高斯模糊实现
    pub fn gaussian_blur(
        &mut self, 
        input: &[u8], 
        output: &mut [u8], 
        radius: f32
    ) {
        let sigma = radius / 3.0;
        let kernel_size = (radius * 6.0) as usize | 1; // 确保奇数
        let kernel = self.create_gaussian_kernel(kernel_size, sigma);
        
        // 分离式卷积：先水平后垂直
        self.horizontal_blur(input, &kernel);
        self.vertical_blur(output, &kernel);
    }
    
    fn create_gaussian_kernel(&self, size: usize, sigma: f32) -> Vec<f32> {
        let mut kernel = vec![0.0; size];
        let center = size / 2;
        let mut sum = 0.0;
        
        for (i, k) in kernel.iter_mut().enumerate() {
            let x = (i as i32 - center as i32) as f32;
            *k = (-x * x / (2.0 * sigma * sigma)).exp();
            sum += *k;
        }
        
        // 归一化
        for k in &mut kernel {
            *k /= sum;
        }
        
        kernel
    }
    
    fn horizontal_blur(&mut self, input: &[u8], kernel: &[f32]) {
        let radius = kernel.len() / 2;
        
        for y in 0..self.height {
            for x in 0..self.width {
                let mut sum = 0.0;
                
                for (i, &k) in kernel.iter().enumerate() {
                    let sample_x = (x as i32 + i as i32 - radius as i32)
                        .max(0)
                        .min(self.width as i32 - 1) as usize;
                    
                    sum += input[y * self.width + sample_x] as f32 * k;
                }
                
                self.temp_buffer[y * self.width + x] = sum;
            }
        }
    }
    
    fn vertical_blur(&self, output: &mut [u8], kernel: &[f32]) {
        let radius = kernel.len() / 2;
        
        for y in 0..self.height {
            for x in 0..self.width {
                let mut sum = 0.0;
                
                for (i, &k) in kernel.iter().enumerate() {
                    let sample_y = (y as i32 + i as i32 - radius as i32)
                        .max(0)
                        .min(self.height as i32 - 1) as usize;
                    
                    sum += self.temp_buffer[sample_y * self.width + x] * k;
                }
                
                output[y * self.width + x] = sum.round().max(0.0).min(255.0) as u8;
            }
        }
    }
}
```

通过本章的学习，你应该掌握了 WebAssembly 性能优化的核心技术和最佳实践。从编译时优化到运行时调优，再到性能监控和分析，这些技术将帮助你构建高性能的 WebAssembly 应用。

记住，性能优化是一个持续的过程，需要：
1. **测量优先**：始终基于实际测量结果进行优化
2. **找出瓶颈**：专注于性能关键路径
3. **权衡取舍**：在性能、可维护性和开发时间之间找到平衡
4. **持续监控**：建立性能回归检测机制

在下一章中，我们将学习 WebAssembly 应用的调试技巧，这将帮助你更有效地诊断和解决性能问题。
