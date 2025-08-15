# WebAssembly 深入教程项目任务

# 默认任务：显示帮助
default:
    @just --list

# 🚀 开发任务

# 启动开发服务器（自动重载）
dev:
    @echo "🌐 启动开发服务器..."
    mdbook serve --port 8080 --hostname 0.0.0.0

# 构建教程
build:
    @echo "📚 构建教程..."
    mdbook build

# 清理构建文件
clean:
    @echo "🧹 清理构建文件..."
    rm -rf book/

# 重新构建（清理后构建）
rebuild: clean build

# 🧪 测试和验证

# 检查所有 WAT 文件语法
check-wat:
    @echo "🔍 检查 WAT 文件语法..."
    @find . -name "*.wat" -type f | while read file; do \
        echo "检查: $file"; \
        wat2wasm "$file" -o /tmp/test.wasm && echo "✅ $file 语法正确" || echo "❌ $file 语法错误"; \
    done

# 验证所有 markdown 链接
check-links:
    @echo "🔗 检查 markdown 链接..."
    mdbook test

# 运行所有测试
test: check-wat check-links
    @echo "✅ 所有测试完成"

# 📝 内容管理

# 创建新章节
new-chapter name:
    @echo "📝 创建新章节: {{name}}"
    @mkdir -p "src/{{name}}"
    @echo "# {{name}}\n\nTODO: 待完成内容" > "src/{{name}}/index.md"
    @echo "# {{name}} 练习题\n\nTODO: 待完成练习" > "src/{{name}}/exercises.md"

# 添加新的 WAT 示例
new-example name:
    @echo "📄 创建新示例: {{name}}"
    @mkdir -p examples
    @echo ";; {{name}} 示例\n(module\n  ;; TODO: 添加模块内容\n)" > "examples/{{name}}.wat"

# 🔧 工具和实用程序

# 格式化所有代码
format:
    @echo "🎨 格式化代码..."
    @find . -name "*.md" -type f | xargs prettier --write --prose-wrap always || echo "需要安装 prettier"

# 统计项目信息
stats:
    @echo "📊 项目统计信息:"
    @echo "  总文件数: $(find src/ -name "*.md" | wc -l)"
    @echo "  总行数: $(find src/ -name "*.md" -exec cat {} \; | wc -l)"
    @echo "  总字数: $(find src/ -name "*.md" -exec cat {} \; | wc -w)"
    @echo "  WAT 示例: $(find . -name "*.wat" | wc -l)"

# 🚀 部署相关

# 构建生产版本
build-prod:
    @echo "🏗️ 构建生产版本..."
    mdbook build --dest-dir dist

# 本地预览生产版本
preview-prod: build-prod
    @echo "👀 预览生产版本..."
    python3 -m http.server 8000 --directory dist

# 📦 示例和测试

# 编译所有 WAT 示例
compile-examples:
    @echo "🔨 编译 WAT 示例..."
    @mkdir -p examples/compiled
    @find examples/ -name "*.wat" -type f | while read file; do \
        base=$(basename "$file" .wat); \
        echo "编译: $file -> examples/compiled/$base.wasm"; \
        wat2wasm "$file" -o "examples/compiled/$base.wasm"; \
    done

# 运行 WASM 示例测试
test-examples:
    @echo "🧪 测试 WASM 示例..."
    @find examples/compiled/ -name "*.wasm" -type f | while read file; do \
        echo "测试: $file"; \
        wasmtime "$file" || echo "⚠️ $file 运行失败"; \
    done

# 🔄 Git 和版本控制

# 提交当前更改
commit message:
    @echo "📝 提交更改: {{message}}"
    git add .
    git commit -m "{{message}}"

# 创建新的发布标签
tag version:
    @echo "🏷️ 创建标签: {{version}}"
    git tag -a "{{version}}" -m "Release {{version}}"

# 🎯 快速开始

# 初始化开发环境
init:
    @echo "🎯 初始化开发环境..."
    @echo "检查必要工具..."
    @command -v mdbook >/dev/null 2>&1 || (echo "❌ mdbook 未安装" && exit 1)
    @command -v wat2wasm >/dev/null 2>&1 || (echo "❌ wabt 未安装" && exit 1)
    @command -v node >/dev/null 2>&1 || (echo "❌ node 未安装" && exit 1)
    @echo "✅ 开发环境就绪"
    @echo "运行 'just dev' 开始开发"

# 全面检查项目健康状态
health-check: init test
    @echo "🏥 项目健康检查完成"

# 📚 文档生成

# 生成 API 文档
docs:
    @echo "📖 生成文档..."
    @echo "教程已通过 mdbook 构建，访问 http://localhost:8080 查看"

# 生成目录结构
toc:
    @echo "📑 项目目录结构:"
    @tree src/ || find src/ -type f | sort

# 🔧 维护任务

# 更新依赖
update:
    @echo "🔄 更新 Nix flake..."
    nix flake update

# 检查过时的内容
check-outdated:
    @echo "🕐 检查可能过时的内容..."
    @grep -r "TODO" src/ || echo "没有找到 TODO 项目"
    @grep -r "FIXME" src/ || echo "没有找到 FIXME 项目"

# 🎨 主题和样式

# 预览不同主题
preview-themes:
    @echo "🎨 可用主题预览:"
    @echo "  - light: 浅色主题"
    @echo "  - rust: Rust 风格"
    @echo "  - coal: 深色主题"
    @echo "  - navy: 海军蓝主题"
    @echo "  - ayu: Ayu 主题"

# 📊 分析

# 分析构建大小
analyze-size:
    @echo "📊 分析构建大小..."
    @if [ -d "book" ]; then \
        echo "总大小: $(du -sh book/ | cut -f1)"; \
        echo "HTML 文件: $(find book/ -name "*.html" | wc -l)"; \
        echo "CSS 文件: $(find book/ -name "*.css" | wc -l)"; \
        echo "JS 文件: $(find book/ -name "*.js" | wc -l)"; \
    else \
        echo "请先运行 'just build'"; \
    fi