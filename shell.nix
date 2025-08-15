# shell.nix - 兼容性后备方案
# 使用: nix-shell

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # mdbook 和相关工具
    mdbook
    
    # WebAssembly 工具链
    wabt
    binaryen
    
    # 编译工具链
    emscripten
    
    # Rust 工具链
    rustc
    cargo
    
    # Node.js 环境
    nodejs_20
    
    # 开发工具
    just
    git
    curl
    python3
    
    # WASM 运行时
    wasmtime
  ];

  shellHook = ''
    echo "📚 WebAssembly 教程开发环境 (legacy shell.nix)"
    echo "💡 建议升级到 Nix Flakes: nix develop"
    echo ""
    echo "可用命令: just --list"
  '';
}