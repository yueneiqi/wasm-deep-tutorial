# 第2章 练习题

## 环境配置验证题

### 1. 工具链安装验证 (15分)

**题目**：请在你的系统上安装 WABT 工具集，并完成以下任务：

1. 验证 `wat2wasm` 和 `wasm2wat` 命令是否可用
2. 创建一个简单的 WAT 文件，包含一个返回常数的函数
3. 编译为 WASM 并反编译验证结果一致性

**要求**：提供完整的命令行输出截图或文本记录

<details>
<summary>🔍 参考答案</summary>

**1. 验证工具安装**
```bash
# 检查工具版本
$ wat2wasm --version
1.0.34

$ wasm2wat --version  
1.0.34

$ wasm-validate --version
1.0.34
```

**2. 创建 WAT 文件 (simple.wat)**
```wat
(module
  (func $getAnswer (result i32)
    i32.const 42)
  (export "getAnswer" (func $getAnswer)))
```

**3. 编译和反编译验证**
```bash
# 编译 WAT 到 WASM
$ wat2wasm simple.wat -o simple.wasm
$ echo "编译成功，生成 simple.wasm"

# 验证 WASM 文件有效性
$ wasm-validate simple.wasm
$ echo "WASM 文件验证通过"

# 反编译 WASM 到 WAT
$ wasm2wat simple.wasm -o simple_decompiled.wat

# 比较原始文件和反编译文件
$ diff simple.wat simple_decompiled.wat
# 注意：格式可能略有不同，但语义应该相同
```

**预期的反编译结果：**
```wat
(module
  (type (;0;) (func (result i32)))
  (func $getAnswer (type 0) (result i32)
    i32.const 42)
  (export "getAnswer" (func $getAnswer)))
```

**验证要点：**
- 工具能正常运行且显示版本信息
- WAT 文件语法正确，能成功编译
- WASM 文件通过验证
- 反编译结果在语义上与原文件一致
</details>

### 2. Emscripten 环境配置 (20分)

**题目**：安装并配置 Emscripten 开发环境，完成以下任务：

1. 安装 Emscripten SDK
2. 编写一个简单的 C 程序计算两个数的乘积
3. 使用 Emscripten 编译为 WebAssembly
4. 创建 HTML 页面调用编译后的函数

<details>
<summary>🔍 参考答案</summary>

**1. 安装 Emscripten SDK**
```bash
# 克隆 emsdk 仓库
$ git clone https://github.com/emscripten-core/emsdk.git
$ cd emsdk

# 安装最新版本
$ ./emsdk install latest
$ ./emsdk activate latest

# 设置环境变量
$ source ./emsdk_env.sh

# 验证安装
$ emcc --version
emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 3.1.51
```

**2. 编写 C 程序 (multiply.c)**
```c
#include <emscripten.h>

// 导出函数到 JavaScript
EMSCRIPTEN_KEEPALIVE
int multiply(int a, int b) {
    return a * b;
}

// 主函数（可选）
int main() {
    return 0;
}
```

**3. 编译为 WebAssembly**
```bash
# 编译命令
$ emcc multiply.c -o multiply.html \
    -s EXPORTED_FUNCTIONS='["_multiply"]' \
    -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
    -s WASM=1

# 生成的文件
$ ls multiply.*
multiply.html  multiply.js  multiply.wasm
```

**4. 创建测试页面 (test.html)**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Emscripten WASM 测试</title>
</head>
<body>
    <h1>C 函数调用测试</h1>
    <button onclick="testMultiply()">测试乘法函数</button>
    <div id="result"></div>

    <script src="multiply.js"></script>
    <script>
        // 等待模块加载完成
        Module.onRuntimeInitialized = function() {
            console.log('Emscripten 模块已加载');
            
            // 包装 C 函数
            window.multiply = Module.cwrap('multiply', 'number', ['number', 'number']);
        };

        function testMultiply() {
            if (typeof window.multiply !== 'function') {
                document.getElementById('result').innerHTML = 
                    '<p style="color: red;">模块尚未加载完成</p>';
                return;
            }

            const a = 7;
            const b = 6;
            const result = window.multiply(a, b);
            
            document.getElementById('result').innerHTML = 
                `<p>C 函数计算结果: ${a} × ${b} = ${result}</p>`;
            
            console.log(`multiply(${a}, ${b}) = ${result}`);
        }
    </script>
</body>
</html>
```

**5. 运行测试**
```bash
# 启动 HTTP 服务器
$ python -m http.server 8000

# 在浏览器中访问 http://localhost:8000/test.html
# 点击按钮测试功能
```

**预期结果：**
- 页面正常加载，无控制台错误
- 点击按钮后显示 "C 函数计算结果: 7 × 6 = 42"
- 控制台输出相应的日志信息
</details>

### 3. Rust WASM 环境配置 (20分)

**题目**：配置 Rust WebAssembly 开发环境，并实现一个字符串处理函数：

1. 安装 Rust 和 wasm-pack
2. 创建一个 Rust 库项目
3. 实现一个函数来统计字符串中某个字符的出现次数
4. 编译为 WASM 并在网页中测试

<details>
<summary>🔍 参考答案</summary>

**1. 环境安装**
```bash
# 安装 Rust（如果尚未安装）
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
$ source ~/.cargo/env

# 添加 WASM 目标
$ rustup target add wasm32-unknown-unknown

# 安装 wasm-pack
$ curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# 验证安装
$ rustc --version
$ wasm-pack --version
```

**2. 创建 Rust 项目**
```bash
$ cargo new --lib string-utils
$ cd string-utils
```

**3. 配置 Cargo.toml**
```toml
[package]
name = "string-utils"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
]
```

**4. 实现字符串处理函数 (src/lib.rs)**
```rust
use wasm_bindgen::prelude::*;

// 导入 console.log
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 便利宏
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 统计字符出现次数
#[wasm_bindgen]
pub fn count_char(text: &str, target: char) -> usize {
    let count = text.chars().filter(|&c| c == target).count();
    console_log!("统计字符 '{}' 在 '{}' 中出现了 {} 次", target, text, count);
    count
}

// 字符串反转
#[wasm_bindgen]
pub fn reverse_string(text: &str) -> String {
    let reversed: String = text.chars().rev().collect();
    console_log!("原字符串: '{}', 反转后: '{}'", text, reversed);
    reversed
}

// 字符串长度（UTF-8 字符数）
#[wasm_bindgen]
pub fn char_length(text: &str) -> usize {
    let len = text.chars().count();
    console_log!("字符串 '{}' 的字符数: {}", text, len);
    len
}

// 初始化函数
#[wasm_bindgen(start)]
pub fn main() {
    console_log!("Rust WASM 字符串工具模块已加载");
}
```

**5. 编译项目**
```bash
$ wasm-pack build --target web
```

**6. 创建测试页面 (index.html)**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Rust WASM 字符串工具测试</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .test-group { margin: 20px 0; padding: 15px; border: 1px solid #ccc; }
        input, button { margin: 5px; padding: 8px; }
        .result { margin: 10px 0; font-weight: bold; color: #2196F3; }
    </style>
</head>
<body>
    <h1>Rust WebAssembly 字符串工具</h1>
    
    <div class="test-group">
        <h3>字符计数测试</h3>
        <input type="text" id="countText" placeholder="输入文本" value="Hello World">
        <input type="text" id="countChar" placeholder="要统计的字符" value="l" maxlength="1">
        <button onclick="testCountChar()">统计字符</button>
        <div id="countResult" class="result"></div>
    </div>
    
    <div class="test-group">
        <h3>字符串反转测试</h3>
        <input type="text" id="reverseText" placeholder="输入文本" value="Hello WebAssembly">
        <button onclick="testReverse()">反转字符串</button>
        <div id="reverseResult" class="result"></div>
    </div>
    
    <div class="test-group">
        <h3>字符长度测试</h3>
        <input type="text" id="lengthText" placeholder="输入文本" value="你好,WebAssembly!">
        <button onclick="testLength()">计算长度</button>
        <div id="lengthResult" class="result"></div>
    </div>

    <script type="module">
        import init, { count_char, reverse_string, char_length } from './pkg/string_utils.js';
        
        async function run() {
            await init();
            console.log('Rust WASM 模块加载完成');
            
            // 将函数绑定到全局作用域
            window.count_char = count_char;
            window.reverse_string = reverse_string;
            window.char_length = char_length;
        }
        
        window.testCountChar = function() {
            const text = document.getElementById('countText').value;
            const char = document.getElementById('countChar').value;
            
            if (char.length !== 1) {
                alert('请输入单个字符');
                return;
            }
            
            const count = window.count_char(text, char);
            document.getElementById('countResult').textContent = 
                `字符 '${char}' 在 "${text}" 中出现了 ${count} 次`;
        };
        
        window.testReverse = function() {
            const text = document.getElementById('reverseText').value;
            const reversed = window.reverse_string(text);
            document.getElementById('reverseResult').textContent = 
                `"${text}" 反转后: "${reversed}"`;
        };
        
        window.testLength = function() {
            const text = document.getElementById('lengthText').value;
            const length = window.char_length(text);
            document.getElementById('lengthResult').textContent = 
                `"${text}" 的字符长度: ${length}`;
        };
        
        run();
    </script>
</body>
</html>
```

**7. 测试运行**
```bash
# 启动服务器
$ python -m http.server 8000

# 在浏览器中打开 http://localhost:8000
# 测试各个功能
```

**预期结果：**
- 字符计数：输入 "Hello World" 和 "l"，应显示 "字符 'l' 在 "Hello World" 中出现了 3 次"
- 字符串反转：输入 "Hello WebAssembly"，应显示反转结果
- 字符长度：输入中文字符串，正确显示 UTF-8 字符数
</details>

## 编辑器配置题

### 4. VS Code 工作区配置 (15分)

**题目**：为 WebAssembly 项目配置 VS Code 工作区，要求：

1. 安装必要的扩展插件
2. 配置自动构建任务
3. 设置调试配置
4. 创建代码片段模板

<details>
<summary>🔍 参考答案</summary>

**1. 扩展插件列表 (.vscode/extensions.json)**
```json
{
    "recommendations": [
        "ms-vscode.vscode-wasm",
        "rust-lang.rust-analyzer", 
        "ms-vscode.cpptools",
        "ritwickdey.liveserver",
        "ms-vscode.cmake-tools"
    ]
}
```

**2. 工作区设置 (.vscode/settings.json)**
```json
{
    "files.associations": {
        "*.wat": "wasm",
        "*.wast": "wasm"
    },
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.formatOnSave": true,
    "rust-analyzer.cargo.allFeatures": true,
    "rust-analyzer.checkOnSave.command": "clippy",
    "C_Cpp.default.cStandard": "c11",
    "C_Cpp.default.cppStandard": "c++17",
    "liveServer.settings.port": 8080,
    "liveServer.settings.CustomBrowser": "chrome"
}
```

**3. 构建任务配置 (.vscode/tasks.json)**
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build WAT to WASM",
            "type": "shell",
            "command": "wat2wasm",
            "args": [
                "${file}",
                "-o",
                "${fileDirname}/${fileBasenameNoExtension}.wasm"
            ],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            },
            "problemMatcher": []
        },
        {
            "label": "Build Rust WASM",
            "type": "shell",
            "command": "wasm-pack",
            "args": ["build", "--target", "web"],
            "group": "build",
            "options": {
                "cwd": "${workspaceFolder}"
            },
            "presentation": {
                "echo": true,
                "reveal": "always"
            }
        },
        {
            "label": "Build C/C++ with Emscripten",
            "type": "shell",
            "command": "emcc",
            "args": [
                "${file}",
                "-o",
                "${fileDirname}/${fileBasenameNoExtension}.html",
                "-s", "WASM=1",
                "-s", "EXPORTED_RUNTIME_METHODS=['ccall','cwrap']"
            ],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always"
            }
        },
        {
            "label": "Start HTTP Server",
            "type": "shell",
            "command": "python",
            "args": ["-m", "http.server", "8000"],
            "group": "test",
            "isBackground": true,
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        }
    ]
}
```

**4. 调试配置 (.vscode/launch.json)**
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "chrome",
            "request": "launch",
            "name": "Launch Chrome against localhost",
            "url": "http://localhost:8000",
            "webRoot": "${workspaceFolder}",
            "sourceMaps": true
        },
        {
            "type": "node",
            "request": "launch",
            "name": "Debug WASM in Node.js",
            "program": "${workspaceFolder}/test.js",
            "console": "integratedTerminal"
        }
    ]
}
```

**5. 代码片段 (.vscode/wasm.code-snippets)**
```json
{
    "WAT Module Template": {
        "prefix": "wat-module",
        "body": [
            "(module",
            "  (func $$${1:function_name} (param $$${2:param} ${3:i32}) (result ${4:i32})",
            "    ${5:// function body}",
            "    local.get $$${2:param})",
            "  (export \"${1:function_name}\" (func $$${1:function_name})))"
        ],
        "description": "Basic WAT module template"
    },
    "Rust WASM Function": {
        "prefix": "rust-wasm-fn",
        "body": [
            "#[wasm_bindgen]",
            "pub fn ${1:function_name}(${2:param}: ${3:i32}) -> ${4:i32} {",
            "    ${5:// function body}",
            "    ${2:param}",
            "}"
        ],
        "description": "Rust WebAssembly function template"
    },
    "HTML WASM Loader": {
        "prefix": "html-wasm",
        "body": [
            "<!DOCTYPE html>",
            "<html>",
            "<head>",
            "    <title>${1:WASM Test}</title>",
            "</head>",
            "<body>",
            "    <script>",
            "        async function loadWasm() {",
            "            const wasmModule = await WebAssembly.instantiateStreaming(",
            "                fetch('${2:module.wasm}')",
            "            );",
            "            ",
            "            // Use wasmModule.instance.exports here",
            "            console.log(wasmModule.instance.exports);",
            "        }",
            "        ",
            "        loadWasm();",
            "    </script>",
            "</body>",
            "</html>"
        ],
        "description": "HTML template for loading WASM"
    }
}
```

**使用方法：**
- 按 `Ctrl+Shift+P` 打开命令面板
- 输入任务名称执行构建任务
- 按 `F5` 启动调试
- 输入代码片段前缀快速生成模板代码
</details>

## 调试工具题

### 5. 浏览器调试实践 (20分)

**题目**：使用浏览器开发者工具调试 WebAssembly，完成以下任务：

1. 创建一个有 bug 的 WASM 程序（例如数组越界）
2. 在 Chrome DevTools 中设置断点
3. 检查内存状态和变量值
4. 修复 bug 并验证修复效果

<details>
<summary>🔍 参考答案</summary>

**1. 创建有 bug 的程序 (buggy.wat)**
```wat
(module
  (memory (export "memory") 1)
  
  ;; 数组求和函数 - 包含越界访问 bug
  (func $sum_array (param $ptr i32) (param $len i32) (result i32)
    (local $i i32)
    (local $sum i32)
    
    (loop $loop
      ;; Bug: 没有检查边界，可能访问越界
      (local.set $sum
        (i32.add
          (local.get $sum)
          (i32.load (local.get $ptr))))
      
      ;; 递增指针和计数器
      (local.set $ptr (i32.add (local.get $ptr) (i32.const 4)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; Bug: 应该是 i32.lt_u 而不是 i32.le_u
      (br_if $loop (i32.le_u (local.get $i) (local.get $len)))
    )
    
    local.get $sum)
  
  ;; 初始化数组
  (func $init_array (param $ptr i32)
    ;; 在内存中写入测试数据: [1, 2, 3, 4, 5]
    (i32.store (local.get $ptr) (i32.const 1))
    (i32.store (i32.add (local.get $ptr) (i32.const 4)) (i32.const 2))
    (i32.store (i32.add (local.get $ptr) (i32.const 8)) (i32.const 3))
    (i32.store (i32.add (local.get $ptr) (i32.const 12)) (i32.const 4))
    (i32.store (i32.add (local.get $ptr) (i32.const 16)) (i32.const 5)))
  
  (export "sum_array" (func $sum_array))
  (export "init_array" (func $init_array)))
```

**2. 编译和测试页面**
```bash
$ wat2wasm buggy.wat -o buggy.wasm
```

**测试页面 (debug.html)**
```html
<!DOCTYPE html>
<html>
<head>
    <title>WebAssembly 调试练习</title>
</head>
<body>
    <h1>WebAssembly 调试练习</h1>
    <button onclick="testBuggyFunction()">测试有 bug 的函数</button>
    <button onclick="testFixedFunction()">测试修复后的函数</button>
    <div id="result"></div>

    <script>
        let wasmModule;
        
        async function loadWasm() {
            wasmModule = await WebAssembly.instantiateStreaming(fetch('buggy.wasm'));
            console.log('WASM 模块已加载');
        }
        
        function testBuggyFunction() {
            if (!wasmModule) {
                alert('WASM 模块尚未加载');
                return;
            }
            
            const { memory, init_array, sum_array } = wasmModule.instance.exports;
            
            // 在内存起始位置初始化数组
            const arrayPtr = 0;
            init_array(arrayPtr);
            
            // 设置断点的好位置
            debugger; // 浏览器会在这里停止
            
            // 调用有 bug 的求和函数
            const result = sum_array(arrayPtr, 5); // 期望结果: 1+2+3+4+5 = 15
            
            // 检查内存内容
            const view = new Int32Array(memory.buffer, 0, 10);
            console.log('内存内容:', view);
            console.log('求和结果:', result);
            
            document.getElementById('result').innerHTML = `
                <p>数组内容: [${Array.from(view.slice(0, 5)).join(', ')}]</p>
                <p>求和结果: ${result} (期望: 15)</p>
                <p style="color: ${result === 15 ? 'green' : 'red'}">
                    ${result === 15 ? '✓ 正确' : '✗ 有 bug'}
                </p>
            `;
        }
        
        async function testFixedFunction() {
            // 加载修复后的版本
            const fixedModule = await WebAssembly.instantiateStreaming(fetch('fixed.wasm'));
            const { memory, init_array, sum_array } = fixedModule.instance.exports;
            
            const arrayPtr = 0;
            init_array(arrayPtr);
            
            const result = sum_array(arrayPtr, 5);
            const view = new Int32Array(memory.buffer, 0, 5);
            
            document.getElementById('result').innerHTML += `
                <hr>
                <p><strong>修复后:</strong></p>
                <p>数组内容: [${Array.from(view).join(', ')}]</p>
                <p>求和结果: ${result} (期望: 15)</p>
                <p style="color: green">✓ 已修复</p>
            `;
        }
        
        loadWasm();
    </script>
</body>
</html>
```

**3. 调试步骤**

在 Chrome DevTools 中：

1. **设置断点**
   - 打开 Sources 面板
   - 找到 `debug.html` 文件
   - 在 `debugger;` 行设置断点

2. **检查内存状态**
   ```javascript
   // 在控制台中执行
   const memory = wasmModule.instance.exports.memory;
   const view = new Int32Array(memory.buffer, 0, 10);
   console.table(view);
   ```

3. **检查 WASM 函数执行**
   - 在 Sources 面板中查看 WAT 代码
   - 观察局部变量值
   - 跟踪循环执行

**4. 修复后的代码 (fixed.wat)**
```wat
(module
  (memory (export "memory") 1)
  
  ;; 修复后的数组求和函数
  (func $sum_array (param $ptr i32) (param $len i32) (result i32)
    (local $i i32)
    (local $sum i32)
    
    (loop $loop
      ;; 修复1: 添加边界检查
      (if (i32.ge_u (local.get $i) (local.get $len))
        (then (br $loop))) ;; 跳出循环
      
      (local.set $sum
        (i32.add
          (local.get $sum)
          (i32.load (local.get $ptr))))
      
      (local.set $ptr (i32.add (local.get $ptr) (i32.const 4)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; 修复2: 使用 i32.lt_u 而不是 i32.le_u
      (br_if $loop (i32.lt_u (local.get $i) (local.get $len)))
    )
    
    local.get $sum)
  
  (func $init_array (param $ptr i32)
    (i32.store (local.get $ptr) (i32.const 1))
    (i32.store (i32.add (local.get $ptr) (i32.const 4)) (i32.const 2))
    (i32.store (i32.add (local.get $ptr) (i32.const 8)) (i32.const 3))
    (i32.store (i32.add (local.get $ptr) (i32.const 12)) (i32.const 4))
    (i32.store (i32.add (local.get $ptr) (i32.const 16)) (i32.const 5)))
  
  (export "sum_array" (func $sum_array))
  (export "init_array" (func $init_array)))
```

**调试发现的问题：**
1. 循环条件错误：使用 `<=` 而不是 `<`，导致多执行一次
2. 缺少边界检查，可能访问未初始化的内存
3. 循环可能读取到垃圾数据

**验证修复效果：**
- 原版本可能返回不正确的结果
- 修复版本应该返回 15 (1+2+3+4+5)
</details>

### 6. 性能分析工具使用 (10分)

**题目**：使用浏览器性能分析工具比较不同 WebAssembly 实现的性能差异。

**要求**：
1. 实现同一算法的两个版本（优化前后）
2. 使用 Performance 面板进行性能分析
3. 对比并解释性能差异

<details>
<summary>🔍 参考答案</summary>

**1. 未优化版本 (slow.wat)**
```wat
(module
  ;; 计算斐波那契数列 - 递归版本（性能较差）
  (func $fibonacci_slow (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (local.get $n))
      (else
        (i32.add
          (call $fibonacci_slow
            (i32.sub (local.get $n) (i32.const 1)))
          (call $fibonacci_slow
            (i32.sub (local.get $n) (i32.const 2)))))))
  
  (export "fibonacci" (func $fibonacci_slow)))
```

**2. 优化版本 (fast.wat)**
```wat
(module
  ;; 计算斐波那契数列 - 迭代版本（性能较好）
  (func $fibonacci_fast (param $n i32) (result i32)
    (local $a i32)
    (local $b i32)
    (local $temp i32)
    (local $i i32)
    
    ;; 处理边界情况
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (local.get $n))
      (else
        ;; 初始化
        (local.set $a (i32.const 0))
        (local.set $b (i32.const 1))
        (local.set $i (i32.const 2))
        
        ;; 迭代计算
        (loop $loop
          (local.set $temp (i32.add (local.get $a) (local.get $b)))
          (local.set $a (local.get $b))
          (local.set $b (local.get $temp))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          
          (br_if $loop (i32.le_s (local.get $i) (local.get $n)))
        )
        
        local.get $b)))
  
  (export "fibonacci" (func $fibonacci_fast)))
```

**3. 性能测试页面 (performance.html)**
```html
<!DOCTYPE html>
<html>
<head>
    <title>WebAssembly 性能分析</title>
    <style>
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ccc; }
        .result { margin: 10px 0; font-family: monospace; }
        .fast { color: green; }
        .slow { color: red; }
    </style>
</head>
<body>
    <h1>WebAssembly 性能分析</h1>
    
    <div class="test-section">
        <h3>斐波那契数列计算性能对比</h3>
        <p>在 Performance 面板中录制性能数据</p>
        <button onclick="runPerformanceTest()">开始性能测试</button>
        <button onclick="runDetailedTest()">详细性能测试</button>
        <div id="results"></div>
    </div>

    <script>
        let slowModule, fastModule;
        
        async function loadModules() {
            try {
                slowModule = await WebAssembly.instantiateStreaming(fetch('slow.wasm'));
                fastModule = await WebAssembly.instantiateStreaming(fetch('fast.wasm'));
                console.log('两个模块都已加载成功');
            } catch (error) {
                console.error('模块加载失败:', error);
            }
        }
        
        function measureTime(fn, label) {
            const start = performance.now();
            const result = fn();
            const end = performance.now();
            const duration = end - start;
            
            console.log(`${label}: ${duration.toFixed(4)}ms, 结果: ${result}`);
            return { duration, result };
        }
        
        async function runPerformanceTest() {
            if (!slowModule || !fastModule) {
                alert('模块尚未加载完成');
                return;
            }
            
            const n = 35; // 足够大的数字来显示性能差异
            
            // 开始性能记录（告诉用户在 DevTools 中手动开始）
            console.log('开始性能测试 - 请在 DevTools Performance 面板中点击录制');
            
            // 测试慢速版本
            performance.mark('slow-start');
            const slowResult = measureTime(
                () => slowModule.instance.exports.fibonacci(n),
                `递归版本 fibonacci(${n})`
            );
            performance.mark('slow-end');
            performance.measure('Slow Fibonacci', 'slow-start', 'slow-end');
            
            // 短暂延迟
            await new Promise(resolve => setTimeout(resolve, 100));
            
            // 测试快速版本
            performance.mark('fast-start');
            const fastResult = measureTime(
                () => fastModule.instance.exports.fibonacci(n),
                `迭代版本 fibonacci(${n})`
            );
            performance.mark('fast-end');
            performance.measure('Fast Fibonacci', 'fast-start', 'fast-end');
            
            // 显示结果
            const speedup = slowResult.duration / fastResult.duration;
            document.getElementById('results').innerHTML = `
                <div class="result">
                    <h4>性能测试结果 (fibonacci(${n})):</h4>
                    <p class="slow">递归版本: ${slowResult.duration.toFixed(4)}ms</p>
                    <p class="fast">迭代版本: ${fastResult.duration.toFixed(4)}ms</p>
                    <p><strong>性能提升: ${speedup.toFixed(2)}x</strong></p>
                    <p>结果验证: ${slowResult.result === fastResult.result ? '✓ 一致' : '✗ 不一致'}</p>
                </div>
            `;
            
            console.log('性能测试完成 - 可以在 DevTools Performance 面板中停止录制并查看结果');
        }
        
        async function runDetailedTest() {
            if (!slowModule || !fastModule) {
                alert('模块尚未加载完成');
                return;
            }
            
            const testCases = [25, 30, 35, 40];
            let results = '<h4>详细性能对比:</h4><table border="1"><tr><th>n</th><th>递归版本(ms)</th><th>迭代版本(ms)</th><th>性能提升</th></tr>';
            
            for (const n of testCases) {
                console.log(`测试 fibonacci(${n})`);
                
                const slowResult = measureTime(
                    () => slowModule.instance.exports.fibonacci(n),
                    `递归 fibonacci(${n})`
                );
                
                const fastResult = measureTime(
                    () => fastModule.instance.exports.fibonacci(n),
                    `迭代 fibonacci(${n})`
                );
                
                const speedup = slowResult.duration / fastResult.duration;
                
                results += `<tr>
                    <td>${n}</td>
                    <td class="slow">${slowResult.duration.toFixed(4)}</td>
                    <td class="fast">${fastResult.duration.toFixed(4)}</td>
                    <td>${speedup.toFixed(2)}x</td>
                </tr>`;
                
                // 避免阻塞 UI
                await new Promise(resolve => setTimeout(resolve, 10));
            }
            
            results += '</table>';
            document.getElementById('results').innerHTML = results;
        }
        
        // 页面加载时自动加载模块
        loadModules();
    </script>
</body>
</html>
```

**4. 性能分析步骤**

1. **录制性能数据**
   - 打开 Chrome DevTools
   - 切换到 Performance 面板
   - 点击录制按钮（圆点图标）
   - 在页面中点击"开始性能测试"
   - 等待测试完成后停止录制

2. **分析性能数据**
   - 查看 Main 线程的活动
   - 找到 WebAssembly 执行的时间段
   - 对比两个版本的执行时间和 CPU 使用情况

3. **关键指标**
   - **执行时间**：递归版本应该显著慢于迭代版本
   - **调用堆栈深度**：递归版本会有很深的调用堆栈
   - **内存使用**：递归版本可能使用更多栈内存

**预期结果：**
- fibonacci(35) 递归版本可能需要几百毫秒
- 迭代版本应该在几毫秒内完成
- 性能提升可能达到 100-1000 倍

**性能分析结论：**
- 算法复杂度对性能的巨大影响
- WebAssembly 中递归调用的开销
- 迭代算法的优势体现
</details>

## 评分标准

| 题目类型 | 分值分布 | 评分要点 |
|---------|---------|----------|
| **环境配置** | 55分 | 工具安装正确性、配置完整性、功能验证 |
| **编辑器配置** | 15分 | 配置文件格式、实用性、完整性 |
| **调试实践** | 30分 | 调试技能、问题分析、解决方案 |

**总分：100分**
**及格线：60分**

---

**🎯 学习要点**：
- 确保所有工具正常安装并可用
- 掌握基本的调试技能和工具使用
- 理解不同编译工具链的特点和适用场景
- 能够配置高效的开发环境