# 附录C 性能基准测试

本附录提供全面的 WebAssembly 性能基准测试指南，涵盖测试方法论、基准测试套件、性能分析工具和优化策略。通过系统性的性能测试，你可以准确评估和优化 WebAssembly 应用的性能表现。

## C.1 基准测试方法论

### C.1.1 基准测试原则

建立科学的基准测试需要遵循以下核心原则：

**可重复性原则**:
```javascript
// 基准测试环境标准化
class BenchmarkEnvironment {
    constructor() {
        this.iterations = 1000;
        this.warmupRounds = 100;
        this.measurementRounds = 1000;
        this.gcBetweenTests = true;
    }
    
    // 环境信息收集
    getEnvironmentInfo() {
        return {
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            hardwareConcurrency: navigator.hardwareConcurrency,
            memory: performance.memory ? {
                usedJSHeapSize: performance.memory.usedJSHeapSize,
                totalJSHeapSize: performance.memory.totalJSHeapSize,
                jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
            } : null,
            timestamp: Date.now()
        };
    }
    
    // 预热阶段
    async warmup(testFunction) {
        console.log('开始预热阶段...');
        for (let i = 0; i < this.warmupRounds; i++) {
            await testFunction();
            if (this.gcBetweenTests && global.gc) {
                global.gc(); // 触发垃圾回收
            }
        }
        console.log('预热完成');
    }
}
```

**统计显著性原则**:
```javascript
// 统计分析工具
class StatisticsAnalyzer {
    static calculateStats(measurements) {
        const sorted = measurements.sort((a, b) => a - b);
        const n = sorted.length;
        
        return {
            count: n,
            min: sorted[0],
            max: sorted[n - 1],
            mean: sorted.reduce((a, b) => a + b) / n,
            median: n % 2 === 0 ? 
                (sorted[n/2 - 1] + sorted[n/2]) / 2 : 
                sorted[Math.floor(n/2)],
            percentile95: sorted[Math.floor(n * 0.95)],
            percentile99: sorted[Math.floor(n * 0.99)],
            standardDeviation: this.calculateStdDev(sorted),
            coefficientOfVariation: null // 后续计算
        };
    }
    
    static calculateStdDev(values) {
        const mean = values.reduce((a, b) => a + b) / values.length;
        const squaredDiffs = values.map(value => Math.pow(value - mean, 2));
        const avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b) / values.length;
        return Math.sqrt(avgSquaredDiff);
    }
    
    // 异常值检测
    static detectOutliers(values) {
        const stats = this.calculateStats(values);
        const threshold = stats.standardDeviation * 2; // 2σ 原则
        
        return values.filter(value => 
            Math.abs(value - stats.mean) > threshold
        );
    }
}
```

### C.1.2 基准测试框架

**高精度计时框架**:
```javascript
// 高精度基准测试框架
class PrecisionBenchmark {
    constructor(name, options = {}) {
        this.name = name;
        this.options = {
            iterations: options.iterations || 1000,
            warmupIterations: options.warmupIterations || 100,
            minTime: options.minTime || 1000, // 最小测试时间 (ms)
            maxTime: options.maxTime || 10000, // 最大测试时间 (ms)
            ...options
        };
        this.results = [];
    }
    
    // 执行基准测试
    async run(testFunction) {
        console.log(`开始基准测试: ${this.name}`);
        
        // 预热
        await this.warmup(testFunction);
        
        // 正式测试
        const measurements = await this.measure(testFunction);
        
        // 分析结果
        const stats = StatisticsAnalyzer.calculateStats(measurements);
        const outliers = StatisticsAnalyzer.detectOutliers(measurements);
        
        return {
            name: this.name,
            measurements,
            statistics: stats,
            outliers,
            environment: new BenchmarkEnvironment().getEnvironmentInfo()
        };
    }
    
    async measure(testFunction) {
        const measurements = [];
        const startTime = performance.now();
        let iterations = 0;
        
        while (performance.now() - startTime < this.options.maxTime && 
               iterations < this.options.iterations) {
            
            // 单次测量
            const start = performance.now();
            await testFunction();
            const end = performance.now();
            
            measurements.push(end - start);
            iterations++;
            
            // 周期性垃圾回收
            if (iterations % 100 === 0 && global.gc) {
                global.gc();
            }
        }
        
        return measurements;
    }
    
    async warmup(testFunction) {
        for (let i = 0; i < this.options.warmupIterations; i++) {
            await testFunction();
        }
    }
}
```

## C.2 基准测试套件

### C.2.1 微基准测试

**算术运算基准测试**:
```wat
;; 整数运算基准测试 WAT 代码
(module
  ;; 32位整数加法测试
  (func $i32_add_benchmark (param $iterations i32) (result i32)
    (local $i i32)
    (local $result i32)
    (local.set $result (i32.const 0))
    (local.set $i (i32.const 0))
    
    (loop $loop
      ;; 执行加法运算
      (local.set $result 
        (i32.add 
          (local.get $result)
          (i32.add (local.get $i) (i32.const 1))))
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; 检查循环条件
      (br_if $loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )
    
    (local.get $result)
  )
  
  ;; 64位整数乘法测试
  (func $i64_mul_benchmark (param $iterations i32) (result i64)
    (local $i i32)
    (local $result i64)
    (local.set $result (i64.const 1))
    (local.set $i (i32.const 0))
    
    (loop $loop
      (local.set $result 
        (i64.mul 
          (local.get $result)
          (i64.extend_i32_u (local.get $i))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )
    
    (local.get $result)
  )
  
  ;; 浮点数运算测试
  (func $f64_math_benchmark (param $iterations i32) (result f64)
    (local $i i32)
    (local $x f64)
    (local $result f64)
    (local.set $result (f64.const 0.0))
    (local.set $i (i32.const 0))
    
    (loop $loop
      (local.set $x (f64.convert_i32_s (local.get $i)))
      (local.set $result 
        (f64.add 
          (local.get $result)
          (f64.mul 
            (f64.sqrt (local.get $x))
            (f64.sin (local.get $x)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )
    
    (local.get $result)
  )
  
  (export "i32_add_benchmark" (func $i32_add_benchmark))
  (export "i64_mul_benchmark" (func $i64_mul_benchmark))
  (export "f64_math_benchmark" (func $f64_math_benchmark))
)
```

**JavaScript 对比测试**:
```javascript
// JavaScript 版本的相同算法
class ArithmeticBenchmarks {
    static i32AddBenchmark(iterations) {
        let result = 0;
        for (let i = 0; i < iterations; i++) {
            result += i + 1;
        }
        return result;
    }
    
    static i64MulBenchmark(iterations) {
        let result = 1n; // BigInt
        for (let i = 0; i < iterations; i++) {
            result *= BigInt(i);
        }
        return result;
    }
    
    static f64MathBenchmark(iterations) {
        let result = 0.0;
        for (let i = 0; i < iterations; i++) {
            const x = i;
            result += Math.sqrt(x) * Math.sin(x);
        }
        return result;
    }
}

// 基准测试执行器
class ArithmeticBenchmarkRunner {
    constructor() {
        this.wasmModule = null;
    }
    
    async loadWasm() {
        // 假设已编译好的 WASM 文件
        const wasmBytes = await fetch('./arithmetic-benchmarks.wasm')
            .then(response => response.arrayBuffer());
        const wasmModule = await WebAssembly.instantiate(wasmBytes);
        this.wasmModule = wasmModule.instance.exports;
    }
    
    async runComparison() {
        const iterations = 1000000;
        const benchmark = new PrecisionBenchmark('Arithmetic Comparison');
        
        // WASM 测试
        const wasmResults = await benchmark.run(async () => {
            this.wasmModule.i32_add_benchmark(iterations);
            this.wasmModule.i64_mul_benchmark(iterations);
            this.wasmModule.f64_math_benchmark(iterations);
        });
        
        // JavaScript 测试
        const jsResults = await benchmark.run(async () => {
            ArithmeticBenchmarks.i32AddBenchmark(iterations);
            ArithmeticBenchmarks.i64MulBenchmark(iterations);
            ArithmeticBenchmarks.f64MathBenchmark(iterations);
        });
        
        return {
            wasm: wasmResults,
            javascript: jsResults,
            speedup: jsResults.statistics.mean / wasmResults.statistics.mean
        };
    }
}
```

### C.2.2 内存操作基准测试

**内存访问模式测试**:
```wat
;; 内存访问基准测试
(module
  (memory $mem 10) ;; 10 页内存 (640KB)
  
  ;; 顺序访问测试
  (func $sequential_access (param $size i32) (result i32)
    (local $i i32)
    (local $sum i32)
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 0))
    
    (loop $loop
      ;; 读取并累加
      (local.set $sum 
        (i32.add 
          (local.get $sum)
          (i32.load (local.get $i))))
      
      ;; 移动到下个 4 字节对齐位置
      (local.set $i (i32.add (local.get $i) (i32.const 4)))
      (br_if $loop (i32.lt_u (local.get $i) (local.get $size)))
    )
    
    (local.get $sum)
  )
  
  ;; 随机访问测试
  (func $random_access (param $size i32) (param $iterations i32) (result i32)
    (local $i i32)
    (local $addr i32)
    (local $sum i32)
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 0))
    
    (loop $loop
      ;; 生成伪随机地址 (简单的线性同余生成器)
      (local.set $addr 
        (i32.and 
          (i32.mul (local.get $i) (i32.const 1664525))
          (i32.sub (local.get $size) (i32.const 4))))
      
      ;; 确保 4 字节对齐
      (local.set $addr 
        (i32.and (local.get $addr) (i32.const 0xfffffffc)))
      
      ;; 读取并累加
      (local.set $sum 
        (i32.add 
          (local.get $sum)
          (i32.load (local.get $addr))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )
    
    (local.get $sum)
  )
  
  ;; 内存复制测试
  (func $memory_copy (param $src i32) (param $dst i32) (param $size i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    
    (loop $loop
      ;; 复制一个字节
      (i32.store8 
        (i32.add (local.get $dst) (local.get $i))
        (i32.load8_u (i32.add (local.get $src) (local.get $i))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $loop (i32.lt_u (local.get $i) (local.get $size)))
    )
  )
  
  ;; 内存初始化
  (func $init_memory (param $pattern i32)
    (local $addr i32)
    (local.set $addr (i32.const 0))
    
    (loop $loop
      (i32.store (local.get $addr) (local.get $pattern))
      (local.set $addr (i32.add (local.get $addr) (i32.const 4)))
      (br_if $loop (i32.lt_u (local.get $addr) (i32.const 65536))) ;; 64KB
    )
  )
  
  (export "memory" (memory $mem))
  (export "sequential_access" (func $sequential_access))
  (export "random_access" (func $random_access))
  (export "memory_copy" (func $memory_copy))
  (export "init_memory" (func $init_memory))
)
```

**内存基准测试套件**:
```javascript
class MemoryBenchmarkSuite {
    constructor() {
        this.wasmModule = null;
        this.testDataSize = 64 * 1024; // 64KB
    }
    
    async initialize() {
        // 加载 WASM 模块
        const wasmBytes = await fetch('./memory-benchmarks.wasm')
            .then(response => response.arrayBuffer());
        const wasmModule = await WebAssembly.instantiate(wasmBytes);
        this.wasmModule = wasmModule.instance.exports;
        
        // 初始化测试数据
        this.wasmModule.init_memory(0x12345678);
    }
    
    // 缓存友好的顺序访问测试
    async testSequentialAccess() {
        const benchmark = new PrecisionBenchmark('Sequential Memory Access');
        
        return await benchmark.run(() => {
            this.wasmModule.sequential_access(this.testDataSize);
        });
    }
    
    // 缓存不友好的随机访问测试
    async testRandomAccess() {
        const benchmark = new PrecisionBenchmark('Random Memory Access');
        
        return await benchmark.run(() => {
            this.wasmModule.random_access(this.testDataSize, 1000);
        });
    }
    
    // 内存带宽测试
    async testMemoryBandwidth() {
        const benchmark = new PrecisionBenchmark('Memory Bandwidth');
        const srcOffset = 0;
        const dstOffset = this.testDataSize / 2;
        const copySize = this.testDataSize / 4;
        
        return await benchmark.run(() => {
            this.wasmModule.memory_copy(srcOffset, dstOffset, copySize);
        });
    }
    
    // 与 JavaScript 的对比测试
    async runJavaScriptComparison() {
        // 获取 WASM 内存视图
        const memory = new Uint32Array(this.wasmModule.memory.buffer);
        
        // JavaScript 顺序访问
        const jsSequential = new PrecisionBenchmark('JS Sequential Access');
        const jsSeqResults = await jsSequential.run(() => {
            let sum = 0;
            for (let i = 0; i < this.testDataSize / 4; i++) {
                sum += memory[i];
            }
            return sum;
        });
        
        // JavaScript 随机访问
        const jsRandom = new PrecisionBenchmark('JS Random Access');
        const jsRandomResults = await jsRandom.run(() => {
            let sum = 0;
            for (let i = 0; i < 1000; i++) {
                const addr = (i * 1664525) % (this.testDataSize / 4);
                sum += memory[addr];
            }
            return sum;
        });
        
        return {
            jsSequential: jsSeqResults,
            jsRandom: jsRandomResults
        };
    }
    
    // 生成性能报告
    async generateReport() {
        const wasmSeq = await this.testSequentialAccess();
        const wasmRand = await this.testRandomAccess();
        const wasmBandwidth = await this.testMemoryBandwidth();
        const jsResults = await this.runJavaScriptComparison();
        
        return {
            wasm: {
                sequential: wasmSeq,
                random: wasmRand,
                bandwidth: wasmBandwidth
            },
            javascript: jsResults,
            performance: {
                sequentialSpeedup: jsResults.jsSequential.statistics.mean / wasmSeq.statistics.mean,
                randomSpeedup: jsResults.jsRandom.statistics.mean / wasmRand.statistics.mean
            }
        };
    }
}
```

## C.3 计算密集型基准测试

### C.3.1 数学运算基准测试

**矩阵运算基准测试**:
```wat
;; 矩阵乘法基准测试
(module
  (memory $mem 1) ;; 1 页内存 (64KB)
  
  ;; 矩阵乘法 C = A * B (NxN 矩阵)
  (func $matrix_multiply (param $n i32) (param $a_offset i32) (param $b_offset i32) (param $c_offset i32)
    (local $i i32) (local $j i32) (local $k i32)
    (local $sum f64) (local $a_val f64) (local $b_val f64)
    (local $a_idx i32) (local $b_idx i32) (local $c_idx i32)
    
    ;; 外层循环 i
    (local.set $i (i32.const 0))
    (loop $i_loop
      ;; 中层循环 j
      (local.set $j (i32.const 0))
      (loop $j_loop
        ;; 初始化累加器
        (local.set $sum (f64.const 0.0))
        
        ;; 内层循环 k (实际的乘法累加)
        (local.set $k (i32.const 0))
        (loop $k_loop
          ;; 计算 A[i][k] 的地址和值
          (local.set $a_idx 
            (i32.add 
              (local.get $a_offset)
              (i32.mul 
                (i32.add 
                  (i32.mul (local.get $i) (local.get $n))
                  (local.get $k))
                (i32.const 8)))) ;; f64 = 8 字节
          (local.set $a_val (f64.load (local.get $a_idx)))
          
          ;; 计算 B[k][j] 的地址和值
          (local.set $b_idx 
            (i32.add 
              (local.get $b_offset)
              (i32.mul 
                (i32.add 
                  (i32.mul (local.get $k) (local.get $n))
                  (local.get $j))
                (i32.const 8))))
          (local.set $b_val (f64.load (local.get $b_idx)))
          
          ;; 累加 A[i][k] * B[k][j]
          (local.set $sum 
            (f64.add 
              (local.get $sum)
              (f64.mul (local.get $a_val) (local.get $b_val))))
          
          ;; k++
          (local.set $k (i32.add (local.get $k) (i32.const 1)))
          (br_if $k_loop (i32.lt_u (local.get $k) (local.get $n)))
        ) ;; end k_loop
        
        ;; 存储 C[i][j] = sum
        (local.set $c_idx 
          (i32.add 
            (local.get $c_offset)
            (i32.mul 
              (i32.add 
                (i32.mul (local.get $i) (local.get $n))
                (local.get $j))
              (i32.const 8))))
        (f64.store (local.get $c_idx) (local.get $sum))
        
        ;; j++
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $j_loop (i32.lt_u (local.get $j) (local.get $n)))
      ) ;; end j_loop
      
      ;; i++
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $i_loop (i32.lt_u (local.get $i) (local.get $n)))
    ) ;; end i_loop
  )
  
  ;; 快速傅里叶变换 (简化版)
  (func $fft_radix2 (param $n i32) (param $real_offset i32) (param $imag_offset i32)
    (local $levels i32) (local $level i32)
    (local $step i32) (local $group_size i32) (local $group i32) (local $pair i32)
    (local $angle f64) (local $cos_val f64) (local $sin_val f64)
    (local $real1 f64) (local $imag1 f64) (local $real2 f64) (local $imag2 f64)
    (local $temp_real f64) (local $temp_imag f64)
    (local $idx1 i32) (local $idx2 i32)
    
    ;; 计算级数 (log2(n))
    (local.set $levels (i32.const 0))
    (local.set $step (local.get $n))
    (loop $count_levels
      (local.set $step (i32.shr_u (local.get $step) (i32.const 1)))
      (local.set $levels (i32.add (local.get $levels) (i32.const 1)))
      (br_if $count_levels (i32.gt_u (local.get $step) (i32.const 1)))
    )
    
    ;; 主 FFT 循环
    (local.set $level (i32.const 0))
    (local.set $group_size (i32.const 2))
    (loop $level_loop
      (local.set $group (i32.const 0))
      (loop $group_loop
        (local.set $pair (i32.const 0))
        (loop $pair_loop
          ;; 计算旋转因子
          (local.set $angle 
            (f64.mul 
              (f64.const -6.283185307179586) ;; -2π
              (f64.div 
                (f64.convert_i32_u (local.get $pair))
                (f64.convert_i32_u (local.get $group_size)))))
          (local.set $cos_val (f64.call_indirect (local.get $angle))) ;; 需要cos函数
          (local.set $sin_val (f64.call_indirect (local.get $angle))) ;; 需要sin函数
          
          ;; 计算数据索引
          (local.set $idx1 
            (i32.add (local.get $group) (local.get $pair)))
          (local.set $idx2 
            (i32.add (local.get $idx1) (i32.shr_u (local.get $group_size) (i32.const 1))))
          
          ;; 读取数据
          (local.set $real1 (f64.load (i32.add (local.get $real_offset) (i32.mul (local.get $idx1) (i32.const 8)))))
          (local.set $imag1 (f64.load (i32.add (local.get $imag_offset) (i32.mul (local.get $idx1) (i32.const 8)))))
          (local.set $real2 (f64.load (i32.add (local.get $real_offset) (i32.mul (local.get $idx2) (i32.const 8)))))
          (local.set $imag2 (f64.load (i32.add (local.get $imag_offset) (i32.mul (local.get $idx2) (i32.const 8)))))
          
          ;; 蝶形运算
          (local.set $temp_real 
            (f64.sub 
              (f64.mul (local.get $real2) (local.get $cos_val))
              (f64.mul (local.get $imag2) (local.get $sin_val))))
          (local.set $temp_imag 
            (f64.add 
              (f64.mul (local.get $real2) (local.get $sin_val))
              (f64.mul (local.get $imag2) (local.get $cos_val))))
          
          ;; 更新数据
          (f64.store 
            (i32.add (local.get $real_offset) (i32.mul (local.get $idx2) (i32.const 8)))
            (f64.sub (local.get $real1) (local.get $temp_real)))
          (f64.store 
            (i32.add (local.get $imag_offset) (i32.mul (local.get $idx2) (i32.const 8)))
            (f64.sub (local.get $imag1) (local.get $temp_imag)))
          (f64.store 
            (i32.add (local.get $real_offset) (i32.mul (local.get $idx1) (i32.const 8)))
            (f64.add (local.get $real1) (local.get $temp_real)))
          (f64.store 
            (i32.add (local.get $imag_offset) (i32.mul (local.get $idx1) (i32.const 8)))
            (f64.add (local.get $imag1) (local.get $temp_imag)))
          
          ;; pair++
          (local.set $pair (i32.add (local.get $pair) (i32.const 1)))
          (br_if $pair_loop (i32.lt_u (local.get $pair) (i32.shr_u (local.get $group_size) (i32.const 1))))
        ) ;; end pair_loop
        
        ;; group += group_size
        (local.set $group (i32.add (local.get $group) (local.get $group_size)))
        (br_if $group_loop (i32.lt_u (local.get $group) (local.get $n)))
      ) ;; end group_loop
      
      ;; group_size *= 2, level++
      (local.set $group_size (i32.shl (local.get $group_size) (i32.const 1)))
      (local.set $level (i32.add (local.get $level) (i32.const 1)))
      (br_if $level_loop (i32.lt_u (local.get $level) (local.get $levels)))
    ) ;; end level_loop
  )
  
  (export "memory" (memory $mem))
  (export "matrix_multiply" (func $matrix_multiply))
  (export "fft_radix2" (func $fft_radix2))
)
```

### C.3.2 图像处理基准测试

**图像滤波器实现**:
```javascript
// 图像处理基准测试套件
class ImageProcessingBenchmarks {
    constructor() {
        this.wasmModule = null;
        this.testImage = null;
        this.canvas = null;
        this.context = null;
    }
    
    async initialize() {
        // 创建测试图像
        this.createTestImage(512, 512);
        
        // 加载 WASM 模块 (假设包含图像处理函数)
        await this.loadWasmModule();
    }
    
    createTestImage(width, height) {
        // 创建 Canvas 和测试图像
        this.canvas = document.createElement('canvas');
        this.canvas.width = width;
        this.canvas.height = height;
        this.context = this.canvas.getContext('2d');
        
        // 生成测试图案
        const imageData = this.context.createImageData(width, height);
        const data = imageData.data;
        
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const index = (y * width + x) * 4;
                // 创建渐变和噪声图案
                const gradient = (x + y) / (width + height) * 255;
                const noise = Math.random() * 50 - 25;
                
                data[index] = Math.max(0, Math.min(255, gradient + noise));     // R
                data[index + 1] = Math.max(0, Math.min(255, gradient * 0.8));  // G  
                data[index + 2] = Math.max(0, Math.min(255, gradient * 0.6));  // B
                data[index + 3] = 255; // A
            }
        }
        
        this.testImage = imageData;
        this.context.putImageData(imageData, 0, 0);
    }
    
    // JavaScript 高斯模糊实现
    applyGaussianBlurJS(imageData, radius) {
        const { width, height, data } = imageData;
        const output = new ImageData(width, height);
        const outputData = output.data;
        
        // 生成高斯核
        const kernel = this.generateGaussianKernel(radius);
        const kernelSize = kernel.length;
        const halfKernel = Math.floor(kernelSize / 2);
        
        // 应用模糊
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                let r = 0, g = 0, b = 0, a = 0;
                let kernelSum = 0;
                
                for (let ky = -halfKernel; ky <= halfKernel; ky++) {
                    for (let kx = -halfKernel; kx <= halfKernel; kx++) {
                        const px = Math.max(0, Math.min(width - 1, x + kx));
                        const py = Math.max(0, Math.min(height - 1, y + ky));
                        const kernelValue = kernel[ky + halfKernel][kx + halfKernel];
                        const pixelIndex = (py * width + px) * 4;
                        
                        r += data[pixelIndex] * kernelValue;
                        g += data[pixelIndex + 1] * kernelValue;
                        b += data[pixelIndex + 2] * kernelValue;
                        a += data[pixelIndex + 3] * kernelValue;
                        kernelSum += kernelValue;
                    }
                }
                
                const outputIndex = (y * width + x) * 4;
                outputData[outputIndex] = r / kernelSum;
                outputData[outputIndex + 1] = g / kernelSum;
                outputData[outputIndex + 2] = b / kernelSum;
                outputData[outputIndex + 3] = a / kernelSum;
            }
        }
        
        return output;
    }
    
    generateGaussianKernel(radius) {
        const size = radius * 2 + 1;
        const kernel = Array(size).fill().map(() => Array(size).fill(0));
        const sigma = radius / 3;
        const twoSigmaSquare = 2 * sigma * sigma;
        const center = radius;
        
        let sum = 0;
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                const distance = (x - center) ** 2 + (y - center) ** 2;
                const value = Math.exp(-distance / twoSigmaSquare);
                kernel[y][x] = value;
                sum += value;
            }
        }
        
        // 归一化
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                kernel[y][x] /= sum;
            }
        }
        
        return kernel;
    }
    
    // 边缘检测 (Sobel 算子)
    applySobelEdgeDetectionJS(imageData) {
        const { width, height, data } = imageData;
        const output = new ImageData(width, height);
        const outputData = output.data;
        
        // Sobel 算子
        const sobelX = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
        const sobelY = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]];
        
        for (let y = 1; y < height - 1; y++) {
            for (let x = 1; x < width - 1; x++) {
                let gx = 0, gy = 0;
                
                // 应用 Sobel 算子
                for (let ky = -1; ky <= 1; ky++) {
                    for (let kx = -1; kx <= 1; kx++) {
                        const pixelIndex = ((y + ky) * width + (x + kx)) * 4;
                        const gray = (data[pixelIndex] + data[pixelIndex + 1] + data[pixelIndex + 2]) / 3;
                        
                        gx += gray * sobelX[ky + 1][kx + 1];
                        gy += gray * sobelY[ky + 1][kx + 1];
                    }
                }
                
                const magnitude = Math.sqrt(gx * gx + gy * gy);
                const outputIndex = (y * width + x) * 4;
                
                outputData[outputIndex] = magnitude;     // R
                outputData[outputIndex + 1] = magnitude; // G
                outputData[outputIndex + 2] = magnitude; // B
                outputData[outputIndex + 3] = 255;       // A
            }
        }
        
        return output;
    }
    
    // 基准测试执行
    async runImageProcessingBenchmarks() {
        const results = {};
        
        // 高斯模糊基准测试
        const blurBenchmark = new PrecisionBenchmark('Gaussian Blur', { iterations: 10 });
        results.gaussianBlur = await blurBenchmark.run(() => {
            return this.applyGaussianBlurJS(this.testImage, 3);
        });
        
        // 边缘检测基准测试
        const edgeBenchmark = new PrecisionBenchmark('Sobel Edge Detection', { iterations: 20 });
        results.edgeDetection = await edgeBenchmark.run(() => {
            return this.applySobelEdgeDetectionJS(this.testImage);
        });
        
        // 如果有 WASM 版本，进行对比
        if (this.wasmModule) {
            results.wasmComparison = await this.runWasmComparison();
        }
        
        return results;
    }
    
    async runWasmComparison() {
        // 假设 WASM 模块有对应的图像处理函数
        // 这里需要将图像数据传递给 WASM 内存
        const wasmResults = {};
        
        // WASM 高斯模糊测试
        const wasmBlurBenchmark = new PrecisionBenchmark('WASM Gaussian Blur', { iterations: 10 });
        wasmResults.gaussianBlur = await wasmBlurBenchmark.run(() => {
            // 调用 WASM 函数 (伪代码)
            // this.wasmModule.gaussian_blur(imageDataPointer, width, height, radius);
        });
        
        return wasmResults;
    }
}
```

## C.4 I/O 和 DOM 基准测试

### C.4.1 DOM 操作基准测试

**DOM 创建和修改测试**:
```javascript
// DOM 操作基准测试套件
class DOMBenchmarkSuite {
    constructor() {
        this.testContainer = null;
        this.setupContainer();
    }
    
    setupContainer() {
        this.testContainer = document.createElement('div');
        this.testContainer.id = 'benchmark-container';
        this.testContainer.style.cssText = `
            position: absolute;
            top: -10000px;
            left: -10000px;
            width: 1000px;
            height: 1000px;
            overflow: hidden;
        `;
        document.body.appendChild(this.testContainer);
    }
    
    // DOM 元素创建基准测试
    async testDOMCreation() {
        const benchmark = new PrecisionBenchmark('DOM Element Creation');
        
        return await benchmark.run(() => {
            const fragment = document.createDocumentFragment();
            
            for (let i = 0; i < 1000; i++) {
                const div = document.createElement('div');
                div.className = `test-element-${i}`;
                div.textContent = `Element ${i}`;
                div.style.cssText = `
                    width: ${Math.random() * 100}px;
                    height: ${Math.random() * 100}px;
                    background-color: hsl(${Math.random() * 360}, 50%, 50%);
                `;
                fragment.appendChild(div);
            }
            
            this.testContainer.appendChild(fragment);
            
            // 清理
            this.testContainer.innerHTML = '';
        });
    }
    
    // DOM 查询基准测试
    async testDOMQuery() {
        // 首先创建测试结构
        this.createTestStructure();
        
        const benchmark = new PrecisionBenchmark('DOM Query Operations');
        
        return await benchmark.run(() => {
            // 各种查询操作
            const byId = document.getElementById('test-element-500');
            const byClass = document.getElementsByClassName('test-class');
            const byTag = document.getElementsByTagName('div');
            const byQuery = document.querySelector('.test-class[data-index="250"]');
            const byQueryAll = document.querySelectorAll('.test-class:nth-child(odd)');
            
            // 返回结果确保操作不被优化掉
            return {
                byId: byId?.id,
                byClassCount: byClass.length,
                byTagCount: byTag.length,
                byQuery: byQuery?.getAttribute('data-index'),
                byQueryAllCount: byQueryAll.length
            };
        });
    }
    
    createTestStructure() {
        const fragment = document.createDocumentFragment();
        
        for (let i = 0; i < 1000; i++) {
            const div = document.createElement('div');
            div.id = `test-element-${i}`;
            div.className = 'test-class';
            div.setAttribute('data-index', i.toString());
            div.textContent = `Test Element ${i}`;
            fragment.appendChild(div);
        }
        
        this.testContainer.appendChild(fragment);
    }
    
    // DOM 样式修改基准测试
    async testStyleModification() {
        this.createTestStructure();
        
        const benchmark = new PrecisionBenchmark('DOM Style Modification');
        const elements = this.testContainer.querySelectorAll('.test-class');
        
        return await benchmark.run(() => {
            elements.forEach((element, index) => {
                // 直接样式修改
                element.style.transform = `translateX(${index % 100}px)`;
                element.style.opacity = Math.random().toString();
                element.style.backgroundColor = `hsl(${index % 360}, 50%, 50%)`;
                
                // 类名切换
                if (index % 2 === 0) {
                    element.classList.add('even-element');
                } else {
                    element.classList.add('odd-element');
                }
            });
        });
    }
    
    // 事件处理基准测试
    async testEventHandling() {
        this.createTestStructure();
        
        let eventCount = 0;
        const eventHandler = (e) => {
            eventCount++;
            e.target.style.backgroundColor = 'red';
        };
        
        // 添加事件监听器
        const elements = this.testContainer.querySelectorAll('.test-class');
        elements.forEach(element => {
            element.addEventListener('click', eventHandler);
        });
        
        const benchmark = new PrecisionBenchmark('Event Handling');
        
        const result = await benchmark.run(() => {
            // 模拟点击事件
            elements.forEach(element => {
                const clickEvent = new MouseEvent('click', {
                    bubbles: true,
                    cancelable: true,
                    view: window
                });
                element.dispatchEvent(clickEvent);
            });
        });
        
        // 清理事件监听器
        elements.forEach(element => {
            element.removeEventListener('click', eventHandler);
        });
        
        return {
            ...result,
            eventsProcessed: eventCount
        };
    }
    
    // 布局和重排基准测试
    async testLayoutThrashing() {
        this.createTestStructure();
        
        const benchmark = new PrecisionBenchmark('Layout Thrashing');
        const elements = this.testContainer.querySelectorAll('.test-class');
        
        return await benchmark.run(() => {
            elements.forEach(element => {
                // 强制布局重计算的操作
                element.style.width = Math.random() * 200 + 'px';
                const width = element.offsetWidth; // 强制布局
                
                element.style.height = Math.random() * 200 + 'px';
                const height = element.offsetHeight; // 强制布局
                
                element.style.marginLeft = Math.random() * 50 + 'px';
                const margin = element.offsetLeft; // 强制布局
            });
        });
    }
    
    // 运行完整的 DOM 基准测试套件
    async runFullSuite() {
        const results = {
            domCreation: await this.testDOMCreation(),
            domQuery: await this.testDOMQuery(),
            styleModification: await this.testStyleModification(),
            eventHandling: await this.testEventHandling(),
            layoutThrashing: await this.testLayoutThrashing()
        };
        
        // 清理
        this.cleanup();
        
        return results;
    }
    
    cleanup() {
        if (this.testContainer && this.testContainer.parentNode) {
            this.testContainer.parentNode.removeChild(this.testContainer);
        }
    }
}
```

### C.4.2 网络 I/O 基准测试

**网络请求性能测试**:
```javascript
// 网络 I/O 基准测试套件
class NetworkBenchmarkSuite {
    constructor() {
        this.testEndpoints = {
            small: './test-data/small.json',    // ~1KB
            medium: './test-data/medium.json',  // ~100KB
            large: './test-data/large.json'     // ~1MB
        };
    }
    
    // Fetch API 性能测试
    async testFetchPerformance() {
        const results = {};
        
        for (const [size, url] of Object.entries(this.testEndpoints)) {
            const benchmark = new PrecisionBenchmark(`Fetch ${size} data`);
            
            results[size] = await benchmark.run(async () => {
                const response = await fetch(url);
                const data = await response.json();
                return data;
            });
        }
        
        return results;
    }
    
    // XMLHttpRequest 性能测试
    async testXHRPerformance() {
        const results = {};
        
        for (const [size, url] of Object.entries(this.testEndpoints)) {
            const benchmark = new PrecisionBenchmark(`XHR ${size} data`);
            
            results[size] = await benchmark.run(() => {
                return new Promise((resolve, reject) => {
                    const xhr = new XMLHttpRequest();
                    xhr.open('GET', url);
                    xhr.onload = () => {
                        if (xhr.status === 200) {
                            resolve(JSON.parse(xhr.responseText));
                        } else {
                            reject(new Error(`HTTP ${xhr.status}`));
                        }
                    };
                    xhr.onerror = reject;
                    xhr.send();
                });
            });
        }
        
        return results;
    }
    
    // WebSocket 性能测试
    async testWebSocketPerformance() {
        // 注意：这需要一个支持 WebSocket 的测试服务器
        const benchmark = new PrecisionBenchmark('WebSocket Round Trip');
        
        return new Promise((resolve) => {
            const ws = new WebSocket('ws://localhost:8080/benchmark');
            const measurements = [];
            let messagesSent = 0;
            const totalMessages = 100;
            
            ws.onopen = () => {
                const sendMessage = () => {
                    const start = performance.now();
                    ws.send(JSON.stringify({ 
                        id: messagesSent, 
                        timestamp: start,
                        data: 'benchmark-data'.repeat(100) // ~1.3KB
                    }));
                };
                
                const interval = setInterval(() => {
                    if (messagesSent < totalMessages) {
                        sendMessage();
                        messagesSent++;
                    } else {
                        clearInterval(interval);
                    }
                }, 10);
            };
            
            ws.onmessage = (event) => {
                const end = performance.now();
                const message = JSON.parse(event.data);
                const roundTripTime = end - message.timestamp;
                measurements.push(roundTripTime);
                
                if (measurements.length === totalMessages) {
                    ws.close();
                    const stats = StatisticsAnalyzer.calculateStats(measurements);
                    resolve({
                        name: 'WebSocket Round Trip',
                        measurements,
                        statistics: stats
                    });
                }
            };
        });
    }
    
    // 并发请求性能测试
    async testConcurrentRequests() {
        const concurrencyLevels = [1, 5, 10, 20, 50];
        const results = {};
        
        for (const concurrency of concurrencyLevels) {
            const benchmark = new PrecisionBenchmark(`Concurrent Requests (${concurrency})`);
            
            results[`concurrency_${concurrency}`] = await benchmark.run(async () => {
                const promises = Array(concurrency).fill().map(async () => {
                    const response = await fetch(this.testEndpoints.medium);
                    return await response.json();
                });
                
                const results = await Promise.all(promises);
                return results.length;
            });
        }
        
        return results;
    }
    
    // 请求缓存性能测试
    async testRequestCaching() {
        const cacheUrl = this.testEndpoints.medium;
        
        // 第一次请求 (无缓存)
        const firstRequestBenchmark = new PrecisionBenchmark('First Request (No Cache)');
        const firstRequest = await firstRequestBenchmark.run(async () => {
            const response = await fetch(cacheUrl + '?nocache=' + Date.now());
            return await response.json();
        });
        
        // 缓存的请求
        const cachedRequestBenchmark = new PrecisionBenchmark('Cached Request');
        const cachedRequest = await cachedRequestBenchmark.run(async () => {
            const response = await fetch(cacheUrl);
            return await response.json();
        });
        
        return {
            firstRequest,
            cachedRequest,
            cacheSpeedup: firstRequest.statistics.mean / cachedRequest.statistics.mean
        };
    }
    
    // 数据传输格式对比测试
    async testDataFormats() {
        const formats = {
            json: './test-data/data.json',
            xml: './test-data/data.xml',
            binary: './test-data/data.bin',
            msgpack: './test-data/data.msgpack'
        };
        
        const results = {};
        
        for (const [format, url] of Object.entries(formats)) {
            const benchmark = new PrecisionBenchmark(`${format.toUpperCase()} Format`);
            
            results[format] = await benchmark.run(async () => {
                const response = await fetch(url);
                
                switch (format) {
                    case 'json':
                        return await response.json();
                    case 'xml':
                        const xmlText = await response.text();
                        const parser = new DOMParser();
                        return parser.parseFromString(xmlText, 'text/xml');
                    case 'binary':
                        return await response.arrayBuffer();
                    case 'msgpack':
                        const buffer = await response.arrayBuffer();
                        // 假设有 msgpack 解析库
                        // return msgpack.decode(new Uint8Array(buffer));
                        return buffer;
                    default:
                        return await response.text();
                }
            });
        }
        
        return results;
    }
    
    // 运行完整网络基准测试套件
    async runFullSuite() {
        console.log('开始网络 I/O 基准测试...');
        
        const results = {
            fetch: await this.testFetchPerformance(),
            xhr: await this.testXHRPerformance(),
            concurrent: await this.testConcurrentRequests(),
            caching: await this.testRequestCaching(),
            dataFormats: await this.testDataFormats()
        };
        
        // WebSocket 测试需要服务器支持，可选
        try {
            results.websocket = await this.testWebSocketPerformance();
        } catch (error) {
            console.warn('WebSocket 测试跳过:', error.message);
        }
        
        return results;
    }
}
```

## C.5 性能分析工具

### C.5.1 浏览器性能 API

**详细性能监控工具**:
```javascript
// 浏览器性能监控工具
class BrowserPerformanceProfiler {
    constructor() {
        this.observer = null;
        this.performanceEntries = [];
        this.memorySnapshots = [];
        this.setupPerformanceObserver();
    }
    
    setupPerformanceObserver() {
        if ('PerformanceObserver' in window) {
            this.observer = new PerformanceObserver((list) => {
                const entries = list.getEntries();
                this.performanceEntries.push(...entries);
            });
            
            // 监控各种性能指标
            try {
                this.observer.observe({ entryTypes: ['measure', 'mark', 'navigation', 'resource', 'paint'] });
            } catch (e) {
                // 降级处理
                this.observer.observe({ entryTypes: ['measure', 'mark'] });
            }
        }
    }
    
    // 添加自定义性能标记
    mark(name) {
        if ('performance' in window && 'mark' in performance) {
            performance.mark(name);
        }
    }
    
    // 测量两个标记之间的时间
    measure(name, startMark, endMark) {
        if ('performance' in window && 'measure' in performance) {
            performance.measure(name, startMark, endMark);
        }
    }
    
    // 获取导航性能信息
    getNavigationTiming() {
        if (!('performance' in window) || !performance.getEntriesByType) {
            return null;
        }
        
        const navigation = performance.getEntriesByType('navigation')[0];
        if (!navigation) return null;
        
        return {
            // DNS 查询时间
            dnsLookup: navigation.domainLookupEnd - navigation.domainLookupStart,
            
            // TCP 连接时间
            tcpConnect: navigation.connectEnd - navigation.connectStart,
            
            // SSL 握手时间 (如果是 HTTPS)
            sslHandshake: navigation.secureConnectionStart > 0 ? 
                navigation.connectEnd - navigation.secureConnectionStart : 0,
            
            // 请求响应时间
            requestResponse: navigation.responseEnd - navigation.requestStart,
            
            // DOM 解析时间
            domParsing: navigation.domInteractive - navigation.responseEnd,
            
            // DOM 内容加载完成
            domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
            
            // 页面完全加载时间
            pageLoad: navigation.loadEventEnd - navigation.loadEventStart,
            
            // 总的页面加载时间
            totalTime: navigation.loadEventEnd - navigation.navigationStart
        };
    }
    
    // 获取资源加载性能
    getResourceTiming() {
        if (!('performance' in window) || !performance.getEntriesByType) {
            return [];
        }
        
        const resources = performance.getEntriesByType('resource');
        
        return resources.map(resource => ({
            name: resource.name,
            duration: resource.duration,
            size: resource.transferSize || resource.encodedBodySize,
            type: this.getResourceType(resource.name),
            cached: resource.transferSize === 0 && resource.encodedBodySize > 0,
            timing: {
                dns: resource.domainLookupEnd - resource.domainLookupStart,
                tcp: resource.connectEnd - resource.connectStart,
                ssl: resource.secureConnectionStart > 0 ? 
                    resource.connectEnd - resource.secureConnectionStart : 0,
                request: resource.responseStart - resource.requestStart,
                response: resource.responseEnd - resource.responseStart
            }
        }));
    }
    
    getResourceType(url) {
        const extension = url.split('.').pop().toLowerCase();
        const typeMap = {
            'js': 'javascript',
            'css': 'stylesheet',
            'png': 'image',
            'jpg': 'image',
            'jpeg': 'image',
            'gif': 'image',
            'svg': 'image',
            'woff': 'font',
            'woff2': 'font',
            'ttf': 'font',
            'json': 'xhr',
            'wasm': 'wasm'
        };
        return typeMap[extension] || 'other';
    }
    
    // 获取绘制性能信息
    getPaintTiming() {
        if (!('performance' in window) || !performance.getEntriesByType) {
            return null;
        }
        
        const paintEntries = performance.getEntriesByType('paint');
        const result = {};
        
        paintEntries.forEach(entry => {
            result[entry.name] = entry.startTime;
        });
        
        return result;
    }
    
    // 内存使用快照
    takeMemorySnapshot() {
        if (!('performance' in window) || !performance.memory) {
            return null;
        }
        
        const snapshot = {
            timestamp: performance.now(),
            usedJSHeapSize: performance.memory.usedJSHeapSize,
            totalJSHeapSize: performance.memory.totalJSHeapSize,
            jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
        };
        
        this.memorySnapshots.push(snapshot);
        return snapshot;
    }
    
    // 分析内存趋势
    analyzeMemoryTrend() {
        if (this.memorySnapshots.length < 2) {
            return null;
        }
        
        const snapshots = this.memorySnapshots.slice(-10); // 最近10个快照
        const growthRates = [];
        
        for (let i = 1; i < snapshots.length; i++) {
            const prev = snapshots[i - 1];
            const curr = snapshots[i];
            const timeDiff = curr.timestamp - prev.timestamp;
            const memoryDiff = curr.usedJSHeapSize - prev.usedJSHeapSize;
            
            if (timeDiff > 0) {
                growthRates.push(memoryDiff / timeDiff); // bytes/ms
            }
        }
        
        const avgGrowthRate = growthRates.reduce((a, b) => a + b, 0) / growthRates.length;
        
        return {
            averageGrowthRate: avgGrowthRate,
            currentUsage: snapshots[snapshots.length - 1].usedJSHeapSize,
            peakUsage: Math.max(...snapshots.map(s => s.usedJSHeapSize)),
            snapshots: snapshots
        };
    }
    
    // 生成性能报告
    generateReport() {
        const report = {
            timestamp: new Date().toISOString(),
            navigation: this.getNavigationTiming(),
            resources: this.getResourceTiming(),
            paint: this.getPaintTiming(),
            memory: this.analyzeMemoryTrend(),
            customMarks: this.performanceEntries.filter(entry => entry.entryType === 'mark'),
            customMeasures: this.performanceEntries.filter(entry => entry.entryType === 'measure')
        };
        
        return report;
    }
    
    // 清理和销毁
    destroy() {
        if (this.observer) {
            this.observer.disconnect();
        }
        this.performanceEntries = [];
        this.memorySnapshots = [];
    }
}
```

### C.5.2 WebAssembly 特定性能分析

**WASM 性能分析工具**:
```javascript
// WebAssembly 性能分析工具
class WasmPerformanceAnalyzer {
    constructor() {
        this.compilationTimes = new Map();
        this.instantiationTimes = new Map();
        this.functionCallTimes = new Map();
        this.memoryUsage = new Map();
    }
    
    // 分析 WASM 模块编译性能
    async analyzeCompilation(wasmBytes, name = 'unknown') {
        const startTime = performance.now();
        
        try {
            const module = await WebAssembly.compile(wasmBytes);
            const endTime = performance.now();
            
            const compilationTime = endTime - startTime;
            this.compilationTimes.set(name, {
                time: compilationTime,
                moduleSize: wasmBytes.byteLength,
                timestamp: Date.now()
            });
            
            return {
                module,
                compilationTime,
                bytesPerMs: wasmBytes.byteLength / compilationTime
            };
        } catch (error) {
            throw new Error(`WASM 编译失败: ${error.message}`);
        }
    }
    
    // 分析 WASM 模块实例化性能
    async analyzeInstantiation(module, importObject = {}, name = 'unknown') {
        const startTime = performance.now();
        
        try {
            const instance = await WebAssembly.instantiate(module, importObject);
            const endTime = performance.now();
            
            const instantiationTime = endTime - startTime;
            this.instantiationTimes.set(name, {
                time: instantiationTime,
                timestamp: Date.now()
            });
            
            return {
                instance,
                instantiationTime
            };
        } catch (error) {
            throw new Error(`WASM 实例化失败: ${error.message}`);
        }
    }
    
    // 分析函数调用性能
    createInstrumentedFunction(wasmFunction, functionName) {
        const analyzer = this;
        
        return function(...args) {
            const startTime = performance.now();
            const result = wasmFunction.apply(this, args);
            const endTime = performance.now();
            
            const callTime = endTime - startTime;
            
            if (!analyzer.functionCallTimes.has(functionName)) {
                analyzer.functionCallTimes.set(functionName, []);
            }
            
            analyzer.functionCallTimes.get(functionName).push({
                time: callTime,
                args: args.length,
                timestamp: startTime
            });
            
            return result;
        };
    }
    
    // 内存使用分析
    analyzeMemoryUsage(wasmInstance, testName) {
        const memory = wasmInstance.exports.memory;
        if (!memory) {
            console.warn('WASM 实例没有导出内存');
            return null;
        }
        
        const memoryInfo = {
            timestamp: performance.now(),
            bufferSize: memory.buffer.byteLength,
            pageCount: memory.buffer.byteLength / 65536, // WASM 页大小
            testName
        };
        
        if (!this.memoryUsage.has(testName)) {
            this.memoryUsage.set(testName, []);
        }
        
        this.memoryUsage.get(testName).push(memoryInfo);
        return memoryInfo;
    }
    
    // WASM 与 JS 性能对比
    async runPerformanceComparison(wasmFunction, jsFunction, testData, iterations = 1000) {
        // 预热
        for (let i = 0; i < 100; i++) {
            wasmFunction(...testData);
            jsFunction(...testData);
        }
        
        // WASM 测试
        const wasmTimes = [];
        for (let i = 0; i < iterations; i++) {
            const start = performance.now();
            wasmFunction(...testData);
            const end = performance.now();
            wasmTimes.push(end - start);
        }
        
        // JavaScript 测试
        const jsTimes = [];
        for (let i = 0; i < iterations; i++) {
            const start = performance.now();
            jsFunction(...testData);
            const end = performance.now();
            jsTimes.push(end - start);
        }
        
        const wasmStats = StatisticsAnalyzer.calculateStats(wasmTimes);
        const jsStats = StatisticsAnalyzer.calculateStats(jsTimes);
        
        return {
            wasm: wasmStats,
            javascript: jsStats,
            speedup: jsStats.mean / wasmStats.mean,
            wasmFaster: wasmStats.mean < jsStats.mean
        };
    }
    
    // 分析编译后的 WASM 代码质量
    analyzeWasmCodeQuality(wasmBytes) {
        // 这是一个简化的分析，实际的分析会更复杂
        const view = new Uint8Array(wasmBytes);
        
        // 检查 WASM 魔数
        const magicNumber = [0x00, 0x61, 0x73, 0x6d];
        const hasMagicNumber = magicNumber.every((byte, index) => view[index] === byte);
        
        // 版本检查
        const version = [view[4], view[5], view[6], view[7]];
        
        // 简单的段分析
        let sectionCount = 0;
        let codeSize = 0;
        let dataSize = 0;
        
        // 这里应该实现完整的 WASM 二进制格式解析
        // 为了简化，我们只做基本检查
        
        return {
            isValid: hasMagicNumber,
            version,
            fileSize: wasmBytes.byteLength,
            sectionCount,
            codeSize,
            dataSize,
            compressionRatio: codeSize / wasmBytes.byteLength
        };
    }
    
    // 生成性能报告
    generatePerformanceReport() {
        const report = {
            timestamp: new Date().toISOString(),
            compilation: Object.fromEntries(this.compilationTimes),
            instantiation: Object.fromEntries(this.instantiationTimes),
            functionCalls: this.analyzeFunctionCallStats(),
            memory: this.analyzeMemoryStats(),
            recommendations: this.generateRecommendations()
        };
        
        return report;
    }
    
    analyzeFunctionCallStats() {
        const stats = {};
        
        for (const [functionName, calls] of this.functionCallTimes) {
            const times = calls.map(call => call.time);
            stats[functionName] = {
                ...StatisticsAnalyzer.calculateStats(times),
                callCount: calls.length,
                totalTime: times.reduce((a, b) => a + b, 0)
            };
        }
        
        return stats;
    }
    
    analyzeMemoryStats() {
        const stats = {};
        
        for (const [testName, snapshots] of this.memoryUsage) {
            const sizes = snapshots.map(snapshot => snapshot.bufferSize);
            stats[testName] = {
                ...StatisticsAnalyzer.calculateStats(sizes),
                snapshotCount: snapshots.length,
                peakMemory: Math.max(...sizes),
                averageMemory: sizes.reduce((a, b) => a + b, 0) / sizes.length
            };
        }
        
        return stats;
    }
    
    generateRecommendations() {
        const recommendations = [];
        
        // 编译时间建议
        for (const [name, data] of this.compilationTimes) {
            if (data.time > 100) { // 超过100ms
                recommendations.push({
                    type: 'compilation',
                    severity: 'warning',
                    message: `模块 "${name}" 编译时间较长 (${data.time.toFixed(2)}ms)，考虑预编译或优化代码`
                });
            }
        }
        
        // 函数调用性能建议
        for (const [functionName, stats] of Object.entries(this.analyzeFunctionCallStats())) {
            if (stats.mean > 10) { // 平均调用时间超过10ms
                recommendations.push({
                    type: 'function_performance',
                    severity: 'warning',
                    message: `函数 "${functionName}" 平均执行时间较长 (${stats.mean.toFixed(2)}ms)，建议优化算法或减少调用频率`
                });
            }
        }
        
        return recommendations;
    }
}
```

## C.6 性能优化策略

### C.6.1 基于基准测试的优化

**自动化性能优化建议系统**:
```javascript
// 性能优化建议系统
class PerformanceOptimizationAdvisor {
    constructor() {
        this.benchmarkResults = new Map();
        this.optimizationRules = this.initializeOptimizationRules();
    }
    
    initializeOptimizationRules() {
        return [
            {
                name: 'memory_allocation_frequency',
                condition: (results) => {
                    const memoryStats = results.memory?.analyzeMemoryTrend?.();
                    return memoryStats && memoryStats.averageGrowthRate > 1000; // >1KB/ms
                },
                recommendation: {
                    severity: 'high',
                    title: '内存分配频率过高',
                    description: '检测到频繁的内存分配，可能导致性能问题',
                    solutions: [
                        '使用对象池减少 GC 压力',
                        '预分配大块内存',
                        '使用 ArrayBuffer 和 TypedArray',
                        '避免在循环中创建临时对象'
                    ]
                }
            },
            {
                name: 'dom_manipulation_performance',
                condition: (results) => {
                    const domResults = results.dom;
                    return domResults && domResults.layoutThrashing?.statistics.mean > 50;
                },
                recommendation: {
                    severity: 'medium',
                    title: 'DOM 操作性能瓶颈',
                    description: 'DOM 操作导致频繁的布局重计算',
                    solutions: [
                        '批量 DOM 操作',
                        '使用 DocumentFragment',
                        '避免频繁读取布局属性',
                        '使用 CSS transforms 替代位置变更'
                    ]
                }
            },
            {
                name: 'wasm_js_boundary_overhead',
                condition: (results) => {
                    const wasmResults = results.wasm;
                    return wasmResults && wasmResults.speedup < 1.5; // WASM 加速比小于1.5x
                },
                recommendation: {
                    severity: 'medium',
                    title: 'WASM/JS 边界开销过高',
                    description: 'WebAssembly 性能优势不明显，可能由于频繁的边界调用',
                    solutions: [
                        '减少 WASM/JS 调用频率',
                        '批量传递数据',
                        '在 WASM 中实现更多逻辑',
                        '使用 SharedArrayBuffer 共享内存'
                    ]
                }
            },
            {
                name: 'network_request_optimization',
                condition: (results) => {
                    const networkResults = results.network;
                    return networkResults && networkResults.caching?.cacheSpeedup < 3;
                },
                recommendation: {
                    severity: 'low',
                    title: '网络请求缓存效果不佳',
                    description: '缓存带来的性能提升有限',
                    solutions: [
                        '检查缓存头配置',
                        '使用 Service Worker 实现应用级缓存',
                        '实现预加载策略',
                        '压缩响应数据'
                    ]
                }
            }
        ];
    }
    
    // 分析基准测试结果并生成优化建议
    analyzeAndRecommend(benchmarkResults) {
        const recommendations = [];
        
        for (const rule of this.optimizationRules) {
            try {
                if (rule.condition(benchmarkResults)) {
                    recommendations.push({
                        ...rule.recommendation,
                        ruleId: rule.name,
                        timestamp: Date.now()
                    });
                }
            } catch (error) {
                console.warn(`优化规则 "${rule.name}" 执行失败:`, error);
            }
        }
        
        return recommendations;
    }
    
    // 生成性能优化报告
    generateOptimizationReport(benchmarkResults) {
        const recommendations = this.analyzeAndRecommend(benchmarkResults);
        
        // 按严重程度排序
        const sortedRecommendations = recommendations.sort((a, b) => {
            const severityOrder = { high: 3, medium: 2, low: 1 };
            return severityOrder[b.severity] - severityOrder[a.severity];
        });
        
        // 生成具体的优化代码示例
        const codeExamples = this.generateCodeExamples(recommendations);
        
        return {
            summary: {
                totalIssues: recommendations.length,
                highPriority: recommendations.filter(r => r.severity === 'high').length,
                mediumPriority: recommendations.filter(r => r.severity === 'medium').length,
                lowPriority: recommendations.filter(r => r.severity === 'low').length
            },
            recommendations: sortedRecommendations,
            codeExamples,
            timestamp: new Date().toISOString()
        };
    }
    
    generateCodeExamples(recommendations) {
        const examples = {};
        
        recommendations.forEach(rec => {
            switch (rec.ruleId) {
                case 'memory_allocation_frequency':
                    examples[rec.ruleId] = {
                        before: `
// 问题代码：频繁内存分配
function processData(items) {
    for (let item of items) {
        const temp = { processed: item.value * 2 }; // 每次分配新对象
        results.push(temp);
    }
}`,
                        after: `
// 优化代码：对象重用
class DataProcessor {
    constructor() {
        this.tempObject = { processed: 0 }; // 重用对象
    }
    
    processData(items) {
        for (let item of items) {
            this.tempObject.processed = item.value * 2;
            results.push({ ...this.tempObject }); // 只在需要时复制
        }
    }
}`
                    };
                    break;
                    
                case 'dom_manipulation_performance':
                    examples[rec.ruleId] = {
                        before: `
// 问题代码：频繁 DOM 操作
elements.forEach(el => {
    el.style.width = Math.random() * 100 + 'px';
    const width = el.offsetWidth; // 强制布局
    el.style.height = width + 'px';
});`,
                        after: `
// 优化代码：批量操作
const fragment = document.createDocumentFragment();
elements.forEach(el => {
    const clone = el.cloneNode(true);
    const width = Math.random() * 100;
    clone.style.width = width + 'px';
    clone.style.height = width + 'px';
    fragment.appendChild(clone);
});
container.replaceChildren(fragment);`
                    };
                    break;
                    
                case 'wasm_js_boundary_overhead':
                    examples[rec.ruleId] = {
                        before: `
// 问题代码：频繁边界调用
for (let i = 0; i < 1000000; i++) {
    wasmModule.process_single_item(data[i]);
}`,
                        after: `
// 优化代码：批量处理
const batchSize = 1000;
for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);
    wasmModule.process_batch(batch);
}`
                    };
                    break;
            }
        });
        
        return examples;
    }
}
```

### C.6.2 持续性能监控

**生产环境性能监控**:
```javascript
// 生产环境性能监控系统
class ProductionPerformanceMonitor {
    constructor(options = {}) {
        this.options = {
            samplingRate: options.samplingRate || 0.1, // 10% 采样
            reportingInterval: options.reportingInterval || 60000, // 1分钟报告一次
            endpointUrl: options.endpointUrl || '/api/performance',
            maxBatchSize: options.maxBatchSize || 100,
            ...options
        };
        
        this.performanceData = [];
        this.isMonitoring = false;
        this.reportingTimer = null;
        
        this.init();
    }
    
    init() {
        // 监控页面加载性能
        this.monitorPageLoad();
        
        // 监控资源加载
        this.monitorResourceLoading();
        
        // 监控运行时性能
        this.monitorRuntimePerformance();
        
        // 监控错误
        this.monitorErrors();
        
        // 启动定期报告
        this.startReporting();
    }
    
    monitorPageLoad() {
        window.addEventListener('load', () => {
            if (Math.random() > this.options.samplingRate) return;
            
            const navigation = performance.getEntriesByType('navigation')[0];
            if (navigation) {
                this.recordMetric('page_load', {
                    timestamp: Date.now(),
                    metrics: {
                        loadTime: navigation.loadEventEnd - navigation.navigationStart,
                        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.navigationStart,
                        firstByte: navigation.responseStart - navigation.navigationStart,
                        domInteractive: navigation.domInteractive - navigation.navigationStart
                    },
                    userAgent: navigator.userAgent,
                    url: window.location.href
                });
            }
        });
    }
    
    monitorResourceLoading() {
        if ('PerformanceObserver' in window) {
            const observer = new PerformanceObserver((list) => {
                if (Math.random() > this.options.samplingRate) return;
                
                const entries = list.getEntries();
                entries.forEach(entry => {
                    if (entry.duration > 1000) { // 只记录加载时间超过1秒的资源
                        this.recordMetric('slow_resource', {
                            timestamp: Date.now(),
                            resource: {
                                name: entry.name,
                                duration: entry.duration,
                                size: entry.transferSize,
                                type: this.getResourceType(entry.name)
                            }
                        });
                    }
                });
            });
            
            observer.observe({ entryTypes: ['resource'] });
        }
    }
    
    monitorRuntimePerformance() {
        // 监控长任务
        if ('PerformanceLongTaskTiming' in window) {
            const observer = new PerformanceObserver((list) => {
                if (Math.random() > this.options.samplingRate) return;
                
                const entries = list.getEntries();
                entries.forEach(entry => {
                    this.recordMetric('long_task', {
                        timestamp: Date.now(),
                        task: {
                            duration: entry.duration,
                            startTime: entry.startTime,
                            name: entry.name
                        }
                    });
                });
            });
            
            observer.observe({ entryTypes: ['longtask'] });
        }
        
        // 监控内存使用
        if (performance.memory) {
            setInterval(() => {
                if (Math.random() > this.options.samplingRate) return;
                
                this.recordMetric('memory_usage', {
                    timestamp: Date.now(),
                    memory: {
                        used: performance.memory.usedJSHeapSize,
                        total: performance.memory.totalJSHeapSize,
                        limit: performance.memory.jsHeapSizeLimit
                    }
                });
            }, 30000); // 每30秒采样一次
        }
    }
    
    monitorErrors() {
        // JavaScript 错误
        window.addEventListener('error', (event) => {
            this.recordMetric('javascript_error', {
                timestamp: Date.now(),
                error: {
                    message: event.message,
                    filename: event.filename,
                    line: event.lineno,
                    column: event.colno,
                    stack: event.error?.stack
                }
            });
        });
        
        // Promise 拒绝
        window.addEventListener('unhandledrejection', (event) => {
            this.recordMetric('promise_rejection', {
                timestamp: Date.now(),
                error: {
                    reason: event.reason?.toString(),
                    stack: event.reason?.stack
                }
            });
        });
    }
    
    recordMetric(type, data) {
        const metric = {
            type,
            ...data,
            sessionId: this.getSessionId(),
            userId: this.getUserId()
        };
        
        this.performanceData.push(metric);
        
        // 如果数据量过大，立即发送
        if (this.performanceData.length >= this.options.maxBatchSize) {
            this.sendMetrics();
        }
    }
    
    startReporting() {
        this.reportingTimer = setInterval(() => {
            if (this.performanceData.length > 0) {
                this.sendMetrics();
            }
        }, this.options.reportingInterval);
    }
    
    async sendMetrics() {
        if (this.performanceData.length === 0) return;
        
        const payload = {
            metrics: [...this.performanceData],
            timestamp: Date.now(),
            userAgent: navigator.userAgent,
            url: window.location.href
        };
        
        this.performanceData = []; // 清空本地数据
        
        try {
            // 使用 navigator.sendBeacon 确保数据能够发送
            if ('sendBeacon' in navigator) {
                const success = navigator.sendBeacon(
                    this.options.endpointUrl,
                    JSON.stringify(payload)
                );
                
                if (!success) {
                    // 降级到 fetch
                    await this.fallbackSend(payload);
                }
            } else {
                await this.fallbackSend(payload);
            }
        } catch (error) {
            console.warn('性能数据发送失败:', error);
            // 可以考虑将数据存储到 localStorage 稍后重试
        }
    }
    
    async fallbackSend(payload) {
        const response = await fetch(this.options.endpointUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload),
            keepalive: true
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
    }
    
    getResourceType(url) {
        const extension = url.split('.').pop()?.toLowerCase();
        const typeMap = {
            'js': 'script',
            'css': 'stylesheet',
            'png': 'image',
            'jpg': 'image',
            'woff': 'font',
            'wasm': 'wasm'
        };
        return typeMap[extension] || 'other';
    }
    
    getSessionId() {
        let sessionId = sessionStorage.getItem('performance-session-id');
        if (!sessionId) {
            sessionId = 'session-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
            sessionStorage.setItem('performance-session-id', sessionId);
        }
        return sessionId;
    }
    
    getUserId() {
        // 返回匿名化的用户标识符
        return localStorage.getItem('anonymous-user-id') || 'anonymous';
    }
    
    // 停止监控
    stop() {
        this.isMonitoring = false;
        if (this.reportingTimer) {
            clearInterval(this.reportingTimer);
        }
        
        // 发送剩余数据
        if (this.performanceData.length > 0) {
            this.sendMetrics();
        }
    }
}

// 使用示例
const monitor = new ProductionPerformanceMonitor({
    samplingRate: 0.05, // 5% 采样率
    endpointUrl: 'https://api.example.com/performance',
    reportingInterval: 30000 // 30秒报告一次
});
```

## C.7 基准测试最佳实践

### C.7.1 测试环境标准化

**自动化基准测试套件**:
```javascript
// 完整的基准测试套件管理器
class BenchmarkSuiteManager {
    constructor() {
        this.suites = new Map();
        this.results = new Map();
        this.config = this.getDefaultConfig();
    }
    
    getDefaultConfig() {
        return {
            environment: {
                warmupRounds: 100,
                measurementRounds: 1000,
                minTestTime: 1000,
                maxTestTime: 10000,
                gcBetweenTests: true,
                isolateTests: true
            },
            reporting: {
                includeEnvironmentInfo: true,
                includeStatistics: true,
                includeOutliers: true,
                generateCharts: false
            },
            comparison: {
                enableBaseline: true,
                baselineThreshold: 0.05, // 5% 差异阈值
                enableRegression: true
            }
        };
    }
    
    // 注册基准测试套件
    registerSuite(name, suite) {
        this.suites.set(name, suite);
    }
    
    // 运行单个套件
    async runSuite(suiteName, options = {}) {
        const suite = this.suites.get(suiteName);
        if (!suite) {
            throw new Error(`基准测试套件 "${suiteName}" 不存在`);
        }
        
        console.log(`开始运行基准测试套件: ${suiteName}`);
        
        // 环境准备
        await this.prepareEnvironment();
        
        try {
            const results = await suite.runFullSuite();
            this.results.set(suiteName, {
                ...results,
                timestamp: Date.now(),
                environment: this.getEnvironmentInfo()
            });
            
            console.log(`套件 "${suiteName}" 完成`);
            return results;
        } catch (error) {
            console.error(`套件 "${suiteName}" 运行失败:`, error);
            throw error;
        }
    }
    
    // 运行所有套件
    async runAllSuites() {
        const results = {};
        
        for (const [suiteName] of this.suites) {
            try {
                results[suiteName] = await this.runSuite(suiteName);
            } catch (error) {
                results[suiteName] = {
                    error: error.message,
                    timestamp: Date.now()
                };
            }
        }
        
        return results;
    }
    
    // 环境准备
    async prepareEnvironment() {
        // 强制垃圾回收
        if (this.config.environment.gcBetweenTests && global.gc) {
            global.gc();
        }
        
        // 等待系统稳定
        await new Promise(resolve => setTimeout(resolve, 100));
        
        // 检查系统资源
        if (performance.memory) {
            const memoryInfo = performance.memory;
            const memoryUsage = memoryInfo.usedJSHeapSize / memoryInfo.jsHeapSizeLimit;
            
            if (memoryUsage > 0.8) {
                console.warn('内存使用率较高，测试结果可能不准确');
            }
        }
    }
    
    getEnvironmentInfo() {
        return {
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            hardwareConcurrency: navigator.hardwareConcurrency,
            memory: performance.memory ? {
                used: performance.memory.usedJSHeapSize,
                total: performance.memory.totalJSHeapSize,
                limit: performance.memory.jsHeapSizeLimit
            } : null,
            timestamp: Date.now(),
            url: window.location.href
        };
    }
    
    // 结果比较
    compareResults(current, baseline) {
        const comparison = {};
        
        for (const [testName, currentResult] of Object.entries(current)) {
            if (!baseline[testName]) continue;
            
            const baselineResult = baseline[testName];
            
            if (currentResult.statistics && baselineResult.statistics) {
                const currentMean = currentResult.statistics.mean;
                const baselineMean = baselineResult.statistics.mean;
                const changeRatio = (currentMean - baselineMean) / baselineMean;
                
                comparison[testName] = {
                    current: currentMean,
                    baseline: baselineMean,
                    changeRatio,
                    changePercent: changeRatio * 100,
                    isRegression: changeRatio > this.config.comparison.baselineThreshold,
                    isImprovement: changeRatio < -this.config.comparison.baselineThreshold,
                    significance: this.calculateSignificance(currentResult, baselineResult)
                };
            }
        }
        
        return comparison;
    }
    
    calculateSignificance(current, baseline) {
        // 简化的统计显著性检验
        const currentStats = current.statistics;
        const baselineStats = baseline.statistics;
        
        if (!currentStats || !baselineStats) return 'unknown';
        
        // 计算标准误差
        const currentSE = currentStats.standardDeviation / Math.sqrt(currentStats.count);
        const baselineSE = baselineStats.standardDeviation / Math.sqrt(baselineStats.count);
        
        // 计算 t 统计量
        const meanDiff = currentStats.mean - baselineStats.mean;
        const pooledSE = Math.sqrt(currentSE * currentSE + baselineSE * baselineSE);
        const tStat = Math.abs(meanDiff / pooledSE);
        
        // 简化的显著性判断
        if (tStat > 2.58) return 'highly_significant'; // p < 0.01
        if (tStat > 1.96) return 'significant';        // p < 0.05
        if (tStat > 1.65) return 'marginally_significant'; // p < 0.10
        return 'not_significant';
    }
    
    // 生成 HTML 报告
    generateHTMLReport(results, comparison = null) {
        const html = `
<!DOCTYPE html>
<html>
<head>
    <title>WebAssembly 性能基准测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .suite { margin: 20px 0; border: 1px solid #ddd; border-radius: 5px; }
        .suite-header { background: #e9e9e9; padding: 15px; font-weight: bold; }
        .test-result { padding: 15px; border-bottom: 1px solid #eee; }
        .statistics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; }
        .stat-item { background: #f9f9f9; padding: 10px; border-radius: 3px; }
        .regression { background-color: #ffebee; }
        .improvement { background-color: #e8f5e8; }
        .chart { margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>WebAssembly 性能基准测试报告</h1>
        <p>生成时间: ${new Date().toLocaleString()}</p>
        <p>测试环境: ${navigator.userAgent}</p>
    </div>
    
    ${Object.entries(results).map(([suiteName, suiteResults]) => `
        <div class="suite">
            <div class="suite-header">${suiteName}</div>
            ${this.generateSuiteHTML(suiteResults, comparison?.[suiteName])}
        </div>
    `).join('')}
    
    ${comparison ? this.generateComparisonHTML(comparison) : ''}
</body>
</html>`;
        
        return html;
    }
    
    generateSuiteHTML(suiteResults, suiteComparison) {
        if (suiteResults.error) {
            return `<div class="test-result">错误: ${suiteResults.error}</div>`;
        }
        
        return Object.entries(suiteResults)
            .filter(([key]) => key !== 'timestamp' && key !== 'environment')
            .map(([testName, testResult]) => {
                const comparisonData = suiteComparison?.[testName];
                const cssClass = comparisonData?.isRegression ? 'regression' : 
                                comparisonData?.isImprovement ? 'improvement' : '';
                
                return `
                <div class="test-result ${cssClass}">
                    <h3>${testName}</h3>
                    ${testResult.statistics ? this.generateStatisticsHTML(testResult.statistics) : ''}
                    ${comparisonData ? this.generateComparisonItemHTML(comparisonData) : ''}
                </div>`;
            }).join('');
    }
    
    generateStatisticsHTML(stats) {
        return `
        <div class="statistics">
            <div class="stat-item">
                <strong>平均值</strong><br>
                ${stats.mean.toFixed(2)}ms
            </div>
            <div class="stat-item">
                <strong>中位数</strong><br>
                ${stats.median.toFixed(2)}ms
            </div>
            <div class="stat-item">
                <strong>最小值</strong><br>
                ${stats.min.toFixed(2)}ms
            </div>
            <div class="stat-item">
                <strong>最大值</strong><br>
                ${stats.max.toFixed(2)}ms
            </div>
            <div class="stat-item">
                <strong>标准差</strong><br>
                ${stats.standardDeviation.toFixed(2)}ms
            </div>
            <div class="stat-item">
                <strong>样本数</strong><br>
                ${stats.count}
            </div>
        </div>`;
    }
    
    generateComparisonItemHTML(comparison) {
        const changeSign = comparison.changePercent >= 0 ? '+' : '';
        const changeColor = comparison.isRegression ? 'red' : 
                           comparison.isImprovement ? 'green' : 'black';
        
        return `
        <div style="margin-top: 10px; padding: 10px; background: #f0f0f0; border-radius: 3px;">
            <strong>与基线比较:</strong>
            <span style="color: ${changeColor};">
                ${changeSign}${comparison.changePercent.toFixed(2)}% 
                (${comparison.current.toFixed(2)}ms vs ${comparison.baseline.toFixed(2)}ms)
            </span>
            <br>
            <small>统计显著性: ${comparison.significance}</small>
        </div>`;
    }
    
    generateComparisonHTML(comparison) {
        return `
        <div class="suite">
            <div class="suite-header">性能对比总结</div>
            <div class="test-result">
                ${Object.entries(comparison).map(([suiteName, suiteComparison]) => `
                    <h3>${suiteName}</h3>
                    ${Object.entries(suiteComparison).map(([testName, comp]) => `
                        <div>${testName}: ${comp.changePercent >= 0 ? '+' : ''}${comp.changePercent.toFixed(2)}%</div>
                    `).join('')}
                `).join('')}
            </div>
        </div>`;
    }
}

// 使用示例
const benchmarkManager = new BenchmarkSuiteManager();

// 注册各种基准测试套件
benchmarkManager.registerSuite('arithmetic', new ArithmeticBenchmarkRunner());
benchmarkManager.registerSuite('memory', new MemoryBenchmarkSuite());
benchmarkManager.registerSuite('dom', new DOMBenchmarkSuite());
benchmarkManager.registerSuite('network', new NetworkBenchmarkSuite());
benchmarkManager.registerSuite('image', new ImageProcessingBenchmarks());

// 运行完整的基准测试
async function runCompleteBenchmark() {
    try {
        console.log('开始运行完整基准测试套件...');
        const results = await benchmarkManager.runAllSuites();
        
        // 生成报告
        const htmlReport = benchmarkManager.generateHTMLReport(results);
        
        // 保存报告
        const blob = new Blob([htmlReport], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `benchmark-report-${Date.now()}.html`;
        a.click();
        
        console.log('基准测试完成，报告已生成');
        return results;
    } catch (error) {
        console.error('基准测试失败:', error);
        throw error;
    }
}
```

## 总结

本附录全面介绍了 WebAssembly 性能基准测试的方方面面，从基础的测试方法论到高级的优化策略。通过系统性的性能测试和分析，开发者可以：

1. **建立科学的测试方法** - 使用统计学原理确保测试结果的可靠性
2. **全面评估性能表现** - 覆盖计算、内存、I/O、图形等各个方面
3. **识别性能瓶颈** - 通过专业的分析工具定位问题根源
4. **实施优化策略** - 基于数据驱动的方法进行性能改进
5. **持续监控性能** - 在生产环境中维持应用的最佳性能

记住，性能优化是一个持续的过程。定期运行基准测试，监控性能趋势，并根据实际使用场景调整优化策略，才能确保 WebAssembly 应用始终保持优异的性能表现。
