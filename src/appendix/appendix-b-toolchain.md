# 附录B 工具链完整指南

本附录提供 WebAssembly 开发工具链的完整指南，涵盖从基础工具安装到高级调试和性能优化的全套工具。无论你是初学者还是高级开发者，这份指南都将帮助你构建高效的 WebAssembly 开发环境。

## B.1 工具链总览

### B.1.1 工具分类

WebAssembly 工具链可以分为以下几个主要类别：

**核心编译工具**：
- **WABT** - WebAssembly Binary Toolkit（官方工具集）
- **Emscripten** - C/C++ 到 WebAssembly 编译器
- **wasm-pack** - Rust 到 WebAssembly 工具
- **AssemblyScript** - TypeScript-like 语言到 WebAssembly

**运行时环境**：
- **Wasmtime** - 独立 WebAssembly 运行时
- **Wasmer** - 通用 WebAssembly 运行时
- **WAMR** - 嵌入式 WebAssembly 运行时
- **Node.js** - 内置 WebAssembly 支持

**优化和分析工具**：
- **Binaryen** - WebAssembly 优化器
- **wasm-opt** - 优化工具
- **Twiggy** - 代码尺寸分析器
- **wasm-objdump** - 二进制分析工具

**调试和开发工具**：
- **Chrome DevTools** - 浏览器调试器
- **VSCode** - 代码编辑器和插件
- **LLDB** - 低级调试器
- **wasm-strip** - 符号表剥离工具

### B.1.2 推荐工具组合

**初学者组合**：
```bash
# 基础工具
- WABT (wat2wasm, wasm2wat)
- Emscripten (C/C++ 编译)
- VSCode + WebAssembly 插件
- Chrome 浏览器 (调试)
```

**Rust 开发者组合**：
```bash
# Rust 生态
- wasm-pack
- wasm-bindgen
- cargo-generate
- wee_alloc
```

**性能优化组合**：
```bash
# 性能工具
- Binaryen (wasm-opt)
- Twiggy (尺寸分析)
- Chrome DevTools (性能分析)
- Wasmtime (基准测试)
```

## B.2 核心工具安装

### B.2.1 WABT (WebAssembly Binary Toolkit)

WABT 是 WebAssembly 官方工具集，提供二进制和文本格式之间的转换功能。

**Ubuntu/Debian 安装**：
```bash
# 使用包管理器
sudo apt-get update
sudo apt-get install wabt

# 验证安装
wat2wasm --version
wasm2wat --version
```

**macOS 安装**：
```bash
# 使用 Homebrew
brew install wabt

# 验证安装
wat2wasm --version
wasm2wat --version
```

**Windows 安装**：
```powershell
# 使用 Chocolatey
choco install wabt

# 或下载预编译二进制文件
# 从 https://github.com/WebAssembly/wabt/releases 下载
```

**从源码编译**：
```bash
# 克隆仓库
git clone --recursive https://github.com/WebAssembly/wabt
cd wabt

# 创建构建目录
mkdir build && cd build

# 配置和编译
cmake ..
make -j$(nproc)

# 安装
sudo make install
```

**主要工具说明**：
- **wat2wasm**: WAT 文本格式转 WASM 二进制格式
- **wasm2wat**: WASM 二进制格式转 WAT 文本格式  
- **wasm-validate**: 验证 WASM 文件有效性
- **wasm-objdump**: 查看 WASM 文件结构和内容
- **wasm-interp**: WebAssembly 解释器
- **wasm-decompile**: 反编译为高级语言风格代码

### B.2.2 Emscripten

Emscripten 是将 C/C++ 代码编译为 WebAssembly 的完整工具链。

**安装 Emscripten SDK**：
```bash
# 下载 emsdk
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# 安装最新稳定版
./emsdk install latest
./emsdk activate latest

# 设置环境变量（临时）
source ./emsdk_env.sh

# 永久设置环境变量
echo 'source /path/to/emsdk/emsdk_env.sh' >> ~/.bashrc
```

**Windows 安装**：
```cmd
# 下载 emsdk
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# 安装和激活
emsdk.bat install latest
emsdk.bat activate latest

# 设置环境变量
emsdk_env.bat
```

**验证安装**：
```bash
# 检查版本
emcc --version
em++ --version
node --version

# 测试编译
echo 'int main() { return 42; }' > test.c
emcc test.c -o test.html
```

**配置选项**：
```bash
# 查看可用版本
./emsdk list

# 安装特定版本
./emsdk install 3.1.45
./emsdk activate 3.1.45

# 设置上游工具链
./emsdk install tot
./emsdk activate tot
```

### B.2.3 Rust 工具链

**安装 Rust**：
```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 重新加载环境
source ~/.cargo/env

# 添加 WebAssembly 目标
rustup target add wasm32-unknown-unknown
rustup target add wasm32-wasi
```

**安装 wasm-pack**：
```bash
# 从官方脚本安装
curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# 或使用 cargo 安装
cargo install wasm-pack

# 验证安装
wasm-pack --version
```

**安装辅助工具**：
```bash
# wasm-bindgen CLI
cargo install wasm-bindgen-cli

# cargo-generate (项目模板)
cargo install cargo-generate

# Twiggy (代码尺寸分析)
cargo install twiggy
```

### B.2.4 WebAssembly 运行时

**Wasmtime**：
```bash
# macOS/Linux
curl https://wasmtime.dev/install.sh -sSf | bash

# 手动安装
wget https://github.com/bytecodealliance/wasmtime/releases/latest/download/wasmtime-v*-x86_64-linux.tar.xz
tar -xf wasmtime-*.tar.xz
sudo cp wasmtime-*/wasmtime /usr/local/bin/

# 验证安装
wasmtime --version
```

**Wasmer**：
```bash
# 安装脚本
curl https://get.wasmer.io -sSfL | sh

# 手动安装
wget https://github.com/wasmerio/wasmer/releases/latest/download/wasmer-linux-amd64.tar.gz
tar -xzf wasmer-linux-amd64.tar.gz
sudo cp bin/wasmer /usr/local/bin/

# 验证安装
wasmer --version
```

### B.2.5 Node.js 环境

**安装 Node.js**：
```bash
# 使用 nvm (推荐)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
nvm use node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node

# 验证安装
node --version
npm --version
```

**WebAssembly 相关包**：
```bash
# 安装常用 WASM 包
npm install -g @wasmer/cli
npm install -g wasmtime
npm install -g wasm-pack

# 开发依赖
npm install --save-dev webpack webpack-cli
npm install --save-dev @wasm-tool/wasm-pack-plugin
```

## B.3 编译工具链详解

### B.3.1 Emscripten 编译选项

**基本编译命令**：
```bash
# 简单编译
emcc source.c -o output.html

# 仅生成 WASM 和 JS
emcc source.c -o output.js

# 仅生成 WASM
emcc source.c -o output.wasm

# 多文件编译
emcc main.c utils.c -o app.html
```

**常用编译选项**：
```bash
# 优化级别
emcc source.c -O0  # 无优化，快速编译
emcc source.c -O1  # 基本优化
emcc source.c -O2  # 标准优化（推荐）
emcc source.c -O3  # 最大优化
emcc source.c -Os  # 尺寸优化
emcc source.c -Oz  # 最大尺寸优化

# 导出函数
emcc source.c -o output.js \
  -s EXPORTED_FUNCTIONS='["_main", "_add", "_multiply"]' \
  -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]'

# 内存设置
emcc source.c -o output.js \
  -s INITIAL_MEMORY=16777216 \    # 16MB 初始内存
  -s ALLOW_MEMORY_GROWTH=1 \      # 允许内存增长
  -s MAXIMUM_MEMORY=67108864      # 64MB 最大内存

# 调试选项
emcc source.c -o output.js \
  -g4 \                           # 包含调试信息
  -s ASSERTIONS=1 \               # 运行时断言
  -s SAFE_HEAP=1 \                # 内存安全检查
  --source-map-base http://localhost:8000/
```

**高级编译选项**：
```bash
# 自定义 HTML 模板
emcc source.c -o output.html --shell-file custom_shell.html

# 预加载文件
emcc source.c -o output.js --preload-file assets/

# 嵌入文件
emcc source.c -o output.js --embed-file config.txt

# 链接库
emcc source.c -o output.js -lm  # 链接数学库

# 使用现代 JS 特性
emcc source.c -o output.js \
  -s ENVIRONMENT='web' \
  -s EXPORT_ES6=1 \
  -s MODULARIZE=1 \
  -s USE_ES6_IMPORT_META=0
```

### B.3.2 wasm-pack 使用

**创建 Rust 项目**：
```bash
# 使用模板创建项目
cargo generate --git https://github.com/rustwasm/wasm-pack-template

# 或手动创建
cargo new --lib my-wasm-project
cd my-wasm-project
```

**配置 Cargo.toml**：
```toml
[package]
name = "my-wasm-project"
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
  "Document",
  "Element",
  "HtmlElement",
  "Window",
]

[dependencies.js-sys]
version = "0.3"
```

**编译命令**：
```bash
# 标准编译（适合打包工具）
wasm-pack build

# 针对浏览器
wasm-pack build --target web

# 针对 Node.js
wasm-pack build --target nodejs

# 针对打包工具
wasm-pack build --target bundler

# 开发模式（包含调试信息）
wasm-pack build --dev

# 生产模式（优化）
wasm-pack build --release

# 指定输出目录
wasm-pack build --out-dir pkg-custom

# 设置范围
wasm-pack build --scope my-org
```

**发布到 npm**：
```bash
# 构建包
wasm-pack build --target bundler

# 发布到 npm
wasm-pack publish
```

### B.3.3 AssemblyScript 工具链

**安装 AssemblyScript**：
```bash
# 全局安装
npm install -g assemblyscript

# 项目级安装
npm install --save-dev assemblyscript

# 初始化项目
npx asinit .
```

**编译 AssemblyScript**：
```bash
# 编译为 WASM
npx asc assembly/index.ts --binaryFile build/optimized.wasm --optimize

# 生成文本格式
npx asc assembly/index.ts --textFile build/optimized.wat

# 调试版本
npx asc assembly/index.ts --binaryFile build/debug.wasm --debug

# 启用运行时检查
npx asc assembly/index.ts --binaryFile build/untouched.wasm --runtime stub
```

## B.4 优化工具

### B.4.1 Binaryen 工具套件

**安装 Binaryen**：
```bash
# Ubuntu/Debian
sudo apt-get install binaryen

# macOS
brew install binaryen

# 从源码编译
git clone https://github.com/WebAssembly/binaryen.git
cd binaryen
cmake . && make

# 验证安装
wasm-opt --version
```

**wasm-opt 优化**：
```bash
# 基本优化
wasm-opt input.wasm -O -o output.wasm

# 尺寸优化
wasm-opt input.wasm -Oz -o output.wasm

# 速度优化
wasm-opt input.wasm -O3 -o output.wasm

# 查看优化后的差异
wasm-opt input.wasm -O --print

# 详细优化选项
wasm-opt input.wasm \
  --duplicate-function-elimination \
  --remove-unused-functions \
  --remove-unused-module-elements \
  --vacuum \
  -o output.wasm
```

**其他 Binaryen 工具**：
```bash
# 验证 WASM 文件
wasm-validate input.wasm

# 生成调用图
wasm-metadce input.wasm --graph-file callgraph.dot

# 测量模块大小
wasm-reduce input.wasm --output reduced.wasm

# 二进制到文本转换
wasm-dis input.wasm -o output.wat

# 文本到二进制转换
wasm-as input.wat -o output.wasm
```

### B.4.2 Twiggy 代码分析

**安装和使用 Twiggy**：
```bash
# 安装
cargo install twiggy

# 分析 WASM 文件大小
twiggy top my-app.wasm

# 生成详细报告
twiggy top my-app.wasm --max-items 20

# 分析函数调用
twiggy dominators my-app.wasm

# 生成可视化报告
twiggy top my-app.wasm --format json > report.json
```

**Twiggy 输出示例**：
```text
Shallow Bytes │ Shallow % │ Item
──────────────┼───────────┼────────────────────────────
          9949 ┊    19.65% ┊ data[0]
          3251 ┊     6.42% ┊ "function names" subsection
          1249 ┊     2.47% ┊ add
          1200 ┊     2.37% ┊ multiply
          1130 ┊     2.23% ┊ subtract
           970 ┊     1.92% ┊ divide
```

## B.5 调试工具

### B.5.1 浏览器调试

**Chrome DevTools WASM 调试**：
```javascript
// 启用 WASM 调试
// 在 Chrome 中打开：chrome://flags/
// 启用：WebAssembly Debugging

// 加载 WASM 模块
WebAssembly.instantiateStreaming(fetch('module.wasm'))
  .then(result => {
    // 设置断点和调试
    console.log(result);
  });
```

**Source Maps 配置**：
```bash
# Emscripten 生成 source map
emcc source.c -o output.js -g4 --source-map-base http://localhost:8000/

# Rust 生成调试信息
wasm-pack build --dev

# 在浏览器中查看源码
# DevTools -> Sources -> 查看原始 C/Rust 代码
```

### B.5.2 命令行调试

**使用 wasmtime 调试**：
```bash
# 运行 WASM 模块
wasmtime run module.wasm

# 启用调试器
wasmtime run --gdb-port 1234 module.wasm

# 连接 GDB
gdb
(gdb) target remote localhost:1234
(gdb) break main
(gdb) continue
```

**使用 LLDB 调试**：
```bash
# 使用 LLDB 调试 WASM
lldb
(lldb) target create module.wasm
(lldb) breakpoint set --name main
(lldb) run
```

### B.5.3 日志和性能分析

**性能分析工具**：
```bash
# 使用 wasmtime 性能分析
wasmtime run --profile module.wasm

# 生成火焰图
wasmtime run --profile=jitdump module.wasm
perf record -g ./script
perf script | stackcollapse-perf.pl | flamegraph.pl > profile.svg
```

**内存分析**：
```javascript
// 监控 WASM 内存使用
const memory = new WebAssembly.Memory({ initial: 1 });
console.log('Memory pages:', memory.buffer.byteLength / 65536);

// 检查内存增长
setInterval(() => {
  console.log('Current memory:', memory.buffer.byteLength);
}, 1000);
```

## B.6 构建系统集成

### B.6.1 Webpack 集成

**安装 Webpack 插件**：
```bash
npm install --save-dev @wasm-tool/wasm-pack-plugin
npm install --save-dev html-webpack-plugin
```

**webpack.config.js 配置**：
```javascript
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const WasmPackPlugin = require('@wasm-tool/wasm-pack-plugin');

module.exports = {
  entry: './js/index.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'index.js',
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: 'index.html'
    }),
    new WasmPackPlugin({
      crateDirectory: path.resolve(__dirname, '.')
    }),
  ],
  experiments: {
    asyncWebAssembly: true,
  },
};
```

### B.6.2 Rollup 集成

**安装 Rollup 插件**：
```bash
npm install --save-dev rollup
npm install --save-dev @rollup/plugin-wasm
npm install --save-dev rollup-plugin-rust
```

**rollup.config.js 配置**：
```javascript
import wasm from '@rollup/plugin-wasm';
import rust from 'rollup-plugin-rust';

export default {
  input: 'src/main.js',
  output: {
    file: 'dist/bundle.js',
    format: 'es'
  },
  plugins: [
    rust({
      serverPath: '/pkg/',
    }),
    wasm({
      sync: ['**/my-module.wasm']
    })
  ]
};
```

### B.6.3 Vite 集成

**vite.config.js 配置**：
```javascript
import { defineConfig } from 'vite';
import wasmPack from 'vite-plugin-wasm-pack';

export default defineConfig({
  plugins: [
    wasmPack('./my-wasm-project')
  ],
  server: {
    fs: {
      allow: ['..']
    }
  }
});
```

### B.6.4 CMake 集成

**CMakeLists.txt 配置**：
```cmake
cmake_minimum_required(VERSION 3.16)
project(MyWasmProject)

# 设置 Emscripten 工具链
set(CMAKE_TOOLCHAIN_FILE ${EMSCRIPTEN}/cmake/Modules/Platform/Emscripten.cmake)

# 添加可执行文件
add_executable(myapp main.c utils.c)

# 设置编译选项
set_target_properties(myapp PROPERTIES
    COMPILE_FLAGS "-O2"
    LINK_FLAGS "-O2 -s EXPORTED_FUNCTIONS='[\"_main\"]' -s EXPORTED_RUNTIME_METHODS='[\"ccall\"]'"
)
```

**构建脚本**：
```bash
#!/bin/bash
mkdir -p build
cd build
emcmake cmake ..
emmake make
```

## B.7 IDE 和编辑器配置

### B.7.1 Visual Studio Code

**安装扩展**：
```bash
# 通过命令行安装扩展
code --install-extension ms-vscode.wasm
code --install-extension rust-lang.rust-analyzer
code --install-extension ms-vscode.cpptools
```

**settings.json 配置**：
```json
{
  "rust-analyzer.cargo.target": "wasm32-unknown-unknown",
  "rust-analyzer.checkOnSave.allTargets": false,
  "files.associations": {
    "*.wat": "wasm",
    "*.wast": "wasm"
  },
  "emmet.includeLanguages": {
    "wat": "html"
  }
}
```

**tasks.json 配置**：
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "wasm-pack build",
      "type": "shell",
      "command": "wasm-pack",
      "args": ["build", "--target", "web"],
      "group": "build",
      "problemMatcher": []
    },
    {
      "label": "emcc compile",
      "type": "shell",
      "command": "emcc",
      "args": ["${file}", "-o", "${fileDirname}/${fileBasenameNoExtension}.html"],
      "group": "build"
    }
  ]
}
```

**launch.json 配置**：
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch WASM in Browser",
      "type": "chrome",
      "request": "launch",
      "url": "http://localhost:8000",
      "webRoot": "${workspaceFolder}"
    }
  ]
}
```

### B.7.2 WebStorm/CLion

**配置 Emscripten**：
```text
File -> Settings -> Build, Execution, Deployment -> CMake
- Add new profile: "Emscripten"
- CMake options: -DCMAKE_TOOLCHAIN_FILE=/path/to/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
```

**文件类型关联**：
```text
File -> Settings -> Editor -> File Types
- Add pattern "*.wat" to "WebAssembly Text"
- Add pattern "*.wasm" to "Binary files"
```

### B.7.3 Vim/Neovim

**安装插件**：
```vim
" 使用 vim-plug
Plug 'rhysd/vim-wasm'
Plug 'rust-lang/rust.vim'
Plug 'neoclide/coc.nvim'

" WebAssembly 语法高亮
autocmd BufNewFile,BufRead *.wat set filetype=wasm
autocmd BufNewFile,BufRead *.wast set filetype=wasm
```

## B.8 测试框架

### B.8.1 Web 端测试

**使用 Jest 测试**：
```bash
# 安装测试依赖
npm install --save-dev jest
npm install --save-dev jest-environment-node
```

**jest.config.js**：
```javascript
module.exports = {
  testEnvironment: 'node',
  transform: {},
  testMatch: ['**/*.test.js'],
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js']
};
```

**测试示例**：
```javascript
// math.test.js
import init, { add, multiply } from '../pkg/my_wasm_project.js';

beforeAll(async () => {
  await init();
});

test('addition works', () => {
  expect(add(2, 3)).toBe(5);
});

test('multiplication works', () => {
  expect(multiply(4, 5)).toBe(20);
});
```

### B.8.2 Rust 单元测试

**配置 wasm-bindgen-test**：
```toml
[dev-dependencies]
wasm-bindgen-test = "0.3"
```

**测试代码**：
```rust
// lib.rs
#[cfg(test)]
mod tests {
    use super::*;
    use wasm_bindgen_test::*;

    wasm_bindgen_test_configure!(run_in_browser);

    #[wasm_bindgen_test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }
}
```

**运行测试**：
```bash
# 在 Node.js 中运行
wasm-pack test --node

# 在浏览器中运行
wasm-pack test --chrome --headless

# 在 Firefox 中运行
wasm-pack test --firefox --headless
```

### B.8.3 C/C++ 测试

**使用 Emscripten 测试**：
```c
// test.c
#include <assert.h>
#include <emscripten.h>

int add(int a, int b) {
    return a + b;
}

int main() {
    assert(add(2, 3) == 5);
    assert(add(-1, 1) == 0);
    emscripten_force_exit(0);
    return 0;
}
```

**编译和运行测试**：
```bash
# 编译测试
emcc test.c -o test.js -s ASSERTIONS=1

# 运行测试
node test.js
```

## B.9 性能工具

### B.9.1 基准测试

**使用 Criterion.rs**：
```toml
[dev-dependencies]
criterion = { version = "0.4", features = ["html_reports"] }
```

**基准测试代码**：
```rust,ignore
// benches/my_benchmark.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use my_wasm_project::add;

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("add", |b| b.iter(|| add(black_box(20), black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

**运行基准测试**：
```bash
cargo bench
```

### B.9.2 内存分析

**使用 wee_alloc**：
```toml
[dependencies]
wee_alloc = "0.4.5"
```

```rust,ignore
// lib.rs
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
```

**监控内存使用**：
```javascript
// 监控 WebAssembly 内存
function monitorWasmMemory(wasmMemory) {
    const initialSize = wasmMemory.buffer.byteLength;
    console.log(`Initial WASM memory: ${initialSize} bytes`);
    
    setInterval(() => {
        const currentSize = wasmMemory.buffer.byteLength;
        console.log(`Current WASM memory: ${currentSize} bytes`);
    }, 1000);
}
```

### B.9.3 性能分析

**Chrome DevTools Profiling**：
```javascript
// 性能测试包装器
function benchmark(fn, iterations = 1000) {
    const start = performance.now();
    for (let i = 0; i < iterations; i++) {
        fn();
    }
    const end = performance.now();
    return end - start;
}

// 使用示例
const wasmTime = benchmark(() => wasmAdd(1000, 2000));
const jsTime = benchmark(() => jsAdd(1000, 2000));
console.log(`WASM: ${wasmTime}ms, JS: ${jsTime}ms`);
```

## B.10 部署工具

### B.10.1 Web 优化

**压缩和优化**：
```bash
# 使用 gzip 压缩
gzip -k -9 output.wasm

# 使用 Brotli 压缩
brotli -q 11 output.wasm

# wasm-opt 优化
wasm-opt input.wasm -Oz --enable-bulk-memory -o output.wasm
```

**服务器配置**：
```nginx
# Nginx 配置
location ~* \.wasm$ {
    add_header Content-Type application/wasm;
    add_header Cross-Origin-Embedder-Policy require-corp;
    add_header Cross-Origin-Opener-Policy same-origin;
    gzip_static on;
    expires 1y;
}
```

### B.10.2 CDN 部署

**上传到 CDN**：
```bash
# AWS S3
aws s3 cp dist/ s3://my-bucket/wasm-app/ --recursive \
  --content-type "application/wasm" \
  --content-encoding gzip

# Google Cloud Storage
gsutil -m cp -r dist/ gs://my-bucket/wasm-app/
gsutil -m setmeta -h "Content-Type:application/wasm" gs://my-bucket/wasm-app/*.wasm
```

**设置 CORS**：
```json
{
  "cors": [
    {
      "origin": ["*"],
      "method": ["GET"],
      "responseHeader": ["Content-Type", "Cross-Origin-Embedder-Policy"],
      "maxAgeSeconds": 3600
    }
  ]
}
```

## B.11 故障排除

### B.11.1 常见问题

**编译错误**：
```bash
# 问题：wat2wasm 命令未找到
# 解决：检查 WABT 是否正确安装
which wat2wasm
export PATH=$PATH:/usr/local/bin

# 问题：emcc 命令未找到
# 解决：激活 Emscripten 环境
source /path/to/emsdk/emsdk_env.sh

# 问题：Rust 目标未安装
# 解决：添加 WebAssembly 目标
rustup target add wasm32-unknown-unknown
```

**运行时错误**：
```javascript
// 问题：CORS 错误
// 解决：设置正确的 HTTP 头
fetch('module.wasm', {
    headers: {
        'Cross-Origin-Embedder-Policy': 'require-corp'
    }
});

// 问题：内存不足
// 解决：增加初始内存大小
const memory = new WebAssembly.Memory({ 
    initial: 256,  // 16MB
    maximum: 1024  // 64MB
});
```

### B.11.2 性能问题

**优化建议**：
```bash
# 启用所有优化
wasm-opt input.wasm -O4 --enable-bulk-memory --enable-simd -o output.wasm

# 移除调试信息
wasm-strip input.wasm

# 分析代码大小
twiggy top input.wasm --max-items 50
```

**内存优化**：
```rust,ignore
// 使用 wee_alloc 减少内存占用
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// 避免不必要的分配
#[wasm_bindgen]
pub fn process_slice(data: &[u8]) -> u32 {
    // 直接处理，避免复制
    data.iter().map(|&x| x as u32).sum()
}
```

### B.11.3 调试技巧

**启用详细日志**：
```bash
# Emscripten 详细输出
emcc -v source.c -o output.js

# wasm-pack 详细输出
wasm-pack build --log-level info

# 环境变量调试
RUST_LOG=debug wasm-pack build
```

**使用断言和检查**：
```rust,ignore
// Rust 中的断言
debug_assert!(value > 0, "Value must be positive");

// wasm-bindgen 类型检查
#[wasm_bindgen]
pub fn safe_divide(a: f64, b: f64) -> Result<f64, JsValue> {
    if b == 0.0 {
        Err(JsValue::from_str("Division by zero"))
    } else {
        Ok(a / b)
    }
}
```

## B.12 工具链更新和维护

### B.12.1 版本管理

**跟踪工具版本**：
```bash
# 创建版本记录脚本
cat > check_versions.sh << 'EOF'
#!/bin/bash
echo "=== WebAssembly Toolchain Versions ==="
echo "WABT: $(wat2wasm --version 2>&1 | head -1)"
echo "Emscripten: $(emcc --version 2>&1 | head -1)"
echo "wasm-pack: $(wasm-pack --version)"
echo "Rust: $(rustc --version)"
echo "Node.js: $(node --version)"
echo "Wasmtime: $(wasmtime --version)"
EOF

chmod +x check_versions.sh
```

**更新脚本**：
```bash
# 更新 Emscripten
cd /path/to/emsdk
./emsdk update
./emsdk install latest
./emsdk activate latest

# 更新 Rust 工具链
rustup update
cargo install --force wasm-pack

# 更新 WABT
# Ubuntu/Debian
sudo apt-get update && sudo apt-get upgrade wabt

# macOS
brew upgrade wabt
```

### B.12.2 环境一致性

**Docker 化开发环境**：
```dockerfile
# Dockerfile
FROM ubuntu:22.04

# 安装基础工具
RUN apt-get update && apt-get install -y \
    curl git build-essential cmake python3 nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup target add wasm32-unknown-unknown

# 安装 Emscripten
RUN git clone https://github.com/emscripten-core/emsdk.git /opt/emsdk
WORKDIR /opt/emsdk
RUN ./emsdk install latest && ./emsdk activate latest
ENV PATH="/opt/emsdk:${PATH}"

# 安装 wasm-pack
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# 工作目录
WORKDIR /workspace
```

**使用 Nix 管理环境**：
```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # WebAssembly tools
    wabt
    binaryen
    emscripten
    wasmtime
    
    # Rust toolchain
    rustc
    cargo
    
    # Node.js environment
    nodejs
    nodePackages.npm
    
    # Development tools
    cmake
    pkg-config
  ];
  
  shellHook = ''
    echo "WebAssembly development environment ready!"
    echo "Available tools:"
    echo "  - wat2wasm, wasm2wat (WABT)"
    echo "  - emcc, em++ (Emscripten)"
    echo "  - wasmtime (Runtime)"
    echo "  - wasm-opt (Binaryen)"
  '';
}
```

通过遵循本附录的指南，你将能够构建一个完整、高效的 WebAssembly 开发环境。无论是简单的学习项目还是复杂的生产应用，这些工具都将为你的 WebAssembly 开发之路提供强有力的支持。
