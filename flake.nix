{
  description = "WebAssembly 深入教程开发环境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;  # 允许不自由软件如 VSCode
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # mdbook 和相关工具
            mdbook
            mdbook-mermaid
            mdbook-toc
            
            # WebAssembly 工具链
            wabt              # wat2wasm, wasm2wat 等
            binaryen          # wasm-opt 等优化工具
            
            # 编译工具链
            emscripten        # C/C++ 到 WASM
            
            # Rust 工具链 (用于 wasm-pack)
            rustc
            cargo
            rust-analyzer
            
            # Node.js 环境 (用于测试和工具)
            nodejs_20
            yarn
            
            # 开发工具
            just              # 任务运行器
            git
            curl
            python3           # HTTP 服务器
            
            # 编辑器支持
            vscode
            
            # 调试和性能分析
            wasmtime          # WASM 运行时
            wasmer            # 另一个 WASM 运行时
          ];

          shellHook = ''
            echo "🚀 WebAssembly 教程开发环境已启动"
            echo ""
            echo "📚 可用工具:"
            echo "  mdbook --version: $(mdbook --version)"
            echo "  wat2wasm --version: $(wat2wasm --version)"
            echo "  emcc --version: $(emcc --version 2>/dev/null | head -n1 || echo '需要运行 source $EMSDK/emsdk_env.sh')"
            echo "  node --version: $(node --version)"
            echo "  rustc --version: $(rustc --version)"
            echo "  just --version: $(just --version)"
            echo ""
            echo "🔧 常用命令:"
            echo "  just help     - 显示所有可用任务"
            echo "  just dev      - 启动开发服务器"
            echo "  just build    - 构建教程"
            echo "  just test     - 运行测试"
            echo ""
            
            # 设置 Rust target
            if command -v rustup >/dev/null 2>&1; then
              rustup target add wasm32-unknown-unknown 2>/dev/null || true
            fi
            
            # 检查并安装 wasm-pack
            if ! command -v wasm-pack >/dev/null 2>&1; then
              echo "📦 Installing wasm-pack..."
              curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
            fi
          '';

          # 环境变量
          RUST_BACKTRACE = "1";
          MDBOOK_BOOK__LANGUAGE = "zh-CN";
        };

        # 为 CI/CD 提供的包
        packages.default = pkgs.stdenv.mkDerivation {
          name = "wasm-tutorial";
          src = ./.;
          
          buildInputs = with pkgs; [
            mdbook
            mdbook-mermaid
            mdbook-toc
          ];
          
          buildPhase = ''
            mdbook build
          '';
          
          installPhase = ''
            mkdir -p $out
            cp -r book/* $out/
          '';
        };
      }
    );
}