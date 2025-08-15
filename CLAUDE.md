# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive WebAssembly tutorial project (`WebAssembly 深入教程`) built with mdBook. It's a Chinese-language educational resource covering WebAssembly from basics to advanced topics, including extensive exercises and answers.

## Key Information from Original CLAUDE.md

**Communication**: English is acceptable for conversation, but documentation is in Chinese.

**Special AI Integration**: When needed, use `gemini -p "深入回答：<要问的问题>" -m gemini-2.5-pro` to get reference opinions from Gemini-2.5-pro (only ask 2.5-pro, no others).

## Development Environment

This project uses **Nix Flakes** for reproducible development environments. The recommended workflow:

```bash
# Enter development environment
nix develop

# Or with direnv (automatic)
direnv allow

# View available commands
just

# Start development server
just dev
```

## Essential Commands

### Development
- `just dev` - Start development server with hot reload (port 8080)
- `just build` - Build the tutorial 
- `just rebuild` - Clean and rebuild
- `just clean` - Remove build artifacts

### Testing & Validation  
- `just test` - Run all tests (WAT syntax + link validation)
- `just check-wat` - Validate all WAT file syntax using `wat2wasm`
- `just check-links` - Test markdown links using `mdbook test`

### Content Management
- `just new-chapter name` - Create new chapter with exercises template
- `just new-example name` - Add new WAT example file
- `just stats` - Show project statistics (files, lines, words, examples)

### WebAssembly Tools
- `just compile-examples` - Compile all WAT files to WASM
- `just test-examples` - Test WASM files with `wasmtime`

### Maintenance
- `just health-check` - Full project health check
- `just format` - Format code with prettier
- `just init` - Check development environment setup

## Project Architecture

### Directory Structure
```
src/                    # Source markdown files
├── SUMMARY.md         # Table of contents (mdBook structure)
├── introduction.md    # Tutorial introduction
├── part1/            # Part 1: WebAssembly Basics
├── part2/            # Part 2: Core Technologies  
├── part3/            # Part 3: Practical Applications
└── appendix/         # Reference appendices

book/                  # Generated HTML output
examples/              # WAT example files (if created)
justfile              # Task runner configuration
book.toml             # mdBook configuration
flake.nix             # Nix development environment
```

### Content Patterns

**Chapter Structure**: Each chapter follows a consistent pattern:
- Main content: `partN/chapterN-topic.md` 
- Exercises: `partN/chapterN-exercises.md`

**Exercise Format**: Exercises use collapsible details for answers:
```markdown
**题目**: Question content

<details>
<summary>🔍 参考答案</summary>

Answer content with explanations, tables, code examples
</details>
```

**Code Examples**: WAT (WebAssembly Text) format is used extensively:
```wat
;; Comment explaining the example
(module
  (func $name (param $a i32) (result i32)
    local.get $a
    i32.const 1
    i32.add)
  (export "name" (func $name)))
```

## Key Tools & Technologies

### Core Stack
- **mdBook**: Static site generator for the tutorial
- **WABT**: WebAssembly Binary Toolkit (`wat2wasm`, `wasm2wat`)
- **Emscripten**: C/C++ to WebAssembly compiler
- **Just**: Modern task runner (replaces Make)
- **Nix Flakes**: Reproducible development environment

### WebAssembly Toolchain
- **wasmtime**: WebAssembly runtime for testing
- **binaryen**: WebAssembly optimization tools (`wasm-opt`)
- **Rust toolchain**: For Rust → WASM compilation examples
- **Node.js**: For JavaScript/WASM integration examples

### Development Support
- **rust-analyzer**: Rust language server
- **VSCode workspace**: Pre-configured with extensions and tasks
- **direnv**: Automatic environment activation

## Testing & Quality

### Validation Pipeline
1. **WAT Syntax Check**: All `.wat` files validated with `wat2wasm`
2. **Link Validation**: All markdown links tested with `mdbook test`  
3. **WASM Runtime Test**: Compiled examples tested with `wasmtime`
4. **Build Verification**: Full tutorial builds without errors

### File Associations (VSCode)
- `*.wat` → WASM syntax highlighting
- `*.wast` → WASM test format
- `justfile` → Makefile syntax highlighting

## Content Guidelines

### Language & Style
- **Primary language**: Chinese (Simplified)
- **Technical terms**: Often include English in parentheses
- **Code comments**: Use Chinese with English technical terms
- **Exercise numbering**: Use structured format with point values

### Technical Focus
- **Comprehensive coverage**: From basics to advanced WebAssembly topics
- **Hands-on approach**: Heavy emphasis on practical exercises
- **Multiple compilation targets**: C/C++, Rust → WASM examples
- **Performance focus**: Optimization and debugging chapters

## Development Workflow

### Adding New Content
1. Use `just new-chapter` for structured chapter creation
2. Follow existing naming conventions (`partN/chapterN-topic.md`)
3. Include both content and exercise files
4. Add WAT examples using `just new-example`
5. Validate with `just test` before committing

### Editing Workflow
1. Start development server: `just dev`
2. Edit markdown files in `src/`
3. View changes at `http://localhost:8080`
4. Validate syntax: `just check-wat` 
5. Run full tests: `just test`

### Build & Deploy
- **Development**: `just dev` (auto-reload)
- **Production build**: `just build-prod`
- **Preview**: `just preview-prod`

This project emphasizes educational quality, technical accuracy, and modern development practices through its comprehensive toolchain and structured approach to WebAssembly education.