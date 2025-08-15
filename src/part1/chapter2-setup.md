# 第2章 开发环境搭建

本章将指导你搭建完整的 WebAssembly 开发环境，包括必要的工具安装、编辑器配置和调试工具设置。

## 必要工具安装

### 2.1.1 WebAssembly 工具链

**1. WABT (WebAssembly Binary Toolkit)**

WABT 是 WebAssembly 的官方工具集，提供了二进制格式和文本格式之间的转换工具。

```bash
# Ubuntu/Debian
sudo apt-get install wabt

# macOS
brew install wabt

# 从源码编译
git clone --recursive https://github.com/WebAssembly/wabt
cd wabt
mkdir build && cd build
cmake .. && make

# 验证安装
wat2wasm --version
wasm2wat --version
```

**主要工具说明：**
- `wat2wasm`：将 WAT 文本格式编译为 WASM 二进制格式
- `wasm2wat`：将 WASM 二进制格式反编译为 WAT 文本格式
- `wasm-validate`：验证 WASM 文件的有效性
- `wasm-objdump`：查看 WASM 文件的详细信息

**2. Emscripten SDK**

Emscripten 是将 C/C++ 代码编译为 WebAssembly 的完整工具链。

```bash
# 下载 emsdk
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# 安装最新版本
./emsdk install latest
./emsdk activate latest

# 设置环境变量
source ./emsdk_env.sh

# 验证安装
emcc --version
em++ --version
```

**3. wasm-pack (Rust 工具链)**

wasm-pack 是 Rust 生态系统中最重要的 WebAssembly 工具。

```bash
# 安装 Rust (如果尚未安装)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 添加 wasm32 目标
rustup target add wasm32-unknown-unknown

# 安装 wasm-pack
curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# 验证安装
wasm-pack --version
```

### 2.1.2 Node.js 环境

Node.js 提供了服务器端的 WebAssembly 运行时环境。

```bash
# 安装 Node.js (建议使用 LTS 版本)
# 方法1: 使用包管理器
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node

# 方法2: 使用 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts
nvm use --lts

# 验证安装
node --version
npm --version
```

### 2.1.3 HTTP 服务器

由于 CORS 限制，WebAssembly 文件需要通过 HTTP 服务器加载。

```bash
# 方法1: 使用 Python 内置服务器
# Python 3
python -m http.server 8000

# Python 2
python -m SimpleHTTPServer 8000

# 方法2: 使用 Node.js 工具
npm install -g http-server
http-server -p 8000

# 方法3: 使用 Live Server (VS Code 插件)
# 在 VS Code 中安装 Live Server 扩展
```

## 编辑器配置

### 2.2.1 Visual Studio Code 配置

VS Code 是 WebAssembly 开发的首选编辑器，提供了丰富的插件支持。

**推荐插件：**

1. **WebAssembly**
   ```bash
   # 扩展ID: ms-vscode.vscode-wasm
   ```
   - 提供 WAT 语法高亮
   - 支持 WASM 文件查看

2. **Rust Analyzer**
   ```bash
   # 扩展ID: rust-lang.rust-analyzer
   ```
   - Rust 语言服务器
   - 智能补全和错误检查

3. **C/C++**
   ```bash
   # 扩展ID: ms-vscode.cpptools
   ```
   - C/C++ 语言支持
   - 调试功能

4. **Live Server**
   ```bash
   # 扩展ID: ritwickdey.liveserver
   ```
   - 本地开发服务器
   - 自动刷新功能

**配置文件示例：**

```json
// .vscode/settings.json
{
    "files.associations": {
        "*.wat": "wasm",
        "*.wast": "wasm"
    },
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "rust-analyzer.cargo.allFeatures": true,
    "rust-analyzer.checkOnSave.command": "clippy"
}
```

```json
// .vscode/tasks.json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build WAT",
            "type": "shell",
            "command": "wat2wasm",
            "args": ["${file}", "-o", "${fileDirname}/${fileBasenameNoExtension}.wasm"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        },
        {
            "label": "Build Rust WASM",
            "type": "shell",
            "command": "wasm-pack",
            "args": ["build", "--target", "web"],
            "group": "build",
            "options": {
                "cwd": "${workspaceFolder}"
            }
        }
    ]
}
```

### 2.2.2 其他编辑器配置

**Vim/Neovim 配置：**

```vim
" ~/.vimrc 或 ~/.config/nvim/init.vim
" WebAssembly 语法高亮
au BufRead,BufNewFile *.wat set filetype=wasm
au BufRead,BufNewFile *.wast set filetype=wasm

" 安装 vim-wasm 插件 (使用 vim-plug)
Plug 'rhysd/vim-wasm'
```

**Emacs 配置：**

```elisp
;; ~/.emacs.d/init.el
(use-package wasm-mode
  :ensure t
  :mode "\\.wat\\'")
```

## 浏览器调试工具

### 2.3.1 Chrome DevTools

Chrome 提供了最完善的 WebAssembly 调试支持。

**启用 WebAssembly 调试：**

1. 打开 Chrome DevTools (F12)
2. 进入 Settings (F1)
3. 启用 "Enable WebAssembly Debugging"
4. 重启 DevTools

**调试功能：**

- **Sources 面板**：查看 WAT 源码
- **Memory 面板**：检查 WebAssembly 内存
- **Performance 面板**：性能分析
- **Console**：执行 WebAssembly 函数

**使用示例：**

```javascript
// 在控制台中调试 WebAssembly
const wasmModule = await WebAssembly.instantiateStreaming(fetch('module.wasm'));

// 检查导出的函数
console.log(wasmModule.instance.exports);

// 调用函数并设置断点
const result = wasmModule.instance.exports.add(5, 3);
console.log('Result:', result);

// 检查内存
const memory = wasmModule.instance.exports.memory;
const view = new Int32Array(memory.buffer, 0, 10);
console.log('Memory view:', view);
```

### 2.3.2 Firefox Developer Tools

Firefox 也提供了 WebAssembly 调试支持。

**启用方法：**
1. 打开 `about:config`
2. 设置 `devtools.debugger.features.wasm` 为 true
3. 重启浏览器

### 2.3.3 专用调试工具

**1. wasm-objdump**

```bash
# 查看 WASM 文件信息
wasm-objdump -x module.wasm

# 反汇编到 WAT 格式
wasm-objdump -d module.wasm

# 查看导入/导出
wasm-objdump -j import module.wasm
wasm-objdump -j export module.wasm
```

**2. Wasmtime**

Wasmtime 是一个独立的 WebAssembly 运行时，支持命令行调试。

```bash
# 安装 Wasmtime
curl https://wasmtime.dev/install.sh -sSf | bash

# 运行 WASM 文件
wasmtime module.wasm

# 启用调试模式
wasmtime --debug module.wasm
```

## 开发环境验证

### 2.4.1 创建测试项目

创建一个简单的项目来验证环境配置：

```bash
mkdir wasm-test-project
cd wasm-test-project
```

**1. WAT 测试文件 (hello.wat)：**

```wat
(module
  (import "console" "log" (func $log (param i32)))
  (func $hello
    i32.const 42
    call $log)
  (export "hello" (func $hello)))
```

**2. 编译 WAT 文件：**

```bash
wat2wasm hello.wat -o hello.wasm
```

**3. HTML 测试页面 (index.html)：**

```html
<!DOCTYPE html>
<html>
<head>
    <title>WASM 环境测试</title>
</head>
<body>
    <h1>WebAssembly 环境测试</h1>
    <button onclick="testWasm()">测试 WASM</button>
    <div id="output"></div>

    <script>
        const imports = {
            console: {
                log: (arg) => {
                    const output = document.getElementById('output');
                    output.innerHTML += `<p>WASM 输出: ${arg}</p>`;
                    console.log('从 WASM 调用:', arg);
                }
            }
        };

        async function testWasm() {
            try {
                const wasmModule = await WebAssembly.instantiateStreaming(
                    fetch('hello.wasm'), 
                    imports
                );
                
                wasmModule.instance.exports.hello();
                
                const output = document.getElementById('output');
                output.innerHTML += '<p style="color: green;">✓ WebAssembly 环境配置成功！</p>';
            } catch (error) {
                console.error('WASM 加载失败:', error);
                const output = document.getElementById('output');
                output.innerHTML += `<p style="color: red;">✗ 错误: ${error.message}</p>`;
            }
        }
    </script>
</body>
</html>
```

**4. 启动服务器测试：**

```bash
# 启动 HTTP 服务器
python -m http.server 8000

# 在浏览器中打开 http://localhost:8000
# 点击 "测试 WASM" 按钮
```

### 2.4.2 Rust WASM 测试

**1. 创建 Rust 项目：**

```bash
cargo new --lib rust-wasm-test
cd rust-wasm-test
```

**2. 配置 Cargo.toml：**

```toml
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
```

**3. 编写 Rust 代码 (src/lib.rs)：**

```rust
use wasm_bindgen::prelude::*;

// 绑定 console.log 函数
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// 定义 console_log 宏
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 导出函数到 JavaScript
#[wasm_bindgen]
pub fn greet(name: &str) {
    console_log!("Hello, {}!", name);
}

#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

**4. 构建项目：**

```bash
wasm-pack build --target web
```

**5. 测试生成的文件：**

```html
<!DOCTYPE html>
<html>
<head>
    <title>Rust WASM 测试</title>
</head>
<body>
    <h1>Rust WebAssembly 测试</h1>
    <script type="module">
        import init, { greet, add } from './pkg/rust_wasm_test.js';
        
        async function run() {
            await init();
            
            greet('WebAssembly');
            const result = add(5, 3);
            console.log('5 + 3 =', result);
            
            document.body.innerHTML += `<p>Rust WASM 计算结果: 5 + 3 = ${result}</p>`;
        }
        
        run();
    </script>
</body>
</html>
```

## 环境诊断与故障排除

### 2.5.1 常见问题

**1. CORS 错误**
```
错误: Access to fetch at 'file:///path/to/module.wasm' from origin 'null' has been blocked by CORS policy
```
**解决方案：** 使用 HTTP 服务器而不是直接打开 HTML 文件

**2. WebAssembly 不支持**
```
错误: WebAssembly is not supported in this browser
```
**解决方案：** 更新浏览器到支持 WebAssembly 的版本

**3. 模块加载失败**
```
错误: WebAssembly.instantiate(): Wasm decoding failured
```
**解决方案：** 检查 WASM 文件是否正确编译

### 2.5.2 诊断脚本

创建一个环境诊断脚本：

```javascript
// diagnostic.js
async function diagnoseEnvironment() {
    const results = {
        webassemblySupport: false,
        streamingSupport: false,
        memorySupport: false,
        simdSupport: false,
        threadsSupport: false
    };

    // 检查基本 WebAssembly 支持
    if (typeof WebAssembly === 'object') {
        results.webassemblySupport = true;
        
        // 检查流式编译支持
        if (typeof WebAssembly.instantiateStreaming === 'function') {
            results.streamingSupport = true;
        }
        
        // 检查内存支持
        try {
            new WebAssembly.Memory({ initial: 1 });
            results.memorySupport = true;
        } catch (e) {}
        
        // 检查 SIMD 支持
        try {
            WebAssembly.validate(new Uint8Array([
                0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
                0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7b
            ]));
            results.simdSupport = true;
        } catch (e) {}
    }

    return results;
}

// 在页面中显示诊断结果
diagnoseEnvironment().then(results => {
    console.log('WebAssembly 环境诊断结果:', results);
    
    Object.entries(results).forEach(([feature, supported]) => {
        const status = supported ? '✓' : '✗';
        const color = supported ? 'green' : 'red';
        console.log(`%c${status} ${feature}`, `color: ${color}`);
    });
});
```

## 本章小结

通过本章学习，你已经：

1. **安装了完整的工具链**：WABT、Emscripten、wasm-pack 等
2. **配置了开发环境**：编辑器插件、调试工具
3. **验证了环境设置**：通过实际项目测试
4. **掌握了故障排除**：常见问题的解决方案

现在你已经具备了 WebAssembly 开发的基础环境，可以开始编写第一个完整的 WASM 程序了。

---

**📝 进入下一步**：[第3章 第一个 WASM 程序](./chapter3-first-program.md)

**🔧 工具清单**：
- ✅ WABT 工具集
- ✅ Emscripten SDK  
- ✅ wasm-pack (Rust)
- ✅ 编辑器配置
- ✅ 浏览器调试工具