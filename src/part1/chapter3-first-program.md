# 第3章 第一个 WASM 程序

在本章中，我们将创建并运行第一个 WebAssembly 程序，从最简单的 "Hello World" 开始，逐步理解 WAT (WebAssembly Text Format) 的语法结构。

## Hello World 示例

### 3.1.1 最简单的 WASM 模块

让我们从一个最基础的 WebAssembly 模块开始：

```wat
;; hello.wat - 最简单的 WASM 模块
(module
  (func $hello (result i32)
    i32.const 42)
  (export "hello" (func $hello)))
```

这个模块定义了一个函数，返回常数 42。让我们分析每一部分：

- `(module ...)` - 模块的根容器
- `(func $hello ...)` - 定义一个名为 `$hello` 的函数
- `(result i32)` - 函数返回一个 32 位整数
- `i32.const 42` - 将常数 42 压入栈中
- `(export "hello" ...)` - 将函数导出为 "hello"，供 JavaScript 调用

### 3.1.2 编译和运行

**编译 WAT 文件：**
```bash
wat2wasm hello.wat -o hello.wasm
```

**创建 HTML 测试页面：**
```html
<!DOCTYPE html>
<html>
<head>
    <title>我的第一个 WASM 程序</title>
</head>
<body>
    <h1>Hello WebAssembly!</h1>
    <button onclick="callWasm()">调用 WASM 函数</button>
    <div id="output"></div>

    <script>
        async function callWasm() {
            try {
                // 加载并实例化 WASM 模块
                const wasmModule = await WebAssembly.instantiateStreaming(
                    fetch('hello.wasm')
                );
                
                // 调用导出的函数
                const result = wasmModule.instance.exports.hello();
                
                // 显示结果
                document.getElementById('output').innerHTML = 
                    `<p>WASM 函数返回: ${result}</p>`;
                
                console.log('Hello WebAssembly! 返回值:', result);
            } catch (error) {
                console.error('WASM 加载失败:', error);
            }
        }
    </script>
</body>
</html>
```

### 3.1.3 更有趣的例子

让我们创建一个更有意义的例子：

```wat
;; calculator.wat - 简单的计算器
(module
  ;; 加法函数
  (func $add (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.add)
  
  ;; 乘法函数
  (func $multiply (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.mul)
  
  ;; 阶乘函数（递归）
  (func $factorial (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (i32.const 1))
      (else
        (i32.mul
          (local.get $n)
          (call $factorial
            (i32.sub (local.get $n) (i32.const 1)))))))
  
  ;; 导出函数
  (export "add" (func $add))
  (export "multiply" (func $multiply))
  (export "factorial" (func $factorial)))
```

## WAT 语法基础

### 3.2.1 S-表达式结构

WebAssembly 文本格式使用 S-表达式（S-expressions）语法，这是一种基于括号的语法结构：

```wat
;; 基本结构
(operator operand1 operand2 ...)

;; 嵌套结构
(outer-op
  (inner-op arg1 arg2)
  arg3)
```

**示例对比：**

```wat
;; 堆栈形式（较难阅读）
i32.const 10
i32.const 20
i32.add

;; S-表达式形式（更易理解）
(i32.add
  (i32.const 10)
  (i32.const 20))
```

### 3.2.2 基本数据类型

WebAssembly 支持四种基本数值类型：

| 类型 | 描述 | 大小 | 值范围 |
|------|------|------|--------|
| `i32` | 32位整数 | 4字节 | -2³¹ ~ 2³¹-1 |
| `i64` | 64位整数 | 8字节 | -2⁶³ ~ 2⁶³-1 |
| `f32` | 32位浮点数 | 4字节 | IEEE 754 单精度 |
| `f64` | 64位浮点数 | 8字节 | IEEE 754 双精度 |

**类型示例：**

```wat
(module
  (func $type_examples
    ;; 整数常量
    i32.const 42        ;; 32位整数
    i64.const 1000000   ;; 64位整数
    
    ;; 浮点常量
    f32.const 3.14      ;; 32位浮点数
    f64.const 2.71828   ;; 64位浮点数
    
    ;; 十六进制表示
    i32.const 0xFF      ;; 255
    i32.const 0x100     ;; 256
    
    ;; 清空栈
    drop drop drop drop drop))
```

### 3.2.3 函数定义

函数是 WebAssembly 的基本执行单元：

```wat
;; 函数定义的完整语法
(func $function_name 
  (param $param1 type1) (param $param2 type2) ...
  (local $local1 type1) (local $local2 type2) ...
  (result result_type)
  
  ;; 函数体
  instruction1
  instruction2
  ...)
```

**详细示例：**

```wat
(module
  ;; 无参数，无返回值
  (func $simple
    ;; 函数体为空也是有效的
    nop)
  
  ;; 带参数和返回值
  (func $max (param $a i32) (param $b i32) (result i32)
    (if (result i32)
      (i32.gt_s (local.get $a) (local.get $b))
      (then (local.get $a))
      (else (local.get $b))))
  
  ;; 使用局部变量
  (func $sum_of_squares (param $a i32) (param $b i32) (result i32)
    (local $square_a i32)
    (local $square_b i32)
    
    ;; 计算 a²
    (local.set $square_a
      (i32.mul (local.get $a) (local.get $a)))
    
    ;; 计算 b²
    (local.set $square_b
      (i32.mul (local.get $b) (local.get $b)))
    
    ;; 返回 a² + b²
    (i32.add (local.get $square_a) (local.get $square_b))))
```

### 3.2.4 栈式执行模型

WebAssembly 使用栈式虚拟机，所有操作都在一个隐式的栈上进行：

```wat
;; 栈操作示例
(module
  (func $stack_demo (result i32)
    ;; 栈: []
    i32.const 10    ;; 栈: [10]
    i32.const 20    ;; 栈: [10, 20]
    i32.add         ;; 栈: [30]  (弹出 20 和 10，压入 30)
    
    i32.const 5     ;; 栈: [30, 5]
    i32.mul         ;; 栈: [150] (弹出 5 和 30，压入 150)
    ;; 函数返回栈顶的值 150
  ))
```

**栈操作指令：**

```wat
(module
  (func $stack_operations
    i32.const 1
    i32.const 2
    i32.const 3     ;; 栈: [1, 2, 3]
    
    drop            ;; 丢弃栈顶 -> 栈: [1, 2]
    dup             ;; 复制栈顶 -> 栈: [1, 2, 2] (注意: dup 在某些版本中不可用)
    swap            ;; 交换栈顶两个元素 (注意: swap 在某些版本中不可用)
    
    ;; 清空剩余元素
    drop drop drop))
```

### 3.2.5 控制流基础

WebAssembly 提供了结构化的控制流指令：

**条件分支：**

```wat
(module
  (func $abs (param $x i32) (result i32)
    (if (result i32)
      (i32.lt_s (local.get $x) (i32.const 0))
      (then
        ;; 如果 x < 0，返回 -x
        (i32.sub (i32.const 0) (local.get $x)))
      (else
        ;; 如果 x >= 0，返回 x
        (local.get $x)))))
```

**循环结构：**

```wat
(module
  (func $count_down (param $n i32) (result i32)
    (local $sum i32)
    
    (loop $my_loop
      ;; 检查循环条件
      (if (i32.gt_s (local.get $n) (i32.const 0))
        (then
          ;; 累加
          (local.set $sum
            (i32.add (local.get $sum) (local.get $n)))
          
          ;; 递减计数器
          (local.set $n
            (i32.sub (local.get $n) (i32.const 1)))
          
          ;; 继续循环
          (br $my_loop))))
    
    local.get $sum))
```

## 编译与运行

### 3.3.1 WAT 到 WASM 编译

**基本编译：**
```bash
# 编译 WAT 文件
wat2wasm input.wat -o output.wasm

# 启用调试信息
wat2wasm input.wat -o output.wasm --debug-names

# 验证输出
wasm-validate output.wasm
```

**查看编译结果：**
```bash
# 反编译查看结果
wasm2wat output.wasm -o check.wat

# 查看二进制结构
wasm-objdump -x output.wasm

# 查看反汇编
wasm-objdump -d output.wasm
```

### 3.3.2 JavaScript 加载方式

**方式一：流式加载（推荐）**
```javascript
async function loadWasmStreaming(url) {
    try {
        const wasmModule = await WebAssembly.instantiateStreaming(fetch(url));
        return wasmModule.instance.exports;
    } catch (error) {
        console.error('流式加载失败:', error);
        return null;
    }
}

// 使用示例
const wasmExports = await loadWasmStreaming('module.wasm');
if (wasmExports) {
    const result = wasmExports.add(5, 3);
    console.log('结果:', result);
}
```

**方式二：数组缓冲区加载**
```javascript
async function loadWasmBuffer(url) {
    try {
        const response = await fetch(url);
        const bytes = await response.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(bytes);
        return wasmModule.instance.exports;
    } catch (error) {
        console.error('缓冲区加载失败:', error);
        return null;
    }
}
```

**方式三：同步加载（Node.js）**
```javascript
const fs = require('fs');
const wasmBuffer = fs.readFileSync('module.wasm');
const wasmModule = new WebAssembly.Module(wasmBuffer);
const wasmInstance = new WebAssembly.Instance(wasmModule);
const exports = wasmInstance.exports;
```

### 3.3.3 错误处理和调试

**常见编译错误：**

```wat
;; 错误示例1: 类型不匹配
(module
  (func $type_error (result i32)
    f32.const 3.14))  ;; 错误：返回类型应该是 i32

;; 错误示例2: 未定义的标识符
(module
  (func $undefined_error
    local.get $undefined_var))  ;; 错误：变量未定义

;; 错误示例3: 栈不平衡
(module
  (func $stack_error (result i32)
    i32.const 10
    i32.const 20
    i32.add
    i32.add))  ;; 错误：栈上只有一个值，但需要两个
```

**调试技巧：**

```javascript
// 1. 检查模块导出
console.log('导出的函数:', Object.keys(wasmModule.instance.exports));

// 2. 包装函数调用以捕获异常
function safeCall(wasmFunction, ...args) {
    try {
        return wasmFunction(...args);
    } catch (error) {
        console.error('WASM 函数调用失败:', error);
        console.error('参数:', args);
        return null;
    }
}

// 3. 验证参数类型
function validateAndCall(wasmFunction, expectedTypes, ...args) {
    if (args.length !== expectedTypes.length) {
        throw new Error(`参数数量不匹配: 期望 ${expectedTypes.length}, 实际 ${args.length}`);
    }
    
    for (let i = 0; i < args.length; i++) {
        const expectedType = expectedTypes[i];
        const actualValue = args[i];
        
        if (expectedType === 'i32' && (!Number.isInteger(actualValue) || actualValue < -2**31 || actualValue >= 2**31)) {
            throw new Error(`参数 ${i} 不是有效的 i32 值: ${actualValue}`);
        }
        // 添加其他类型检查...
    }
    
    return wasmFunction(...args);
}

// 使用示例
const result = validateAndCall(wasmExports.add, ['i32', 'i32'], 10, 20);
```

### 3.3.4 完整示例项目

让我们创建一个完整的数学工具库：

**math_utils.wat:**
```wat
(module
  ;; 计算两个数的最大公约数（欧几里得算法）
  (func $gcd (param $a i32) (param $b i32) (result i32)
    (local $temp i32)
    
    (loop $gcd_loop
      (if (i32.eqz (local.get $b))
        (then (br $gcd_loop)))
      
      (local.set $temp (local.get $b))
      (local.set $b (i32.rem_u (local.get $a) (local.get $b)))
      (local.set $a (local.get $temp))
      (br $gcd_loop))
    
    local.get $a)
  
  ;; 计算最小公倍数
  (func $lcm (param $a i32) (param $b i32) (result i32)
    (i32.div_u
      (i32.mul (local.get $a) (local.get $b))
      (call $gcd (local.get $a) (local.get $b))))
  
  ;; 判断是否为质数
  (func $is_prime (param $n i32) (result i32)
    (local $i i32)
    
    ;; 小于 2 的数不是质数
    (if (i32.lt_u (local.get $n) (i32.const 2))
      (then (return (i32.const 0))))
    
    ;; 2 是质数
    (if (i32.eq (local.get $n) (i32.const 2))
      (then (return (i32.const 1))))
    
    ;; 偶数不是质数
    (if (i32.eqz (i32.rem_u (local.get $n) (i32.const 2)))
      (then (return (i32.const 0))))
    
    ;; 检查奇数因子
    (local.set $i (i32.const 3))
    
    (loop $check_loop
      (if (i32.gt_u
            (i32.mul (local.get $i) (local.get $i))
            (local.get $n))
        (then (return (i32.const 1))))
      
      (if (i32.eqz (i32.rem_u (local.get $n) (local.get $i)))
        (then (return (i32.const 0))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 2)))
      (br $check_loop))
    
    i32.const 1)
  
  ;; 计算幂（快速幂算法）
  (func $power (param $base i32) (param $exp i32) (result i32)
    (local $result i32)
    
    (local.set $result (i32.const 1))
    
    (loop $power_loop
      (if (i32.eqz (local.get $exp))
        (then (br $power_loop)))
      
      (if (i32.rem_u (local.get $exp) (i32.const 2))
        (then
          (local.set $result
            (i32.mul (local.get $result) (local.get $base)))))
      
      (local.set $base
        (i32.mul (local.get $base) (local.get $base)))
      (local.set $exp
        (i32.div_u (local.get $exp) (i32.const 2)))
      (br $power_loop))
    
    local.get $result)
  
  ;; 导出所有函数
  (export "gcd" (func $gcd))
  (export "lcm" (func $lcm))
  (export "is_prime" (func $is_prime))
  (export "power" (func $power)))
```

**测试页面 (math_test.html):**
```html
<!DOCTYPE html>
<html>
<head>
    <title>数学工具库测试</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        input { margin: 5px; padding: 5px; width: 100px; }
        button { margin: 5px; padding: 8px 15px; }
        .result { margin: 10px 0; font-weight: bold; color: #2196F3; }
    </style>
</head>
<body>
    <h1>WebAssembly 数学工具库</h1>
    
    <div class="test-section">
        <h3>最大公约数 (GCD)</h3>
        <input type="number" id="gcd_a" value="48">
        <input type="number" id="gcd_b" value="18">
        <button onclick="testGCD()">计算 GCD</button>
        <div id="gcd_result" class="result"></div>
    </div>
    
    <div class="test-section">
        <h3>最小公倍数 (LCM)</h3>
        <input type="number" id="lcm_a" value="12">
        <input type="number" id="lcm_b" value="18">
        <button onclick="testLCM()">计算 LCM</button>
        <div id="lcm_result" class="result"></div>
    </div>
    
    <div class="test-section">
        <h3>质数检测</h3>
        <input type="number" id="prime_n" value="17">
        <button onclick="testPrime()">检测质数</button>
        <div id="prime_result" class="result"></div>
    </div>
    
    <div class="test-section">
        <h3>幂运算</h3>
        <input type="number" id="power_base" value="2">
        <input type="number" id="power_exp" value="10">
        <button onclick="testPower()">计算幂</button>
        <div id="power_result" class="result"></div>
    </div>

    <script>
        let mathUtils;
        
        async function loadMathUtils() {
            try {
                const wasmModule = await WebAssembly.instantiateStreaming(
                    fetch('math_utils.wasm')
                );
                mathUtils = wasmModule.instance.exports;
                console.log('数学工具库加载成功');
            } catch (error) {
                console.error('加载失败:', error);
                alert('WebAssembly 模块加载失败');
            }
        }
        
        function testGCD() {
            if (!mathUtils) { alert('模块未加载'); return; }
            
            const a = parseInt(document.getElementById('gcd_a').value);
            const b = parseInt(document.getElementById('gcd_b').value);
            const result = mathUtils.gcd(a, b);
            
            document.getElementById('gcd_result').textContent = 
                `GCD(${a}, ${b}) = ${result}`;
        }
        
        function testLCM() {
            if (!mathUtils) { alert('模块未加载'); return; }
            
            const a = parseInt(document.getElementById('lcm_a').value);
            const b = parseInt(document.getElementById('lcm_b').value);
            const result = mathUtils.lcm(a, b);
            
            document.getElementById('lcm_result').textContent = 
                `LCM(${a}, ${b}) = ${result}`;
        }
        
        function testPrime() {
            if (!mathUtils) { alert('模块未加载'); return; }
            
            const n = parseInt(document.getElementById('prime_n').value);
            const result = mathUtils.is_prime(n);
            
            document.getElementById('prime_result').textContent = 
                `${n} ${result ? '是' : '不是'}质数`;
        }
        
        function testPower() {
            if (!mathUtils) { alert('模块未加载'); return; }
            
            const base = parseInt(document.getElementById('power_base').value);
            const exp = parseInt(document.getElementById('power_exp').value);
            const result = mathUtils.power(base, exp);
            
            document.getElementById('power_result').textContent = 
                `${base}^${exp} = ${result}`;
        }
        
        // 页面加载时自动加载模块
        loadMathUtils();
    </script>
</body>
</html>
```

## 本章小结

通过本章学习，你已经：

1. **创建了第一个 WebAssembly 程序**：从简单的 Hello World 到完整的数学工具库
2. **掌握了 WAT 语法基础**：S-表达式、数据类型、函数定义、控制流
3. **理解了栈式执行模型**：WebAssembly 的核心执行机制
4. **学会了编译和运行流程**：从 WAT 到 WASM 到 JavaScript 集成
5. **掌握了调试技巧**：错误处理、类型验证、调试方法

现在你已经具备了编写基本 WebAssembly 程序的能力，可以进入更深入的核心技术学习了。

---

**📝 进入下一步**：[第4章 WebAssembly 文本格式 (WAT)](../part2/chapter4-wat.md)

**🎯 核心技能**：
- ✅ WAT 语法基础
- ✅ 栈式执行模型
- ✅ 函数定义和调用
- ✅ JavaScript 集成
- ✅ 基本调试技能