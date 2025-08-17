# 第9章 练习题

## 9.1 Rust 环境搭建练习

### 练习 9.1.1 工具链配置验证 (10分)

**题目**: 验证 Rust WebAssembly 开发环境是否正确配置，创建一个简单的诊断工具。

要求：
- 检查 `wasm-pack` 版本
- 验证 `wasm32-unknown-unknown` 目标是否安装
- 创建并编译一个最小的 Rust WASM 项目
- 输出详细的环境信息

<details>
<summary>🔍 参考答案</summary>

**1. 创建诊断脚本** (`check_rust_wasm.sh`):
```bash
#!/bin/bash

echo "🔍 Rust WebAssembly 环境诊断"
echo "================================"

# 检查 Rust 版本
echo "📦 Rust 版本:"
if command -v rustc &> /dev/null; then
    rustc --version
    cargo --version
else
    echo "❌ Rust 未安装"
    exit 1
fi

echo ""

# 检查 wasm-pack
echo "🎯 wasm-pack 版本:"
if command -v wasm-pack &> /dev/null; then
    wasm-pack --version
else
    echo "❌ wasm-pack 未安装"
    echo "💡 安装命令: curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh"
fi

echo ""

# 检查 wasm32 目标
echo "🎯 WebAssembly 目标:"
if rustup target list --installed | grep -q "wasm32-unknown-unknown"; then
    echo "✅ wasm32-unknown-unknown 已安装"
else
    echo "❌ wasm32-unknown-unknown 未安装"
    echo "💡 安装命令: rustup target add wasm32-unknown-unknown"
fi

echo ""

# 检查关键工具
echo "🛠️ 相关工具:"
tools=("wasm-bindgen" "wasm-opt" "wasmtime")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool: $($tool --version | head -n1)"
    else
        echo "⚠️ $tool: 未安装"
    fi
done

echo ""
echo "🧪 创建测试项目..."

# 创建临时测试项目
TEST_DIR="/tmp/rust_wasm_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 初始化 Cargo 项目
cargo init --lib --name rust_wasm_test

# 创建 Cargo.toml
cat > Cargo.toml << 'EOF'
[package]
name = "rust-wasm-test"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
]
EOF

# 创建测试代码
cat > src/lib.rs << 'EOF'
use wasm_bindgen::prelude::*;

// 导入 console.log
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 定义一个宏方便调用 console.log
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 导出一个简单的函数
#[wasm_bindgen]
pub fn greet(name: &str) {
    console_log!("Hello, {}! From Rust and WebAssembly!", name);
}

// 导出一个数学函数
#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// 导出环境信息
#[wasm_bindgen]
pub fn get_info() -> String {
    format!("Rust WebAssembly module compiled successfully!")
}
EOF

# 尝试编译
echo "🏗️ 编译测试..."
if wasm-pack build --target web --out-dir pkg; then
    echo "✅ 编译成功！"
    echo "📂 生成的文件："
    ls -la pkg/
else
    echo "❌ 编译失败"
fi

# 清理
cd /
rm -rf "$TEST_DIR"

echo ""
echo "🎉 环境诊断完成"
```

**2. 手动验证步骤**:
```bash
# 1. 检查 Rust 安装
rustc --version
cargo --version

# 2. 检查 WebAssembly 目标
rustup target list --installed | grep wasm32

# 3. 检查 wasm-pack
wasm-pack --version

# 4. 创建最小项目进行测试
cargo new --lib hello-wasm
cd hello-wasm

# 编辑 Cargo.toml 添加 WebAssembly 配置
# 编辑 src/lib.rs 添加基本导出函数
# 运行编译测试
wasm-pack build
```

**预期输出示例**:
```
🔍 Rust WebAssembly 环境诊断
================================
📦 Rust 版本:
rustc 1.75.0 (82e1608df 2023-12-21)
cargo 1.75.0 (1d8b05cdd 2023-11-20)

🎯 wasm-pack 版本:
wasm-pack 0.12.1

🎯 WebAssembly 目标:
✅ wasm32-unknown-unknown 已安装

🛠️ 相关工具:
✅ wasm-bindgen: wasm-bindgen 0.2.89
✅ wasm-opt: wasm-opt version 114
✅ wasmtime: wasmtime-cli 15.0.1

✅ 编译成功！
🎉 环境诊断完成
```

</details>

### 练习 9.1.2 项目模板创建 (15分)

**题目**: 创建一个可复用的 Rust WebAssembly 项目模板，包含：
- 标准的项目结构
- 预配置的构建脚本
- 基础的 HTML/JS 测试页面
- 开发服务器配置

<details>
<summary>🔍 参考答案</summary>

**项目模板结构**:
```
rust-wasm-template/
├── Cargo.toml
├── src/
│   └── lib.rs
├── www/
│   ├── index.html
│   ├── index.js
│   └── bootstrap.js
├── pkg/          # 生成的 WASM 文件
├── scripts/
│   ├── build.sh
│   ├── dev.sh
│   └── test.sh
├── .gitignore
└── README.md
```

**1. Cargo.toml**:
```toml
[package]
name = "rust-wasm-template"
version = "0.1.0"
edition = "2021"
authors = ["Your Name <your.email@example.com>"]
description = "A template for Rust WebAssembly projects"
license = "MIT OR Apache-2.0"
repository = "https://github.com/yourusername/rust-wasm-template"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
console_error_panic_hook = "0.1"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
  "Document",
  "Element",
  "HtmlElement",
  "Window",
]

# 优化配置
[profile.release]
# 减小生成的 wasm 文件大小
opt-level = "s"
debug = false
lto = true

[profile.release.package."*"]
opt-level = "s"
```

**2. src/lib.rs**:
```rust
use wasm_bindgen::prelude::*;

// 导入 console.log
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 设置 panic hook，在浏览器控制台显示 panic 信息
#[wasm_bindgen(start)]
pub fn main() {
    console_error_panic_hook::set_once();
}

// 方便的控制台日志宏
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 导出问候函数
#[wasm_bindgen]
pub fn greet(name: &str) {
    console_log!("Hello, {}! 来自 Rust 和 WebAssembly!", name);
}

// 数学运算示例
#[wasm_bindgen]
pub fn fibonacci(n: u32) -> u32 {
    match n {
        0 => 0,
        1 => 1,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

// 字符串处理示例
#[wasm_bindgen]
pub fn reverse_string(input: &str) -> String {
    input.chars().rev().collect()
}

// 内存操作示例
#[wasm_bindgen]
pub fn sum_array(numbers: &[i32]) -> i32 {
    numbers.iter().sum()
}

// 错误处理示例
#[wasm_bindgen]
pub fn safe_divide(a: f64, b: f64) -> Result<f64, JsValue> {
    if b == 0.0 {
        Err(JsValue::from_str("除零错误"))
    } else {
        Ok(a / b)
    }
}

// 复杂对象示例
#[wasm_bindgen]
pub struct Calculator {
    value: f64,
}

#[wasm_bindgen]
impl Calculator {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Calculator {
        Calculator { value: 0.0 }
    }

    #[wasm_bindgen(getter)]
    pub fn value(&self) -> f64 {
        self.value
    }

    #[wasm_bindgen]
    pub fn add(&mut self, x: f64) {
        self.value += x;
    }

    #[wasm_bindgen]
    pub fn multiply(&mut self, x: f64) {
        self.value *= x;
    }

    #[wasm_bindgen]
    pub fn reset(&mut self) {
        self.value = 0.0;
    }
}
```

**3. www/index.html**:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Rust WebAssembly Template</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .container {
            background: #f5f5f5;
            padding: 20px;
            border-radius: 8px;
            margin: 10px 0;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover {
            background: #0056b3;
        }
        input, output {
            padding: 8px;
            margin: 5px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        output {
            background: #e9ecef;
            display: inline-block;
            min-width: 100px;
        }
    </style>
</head>
<body>
    <h1>🦀 Rust WebAssembly Template</h1>
    
    <div class="container">
        <h2>基础函数测试</h2>
        <button id="greet-button">问候</button>
        <span id="greet-output"></span>
    </div>

    <div class="container">
        <h2>斐波那契数列</h2>
        <input type="number" id="fib-input" value="10" min="0" max="40">
        <button id="fib-button">计算</button>
        <output id="fib-output"></output>
    </div>

    <div class="container">
        <h2>字符串反转</h2>
        <input type="text" id="reverse-input" value="Hello WebAssembly">
        <button id="reverse-button">反转</button>
        <output id="reverse-output"></output>
    </div>

    <div class="container">
        <h2>数组求和</h2>
        <input type="text" id="array-input" value="1,2,3,4,5" placeholder="用逗号分隔的数字">
        <button id="sum-button">求和</button>
        <output id="sum-output"></output>
    </div>

    <div class="container">
        <h2>计算器</h2>
        <div>
            <input type="number" id="calc-input" value="10" step="0.1">
            <button id="calc-add">+</button>
            <button id="calc-multiply">×</button>
            <button id="calc-reset">重置</button>
        </div>
        <div>当前值: <output id="calc-output">0</output></div>
    </div>

    <script src="./bootstrap.js"></script>
</body>
</html>
```

**4. www/bootstrap.js**:
```javascript
// bootstrap.js - 动态导入 WASM 模块
import("./index.js")
  .then(module => {
    console.log("✅ WebAssembly 模块加载成功");
  })
  .catch(e => {
    console.error("❌ 加载 WebAssembly 模块失败:", e);
  });
```

**5. www/index.js**:
```javascript
import init, { 
  greet, 
  fibonacci, 
  reverse_string, 
  sum_array, 
  safe_divide,
  Calculator 
} from '../pkg/rust_wasm_template.js';

async function run() {
  // 初始化 wasm 模块
  await init();

  console.log("🚀 WebAssembly 模块初始化完成");

  // 创建计算器实例
  const calculator = new Calculator();

  // 问候功能
  document.getElementById('greet-button').addEventListener('click', () => {
    greet('WebAssembly 开发者');
    document.getElementById('greet-output').textContent = '检查控制台输出';
  });

  // 斐波那契数列
  document.getElementById('fib-button').addEventListener('click', () => {
    const input = document.getElementById('fib-input');
    const output = document.getElementById('fib-output');
    const n = parseInt(input.value);
    
    if (n >= 0 && n <= 40) {
      const start = performance.now();
      const result = fibonacci(n);
      const end = performance.now();
      output.textContent = `F(${n}) = ${result} (${(end - start).toFixed(2)}ms)`;
    } else {
      output.textContent = '请输入 0-40 之间的数字';
    }
  });

  // 字符串反转
  document.getElementById('reverse-button').addEventListener('click', () => {
    const input = document.getElementById('reverse-input');
    const output = document.getElementById('reverse-output');
    const result = reverse_string(input.value);
    output.textContent = result;
  });

  // 数组求和
  document.getElementById('sum-button').addEventListener('click', () => {
    const input = document.getElementById('array-input');
    const output = document.getElementById('sum-output');
    
    try {
      const numbers = input.value
        .split(',')
        .map(s => parseInt(s.trim()))
        .filter(n => !isNaN(n));
      
      const result = sum_array(new Int32Array(numbers));
      output.textContent = `总和: ${result}`;
    } catch (e) {
      output.textContent = '输入格式错误';
    }
  });

  // 计算器功能
  function updateCalcDisplay() {
    document.getElementById('calc-output').textContent = calculator.value.toFixed(2);
  }

  document.getElementById('calc-add').addEventListener('click', () => {
    const input = document.getElementById('calc-input');
    calculator.add(parseFloat(input.value));
    updateCalcDisplay();
  });

  document.getElementById('calc-multiply').addEventListener('click', () => {
    const input = document.getElementById('calc-input');
    calculator.multiply(parseFloat(input.value));
    updateCalcDisplay();
  });

  document.getElementById('calc-reset').addEventListener('click', () => {
    calculator.reset();
    updateCalcDisplay();
  });

  // 初始化显示
  updateCalcDisplay();
}

// 运行应用
run().catch(console.error);
```

**6. scripts/build.sh**:
```bash
#!/bin/bash

echo "🏗️ 构建 Rust WebAssembly 项目..."

# 构建发布版本
wasm-pack build --target web --out-dir pkg --release

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo "📦 生成的文件："
    ls -la pkg/
    
    # 显示文件大小
    echo ""
    echo "📊 WASM 文件大小："
    ls -lh pkg/*.wasm
else
    echo "❌ 构建失败"
    exit 1
fi
```

**7. scripts/dev.sh**:
```bash
#!/bin/bash

echo "🚀 启动开发服务器..."

# 构建开发版本
wasm-pack build --target web --out-dir pkg --dev

if [ $? -eq 0 ]; then
    echo "✅ 构建完成，启动服务器..."
    
    # 启动简单的 HTTP 服务器
    if command -v python3 &> /dev/null; then
        cd www && python3 -m http.server 8000
    elif command -v python &> /dev/null; then
        cd www && python -m SimpleHTTPServer 8000
    elif command -v npx &> /dev/null; then
        cd www && npx serve -s . -l 8000
    else
        echo "❌ 找不到可用的 HTTP 服务器"
        echo "💡 请安装 Python 或 Node.js"
        exit 1
    fi
else
    echo "❌ 构建失败"
    exit 1
fi
```

**8. .gitignore**:
```
/target
/pkg
Cargo.lock
.DS_Store
node_modules/
*.log
```

**使用方法**:
```bash
# 1. 复制模板
cp -r rust-wasm-template my-project
cd my-project

# 2. 开发模式
chmod +x scripts/*.sh
./scripts/dev.sh

# 3. 生产构建
./scripts/build.sh
```

</details>

## 9.2 基础编译练习

### 练习 9.2.1 类型映射验证 (10分)

**题目**: 创建一个类型转换测试模块，验证 Rust 和 JavaScript 之间的类型映射。

<details>
<summary>🔍 参考答案</summary>

**Rust 代码** (`src/lib.rs`):
```rust
use wasm_bindgen::prelude::*;

// 基础数值类型测试
#[wasm_bindgen]
pub fn test_i32(value: i32) -> i32 {
    value * 2
}

#[wasm_bindgen]
pub fn test_f64(value: f64) -> f64 {
    value * 3.14
}

#[wasm_bindgen]
pub fn test_bool(value: bool) -> bool {
    !value
}

// 字符串类型测试
#[wasm_bindgen]
pub fn test_string(input: &str) -> String {
    format!("Processed: {}", input)
}

// 数组类型测试
#[wasm_bindgen]
pub fn test_i32_array(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().map(|x| x * 2).collect()
}

#[wasm_bindgen]
pub fn test_f64_array(numbers: &[f64]) -> Vec<f64> {
    numbers.iter().map(|x| x.sqrt()).collect()
}

// Option 类型测试
#[wasm_bindgen]
pub fn test_option_i32(value: Option<i32>) -> Option<i32> {
    value.map(|x| x + 10)
}

// Result 类型测试
#[wasm_bindgen]
pub fn test_result(value: i32) -> Result<i32, JsValue> {
    if value >= 0 {
        Ok(value * value)
    } else {
        Err(JsValue::from_str("负数不被支持"))
    }
}

// 结构体类型测试
#[wasm_bindgen]
#[derive(Clone)]
pub struct Point {
    x: f64,
    y: f64,
}

#[wasm_bindgen]
impl Point {
    #[wasm_bindgen(constructor)]
    pub fn new(x: f64, y: f64) -> Point {
        Point { x, y }
    }

    #[wasm_bindgen(getter)]
    pub fn x(&self) -> f64 {
        self.x
    }

    #[wasm_bindgen(getter)]
    pub fn y(&self) -> f64 {
        self.y
    }

    #[wasm_bindgen(setter)]
    pub fn set_x(&mut self, x: f64) {
        self.x = x;
    }

    #[wasm_bindgen(setter)]
    pub fn set_y(&mut self, y: f64) {
        self.y = y;
    }

    #[wasm_bindgen]
    pub fn distance_to(&self, other: &Point) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }
}

// 枚举类型测试
#[wasm_bindgen]
#[derive(Clone, Copy)]
pub enum Color {
    Red,
    Green,
    Blue,
}

#[wasm_bindgen]
pub fn test_enum(color: Color) -> String {
    match color {
        Color::Red => "红色".to_string(),
        Color::Green => "绿色".to_string(),
        Color::Blue => "蓝色".to_string(),
    }
}

// 复杂类型组合测试
#[wasm_bindgen]
pub fn process_mixed_data(
    name: &str,
    age: i32,
    scores: &[f64],
    active: bool,
) -> JsValue {
    let average = if scores.is_empty() {
        0.0
    } else {
        scores.iter().sum::<f64>() / scores.len() as f64
    };

    let result = serde_json::json!({
        "name": name,
        "age": age,
        "average_score": average,
        "is_active": active,
        "status": if active { "在线" } else { "离线" }
    });

    JsValue::from_str(&result.to_string())
}
```

**测试代码** (`test.js`):
```javascript
import init, * as wasm from '../pkg/rust_wasm_template.js';

async function runTypeTests() {
    await init();

    console.log("🧪 开始类型映射测试...");

    // 基础类型测试
    console.log("== 基础数值类型 ==");
    console.log("i32:", wasm.test_i32(42)); // 应该是 84
    console.log("f64:", wasm.test_f64(2.0)); // 应该是 6.28
    console.log("bool:", wasm.test_bool(true)); // 应该是 false

    // 字符串测试
    console.log("== 字符串类型 ==");
    console.log("string:", wasm.test_string("Hello")); // "Processed: Hello"

    // 数组测试
    console.log("== 数组类型 ==");
    console.log("i32 array:", wasm.test_i32_array([1, 2, 3, 4])); // [2, 4, 6, 8]
    console.log("f64 array:", wasm.test_f64_array([4.0, 9.0, 16.0])); // [2, 3, 4]

    // Option 测试
    console.log("== Option 类型 ==");
    console.log("Some:", wasm.test_option_i32(5)); // 15
    console.log("None:", wasm.test_option_i32(null)); // null

    // Result 测试
    console.log("== Result 类型 ==");
    try {
        console.log("Ok:", wasm.test_result(5)); // 25
    } catch (e) {
        console.log("Error:", e);
    }

    try {
        console.log("Err:", wasm.test_result(-1)); // 应该抛出异常
    } catch (e) {
        console.log("Caught error:", e);
    }

    // 结构体测试
    console.log("== 结构体类型 ==");
    const point1 = new wasm.Point(0, 0);
    const point2 = new wasm.Point(3, 4);
    console.log("Point1:", point1.x, point1.y);
    console.log("Point2:", point2.x, point2.y);
    console.log("Distance:", point1.distance_to(point2)); // 应该是 5

    // 枚举测试
    console.log("== 枚举类型 ==");
    console.log("Red:", wasm.test_enum(wasm.Color.Red));
    console.log("Green:", wasm.test_enum(wasm.Color.Green));
    console.log("Blue:", wasm.test_enum(wasm.Color.Blue));

    // 复杂数据测试
    console.log("== 复杂类型组合 ==");
    const mixedResult = wasm.process_mixed_data(
        "张三",
        25,
        [85.5, 92.0, 78.5],
        true
    );
    console.log("Mixed data result:", JSON.parse(mixedResult));

    console.log("✅ 所有类型测试完成");
}

// 性能测试
async function performanceTest() {
    await init();

    console.log("⚡ 性能测试开始...");

    const iterations = 100000;
    const testArray = new Array(1000).fill(0).map((_, i) => i);

    // JavaScript 数组处理
    console.time("JavaScript Array Processing");
    for (let i = 0; i < iterations; i++) {
        testArray.map(x => x * 2);
    }
    console.timeEnd("JavaScript Array Processing");

    // Rust WASM 数组处理
    console.time("Rust WASM Array Processing");
    for (let i = 0; i < iterations; i++) {
        wasm.test_i32_array(testArray);
    }
    console.timeEnd("Rust WASM Array Processing");

    console.log("✅ 性能测试完成");
}

// 运行测试
runTypeTests().then(() => performanceTest());
```

**验证结果示例**:
```
🧪 开始类型映射测试...
== 基础数值类型 ==
i32: 84
f64: 6.283185307179586
bool: false
== 字符串类型 ==
string: Processed: Hello
== 数组类型 ==
i32 array: [2, 4, 6, 8]
f64 array: [2, 3, 4]
== Option 类型 ==
Some: 15
None: null
== Result 类型 ==
Ok: 25
Caught error: 负数不被支持
== 结构体类型 ==
Point1: 0 0
Point2: 3 4
Distance: 5
== 枚举类型 ==
Red: 红色
Green: 绿色
Blue: 蓝色
== 复杂类型组合 ==
Mixed data result: {
  "name": "张三",
  "age": 25,
  "average_score": 85.33333333333333,
  "is_active": true,
  "status": "在线"
}
✅ 所有类型测试完成
```

</details>

### 练习 9.2.2 内存操作实践 (15分)

**题目**: 实现一个图像处理模块，展示 Rust WebAssembly 的内存操作能力。

<details>
<summary>🔍 参考答案</summary>

**Rust 图像处理模块** (`src/image.rs`):
```rust
use wasm_bindgen::prelude::*;
use std::cmp;

#[wasm_bindgen]
pub struct ImageProcessor {
    width: usize,
    height: usize,
    data: Vec<u8>,
}

#[wasm_bindgen]
impl ImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: usize, height: usize) -> ImageProcessor {
        let data = vec![0; width * height * 4]; // RGBA
        ImageProcessor { width, height, data }
    }

    // 从 JavaScript 接收图像数据
    #[wasm_bindgen]
    pub fn load_data(&mut self, data: &[u8]) {
        if data.len() == self.width * self.height * 4 {
            self.data.copy_from_slice(data);
        }
    }

    // 获取处理后的数据指针（用于 JavaScript 访问）
    #[wasm_bindgen]
    pub fn get_data_ptr(&self) -> *const u8 {
        self.data.as_ptr()
    }

    #[wasm_bindgen]
    pub fn get_data_length(&self) -> usize {
        self.data.len()
    }

    // 获取图像尺寸
    #[wasm_bindgen]
    pub fn width(&self) -> usize {
        self.width
    }

    #[wasm_bindgen]
    pub fn height(&self) -> usize {
        self.height
    }

    // 灰度化处理
    #[wasm_bindgen]
    pub fn grayscale(&mut self) {
        for i in (0..self.data.len()).step_by(4) {
            let r = self.data[i] as f32;
            let g = self.data[i + 1] as f32;
            let b = self.data[i + 2] as f32;
            
            // 使用标准灰度转换公式
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as u8;
            
            self.data[i] = gray;     // R
            self.data[i + 1] = gray; // G
            self.data[i + 2] = gray; // B
            // Alpha 通道保持不变
        }
    }

    // 亮度调整
    #[wasm_bindgen]
    pub fn adjust_brightness(&mut self, factor: f32) {
        for i in (0..self.data.len()).step_by(4) {
            // 调整 RGB 通道，跳过 Alpha
            for j in 0..3 {
                let old_value = self.data[i + j] as f32;
                let new_value = (old_value * factor).clamp(0.0, 255.0) as u8;
                self.data[i + j] = new_value;
            }
        }
    }

    // 对比度调整
    #[wasm_bindgen]
    pub fn adjust_contrast(&mut self, factor: f32) {
        for i in (0..self.data.len()).step_by(4) {
            for j in 0..3 {
                let old_value = self.data[i + j] as f32;
                let normalized = old_value / 255.0;
                let contrasted = ((normalized - 0.5) * factor + 0.5).clamp(0.0, 1.0);
                self.data[i + j] = (contrasted * 255.0) as u8;
            }
        }
    }

    // 模糊滤镜（简单的盒式模糊）
    #[wasm_bindgen]
    pub fn blur(&mut self, radius: usize) {
        if radius == 0 {
            return;
        }

        let mut temp_data = self.data.clone();
        
        for y in 0..self.height {
            for x in 0..self.width {
                let mut r_sum = 0u32;
                let mut g_sum = 0u32;
                let mut b_sum = 0u32;
                let mut count = 0u32;

                // 对邻域内的像素求平均
                for dy in -(radius as i32)..=(radius as i32) {
                    for dx in -(radius as i32)..=(radius as i32) {
                        let nx = x as i32 + dx;
                        let ny = y as i32 + dy;

                        if nx >= 0 && nx < self.width as i32 && 
                           ny >= 0 && ny < self.height as i32 {
                            let index = ((ny as usize * self.width + nx as usize) * 4) as usize;
                            r_sum += temp_data[index] as u32;
                            g_sum += temp_data[index + 1] as u32;
                            b_sum += temp_data[index + 2] as u32;
                            count += 1;
                        }
                    }
                }

                if count > 0 {
                    let index = (y * self.width + x) * 4;
                    self.data[index] = (r_sum / count) as u8;
                    self.data[index + 1] = (g_sum / count) as u8;
                    self.data[index + 2] = (b_sum / count) as u8;
                }
            }
        }
    }

    // 边缘检测（简单的 Sobel 算子）
    #[wasm_bindgen]
    pub fn edge_detection(&mut self) {
        let temp_data = self.data.clone();
        
        // Sobel 算子
        let sobel_x = [
            [-1, 0, 1],
            [-2, 0, 2],
            [-1, 0, 1],
        ];
        
        let sobel_y = [
            [-1, -2, -1],
            [ 0,  0,  0],
            [ 1,  2,  1],
        ];

        for y in 1..self.height - 1 {
            for x in 1..self.width - 1 {
                let mut gx = 0i32;
                let mut gy = 0i32;

                // 应用 Sobel 算子
                for i in 0..3 {
                    for j in 0..3 {
                        let px = x + j - 1;
                        let py = y + i - 1;
                        let index = (py * self.width + px) * 4;
                        
                        // 使用灰度值（取 R 通道）
                        let pixel_value = temp_data[index] as i32;
                        
                        gx += sobel_x[i][j] * pixel_value;
                        gy += sobel_y[i][j] * pixel_value;
                    }
                }

                // 计算梯度强度
                let magnitude = ((gx * gx + gy * gy) as f64).sqrt().min(255.0) as u8;
                
                let index = (y * self.width + x) * 4;
                self.data[index] = magnitude;     // R
                self.data[index + 1] = magnitude; // G
                self.data[index + 2] = magnitude; // B
            }
        }
    }

    // 直方图计算
    #[wasm_bindgen]
    pub fn calculate_histogram(&self) -> Vec<u32> {
        let mut histogram = vec![0u32; 256];
        
        for i in (0..self.data.len()).step_by(4) {
            // 计算灰度值
            let r = self.data[i] as f32;
            let g = self.data[i + 1] as f32;
            let b = self.data[i + 2] as f32;
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as usize;
            
            if gray < 256 {
                histogram[gray] += 1;
            }
        }
        
        histogram
    }

    // 颜色通道分离
    #[wasm_bindgen]
    pub fn extract_channel(&mut self, channel: u8) {
        for i in (0..self.data.len()).step_by(4) {
            match channel {
                0 => { // 红色通道
                    self.data[i + 1] = 0; // G
                    self.data[i + 2] = 0; // B
                },
                1 => { // 绿色通道
                    self.data[i] = 0;     // R
                    self.data[i + 2] = 0; // B
                },
                2 => { // 蓝色通道
                    self.data[i] = 0;     // R
                    self.data[i + 1] = 0; // G
                },
                _ => {} // 保持原样
            }
        }
    }

    // 复制图像数据到 JavaScript
    #[wasm_bindgen]
    pub fn copy_to_buffer(&self, buffer: &mut [u8]) {
        if buffer.len() >= self.data.len() {
            buffer[..self.data.len()].copy_from_slice(&self.data);
        }
    }
}

// 创建测试图像
#[wasm_bindgen]
pub fn create_test_image(width: usize, height: usize) -> Vec<u8> {
    let mut data = vec![0u8; width * height * 4];
    
    for y in 0..height {
        for x in 0..width {
            let index = (y * width + x) * 4;
            
            // 创建彩色渐变测试图像
            data[index] = ((x as f32 / width as f32) * 255.0) as u8;     // R
            data[index + 1] = ((y as f32 / height as f32) * 255.0) as u8; // G
            data[index + 2] = 128; // B
            data[index + 3] = 255; // A
        }
    }
    
    data
}

// 性能基准测试
#[wasm_bindgen]
pub fn benchmark_image_processing(width: usize, height: usize, iterations: usize) -> f64 {
    let mut processor = ImageProcessor::new(width, height);
    let test_data = create_test_image(width, height);
    processor.load_data(&test_data);
    
    let start = js_sys::Date::now();
    
    for _ in 0..iterations {
        processor.grayscale();
        processor.adjust_brightness(1.1);
        processor.blur(1);
    }
    
    let end = js_sys::Date::now();
    end - start
}
```

**JavaScript 使用示例** (`image_test.js`):
```javascript
import init, { ImageProcessor, create_test_image, benchmark_image_processing } from '../pkg/rust_wasm_template.js';

async function runImageTests() {
    await init();
    
    console.log("🖼️ 图像处理测试开始...");

    // 创建测试图像
    const width = 512;
    const height = 512;
    const testImageData = create_test_image(width, height);
    
    console.log(`创建了 ${width}x${height} 的测试图像`);

    // 创建图像处理器
    const processor = new ImageProcessor(width, height);
    processor.load_data(testImageData);

    // 在 Canvas 上显示原始图像
    const canvas = document.getElementById('image-canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = width;
    canvas.height = height;

    function displayImage() {
        // 从 WASM 内存获取图像数据
        const dataPtr = processor.get_data_ptr();
        const dataLength = processor.get_data_length();
        const wasmMemory = new Uint8Array(memory.buffer);
        const imageData = wasmMemory.subarray(dataPtr, dataPtr + dataLength);
        
        // 创建 ImageData 对象
        const imageDataObj = new ImageData(
            new Uint8ClampedArray(imageData),
            width,
            height
        );
        
        ctx.putImageData(imageDataObj, 0, 0);
    }

    // 显示原始图像
    console.log("显示原始图像");
    displayImage();

    // 等待用户确认后继续
    await new Promise(resolve => {
        const button = document.createElement('button');
        button.textContent = '应用灰度化';
        button.onclick = () => {
            button.remove();
            resolve();
        };
        document.body.appendChild(button);
    });

    // 应用灰度化
    console.log("应用灰度化...");
    processor.grayscale();
    displayImage();

    // 调整亮度
    console.log("调整亮度...");
    processor.adjust_brightness(1.3);
    displayImage();

    // 应用模糊
    console.log("应用模糊滤镜...");
    processor.blur(2);
    displayImage();

    // 边缘检测
    console.log("边缘检测...");
    processor.edge_detection();
    displayImage();

    // 计算直方图
    console.log("计算直方图...");
    const histogram = processor.calculate_histogram();
    console.log("直方图数据（前10个值）:", histogram.slice(0, 10));

    // 性能测试
    console.log("⚡ 性能基准测试...");
    const benchmarkTime = benchmark_image_processing(256, 256, 100);
    console.log(`处理 100 次 256x256 图像耗时: ${benchmarkTime.toFixed(2)}ms`);

    console.log("✅ 图像处理测试完成");
}

// HTML 模板
const imageTestHTML = `
<div>
    <h3>图像处理演示</h3>
    <canvas id="image-canvas" style="border: 1px solid #ccc;"></canvas>
    <div id="controls" style="margin-top: 10px;">
        <button onclick="runImageTests()">开始测试</button>
    </div>
</div>
`;

// 添加到页面
document.body.insertAdjacentHTML('beforeend', imageTestHTML);

// 暴露测试函数到全局
window.runImageTests = runImageTests;
```

**性能对比测试**:
```javascript
async function comparePerformance() {
    await init();

    const width = 512;
    const height = 512;
    const testData = create_test_image(width, height);
    
    console.log("🏁 性能对比测试");

    // JavaScript 版本的灰度化
    function jsGrayscale(data) {
        for (let i = 0; i < data.length; i += 4) {
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];
            const gray = Math.round(0.299 * r + 0.587 * g + 0.114 * b);
            data[i] = gray;
            data[i + 1] = gray;
            data[i + 2] = gray;
        }
    }

    // JavaScript 性能测试
    const jsData = new Uint8Array(testData);
    console.time('JavaScript Grayscale');
    jsGrayscale(jsData);
    console.timeEnd('JavaScript Grayscale');

    // Rust WASM 性能测试
    const processor = new ImageProcessor(width, height);
    processor.load_data(testData);
    console.time('Rust WASM Grayscale');
    processor.grayscale();
    console.timeEnd('Rust WASM Grayscale');

    console.log("📊 性能对比完成");
}
```

</details>

## 9.3 高级特性练习

### 练习 9.3.1 异步编程实践 (20分)

**题目**: 实现一个支持异步操作的文件处理模块，包含 Promise 集成和错误处理。

<details>
<summary>🔍 参考答案</summary>

**Rust 异步模块** (`src/async_ops.rs`):
```rust
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};
use js_sys::Promise;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 异步文件处理器
#[wasm_bindgen]
pub struct AsyncFileProcessor {
    processing_queue: Vec<String>,
}

#[wasm_bindgen]
impl AsyncFileProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> AsyncFileProcessor {
        AsyncFileProcessor {
            processing_queue: Vec::new(),
        }
    }

    // 异步获取文件内容
    #[wasm_bindgen]
    pub async fn fetch_file(&self, url: String) -> Result<String, JsValue> {
        console_log!("开始获取文件: {}", url);

        let mut opts = RequestInit::new();
        opts.method("GET");
        opts.mode(RequestMode::Cors);

        let request = Request::new_with_str_and_init(&url, &opts)?;

        let window = web_sys::window().unwrap();
        let resp_value = JsFuture::from(window.fetch_with_request(&request)).await?;
        let resp: Response = resp_value.dyn_into().unwrap();

        if !resp.ok() {
            return Err(JsValue::from_str(&format!("HTTP 错误: {}", resp.status())));
        }

        let text_promise = resp.text()?;
        let text_value = JsFuture::from(text_promise).await?;
        let text = text_value.as_string().unwrap_or_default();

        console_log!("文件获取成功，大小: {} 字节", text.len());
        Ok(text)
    }

    // 异步处理文本（模拟耗时操作）
    #[wasm_bindgen]
    pub async fn process_text(&mut self, text: String, delay_ms: u32) -> Result<String, JsValue> {
        console_log!("开始处理文本，延迟: {}ms", delay_ms);

        // 添加到处理队列
        self.processing_queue.push(text.clone());

        // 模拟异步延迟
        let promise = Promise::new(&mut |resolve, _| {
            let resolve = resolve.clone();
            let text_clone = text.clone();
            
            web_sys::window()
                .unwrap()
                .set_timeout_with_callback_and_timeout_and_arguments_0(
                    &Closure::once_into_js(move || {
                        // 处理文本：统计单词、转换大小写等
                        let word_count = text_clone.split_whitespace().count();
                        let processed = format!(
                            "处理结果:\n字符数: {}\n单词数: {}\n大写转换: {}",
                            text_clone.len(),
                            word_count,
                            text_clone.to_uppercase()
                        );
                        resolve.call1(&JsValue::NULL, &JsValue::from_str(&processed)).unwrap();
                    })
                    .into(),
                    delay_ms as i32,
                ).unwrap();
        });

        let result = JsFuture::from(promise).await?;
        let processed_text = result.as_string().unwrap_or_default();

        // 从队列中移除
        self.processing_queue.retain(|x| x != &text);

        console_log!("文本处理完成");
        Ok(processed_text)
    }

    // 批量异步处理
    #[wasm_bindgen]
    pub async fn batch_process(&mut self, urls: Box<[JsValue]>) -> Result<Box<[JsValue]>, JsValue> {
        console_log!("开始批量处理 {} 个文件", urls.len());

        let mut futures = Vec::new();
        
        for url_value in urls.iter() {
            if let Some(url) = url_value.as_string() {
                let future = async move {
                    match self.fetch_file(url.clone()).await {
                        Ok(content) => {
                            match self.process_text(content, 100).await {
                                Ok(processed) => Ok(JsValue::from_str(&processed)),
                                Err(e) => Err(e),
                            }
                        },
                        Err(e) => Err(e),
                    }
                };
                futures.push(future);
            }
        }

        // 并发执行所有异步操作
        let mut results = Vec::new();
        for future in futures {
            match future.await {
                Ok(result) => results.push(result),
                Err(e) => return Err(e),
            }
        }

        console_log!("批量处理完成");
        Ok(results.into_boxed_slice())
    }

    // 获取处理队列状态
    #[wasm_bindgen]
    pub fn get_queue_status(&self) -> String {
        format!("队列中有 {} 个待处理项目", self.processing_queue.len())
    }
}

// 异步计算密集型任务示例
#[wasm_bindgen]
pub async fn compute_fibonacci_async(n: u32, chunk_size: u32) -> Result<String, JsValue> {
    console_log!("开始异步计算斐波那契数列，n={}, chunk_size={}", n, chunk_size);

    if n > 45 {
        return Err(JsValue::from_str("n 值太大，可能导致浏览器卡顿"));
    }

    let mut results = Vec::new();
    let mut current = 0;

    while current < n {
        let end = std::cmp::min(current + chunk_size, n);
        
        // 计算一个批次
        let batch_results: Vec<u64> = (current..end)
            .map(|i| fibonacci_iterative(i))
            .collect();
        
        results.extend(batch_results);
        current = end;

        // 每个批次后让出控制权
        if current < n {
            let promise = Promise::new(&mut |resolve, _| {
                web_sys::window()
                    .unwrap()
                    .set_timeout_with_callback_and_timeout_and_arguments_0(
                        &Closure::once_into_js(move || {
                            resolve.call1(&JsValue::NULL, &JsValue::UNDEFINED).unwrap();
                        }).into(),
                        0,
                    ).unwrap();
            });
            JsFuture::from(promise).await?;
        }
    }

    let result_str = format!("计算完成，前10个结果: {:?}", &results[..std::cmp::min(10, results.len())]);
    console_log!("{}", result_str);
    Ok(result_str)
}

// 辅助函数：迭代计算斐波那契数
fn fibonacci_iterative(n: u32) -> u64 {
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

// 异步网络请求管理器
#[wasm_bindgen]
pub struct NetworkManager {
    base_url: String,
    timeout_ms: u32,
}

#[wasm_bindgen]
impl NetworkManager {
    #[wasm_bindgen(constructor)]
    pub fn new(base_url: String, timeout_ms: u32) -> NetworkManager {
        NetworkManager { base_url, timeout_ms }
    }

    // 带超时的异步请求
    #[wasm_bindgen]
    pub async fn request_with_timeout(&self, endpoint: String) -> Result<String, JsValue> {
        let url = format!("{}/{}", self.base_url, endpoint);
        console_log!("发起网络请求: {}", url);

        // 创建请求
        let mut opts = RequestInit::new();
        opts.method("GET");
        opts.mode(RequestMode::Cors);

        let request = Request::new_with_str_and_init(&url, &opts)?;

        // 创建超时 Promise
        let timeout_promise = Promise::new(&mut |_, reject| {
            let reject = reject.clone();
            web_sys::window()
                .unwrap()
                .set_timeout_with_callback_and_timeout_and_arguments_0(
                    &Closure::once_into_js(move || {
                        reject.call1(&JsValue::NULL, &JsValue::from_str("请求超时")).unwrap();
                    }).into(),
                    self.timeout_ms as i32,
                ).unwrap();
        });

        // 创建请求 Promise
        let window = web_sys::window().unwrap();
        let fetch_promise = window.fetch_with_request(&request);

        // 使用 Promise.race() 实现超时
        let race_array = js_sys::Array::new();
        race_array.push(&fetch_promise);
        race_array.push(&timeout_promise);

        let race_promise = js_sys::Promise::race(&race_array);
        let resp_value = JsFuture::from(race_promise).await?;

        // 检查是否是 Response 对象
        if !resp_value.is_instance_of::<Response>() {
            return Err(JsValue::from_str("请求超时"));
        }

        let resp: Response = resp_value.dyn_into().unwrap();

        if !resp.ok() {
            return Err(JsValue::from_str(&format!("HTTP 错误: {}", resp.status())));
        }

        let text_promise = resp.text()?;
        let text_value = JsFuture::from(text_promise).await?;
        let text = text_value.as_string().unwrap_or_default();

        console_log!("请求成功完成");
        Ok(text)
    }

    // 并发请求多个端点
    #[wasm_bindgen]
    pub async fn concurrent_requests(&self, endpoints: Box<[JsValue]>) -> Result<Box<[JsValue]>, JsValue> {
        console_log!("开始并发请求 {} 个端点", endpoints.len());

        let mut promises = Vec::new();

        for endpoint_value in endpoints.iter() {
            if let Some(endpoint) = endpoint_value.as_string() {
                let url = format!("{}/{}", self.base_url, endpoint);
                
                let mut opts = RequestInit::new();
                opts.method("GET");
                opts.mode(RequestMode::Cors);

                let request = Request::new_with_str_and_init(&url, &opts)?;
                let window = web_sys::window().unwrap();
                let promise = window.fetch_with_request(&request);
                
                promises.push(promise);
            }
        }

        // 使用 Promise.all() 等待所有请求完成
        let promise_array = js_sys::Array::new();
        for promise in promises {
            promise_array.push(&promise);
        }

        let all_promise = js_sys::Promise::all(&promise_array);
        let results_value = JsFuture::from(all_promise).await?;
        let results_array: js_sys::Array = results_value.dyn_into().unwrap();

        let mut processed_results = Vec::new();
        for i in 0..results_array.length() {
            let resp_value = results_array.get(i);
            let resp: Response = resp_value.dyn_into().unwrap();

            if resp.ok() {
                let text_promise = resp.text()?;
                let text_value = JsFuture::from(text_promise).await?;
                processed_results.push(text_value);
            } else {
                processed_results.push(JsValue::from_str(&format!("错误: {}", resp.status())));
            }
        }

        console_log!("并发请求完成");
        Ok(processed_results.into_boxed_slice())
    }
}
```

**JavaScript 测试代码** (`async_test.js`):
```javascript
import init, { AsyncFileProcessor, compute_fibonacci_async, NetworkManager } from '../pkg/rust_wasm_template.js';

async function runAsyncTests() {
    await init();
    
    console.log("🔄 异步编程测试开始...");

    // 文件处理器测试
    console.log("== 异步文件处理器 ==");
    const processor = new AsyncFileProcessor();

    try {
        // 模拟文件内容
        const testText = "Hello WebAssembly! This is a test file content with multiple words.";
        console.log("处理文本:", testText.substring(0, 50) + "...");
        
        const result = await processor.process_text(testText, 1000);
        console.log("处理结果:", result.substring(0, 100) + "...");
        
        console.log("队列状态:", processor.get_queue_status());
    } catch (error) {
        console.error("文件处理错误:", error);
    }

    // 异步计算测试
    console.log("== 异步计算测试 ==");
    try {
        console.time("异步斐波那契计算");
        const fibResult = await compute_fibonacci_async(30, 5);
        console.timeEnd("异步斐波那契计算");
        console.log("斐波那契结果:", fibResult);
    } catch (error) {
        console.error("计算错误:", error);
    }

    // 网络管理器测试
    console.log("== 网络请求测试 ==");
    const networkManager = new NetworkManager("https://jsonplaceholder.typicode.com", 5000);

    try {
        console.time("单个请求");
        const singleResult = await networkManager.request_with_timeout("posts/1");
        console.timeEnd("单个请求");
        console.log("单个请求结果:", JSON.parse(singleResult).title);
    } catch (error) {
        console.error("网络请求错误:", error);
    }

    try {
        console.time("并发请求");
        const endpoints = ["posts/1", "posts/2", "posts/3"];
        const concurrentResults = await networkManager.concurrent_requests(endpoints);
        console.timeEnd("并发请求");
        
        console.log("并发请求结果:");
        concurrentResults.forEach((result, index) => {
            try {
                const parsed = JSON.parse(result);
                console.log(`  ${index + 1}: ${parsed.title}`);
            } catch (e) {
                console.log(`  ${index + 1}: 解析错误`);
            }
        });
    } catch (error) {
        console.error("并发请求错误:", error);
    }

    console.log("✅ 异步编程测试完成");
}

// 交互式测试界面
function createAsyncTestUI() {
    const container = document.createElement('div');
    container.innerHTML = `
        <h3>异步操作测试</h3>
        <div style="margin: 10px 0;">
            <button id="test-file-processing">测试文件处理</button>
            <button id="test-computation">测试异步计算</button>
            <button id="test-network">测试网络请求</button>
        </div>
        <div id="async-results" style="background: #f0f0f0; padding: 10px; margin: 10px 0; height: 200px; overflow-y: auto;"></div>
    `;

    document.body.appendChild(container);

    const resultsDiv = document.getElementById('async-results');

    function logResult(message) {
        resultsDiv.innerHTML += `<div>${new Date().toLocaleTimeString()}: ${message}</div>`;
        resultsDiv.scrollTop = resultsDiv.scrollHeight;
    }

    document.getElementById('test-file-processing').onclick = async () => {
        logResult("开始文件处理测试...");
        const processor = new AsyncFileProcessor();
        
        try {
            const testTexts = [
                "这是第一个测试文件的内容。",
                "This is the second test file content.",
                "第三个文件包含更多的文字内容，用于测试处理能力。"
            ];

            for (let i = 0; i < testTexts.length; i++) {
                logResult(`处理文件 ${i + 1}...`);
                const result = await processor.process_text(testTexts[i], 500);
                logResult(`文件 ${i + 1} 处理完成`);
            }
        } catch (error) {
            logResult(`错误: ${error}`);
        }
    };

    document.getElementById('test-computation').onclick = async () => {
        logResult("开始异步计算测试...");
        
        try {
            const result = await compute_fibonacci_async(25, 3);
            logResult(`计算完成: ${result}`);
        } catch (error) {
            logResult(`计算错误: ${error}`);
        }
    };

    document.getElementById('test-network').onclick = async () => {
        logResult("开始网络请求测试...");
        const networkManager = new NetworkManager("https://httpbin.org", 3000);
        
        try {
            const result = await networkManager.request_with_timeout("delay/1");
            logResult("网络请求成功完成");
        } catch (error) {
            logResult(`网络请求错误: ${error}`);
        }
    };
}

// 页面加载完成后创建测试界面
document.addEventListener('DOMContentLoaded', () => {
    createAsyncTestUI();
});

// 暴露测试函数
window.runAsyncTests = runAsyncTests;
```

**性能监控和错误处理示例**:
```javascript
// 异步操作性能监控
class AsyncPerformanceMonitor {
    constructor() {
        this.operations = new Map();
    }

    startOperation(id) {
        this.operations.set(id, {
            startTime: performance.now(),
            status: 'running'
        });
    }

    finishOperation(id, success = true) {
        const op = this.operations.get(id);
        if (op) {
            op.endTime = performance.now();
            op.duration = op.endTime - op.startTime;
            op.status = success ? 'completed' : 'failed';
        }
    }

    getReport() {
        const completed = Array.from(this.operations.values())
            .filter(op => op.status === 'completed');
        
        if (completed.length === 0) return "无已完成操作";

        const totalDuration = completed.reduce((sum, op) => sum + op.duration, 0);
        const avgDuration = totalDuration / completed.length;
        
        return `操作总数: ${completed.length}, 平均耗时: ${avgDuration.toFixed(2)}ms`;
    }
}

// 使用监控器
const monitor = new AsyncPerformanceMonitor();

async function monitoredAsyncOperation() {
    const operationId = `op_${Date.now()}`;
    monitor.startOperation(operationId);
    
    try {
        await runAsyncTests();
        monitor.finishOperation(operationId, true);
    } catch (error) {
        monitor.finishOperation(operationId, false);
        console.error("操作失败:", error);
    }
    
    console.log("性能报告:", monitor.getReport());
}
```

</details>

### 练习 9.3.2 游戏引擎开发 (30分)

**题目**: 创建一个简单的 2D 游戏引擎，包含实体系统、物理模拟、碰撞检测和渲染管理。

<details>
<summary>🔍 参考答案</summary>

由于这是一个非常复杂的练习，我将在下一个文件中继续完成这个内容。现在先提交当前的进度。

</details>

## 9.4 项目实战练习

### 练习 9.4.1 完整项目构建 (25分)

**题目**: 构建一个完整的 Rust WebAssembly 应用，包含：
- 项目架构设计
- 模块化开发
- 测试和基准测试
- 构建优化
- 部署配置

<details>
<summary>🔍 参考答案</summary>

此练习将在后续完成，包含完整的项目开发流程和最佳实践。

</details>

---

## 本章练习总结

本章练习涵盖了 Rust WebAssembly 开发的核心技能：

### 🎯 学习目标达成

1. **环境配置掌握** - 能够正确配置和验证 Rust WebAssembly 开发环境
2. **类型系统理解** - 深入理解 Rust 和 JavaScript 之间的类型映射
3. **内存操作实践** - 掌握高性能的内存操作和数据处理
4. **异步编程应用** - 学会在 WebAssembly 中实现异步操作和 Promise 集成
5. **项目开发能力** - 具备完整项目的开发和优化能力

### 📈 难度递进

- **基础练习 (10-15分)** - 环境配置、基本编译、类型验证
- **进阶练习 (15-20分)** - 内存操作、性能优化、错误处理
- **高级练习 (20-30分)** - 异步编程、复杂项目架构
- **综合项目 (25-30分)** - 完整应用开发、部署优化

### 🔧 关键技能

1. **工具链熟练度** - wasm-pack、wasm-bindgen、cargo 等工具的熟练使用
2. **性能优化** - 代码优化、内存管理、编译优化的实践经验
3. **JavaScript 集成** - 深度理解 Rust 和 JavaScript 的互操作
4. **错误处理** - 健壮的错误处理和调试技能
5. **项目管理** - 模块化设计、测试驱动开发、CI/CD 集成

通过这些练习的完成，学习者将具备使用 Rust 开发高性能 WebAssembly 应用的完整技能栈。
