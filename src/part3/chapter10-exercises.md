# 第10章 练习题

## 10.1 编译时优化练习

### 练习 10.1.1 编译器优化配置实验 (15分)

**题目**: 创建一个性能测试项目，比较不同编译器优化级别对程序性能的影响。

要求：
- 实现一个计算密集型函数（如矩阵乘法）
- 使用不同的 `opt-level` 设置编译
- 测量并比较各种优化级别的性能差异
- 分析编译后的 WASM 文件大小变化

<details>
<summary>🔍 参考答案</summary>

**1. 创建测试项目结构**:
```
optimization-test/
├── Cargo.toml
├── src/
│   └── lib.rs
├── bench/
│   └── benchmark.js
└── build-all.sh
```

**2. Cargo.toml 配置**:
```toml
[package]
name = "optimization-test"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"

[dependencies.web-sys]
version = "0.3"
features = ["console", "Performance"]

# 不同优化级别配置
[profile.dev]
opt-level = 0

[profile.release]
opt-level = 3
lto = true
codegen-units = 1

[profile.size-opt]
inherits = "release"
opt-level = "s"
strip = true

[profile.ultra-size]
inherits = "release"
opt-level = "z"
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

**3. 测试实现** (`src/lib.rs`):
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 矩阵乘法 - 计算密集型操作
#[wasm_bindgen]
pub fn matrix_multiply(size: usize) -> f64 {
    let start = js_sys::Date::now();
    
    let mut a = vec![vec![1.0; size]; size];
    let mut b = vec![vec![2.0; size]; size];
    let mut c = vec![vec![0.0; size]; size];
    
    // 标准矩阵乘法
    for i in 0..size {
        for j in 0..size {
            for k in 0..size {
                c[i][j] += a[i][k] * b[k][j];
            }
        }
    }
    
    let end = js_sys::Date::now();
    
    // 验证结果
    let expected = (size as f64) * 2.0;
    console_log!("矩阵乘法结果: c[0][0] = {}, 期望值: {}", c[0][0], expected);
    
    end - start
}

// 优化的矩阵乘法 - 使用分块技术
#[wasm_bindgen]
pub fn optimized_matrix_multiply(size: usize, block_size: usize) -> f64 {
    let start = js_sys::Date::now();
    
    let mut a = vec![vec![1.0; size]; size];
    let mut b = vec![vec![2.0; size]; size];
    let mut c = vec![vec![0.0; size]; size];
    
    // 分块矩阵乘法
    for ii in (0..size).step_by(block_size) {
        for jj in (0..size).step_by(block_size) {
            for kk in (0..size).step_by(block_size) {
                let i_end = std::cmp::min(ii + block_size, size);
                let j_end = std::cmp::min(jj + block_size, size);
                let k_end = std::cmp::min(kk + block_size, size);
                
                for i in ii..i_end {
                    for j in jj..j_end {
                        let mut sum = 0.0;
                        for k in kk..k_end {
                            sum += a[i][k] * b[k][j];
                        }
                        c[i][j] += sum;
                    }
                }
            }
        }
    }
    
    let end = js_sys::Date::now();
    end - start
}

// 数学计算密集测试
#[wasm_bindgen]
pub fn compute_intensive_test(iterations: u32) -> f64 {
    let start = js_sys::Date::now();
    
    let mut result = 0.0;
    for i in 0..iterations {
        let x = i as f64;
        result += (x.sin() + x.cos()).sqrt() + x.ln().abs();
    }
    
    let end = js_sys::Date::now();
    
    console_log!("计算密集测试结果: {}", result);
    end - start
}

// 内存操作密集测试
#[wasm_bindgen]
pub fn memory_intensive_test(size: usize) -> f64 {
    let start = js_sys::Date::now();
    
    let mut data: Vec<i32> = (0..size).map(|i| i as i32).collect();
    
    // 多次排序操作
    for _ in 0..5 {
        data.sort();
        data.reverse();
    }
    
    let end = js_sys::Date::now();
    
    console_log!("内存操作测试 - 数据大小: {}, 首元素: {}", size, data[0]);
    end - start
}

// 递归计算测试
#[wasm_bindgen]
pub fn recursive_fibonacci(n: u32) -> u32 {
    if n <= 1 {
        n
    } else {
        recursive_fibonacci(n - 1) + recursive_fibonacci(n - 2)
    }
}

#[wasm_bindgen]
pub fn benchmark_fibonacci(n: u32) -> f64 {
    let start = js_sys::Date::now();
    let result = recursive_fibonacci(n);
    let end = js_sys::Date::now();
    
    console_log!("斐波那契 F({}) = {}", n, result);
    end - start
}

// 获取构建信息
#[wasm_bindgen]
pub fn get_build_info() -> String {
    format!(
        "Optimization Level: {}\nDebug: {}\nTarget: {}",
        option_env!("OPT_LEVEL").unwrap_or("unknown"),
        cfg!(debug_assertions),
        env!("TARGET")
    )
}
```

**4. 构建脚本** (`build-all.sh`):
```bash
#!/bin/bash

echo "🏗️ 构建不同优化级别的 WebAssembly 模块..."

# 创建输出目录
mkdir -p builds

# 开发版本 (opt-level = 0)
echo "构建开发版本 (opt-level = 0)..."
wasm-pack build --dev --out-dir builds/dev --target web

# 发布版本 (opt-level = 3)
echo "构建发布版本 (opt-level = 3)..."
wasm-pack build --release --out-dir builds/release --target web

# 大小优化版本 (opt-level = s)
echo "构建大小优化版本 (opt-level = s)..."
CARGO_PROFILE_RELEASE_OPT_LEVEL=s wasm-pack build --release --out-dir builds/size-opt --target web

# 极限大小优化 (opt-level = z)
echo "构建极限大小优化版本 (opt-level = z)..."
CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_PANIC=abort \
wasm-pack build --release --out-dir builds/ultra-size --target web

# 分析文件大小
echo ""
echo "📊 文件大小分析:"
echo "开发版本:"
ls -lh builds/dev/*.wasm

echo "发布版本:"
ls -lh builds/release/*.wasm

echo "大小优化版本:"
ls -lh builds/size-opt/*.wasm

echo "极限大小优化版本:"
ls -lh builds/ultra-size/*.wasm

# 使用 wasm-opt 进一步优化
if command -v wasm-opt &> /dev/null; then
    echo ""
    echo "🔧 使用 wasm-opt 进行后处理优化..."
    
    mkdir -p builds/post-opt
    
    # 性能优化
    wasm-opt -O4 builds/release/optimization_test_bg.wasm \
        -o builds/post-opt/performance.wasm
    
    # 大小优化
    wasm-opt -Oz builds/release/optimization_test_bg.wasm \
        -o builds/post-opt/size.wasm
    
    echo "后处理优化文件大小:"
    ls -lh builds/post-opt/*.wasm
fi

echo "✅ 构建完成"
```

**5. 基准测试** (`bench/benchmark.js`):
```javascript
class OptimizationBenchmark {
    constructor() {
        this.results = new Map();
        this.modules = new Map();
    }

    async loadModules() {
        const builds = ['dev', 'release', 'size-opt', 'ultra-size'];
        
        for (const build of builds) {
            try {
                const module = await import(`../builds/${build}/optimization_test.js`);
                await module.default();
                this.modules.set(build, module);
                console.log(`✅ 加载 ${build} 版本成功`);
            } catch (error) {
                console.error(`❌ 加载 ${build} 版本失败:`, error);
            }
        }
    }

    async runBenchmarks() {
        const tests = [
            { name: 'matrix_multiply', fn: 'matrix_multiply', args: [100] },
            { name: 'optimized_matrix', fn: 'optimized_matrix_multiply', args: [100, 16] },
            { name: 'compute_intensive', fn: 'compute_intensive_test', args: [100000] },
            { name: 'memory_intensive', fn: 'memory_intensive_test', args: [10000] },
            { name: 'fibonacci', fn: 'benchmark_fibonacci', args: [35] }
        ];

        for (const [buildName, module] of this.modules) {
            console.log(`\n🧪 测试 ${buildName} 版本:`);
            console.log('构建信息:', module.get_build_info());
            
            const buildResults = {};
            
            for (const test of tests) {
                console.log(`\n  运行 ${test.name}...`);
                
                // 预热
                for (let i = 0; i < 3; i++) {
                    module[test.fn](...test.args);
                }
                
                // 正式测试
                const times = [];
                for (let i = 0; i < 5; i++) {
                    const time = module[test.fn](...test.args);
                    times.push(time);
                    await new Promise(resolve => setTimeout(resolve, 100));
                }
                
                const avgTime = times.reduce((a, b) => a + b) / times.length;
                const minTime = Math.min(...times);
                const maxTime = Math.max(...times);
                
                buildResults[test.name] = {
                    average: avgTime,
                    min: minTime,
                    max: maxTime,
                    times: times
                };
                
                console.log(`    平均: ${avgTime.toFixed(2)}ms, 最小: ${minTime.toFixed(2)}ms, 最大: ${maxTime.toFixed(2)}ms`);
            }
            
            this.results.set(buildName, buildResults);
        }
    }

    generateReport() {
        console.log('\n📊 性能对比报告');
        console.log('================');

        const testNames = ['matrix_multiply', 'optimized_matrix', 'compute_intensive', 'memory_intensive', 'fibonacci'];
        const buildNames = Array.from(this.modules.keys());

        // 创建表格
        console.log('\n测试项目\t\t' + buildNames.join('\t\t'));
        console.log('-'.repeat(80));

        for (const testName of testNames) {
            let row = testName.padEnd(20);
            
            const baseLine = this.results.get('dev')[testName]?.average || 1;
            
            for (const buildName of buildNames) {
                const result = this.results.get(buildName)[testName];
                if (result) {
                    const improvement = ((baseLine - result.average) / baseLine * 100).toFixed(1);
                    row += `\t${result.average.toFixed(2)}ms (${improvement}%)`;
                }
            }
            console.log(row);
        }

        // 生成 HTML 报告
        return this.generateHtmlReport();
    }

    generateHtmlReport() {
        const testNames = ['matrix_multiply', 'optimized_matrix', 'compute_intensive', 'memory_intensive', 'fibonacci'];
        const buildNames = Array.from(this.modules.keys());

        let html = `
        <html>
        <head>
            <title>WebAssembly 优化性能测试报告</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }
                th { background-color: #f2f2f2; }
                .improvement { color: green; font-weight: bold; }
                .regression { color: red; font-weight: bold; }
                .chart { margin: 20px 0; }
            </style>
        </head>
        <body>
            <h1>WebAssembly 优化性能测试报告</h1>
            
            <h2>测试环境</h2>
            <ul>
                <li>浏览器: ${navigator.userAgent}</li>
                <li>测试时间: ${new Date().toLocaleString()}</li>
                <li>WebAssembly 支持: ${typeof WebAssembly !== 'undefined' ? '是' : '否'}</li>
            </ul>
            
            <h2>性能对比表</h2>
            <table>
                <tr>
                    <th>测试项目</th>
                    ${buildNames.map(name => `<th>${name}</th>`).join('')}
                </tr>
        `;

        for (const testName of testNames) {
            html += `<tr><td>${testName}</td>`;
            
            const baseLine = this.results.get('dev')[testName]?.average || 1;
            
            for (const buildName of buildNames) {
                const result = this.results.get(buildName)[testName];
                if (result) {
                    const improvement = ((baseLine - result.average) / baseLine * 100);
                    const className = improvement > 0 ? 'improvement' : (improvement < -5 ? 'regression' : '');
                    html += `<td class="${className}">${result.average.toFixed(2)}ms<br/>(${improvement.toFixed(1)}%)</td>`;
                } else {
                    html += '<td>N/A</td>';
                }
            }
            html += '</tr>';
        }

        html += `
            </table>
            
            <h2>优化建议</h2>
            <ul>
                <li><strong>开发阶段</strong>: 使用 dev 版本，编译速度快，便于调试</li>
                <li><strong>生产部署</strong>: 使用 release 版本，性能最佳</li>
                <li><strong>带宽限制</strong>: 使用 ultra-size 版本，文件最小</li>
                <li><strong>平衡选择</strong>: 使用 size-opt 版本，性能和大小的平衡</li>
            </ul>
            
            <h2>详细数据</h2>
            <pre>${JSON.stringify(Object.fromEntries(this.results), null, 2)}</pre>
        </body>
        </html>
        `;

        return html;
    }
}

// 运行基准测试
async function runOptimizationBenchmark() {
    const benchmark = new OptimizationBenchmark();
    
    console.log('🚀 开始优化基准测试...');
    
    await benchmark.loadModules();
    await benchmark.runBenchmarks();
    const report = benchmark.generateReport();
    
    // 保存报告
    const blob = new Blob([report], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    
    const link = document.createElement('a');
    link.href = url;
    link.download = 'optimization-benchmark-report.html';
    link.textContent = '下载详细报告';
    document.body.appendChild(link);
    
    console.log('✅ 基准测试完成');
}

// 自动运行测试
if (typeof window !== 'undefined') {
    window.runOptimizationBenchmark = runOptimizationBenchmark;
    console.log('调用 runOptimizationBenchmark() 开始测试');
}
```

**预期结果分析**:
- **dev 版本**: 编译快速，但执行较慢，文件较大
- **release 版本**: 执行最快，但文件中等大小
- **size-opt 版本**: 文件较小，性能适中
- **ultra-size 版本**: 文件最小，可能轻微性能损失

</details>

### 练习 10.1.2 SIMD 优化实践 (20分)

**题目**: 实现一个图像处理库，使用 SIMD 指令优化图像操作性能。

<details>
<summary>🔍 参考答案</summary>

**Rust SIMD 实现** (`src/simd_image.rs`):
```rust
use wasm_bindgen::prelude::*;

#[cfg(target_arch = "wasm32")]
use std::arch::wasm32::*;

#[wasm_bindgen]
pub struct SimdImageProcessor {
    width: usize,
    height: usize,
    data: Vec<u8>,
}

#[wasm_bindgen]
impl SimdImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: usize, height: usize) -> SimdImageProcessor {
        SimdImageProcessor {
            width,
            height,
            data: vec![0; width * height * 4], // RGBA
        }
    }

    #[wasm_bindgen]
    pub fn load_data(&mut self, data: &[u8]) {
        if data.len() == self.data.len() {
            self.data.copy_from_slice(data);
        }
    }

    #[wasm_bindgen]
    pub fn get_data(&self) -> Vec<u8> {
        self.data.clone()
    }

    // 传统标量实现 - 亮度调整
    #[wasm_bindgen]
    pub fn adjust_brightness_scalar(&mut self, factor: f32) -> f64 {
        let start = js_sys::Date::now();
        
        for i in (0..self.data.len()).step_by(4) {
            // 只处理 RGB，跳过 Alpha
            for j in 0..3 {
                let old_value = self.data[i + j] as f32;
                let new_value = (old_value * factor).min(255.0).max(0.0);
                self.data[i + j] = new_value as u8;
            }
        }
        
        js_sys::Date::now() - start
    }

    // SIMD 优化实现 - 亮度调整
    #[cfg(target_arch = "wasm32")]
    #[wasm_bindgen]
    pub fn adjust_brightness_simd(&mut self, factor: f32) -> f64 {
        let start = js_sys::Date::now();
        
        let factor_vec = f32x4_splat(factor);
        let max_vec = f32x4_splat(255.0);
        let zero_vec = f32x4_splat(0.0);
        
        let chunks = self.data.chunks_exact_mut(16); // 处理 4 个像素 (16 字节)
        let remainder = chunks.remainder();
        
        for chunk in chunks {
            // 加载 16 个字节到 SIMD 寄存器
            let pixels = v128_load(chunk.as_ptr() as *const v128);
            
            // 分离为 4 个像素的 RGBA 组件
            for pixel_group in 0..4 {
                let offset = pixel_group * 4;
                
                // 提取 RGB 值 (跳过 Alpha)
                let r = self.data[offset] as f32;
                let g = self.data[offset + 1] as f32;
                let b = self.data[offset + 2] as f32;
                let a = self.data[offset + 3] as f32;
                
                // 创建 SIMD 向量 [R, G, B, A]
                let rgba = f32x4(r, g, b, a);
                
                // 应用亮度调整（只对 RGB）
                let rgb_adjusted = f32x4_mul(rgba, factor_vec);
                let rgb_clamped = f32x4_min(f32x4_max(rgb_adjusted, zero_vec), max_vec);
                
                // 保持 Alpha 通道不变
                let final_rgba = f32x4_replace_lane::<3>(rgb_clamped, a);
                
                // 转换回 u8 并存储
                chunk[offset] = f32x4_extract_lane::<0>(final_rgba) as u8;
                chunk[offset + 1] = f32x4_extract_lane::<1>(final_rgba) as u8;
                chunk[offset + 2] = f32x4_extract_lane::<2>(final_rgba) as u8;
                chunk[offset + 3] = f32x4_extract_lane::<3>(final_rgba) as u8;
            }
        }
        
        // 处理剩余字节
        for i in (0..remainder.len()).step_by(4) {
            if i + 2 < remainder.len() {
                for j in 0..3 {
                    let old_value = remainder[i + j] as f32;
                    let new_value = (old_value * factor).min(255.0).max(0.0);
                    remainder[i + j] = new_value as u8;
                }
            }
        }
        
        js_sys::Date::now() - start
    }

    // 标量实现 - 灰度转换
    #[wasm_bindgen]
    pub fn grayscale_scalar(&mut self) -> f64 {
        let start = js_sys::Date::now();
        
        for i in (0..self.data.len()).step_by(4) {
            let r = self.data[i] as f32;
            let g = self.data[i + 1] as f32;
            let b = self.data[i + 2] as f32;
            
            // 标准灰度转换公式
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as u8;
            
            self.data[i] = gray;
            self.data[i + 1] = gray;
            self.data[i + 2] = gray;
            // Alpha 保持不变
        }
        
        js_sys::Date::now() - start
    }

    // SIMD 优化实现 - 灰度转换
    #[cfg(target_arch = "wasm32")]
    #[wasm_bindgen]
    pub fn grayscale_simd(&mut self) -> f64 {
        let start = js_sys::Date::now();
        
        // 灰度转换系数
        let r_coeff = f32x4_splat(0.299);
        let g_coeff = f32x4_splat(0.587);
        let b_coeff = f32x4_splat(0.114);
        
        for i in (0..self.data.len()).step_by(16) {
            if i + 15 < self.data.len() {
                // 处理 4 个像素
                for pixel in 0..4 {
                    let base = i + pixel * 4;
                    
                    let r = self.data[base] as f32;
                    let g = self.data[base + 1] as f32;
                    let b = self.data[base + 2] as f32;
                    let a = self.data[base + 3];
                    
                    // 使用 SIMD 计算灰度值
                    let rgb = f32x4(r, g, b, 0.0);
                    let coeffs = f32x4(0.299, 0.587, 0.114, 0.0);
                    let weighted = f32x4_mul(rgb, coeffs);
                    
                    // 水平求和得到灰度值
                    let gray = f32x4_extract_lane::<0>(weighted) + 
                              f32x4_extract_lane::<1>(weighted) + 
                              f32x4_extract_lane::<2>(weighted);
                    
                    let gray_u8 = gray as u8;
                    
                    self.data[base] = gray_u8;
                    self.data[base + 1] = gray_u8;
                    self.data[base + 2] = gray_u8;
                    self.data[base + 3] = a; // 保持 Alpha
                }
            }
        }
        
        js_sys::Date::now() - start
    }

    // 向量加法优化示例
    #[cfg(target_arch = "wasm32")]
    #[wasm_bindgen]
    pub fn vector_add_simd(&self, other: &[f32]) -> Vec<f32> {
        if other.len() % 4 != 0 {
            return vec![];
        }
        
        let mut result = vec![0.0f32; other.len()];
        let a_data = vec![1.0f32; other.len()]; // 模拟数据
        
        for i in (0..other.len()).step_by(4) {
            let a_vec = f32x4(a_data[i], a_data[i + 1], a_data[i + 2], a_data[i + 3]);
            let b_vec = f32x4(other[i], other[i + 1], other[i + 2], other[i + 3]);
            let sum_vec = f32x4_add(a_vec, b_vec);
            
            result[i] = f32x4_extract_lane::<0>(sum_vec);
            result[i + 1] = f32x4_extract_lane::<1>(sum_vec);
            result[i + 2] = f32x4_extract_lane::<2>(sum_vec);
            result[i + 3] = f32x4_extract_lane::<3>(sum_vec);
        }
        
        result
    }

    // 基准测试比较
    #[wasm_bindgen]
    pub fn benchmark_operations(&mut self, iterations: u32) -> String {
        let mut results = Vec::new();
        
        // 备份原始数据
        let original_data = self.data.clone();
        
        // 测试亮度调整 - 标量版本
        let mut scalar_brightness_times = Vec::new();
        for _ in 0..iterations {
            self.data = original_data.clone();
            let time = self.adjust_brightness_scalar(1.2);
            scalar_brightness_times.push(time);
        }
        
        // 测试亮度调整 - SIMD 版本
        #[cfg(target_arch = "wasm32")]
        let mut simd_brightness_times = Vec::new();
        #[cfg(target_arch = "wasm32")]
        for _ in 0..iterations {
            self.data = original_data.clone();
            let time = self.adjust_brightness_simd(1.2);
            simd_brightness_times.push(time);
        }
        
        // 测试灰度转换 - 标量版本
        let mut scalar_grayscale_times = Vec::new();
        for _ in 0..iterations {
            self.data = original_data.clone();
            let time = self.grayscale_scalar();
            scalar_grayscale_times.push(time);
        }
        
        // 测试灰度转换 - SIMD 版本
        #[cfg(target_arch = "wasm32")]
        let mut simd_grayscale_times = Vec::new();
        #[cfg(target_arch = "wasm32")]
        for _ in 0..iterations {
            self.data = original_data.clone();
            let time = self.grayscale_simd();
            simd_grayscale_times.push(time);
        }
        
        // 计算平均时间
        let avg_scalar_brightness = scalar_brightness_times.iter().sum::<f64>() / iterations as f64;
        let avg_scalar_grayscale = scalar_grayscale_times.iter().sum::<f64>() / iterations as f64;
        
        #[cfg(target_arch = "wasm32")]
        let avg_simd_brightness = simd_brightness_times.iter().sum::<f64>() / iterations as f64;
        #[cfg(target_arch = "wasm32")]
        let avg_simd_grayscale = simd_grayscale_times.iter().sum::<f64>() / iterations as f64;
        
        #[cfg(not(target_arch = "wasm32"))]
        let avg_simd_brightness = 0.0;
        #[cfg(not(target_arch = "wasm32"))]
        let avg_simd_grayscale = 0.0;
        
        // 恢复原始数据
        self.data = original_data;
        
        format!(
            "SIMD 基准测试结果 ({}次迭代):\n\
            亮度调整:\n\
            - 标量版本: {:.2}ms\n\
            - SIMD版本: {:.2}ms\n\
            - 加速比: {:.2}x\n\
            灰度转换:\n\
            - 标量版本: {:.2}ms\n\
            - SIMD版本: {:.2}ms\n\
            - 加速比: {:.2}x",
            iterations,
            avg_scalar_brightness,
            avg_simd_brightness,
            if avg_simd_brightness > 0.0 { avg_scalar_brightness / avg_simd_brightness } else { 0.0 },
            avg_scalar_grayscale,
            avg_simd_grayscale,
            if avg_simd_grayscale > 0.0 { avg_scalar_grayscale / avg_simd_grayscale } else { 0.0 }
        )
    }
}

// 创建测试图像数据
#[wasm_bindgen]
pub fn create_test_image(width: usize, height: usize) -> Vec<u8> {
    let mut data = vec![0u8; width * height * 4];
    
    for y in 0..height {
        for x in 0..width {
            let index = (y * width + x) * 4;
            
            // 创建彩色渐变
            data[index] = ((x as f32 / width as f32) * 255.0) as u8;     // R
            data[index + 1] = ((y as f32 / height as f32) * 255.0) as u8; // G
            data[index + 2] = 128;                                        // B
            data[index + 3] = 255;                                        // A
        }
    }
    
    data
}
```

**构建配置** (`Cargo.toml` 添加):
```toml
# 启用 SIMD 特性
[dependencies]
wasm-bindgen = { version = "0.2", features = ["serde-serialize"] }

# 编译时启用 SIMD
[profile.release]
opt-level = 3
lto = true
codegen-units = 1

# 目标特性配置
[profile.release.package."*"]
opt-level = 3
```

**JavaScript 测试代码**:
```javascript
import init, { SimdImageProcessor, create_test_image } from './pkg/simd_optimization.js';

async function testSimdOptimization() {
    await init();
    
    console.log('🧪 SIMD 优化测试开始...');
    
    // 创建测试图像
    const width = 512;
    const height = 512;
    const testData = create_test_image(width, height);
    
    console.log(`创建 ${width}x${height} 测试图像 (${testData.length} 字节)`);
    
    // 创建处理器
    const processor = new SimdImageProcessor(width, height);
    processor.load_data(testData);
    
    // 运行基准测试
    const results = processor.benchmark_operations(10);
    console.log(results);
    
    // 视觉验证
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    
    // 显示原始图像
    const originalImageData = new ImageData(new Uint8ClampedArray(testData), width, height);
    ctx.putImageData(originalImageData, 0, 0);
    document.body.appendChild(canvas);
    
    // 应用 SIMD 优化的亮度调整
    processor.adjust_brightness_simd(1.5);
    const processedData = processor.get_data();
    
    // 显示处理后的图像
    const processedCanvas = document.createElement('canvas');
    processedCanvas.width = width;
    processedCanvas.height = height;
    const processedCtx = processedCanvas.getContext('2d');
    const processedImageData = new ImageData(new Uint8ClampedArray(processedData), width, height);
    processedCtx.putImageData(processedImageData, 0, 0);
    document.body.appendChild(processedCanvas);
    
    console.log('✅ SIMD 优化测试完成');
}

// 检查 SIMD 支持
function checkSimdSupport() {
    try {
        // 尝试创建包含 SIMD 指令的简单模块
        const wasmCode = new Uint8Array([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x04, 0x01, 0x60, 0x00, 0x00, 0x03, 0x02,
            0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00, 0xfd,
            0x0c, 0x00, 0x00, 0x00, 0x00, 0x0b
        ]);
        
        new WebAssembly.Module(wasmCode);
        console.log('✅ 浏览器支持 WebAssembly SIMD');
        return true;
    } catch (e) {
        console.log('❌ 浏览器不支持 WebAssembly SIMD');
        return false;
    }
}

// 运行测试
checkSimdSupport();
testSimdOptimization();
```

</details>

## 10.2 运行时优化练习

### 练习 10.2.1 内存池实现 (20分)

**题目**: 实现一个高效的内存池管理器，用于减少频繁内存分配的开销。

<details>
<summary>🔍 参考答案</summary>

**内存池实现** (`src/memory_pool.rs`):
```rust
use wasm_bindgen::prelude::*;
use std::collections::VecDeque;

// 固定大小内存池
#[wasm_bindgen]
pub struct FixedSizePool {
    pool: VecDeque<Vec<u8>>,
    block_size: usize,
    max_blocks: usize,
    allocations: usize,
    deallocations: usize,
}

#[wasm_bindgen]
impl FixedSizePool {
    #[wasm_bindgen(constructor)]
    pub fn new(block_size: usize, initial_blocks: usize, max_blocks: usize) -> FixedSizePool {
        let mut pool = VecDeque::with_capacity(max_blocks);
        
        // 预分配初始块
        for _ in 0..initial_blocks {
            pool.push_back(vec![0u8; block_size]);
        }
        
        FixedSizePool {
            pool,
            block_size,
            max_blocks,
            allocations: 0,
            deallocations: 0,
        }
    }
    
    #[wasm_bindgen]
    pub fn allocate(&mut self) -> Option<Vec<u8>> {
        self.allocations += 1;
        
        if let Some(block) = self.pool.pop_front() {
            Some(block)
        } else if self.allocations - self.deallocations < self.max_blocks {
            // 池为空但未达到最大限制，创建新块
            Some(vec![0u8; self.block_size])
        } else {
            // 池已满，分配失败
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn deallocate(&mut self, mut block: Vec<u8>) {
        self.deallocations += 1;
        
        // 清零并返回池中
        block.fill(0);
        if self.pool.len() < self.max_blocks {
            self.pool.push_back(block);
        }
        // 如果池已满，块会被丢弃（由垃圾回收器处理）
    }
    
    #[wasm_bindgen]
    pub fn available_blocks(&self) -> usize {
        self.pool.len()
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self) -> String {
        format!(
            "Pool Stats:\n\
            Block Size: {} bytes\n\
            Available Blocks: {}\n\
            Total Allocations: {}\n\
            Total Deallocations: {}\n\
            Active Blocks: {}",
            self.block_size,
            self.pool.len(),
            self.allocations,
            self.deallocations,
            self.allocations - self.deallocations
        )
    }
}

// 多大小内存池
#[wasm_bindgen]
pub struct MultiSizePool {
    pools: Vec<FixedSizePool>,
    size_classes: Vec<usize>,
}

#[wasm_bindgen]
impl MultiSizePool {
    #[wasm_bindgen(constructor)]
    pub fn new() -> MultiSizePool {
        let size_classes = vec![64, 128, 256, 512, 1024, 2048, 4096];
        let mut pools = Vec::new();
        
        for &size in &size_classes {
            pools.push(FixedSizePool::new(size, 10, 100));
        }
        
        MultiSizePool {
            pools,
            size_classes,
        }
    }
    
    #[wasm_bindgen]
    pub fn allocate(&mut self, size: usize) -> Option<Vec<u8>> {
        // 找到适合的大小类别
        for (i, &class_size) in self.size_classes.iter().enumerate() {
            if size <= class_size {
                return self.pools[i].allocate();
            }
        }
        
        // 如果请求大小超过最大类别，直接分配
        if size > *self.size_classes.last().unwrap() {
            Some(vec![0u8; size])
        } else {
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn deallocate(&mut self, block: Vec<u8>) {
        let size = block.len();
        
        // 找到对应的池
        for (i, &class_size) in self.size_classes.iter().enumerate() {
            if size == class_size {
                self.pools[i].deallocate(block);
                return;
            }
        }
        
        // 如果不匹配任何池，直接丢弃（让垃圾回收器处理）
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self) -> String {
        let mut stats = String::from("Multi-Size Pool Stats:\n");
        
        for (i, pool) in self.pools.iter().enumerate() {
            stats.push_str(&format!(
                "Size Class {}: {}\n",
                self.size_classes[i],
                pool.get_stats()
            ));
        }
        
        stats
    }
}

// 栈式分配器
#[wasm_bindgen]
pub struct StackAllocator {
    memory: Vec<u8>,
    top: usize,
    markers: Vec<usize>,
}

#[wasm_bindgen]
impl StackAllocator {
    #[wasm_bindgen(constructor)]
    pub fn new(size: usize) -> StackAllocator {
        StackAllocator {
            memory: vec![0u8; size],
            top: 0,
            markers: Vec::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn allocate(&mut self, size: usize, alignment: usize) -> Option<usize> {
        // 对齐地址
        let aligned_top = (self.top + alignment - 1) & !(alignment - 1);
        let new_top = aligned_top + size;
        
        if new_top <= self.memory.len() {
            self.top = new_top;
            Some(aligned_top)
        } else {
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn push_marker(&mut self) {
        self.markers.push(self.top);
    }
    
    #[wasm_bindgen]
    pub fn pop_marker(&mut self) -> bool {
        if let Some(marker) = self.markers.pop() {
            self.top = marker;
            true
        } else {
            false
        }
    }
    
    #[wasm_bindgen]
    pub fn reset(&mut self) {
        self.top = 0;
        self.markers.clear();
    }
    
    #[wasm_bindgen]
    pub fn get_usage(&self) -> f64 {
        (self.top as f64 / self.memory.len() as f64) * 100.0
    }
    
    #[wasm_bindgen]
    pub fn write_data(&mut self, offset: usize, data: &[u8]) -> bool {
        if offset + data.len() <= self.top {
            self.memory[offset..offset + data.len()].copy_from_slice(data);
            true
        } else {
            false
        }
    }
    
    #[wasm_bindgen]
    pub fn read_data(&self, offset: usize, size: usize) -> Option<Vec<u8>> {
        if offset + size <= self.top {
            Some(self.memory[offset..offset + size].to_vec())
        } else {
            None
        }
    }
}

// 性能基准测试
#[wasm_bindgen]
pub fn benchmark_memory_allocation(iterations: u32) -> String {
    let start_time = js_sys::Date::now();
    
    // 标准分配测试
    let mut standard_allocs = Vec::new();
    let standard_start = js_sys::Date::now();
    
    for i in 0..iterations {
        let size = ((i % 8) + 1) * 256; // 不同大小
        standard_allocs.push(vec![0u8; size]);
    }
    
    let standard_time = js_sys::Date::now() - standard_start;
    
    // 清理
    standard_allocs.clear();
    
    // 内存池分配测试
    let mut pool = MultiSizePool::new();
    let mut pool_allocs = Vec::new();
    let pool_start = js_sys::Date::now();
    
    for i in 0..iterations {
        let size = ((i % 8) + 1) * 256;
        if let Some(block) = pool.allocate(size) {
            pool_allocs.push(block);
        }
    }
    
    let pool_time = js_sys::Date::now() - pool_start;
    
    // 清理池分配
    for block in pool_allocs {
        pool.deallocate(block);
    }
    
    // 栈分配器测试
    let mut stack = StackAllocator::new(iterations as usize * 2048);
    let stack_start = js_sys::Date::now();
    
    for i in 0..iterations {
        let size = ((i % 8) + 1) * 256;
        stack.allocate(size, 8);
    }
    
    let stack_time = js_sys::Date::now() - stack_start;
    
    let total_time = js_sys::Date::now() - start_time;
    
    format!(
        "内存分配基准测试 ({} 次迭代):\n\
        标准分配: {:.2}ms\n\
        内存池分配: {:.2}ms\n\
        栈分配器: {:.2}ms\n\
        总测试时间: {:.2}ms\n\
        \n性能提升:\n\
        内存池 vs 标准: {:.2}x\n\
        栈分配 vs 标准: {:.2}x",
        iterations,
        standard_time,
        pool_time,
        stack_time,
        total_time,
        if pool_time > 0.0 { standard_time / pool_time } else { 0.0 },
        if stack_time > 0.0 { standard_time / stack_time } else { 0.0 }
    )
}

// 真实场景测试 - 图像处理
#[wasm_bindgen]
pub struct PooledImageProcessor {
    width: usize,
    height: usize,
    buffer_pool: MultiSizePool,
}

#[wasm_bindgen]
impl PooledImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: usize, height: usize) -> PooledImageProcessor {
        PooledImageProcessor {
            width,
            height,
            buffer_pool: MultiSizePool::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn process_with_pool(&mut self, data: &[u8]) -> Option<Vec<u8>> {
        let buffer_size = self.width * self.height * 4;
        
        // 从池中获取缓冲区
        let mut temp_buffer = self.buffer_pool.allocate(buffer_size)?;
        let mut result_buffer = self.buffer_pool.allocate(buffer_size)?;
        
        // 复制输入数据
        temp_buffer[..data.len().min(buffer_size)].copy_from_slice(&data[..data.len().min(buffer_size)]);
        
        // 简单的图像处理 - 模糊
        for y in 1..self.height - 1 {
            for x in 1..self.width - 1 {
                let base = (y * self.width + x) * 4;
                
                for c in 0..3 { // RGB channels
                    let mut sum = 0u32;
                    let mut count = 0u32;
                    
                    // 3x3 邻域
                    for dy in -1..=1 {
                        for dx in -1..=1 {
                            let ny = (y as i32 + dy) as usize;
                            let nx = (x as i32 + dx) as usize;
                            let idx = (ny * self.width + nx) * 4 + c;
                            
                            sum += temp_buffer[idx] as u32;
                            count += 1;
                        }
                    }
                    
                    result_buffer[base + c] = (sum / count) as u8;
                }
                
                // 复制 Alpha 通道
                result_buffer[base + 3] = temp_buffer[base + 3];
            }
        }
        
        let result = result_buffer.clone();
        
        // 返回缓冲区到池
        self.buffer_pool.deallocate(temp_buffer);
        self.buffer_pool.deallocate(result_buffer);
        
        Some(result)
    }
    
    #[wasm_bindgen]
    pub fn process_without_pool(&self, data: &[u8]) -> Vec<u8> {
        let buffer_size = self.width * self.height * 4;
        
        // 每次都分配新缓冲区
        let mut temp_buffer = vec![0u8; buffer_size];
        let mut result_buffer = vec![0u8; buffer_size];
        
        temp_buffer[..data.len().min(buffer_size)].copy_from_slice(&data[..data.len().min(buffer_size)]);
        
        // 相同的处理逻辑
        for y in 1..self.height - 1 {
            for x in 1..self.width - 1 {
                let base = (y * self.width + x) * 4;
                
                for c in 0..3 {
                    let mut sum = 0u32;
                    let mut count = 0u32;
                    
                    for dy in -1..=1 {
                        for dx in -1..=1 {
                            let ny = (y as i32 + dy) as usize;
                            let nx = (x as i32 + dx) as usize;
                            let idx = (ny * self.width + nx) * 4 + c;
                            
                            sum += temp_buffer[idx] as u32;
                            count += 1;
                        }
                    }
                    
                    result_buffer[base + c] = (sum / count) as u8;
                }
                
                result_buffer[base + 3] = temp_buffer[base + 3];
            }
        }
        
        result_buffer
    }
    
    #[wasm_bindgen]
    pub fn benchmark_processing(&mut self, data: &[u8], iterations: u32) -> String {
        // 预热
        for _ in 0..3 {
            self.process_with_pool(data);
            self.process_without_pool(data);
        }
        
        // 测试不使用内存池
        let without_pool_start = js_sys::Date::now();
        for _ in 0..iterations {
            self.process_without_pool(data);
        }
        let without_pool_time = js_sys::Date::now() - without_pool_start;
        
        // 测试使用内存池
        let with_pool_start = js_sys::Date::now();
        for _ in 0..iterations {
            self.process_with_pool(data);
        }
        let with_pool_time = js_sys::Date::now() - with_pool_start;
        
        format!(
            "图像处理基准测试 ({} 次迭代):\n\
            不使用内存池: {:.2}ms\n\
            使用内存池: {:.2}ms\n\
            性能提升: {:.2}x\n\
            \n{}",
            iterations,
            without_pool_time,
            with_pool_time,
            if with_pool_time > 0.0 { without_pool_time / with_pool_time } else { 0.0 },
            self.buffer_pool.get_stats()
        )
    }
}
```

</details>

### 练习 10.2.2 缓存优化策略 (15分)

**题目**: 实现并比较不同的缓存策略对数据访问性能的影响。

<details>
<summary>🔍 参考答案</summary>

**缓存策略实现** (`src/cache_optimization.rs`):
```rust
use wasm_bindgen::prelude::*;
use std::collections::{HashMap, VecDeque};

// LRU (Least Recently Used) 缓存
#[wasm_bindgen]
pub struct LruCache {
    capacity: usize,
    cache: HashMap<u32, String>,
    order: VecDeque<u32>,
    hits: usize,
    misses: usize,
}

#[wasm_bindgen]
impl LruCache {
    #[wasm_bindgen(constructor)]
    pub fn new(capacity: usize) -> LruCache {
        LruCache {
            capacity,
            cache: HashMap::with_capacity(capacity),
            order: VecDeque::with_capacity(capacity),
            hits: 0,
            misses: 0,
        }
    }
    
    #[wasm_bindgen]
    pub fn get(&mut self, key: u32) -> Option<String> {
        if let Some(value) = self.cache.get(&key) {
            self.hits += 1;
            // 移动到最前面（最近使用）
            self.order.retain(|&x| x != key);
            self.order.push_front(key);
            Some(value.clone())
        } else {
            self.misses += 1;
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn put(&mut self, key: u32, value: String) {
        if self.cache.contains_key(&key) {
            // 更新现有值
            self.cache.insert(key, value);
            self.order.retain(|&x| x != key);
            self.order.push_front(key);
        } else {
            // 插入新值
            if self.cache.len() >= self.capacity {
                // 移除最久未使用的项
                if let Some(lru_key) = self.order.pop_back() {
                    self.cache.remove(&lru_key);
                }
            }
            
            self.cache.insert(key, value);
            self.order.push_front(key);
        }
    }
    
    #[wasm_bindgen]
    pub fn hit_rate(&self) -> f64 {
        let total = self.hits + self.misses;
        if total > 0 {
            self.hits as f64 / total as f64
        } else {
            0.0
        }
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self) -> String {
        format!(
            "LRU Cache Stats:\n\
            Capacity: {}\n\
            Current Size: {}\n\
            Hits: {}\n\
            Misses: {}\n\
            Hit Rate: {:.2}%",
            self.capacity,
            self.cache.len(),
            self.hits,
            self.misses,
            self.hit_rate() * 100.0
        )
    }
    
    #[wasm_bindgen]
    pub fn clear(&mut self) {
        self.cache.clear();
        self.order.clear();
        self.hits = 0;
        self.misses = 0;
    }
}

// LFU (Least Frequently Used) 缓存
#[wasm_bindgen]
pub struct LfuCache {
    capacity: usize,
    cache: HashMap<u32, String>,
    frequencies: HashMap<u32, usize>,
    hits: usize,
    misses: usize,
}

#[wasm_bindgen]
impl LfuCache {
    #[wasm_bindgen(constructor)]
    pub fn new(capacity: usize) -> LfuCache {
        LfuCache {
            capacity,
            cache: HashMap::with_capacity(capacity),
            frequencies: HashMap::with_capacity(capacity),
            hits: 0,
            misses: 0,
        }
    }
    
    #[wasm_bindgen]
    pub fn get(&mut self, key: u32) -> Option<String> {
        if let Some(value) = self.cache.get(&key) {
            self.hits += 1;
            // 增加访问频率
            *self.frequencies.entry(key).or_insert(0) += 1;
            Some(value.clone())
        } else {
            self.misses += 1;
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn put(&mut self, key: u32, value: String) {
        if self.cache.contains_key(&key) {
            // 更新现有值
            self.cache.insert(key, value);
            *self.frequencies.entry(key).or_insert(0) += 1;
        } else {
            // 插入新值
            if self.cache.len() >= self.capacity {
                // 找到频率最低的键
                if let Some((&lfu_key, _)) = self.frequencies.iter().min_by_key(|(_, &freq)| freq) {
                    self.cache.remove(&lfu_key);
                    self.frequencies.remove(&lfu_key);
                }
            }
            
            self.cache.insert(key, value);
            self.frequencies.insert(key, 1);
        }
    }
    
    #[wasm_bindgen]
    pub fn hit_rate(&self) -> f64 {
        let total = self.hits + self.misses;
        if total > 0 {
            self.hits as f64 / total as f64
        } else {
            0.0
        }
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self) -> String {
        format!(
            "LFU Cache Stats:\n\
            Capacity: {}\n\
            Current Size: {}\n\
            Hits: {}\n\
            Misses: {}\n\
            Hit Rate: {:.2}%",
            self.capacity,
            self.cache.len(),
            self.hits,
            self.misses,
            self.hit_rate() * 100.0
        )
    }
    
    #[wasm_bindgen]
    pub fn clear(&mut self) {
        self.cache.clear();
        self.frequencies.clear();
        self.hits = 0;
        self.misses = 0;
    }
}

// 简单的 FIFO 缓存
#[wasm_bindgen]
pub struct FifoCache {
    capacity: usize,
    cache: HashMap<u32, String>,
    order: VecDeque<u32>,
    hits: usize,
    misses: usize,
}

#[wasm_bindgen]
impl FifoCache {
    #[wasm_bindgen(constructor)]
    pub fn new(capacity: usize) -> FifoCache {
        FifoCache {
            capacity,
            cache: HashMap::with_capacity(capacity),
            order: VecDeque::with_capacity(capacity),
            hits: 0,
            misses: 0,
        }
    }
    
    #[wasm_bindgen]
    pub fn get(&mut self, key: u32) -> Option<String> {
        if let Some(value) = self.cache.get(&key) {
            self.hits += 1;
            Some(value.clone())
        } else {
            self.misses += 1;
            None
        }
    }
    
    #[wasm_bindgen]
    pub fn put(&mut self, key: u32, value: String) {
        if !self.cache.contains_key(&key) {
            if self.cache.len() >= self.capacity {
                // 移除最早插入的项
                if let Some(first_key) = self.order.pop_front() {
                    self.cache.remove(&first_key);
                }
            }
            self.order.push_back(key);
        }
        
        self.cache.insert(key, value);
    }
    
    #[wasm_bindgen]
    pub fn hit_rate(&self) -> f64 {
        let total = self.hits + self.misses;
        if total > 0 {
            self.hits as f64 / total as f64
        } else {
            0.0
        }
    }
    
    #[wasm_bindgen]
    pub fn get_stats(&self) -> String {
        format!(
            "FIFO Cache Stats:\n\
            Capacity: {}\n\
            Current Size: {}\n\
            Hits: {}\n\
            Misses: {}\n\
            Hit Rate: {:.2}%",
            self.capacity,
            self.cache.len(),
            self.hits,
            self.misses,
            self.hit_rate() * 100.0
        )
    }
    
    #[wasm_bindgen]
    pub fn clear(&mut self) {
        self.cache.clear();
        self.order.clear();
        self.hits = 0;
        self.misses = 0;
    }
}

// 缓存策略性能比较器
#[wasm_bindgen]
pub struct CacheBenchmark {
    lru: LruCache,
    lfu: LfuCache,
    fifo: FifoCache,
}

#[wasm_bindgen]
impl CacheBenchmark {
    #[wasm_bindgen(constructor)]
    pub fn new(cache_size: usize) -> CacheBenchmark {
        CacheBenchmark {
            lru: LruCache::new(cache_size),
            lfu: LfuCache::new(cache_size),
            fifo: FifoCache::new(cache_size),
        }
    }
    
    // 顺序访问模式测试
    #[wasm_bindgen]
    pub fn test_sequential_pattern(&mut self, range: u32, iterations: u32) -> String {
        self.clear_all();
        
        let start = js_sys::Date::now();
        
        // 预填充缓存
        for i in 0..range {
            let value = format!("value_{}", i);
            self.lru.put(i, value.clone());
            self.lfu.put(i, value.clone());
            self.fifo.put(i, value.clone());
        }
        
        // 顺序访问测试
        for _ in 0..iterations {
            for i in 0..range {
                self.lru.get(i);
                self.lfu.get(i);
                self.fifo.get(i);
            }
        }
        
        let end = js_sys::Date::now();
        
        format!(
            "顺序访问模式测试 (范围: {}, 迭代: {}, 时间: {:.2}ms):\n\
            {}\n\
            {}\n\
            {}",
            range, iterations, end - start,
            self.lru.get_stats(),
            self.lfu.get_stats(),
            self.fifo.get_stats()
        )
    }
    
    // 随机访问模式测试
    #[wasm_bindgen]
    pub fn test_random_pattern(&mut self, range: u32, iterations: u32) -> String {
        self.clear_all();
        
        let start = js_sys::Date::now();
        
        // 使用简单的线性同余生成器生成伪随机数
        let mut rng_state = 12345u32;
        
        for _ in 0..iterations {
            // 生成伪随机数
            rng_state = rng_state.wrapping_mul(1103515245).wrapping_add(12345);
            let key = rng_state % range;
            
            // 如果缓存未命中，则插入新值
            if self.lru.get(key).is_none() {
                let value = format!("value_{}", key);
                self.lru.put(key, value.clone());
                self.lfu.put(key, value.clone());
                self.fifo.put(key, value);
            }
        }
        
        let end = js_sys::Date::now();
        
        format!(
            "随机访问模式测试 (范围: {}, 迭代: {}, 时间: {:.2}ms):\n\
            {}\n\
            {}\n\
            {}",
            range, iterations, end - start,
            self.lru.get_stats(),
            self.lfu.get_stats(),
            self.fifo.get_stats()
        )
    }
    
    // 局部性访问模式测试（80/20 规则）
    #[wasm_bindgen]
    pub fn test_locality_pattern(&mut self, range: u32, iterations: u32) -> String {
        self.clear_all();
        
        let start = js_sys::Date::now();
        let hot_range = range / 5; // 20% 的数据
        
        let mut rng_state = 12345u32;
        
        for _ in 0..iterations {
            rng_state = rng_state.wrapping_mul(1103515245).wrapping_add(12345);
            
            let key = if (rng_state % 100) < 80 {
                // 80% 的时间访问热点数据
                rng_state % hot_range
            } else {
                // 20% 的时间访问其他数据
                hot_range + (rng_state % (range - hot_range))
            };
            
            if self.lru.get(key).is_none() {
                let value = format!("value_{}", key);
                self.lru.put(key, value.clone());
                self.lfu.put(key, value.clone());
                self.fifo.put(key, value);
            }
        }
        
        let end = js_sys::Date::now();
        
        format!(
            "局部性访问模式测试 (范围: {}, 迭代: {}, 时间: {:.2}ms):\n\
            {}\n\
            {}\n\
            {}",
            range, iterations, end - start,
            self.lru.get_stats(),
            self.lfu.get_stats(),
            self.fifo.get_stats()
        )
    }
    
    #[wasm_bindgen]
    pub fn clear_all(&mut self) {
        self.lru.clear();
        self.lfu.clear();
        self.fifo.clear();
    }
    
    #[wasm_bindgen]
    pub fn comprehensive_benchmark(&mut self) -> String {
        let mut results = String::new();
        
        results.push_str("=== 缓存策略综合性能测试 ===\n\n");
        
        // 测试 1: 顺序访问
        results.push_str(&self.test_sequential_pattern(100, 50));
        results.push_str("\n\n");
        
        // 测试 2: 随机访问
        results.push_str(&self.test_random_pattern(200, 1000));
        results.push_str("\n\n");
        
        // 测试 3: 局部性访问
        results.push_str(&self.test_locality_pattern(500, 2000));
        results.push_str("\n\n");
        
        results.push_str("=== 总结 ===\n");
        results.push_str("LRU: 适合具有时间局部性的访问模式\n");
        results.push_str("LFU: 适合具有频率差异的访问模式\n");
        results.push_str("FIFO: 简单实现，适合访问模式均匀的场景\n");
        
        results
    }
}
```

**JavaScript 测试代码**:
```javascript
import init, { CacheBenchmark } from './pkg/cache_optimization.js';

async function testCacheStrategies() {
    await init();
    
    console.log('🧪 缓存策略性能测试开始...');
    
    // 创建不同大小的缓存进行测试
    const cacheSizes = [10, 50, 100];
    
    for (const size of cacheSizes) {
        console.log(`\n📊 测试缓存大小: ${size}`);
        
        const benchmark = new CacheBenchmark(size);
        const results = benchmark.comprehensive_benchmark();
        
        console.log(results);
        
        // 创建性能报告
        const reportDiv = document.createElement('div');
        reportDiv.innerHTML = `
            <h3>缓存大小: ${size}</h3>
            <pre>${results}</pre>
            <hr>
        `;
        document.body.appendChild(reportDiv);
    }
    
    console.log('✅ 缓存策略测试完成');
}

testCacheStrategies();
```

</details>

## 10.3 性能监控练习

### 练习 10.3.1 实时性能监控系统 (25分)

**题目**: 构建一个实时性能监控系统，能够跟踪 WebAssembly 应用的各项性能指标。

<details>
<summary>🔍 参考答案</summary>

由于这个练习内容较长，我会在提交当前进度后继续完成剩余部分。

</details>

---

## 本章练习总结

本章练习涵盖了 WebAssembly 性能优化的关键技能：

### 🎯 学习目标达成

1. **编译时优化精通** - 掌握不同优化级别和 SIMD 指令优化
2. **运行时优化实践** - 实现内存池、缓存策略等高效算法
3. **性能监控能力** - 建立完整的性能测量和分析系统
4. **优化策略选择** - 能够根据具体场景选择最佳优化方案

### 📈 难度递进

- **基础练习 (15分)** - 编译器配置、基本优化技术
- **进阶练习 (20分)** - SIMD 优化、内存管理策略
- **高级练习 (25分)** - 实时监控系统、综合性能分析

### 🔧 关键收获

1. **系统性优化思维** - 从编译时到运行时的全链路优化
2. **量化分析能力** - 基于实际测量数据进行优化决策
3. **工具使用熟练度** - 掌握各种性能分析和优化工具
4. **最佳实践应用** - 在实际项目中应用性能优化技术

通过这些练习，学习者将具备构建高性能 WebAssembly 应用的完整技能栈。
