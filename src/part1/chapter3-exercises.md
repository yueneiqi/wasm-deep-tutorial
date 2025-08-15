# 第3章 练习题

## WAT 语法基础题

### 1. 基本语法理解 (15分)

**题目**：解释下列 WAT 代码的执行过程，包括栈的变化情况：

```wat
(module
  (func $mystery (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.add
    local.get $x
    local.get $y
    i32.mul
    i32.sub))
```

如果调用 `mystery(5, 3)`，请逐步说明栈的变化过程和最终结果。

<details>
<summary>🔍 参考答案</summary>

**函数功能分析：**
这个函数计算 `(x + y) - (x * y)` 的值。

**执行过程（调用 `mystery(5, 3)`）：**

```
初始状态: 栈=[], 参数: $x=5, $y=3

1. local.get $x    -> 栈=[5]
2. local.get $y    -> 栈=[5, 3]
3. i32.add         -> 栈=[8]     (弹出 3,5, 压入 5+3=8)
4. local.get $x    -> 栈=[8, 5]
5. local.get $y    -> 栈=[8, 5, 3]
6. i32.mul         -> 栈=[8, 15]  (弹出 3,5, 压入 5*3=15)
7. i32.sub         -> 栈=[−7]    (弹出 15,8, 压入 8-15=-7)

最终结果: -7
```

**数学验证：**
`(5 + 3) - (5 * 3) = 8 - 15 = -7` ✓

**关键点：**
- WebAssembly 栈是 LIFO（后进先出）
- `i32.sub` 执行的是 `第二个值 - 第一个值`（即 `8 - 15`）
- 函数返回栈顶的最后一个值
</details>

### 2. 函数实现 (20分)

**题目**：使用 WAT 实现以下函数，要求包含详细注释：

1. `min(a, b)` - 返回两个数中的较小值
2. `sign(x)` - 返回数字的符号（-1, 0, 或 1）
3. `clamp(x, min, max)` - 将数字限制在指定范围内

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 1. 返回两个数中的较小值
  (func $min (param $a i32) (param $b i32) (result i32)
    ;; 使用条件表达式比较两个参数
    (if (result i32)
      (i32.lt_s (local.get $a) (local.get $b))  ;; if a < b
      (then (local.get $a))                      ;; return a
      (else (local.get $b))))                    ;; else return b

  ;; 2. 返回数字的符号
  (func $sign (param $x i32) (result i32)
    ;; 首先检查是否为 0
    (if (result i32)
      (i32.eqz (local.get $x))                   ;; if x == 0
      (then (i32.const 0))                       ;; return 0
      (else
        ;; 检查是否为负数
        (if (result i32)
          (i32.lt_s (local.get $x) (i32.const 0)) ;; if x < 0
          (then (i32.const -1))                    ;; return -1
          (else (i32.const 1))))))                 ;; else return 1

  ;; 3. 将数字限制在指定范围内
  (func $clamp (param $x i32) (param $min i32) (param $max i32) (result i32)
    ;; 首先确保 x 不小于 min
    (local.set $x
      (if (result i32)
        (i32.lt_s (local.get $x) (local.get $min))
        (then (local.get $min))
        (else (local.get $x))))
    
    ;; 然后确保 x 不大于 max
    (if (result i32)
      (i32.gt_s (local.get $x) (local.get $max))
      (then (local.get $max))
      (else (local.get $x))))

  ;; 导出函数
  (export "min" (func $min))
  (export "sign" (func $sign))
  (export "clamp" (func $clamp)))
```

**测试用例验证：**

```javascript
// 测试 min 函数
console.assert(wasmExports.min(5, 3) === 3);
console.assert(wasmExports.min(-2, -5) === -5);
console.assert(wasmExports.min(10, 10) === 10);

// 测试 sign 函数
console.assert(wasmExports.sign(42) === 1);
console.assert(wasmExports.sign(-17) === -1);
console.assert(wasmExports.sign(0) === 0);

// 测试 clamp 函数
console.assert(wasmExports.clamp(5, 1, 10) === 5);   // 在范围内
console.assert(wasmExports.clamp(-5, 1, 10) === 1);  // 小于最小值
console.assert(wasmExports.clamp(15, 1, 10) === 10); // 大于最大值
```

**优化版本（使用 select 指令）：**

```wat
;; 更简洁的 min 实现
(func $min_optimized (param $a i32) (param $b i32) (result i32)
  (select
    (local.get $a)
    (local.get $b)
    (i32.lt_s (local.get $a) (local.get $b))))
```
</details>

### 3. 循环结构实现 (25分)

**题目**：实现以下循环相关的函数：

1. `sum_range(start, end)` - 计算从 start 到 end（包含）的整数和
2. `find_first_divisor(n)` - 找到 n 的第一个大于 1 的因子
3. `count_bits(n)` - 计算整数 n 的二进制表示中 1 的个数

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 1. 计算范围内整数和
  (func $sum_range (param $start i32) (param $end i32) (result i32)
    (local $sum i32)
    (local $current i32)
    
    ;; 初始化
    (local.set $sum (i32.const 0))
    (local.set $current (local.get $start))
    
    ;; 检查边界条件
    (if (i32.gt_s (local.get $start) (local.get $end))
      (then (return (i32.const 0))))
    
    ;; 循环累加
    (loop $sum_loop
      ;; 累加当前值
      (local.set $sum
        (i32.add (local.get $sum) (local.get $current)))
      
      ;; 检查是否到达结束条件
      (if (i32.eq (local.get $current) (local.get $end))
        (then (br $sum_loop)))  ;; 跳出循环
      
      ;; 递增计数器
      (local.set $current
        (i32.add (local.get $current) (i32.const 1)))
      
      ;; 继续循环
      (br $sum_loop))
    
    local.get $sum)

  ;; 2. 找到第一个大于 1 的因子
  (func $find_first_divisor (param $n i32) (result i32)
    (local $divisor i32)
    
    ;; 处理特殊情况
    (if (i32.le_s (local.get $n) (i32.const 1))
      (then (return (i32.const 0))))  ;; 无效输入
    
    ;; 从 2 开始尝试
    (local.set $divisor (i32.const 2))
    
    (loop $find_loop
      ;; 检查是否已经超过 sqrt(n)
      (if (i32.gt_u
            (i32.mul (local.get $divisor) (local.get $divisor))
            (local.get $n))
        (then (return (local.get $n))))  ;; n 是质数，返回自身
      
      ;; 检查是否整除
      (if (i32.eqz (i32.rem_u (local.get $n) (local.get $divisor)))
        (then (return (local.get $divisor))))  ;; 找到因子
      
      ;; 尝试下一个可能的因子
      (local.set $divisor
        (i32.add (local.get $divisor) (i32.const 1)))
      
      (br $find_loop))
    
    ;; 理论上不会到达这里
    local.get $n)

  ;; 3. 计算二进制中 1 的个数（Brian Kernighan 算法）
  (func $count_bits (param $n i32) (result i32)
    (local $count i32)
    
    (local.set $count (i32.const 0))
    
    ;; 循环直到 n 变为 0
    (loop $count_loop
      (if (i32.eqz (local.get $n))
        (then (br $count_loop)))  ;; 跳出循环
      
      ;; 清除最低位的 1
      (local.set $n
        (i32.and
          (local.get $n)
          (i32.sub (local.get $n) (i32.const 1))))
      
      ;; 计数加 1
      (local.set $count
        (i32.add (local.get $count) (i32.const 1)))
      
      (br $count_loop))
    
    local.get $count)

  ;; 另一种 count_bits 实现（逐位检查）
  (func $count_bits_simple (param $n i32) (result i32)
    (local $count i32)
    
    (local.set $count (i32.const 0))
    
    (loop $bit_loop
      (if (i32.eqz (local.get $n))
        (then (br $bit_loop)))
      
      ;; 检查最低位
      (if (i32.and (local.get $n) (i32.const 1))
        (then
          (local.set $count
            (i32.add (local.get $count) (i32.const 1)))))
      
      ;; 右移一位
      (local.set $n
        (i32.shr_u (local.get $n) (i32.const 1)))
      
      (br $bit_loop))
    
    local.get $count)

  ;; 导出函数
  (export "sum_range" (func $sum_range))
  (export "find_first_divisor" (func $find_first_divisor))
  (export "count_bits" (func $count_bits))
  (export "count_bits_simple" (func $count_bits_simple)))
```

**测试用例：**

```javascript
// 测试 sum_range
console.assert(wasmExports.sum_range(1, 5) === 15);      // 1+2+3+4+5=15
console.assert(wasmExports.sum_range(10, 10) === 10);    // 单个数
console.assert(wasmExports.sum_range(5, 3) === 0);       // 无效范围

// 测试 find_first_divisor
console.assert(wasmExports.find_first_divisor(12) === 2); // 12 = 2*6
console.assert(wasmExports.find_first_divisor(15) === 3); // 15 = 3*5
console.assert(wasmExports.find_first_divisor(17) === 17);// 17 是质数

// 测试 count_bits
console.assert(wasmExports.count_bits(7) === 3);          // 111₂
console.assert(wasmExports.count_bits(8) === 1);          // 1000₂
console.assert(wasmExports.count_bits(255) === 8);        // 11111111₂

// 数学公式验证 sum_range
function mathSumRange(start, end) {
  if (start > end) return 0;
  return (end - start + 1) * (start + end) / 2;
}
console.assert(wasmExports.sum_range(1, 100) === mathSumRange(1, 100));
```
</details>

## 实践编程题

### 4. 数组操作 (20分)

**题目**：实现一个简单的数组排序算法。要求：

1. 实现冒泡排序算法
2. 数组存储在 WebAssembly 线性内存中
3. 提供初始化、排序和显示数组的函数

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 声明内存（1 页 = 64KB）
  (memory (export "memory") 1)
  
  ;; 交换内存中两个位置的值
  (func $swap (param $ptr1 i32) (param $ptr2 i32)
    (local $temp i32)
    
    ;; 读取第一个值
    (local.set $temp (i32.load (local.get $ptr1)))
    
    ;; 第二个值复制到第一个位置
    (i32.store (local.get $ptr1) (i32.load (local.get $ptr2)))
    
    ;; 第一个值复制到第二个位置
    (i32.store (local.get $ptr2) (local.get $temp)))
  
  ;; 初始化数组
  (func $init_array (param $ptr i32) (param $size i32)
    (local $i i32)
    (local $current_ptr i32)
    
    (local.set $i (i32.const 0))
    (local.set $current_ptr (local.get $ptr))
    
    (loop $init_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $init_loop)))
      
      ;; 存储一些测试数据（倒序）
      (i32.store
        (local.get $current_ptr)
        (i32.sub (local.get $size) (local.get $i)))
      
      ;; 移动到下一个位置
      (local.set $current_ptr
        (i32.add (local.get $current_ptr) (i32.const 4)))
      
      (local.set $i
        (i32.add (local.get $i) (i32.const 1)))
      
      (br $init_loop)))
  
  ;; 冒泡排序实现
  (func $bubble_sort (param $ptr i32) (param $size i32)
    (local $i i32)
    (local $j i32)
    (local $ptr_j i32)
    (local $ptr_j_next i32)
    (local $swapped i32)
    
    ;; 外层循环
    (local.set $i (i32.const 0))
    
    (loop $outer_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $outer_loop)))
      
      (local.set $swapped (i32.const 0))
      
      ;; 内层循环
      (local.set $j (i32.const 0))
      
      (loop $inner_loop
        ;; 检查内层循环边界
        (if (i32.ge_u
              (local.get $j)
              (i32.sub
                (i32.sub (local.get $size) (local.get $i))
                (i32.const 1)))
          (then (br $inner_loop)))
        
        ;; 计算当前和下一个元素的指针
        (local.set $ptr_j
          (i32.add
            (local.get $ptr)
            (i32.mul (local.get $j) (i32.const 4))))
        
        (local.set $ptr_j_next
          (i32.add (local.get $ptr_j) (i32.const 4)))
        
        ;; 比较相邻元素
        (if (i32.gt_s
              (i32.load (local.get $ptr_j))
              (i32.load (local.get $ptr_j_next)))
          (then
            ;; 交换元素
            (call $swap (local.get $ptr_j) (local.get $ptr_j_next))
            (local.set $swapped (i32.const 1))))
        
        ;; 内层循环递增
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $inner_loop))
      
      ;; 如果没有交换，说明已经排序完成
      (if (i32.eqz (local.get $swapped))
        (then (br $outer_loop)))
      
      ;; 外层循环递增
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $outer_loop)))
  
  ;; 获取指定位置的数组元素
  (func $get_element (param $ptr i32) (param $index i32) (result i32)
    (i32.load
      (i32.add
        (local.get $ptr)
        (i32.mul (local.get $index) (i32.const 4)))))
  
  ;; 设置指定位置的数组元素
  (func $set_element (param $ptr i32) (param $index i32) (param $value i32)
    (i32.store
      (i32.add
        (local.get $ptr)
        (i32.mul (local.get $index) (i32.const 4)))
      (local.get $value)))
  
  ;; 导出函数
  (export "init_array" (func $init_array))
  (export "bubble_sort" (func $bubble_sort))
  (export "get_element" (func $get_element))
  (export "set_element" (func $set_element)))
```

**JavaScript 测试代码：**

```html
<!DOCTYPE html>
<html>
<head>
    <title>WASM 数组排序测试</title>
</head>
<body>
    <h1>WebAssembly 冒泡排序演示</h1>
    <button onclick="testSort()">测试排序</button>
    <div id="output"></div>

    <script>
        let wasmModule;
        
        async function loadWasm() {
            wasmModule = await WebAssembly.instantiateStreaming(
                fetch('bubble_sort.wasm')
            );
        }
        
        function displayArray(ptr, size, title) {
            const { memory, get_element } = wasmModule.instance.exports;
            const elements = [];
            
            for (let i = 0; i < size; i++) {
                elements.push(get_element(ptr, i));
            }
            
            return `<p><strong>${title}:</strong> [${elements.join(', ')}]</p>`;
        }
        
        async function testSort() {
            if (!wasmModule) await loadWasm();
            
            const { init_array, bubble_sort, set_element } = wasmModule.instance.exports;
            
            const arrayPtr = 0;  // 从内存起始位置开始
            const arraySize = 8;
            
            // 初始化数组（倒序）
            init_array(arrayPtr, arraySize);
            
            let output = '<h3>排序测试结果:</h3>';
            output += displayArray(arrayPtr, arraySize, '排序前');
            
            // 执行排序
            const startTime = performance.now();
            bubble_sort(arrayPtr, arraySize);
            const endTime = performance.now();
            
            output += displayArray(arrayPtr, arraySize, '排序后');
            output += `<p>排序耗时: ${(endTime - startTime).toFixed(4)} ms</p>`;
            
            // 测试自定义数组
            const testData = [64, 34, 25, 12, 22, 11, 90, 5];
            for (let i = 0; i < testData.length; i++) {
                set_element(arrayPtr, i, testData[i]);
            }
            
            output += '<h3>自定义数组测试:</h3>';
            output += displayArray(arrayPtr, testData.length, '排序前');
            
            bubble_sort(arrayPtr, testData.length);
            output += displayArray(arrayPtr, testData.length, '排序后');
            
            document.getElementById('output').innerHTML = output;
        }
        
        loadWasm();
    </script>
</body>
</html>
```

**算法复杂度分析：**
- **时间复杂度**：O(n²)
- **空间复杂度**：O(1)
- **稳定性**：稳定排序算法
</details>

### 5. 字符串处理 (20分)

**题目**：实现基本的字符串操作函数（假设字符串以 null 结尾）：

1. `string_length(ptr)` - 计算字符串长度
2. `string_compare(ptr1, ptr2)` - 比较两个字符串
3. `string_copy(src, dst)` - 复制字符串

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 1)
  
  ;; 计算字符串长度
  (func $string_length (param $ptr i32) (result i32)
    (local $length i32)
    (local $current_ptr i32)
    
    (local.set $length (i32.const 0))
    (local.set $current_ptr (local.get $ptr))
    
    (loop $length_loop
      ;; 检查是否遇到 null 终止符
      (if (i32.eqz (i32.load8_u (local.get $current_ptr)))
        (then (br $length_loop)))
      
      ;; 递增长度和指针
      (local.set $length
        (i32.add (local.get $length) (i32.const 1)))
      (local.set $current_ptr
        (i32.add (local.get $current_ptr) (i32.const 1)))
      
      (br $length_loop))
    
    local.get $length)
  
  ;; 字符串比较
  ;; 返回值: 0=相等, <0=str1<str2, >0=str1>str2
  (func $string_compare (param $ptr1 i32) (param $ptr2 i32) (result i32)
    (local $char1 i32)
    (local $char2 i32)
    
    (loop $compare_loop
      ;; 读取当前字符
      (local.set $char1 (i32.load8_u (local.get $ptr1)))
      (local.set $char2 (i32.load8_u (local.get $ptr2)))
      
      ;; 如果字符不相等，返回差值
      (if (i32.ne (local.get $char1) (local.get $char2))
        (then
          (return
            (i32.sub (local.get $char1) (local.get $char2)))))
      
      ;; 如果遇到字符串结尾，返回 0（相等）
      (if (i32.eqz (local.get $char1))
        (then (return (i32.const 0))))
      
      ;; 移动到下一个字符
      (local.set $ptr1 (i32.add (local.get $ptr1) (i32.const 1)))
      (local.set $ptr2 (i32.add (local.get $ptr2) (i32.const 1)))
      
      (br $compare_loop))
    
    ;; 理论上不会到达这里
    i32.const 0)
  
  ;; 字符串复制
  (func $string_copy (param $src i32) (param $dst i32) (result i32)
    (local $char i32)
    (local $original_dst i32)
    
    ;; 保存原始目标指针
    (local.set $original_dst (local.get $dst))
    
    (loop $copy_loop
      ;; 读取源字符
      (local.set $char (i32.load8_u (local.get $src)))
      
      ;; 写入目标位置
      (i32.store8 (local.get $dst) (local.get $char))
      
      ;; 如果遇到 null 终止符，结束复制
      (if (i32.eqz (local.get $char))
        (then (br $copy_loop)))
      
      ;; 移动指针
      (local.set $src (i32.add (local.get $src) (i32.const 1)))
      (local.set $dst (i32.add (local.get $dst) (i32.const 1)))
      
      (br $copy_loop))
    
    ;; 返回目标字符串指针
    local.get $original_dst)
  
  ;; 字符串连接
  (func $string_concat (param $dst i32) (param $src i32) (result i32)
    (local $dst_end i32)
    (local $original_dst i32)
    
    ;; 保存原始目标指针
    (local.set $original_dst (local.get $dst))
    
    ;; 找到目标字符串的末尾
    (local.set $dst_end (local.get $dst))
    (loop $find_end_loop
      (if (i32.eqz (i32.load8_u (local.get $dst_end)))
        (then (br $find_end_loop)))
      
      (local.set $dst_end
        (i32.add (local.get $dst_end) (i32.const 1)))
      (br $find_end_loop))
    
    ;; 从末尾开始复制源字符串
    (call $string_copy (local.get $src) (local.get $dst_end))
    
    ;; 返回目标字符串指针
    local.get $original_dst)
  
  ;; 在字符串中查找字符
  (func $string_find_char (param $str i32) (param $char i32) (result i32)
    (local $current_char i32)
    (local $index i32)
    
    (local.set $index (i32.const 0))
    
    (loop $find_loop
      (local.set $current_char (i32.load8_u (local.get $str)))
      
      ;; 如果遇到字符串结尾，返回 -1
      (if (i32.eqz (local.get $current_char))
        (then (return (i32.const -1))))
      
      ;; 如果找到目标字符，返回索引
      (if (i32.eq (local.get $current_char) (local.get $char))
        (then (return (local.get $index))))
      
      ;; 移动到下一个字符
      (local.set $str (i32.add (local.get $str) (i32.const 1)))
      (local.set $index (i32.add (local.get $index) (i32.const 1)))
      
      (br $find_loop))
    
    i32.const -1)
  
  ;; 辅助函数：将 JavaScript 字符串写入内存
  (func $write_string (param $ptr i32) (param $char i32)
    (i32.store8 (local.get $ptr) (local.get $char)))
  
  ;; 导出函数
  (export "string_length" (func $string_length))
  (export "string_compare" (func $string_compare))
  (export "string_copy" (func $string_copy))
  (export "string_concat" (func $string_concat))
  (export "string_find_char" (func $string_find_char))
  (export "write_string" (func $write_string)))
```

**JavaScript 测试代码：**

```javascript
async function testStringFunctions() {
    const wasmModule = await WebAssembly.instantiateStreaming(
        fetch('string_ops.wasm')
    );
    
    const { memory, string_length, string_compare, string_copy, 
            string_concat, string_find_char, write_string } = wasmModule.instance.exports;
    
    const memoryView = new Uint8Array(memory.buffer);
    
    // 辅助函数：将 JavaScript 字符串写入 WASM 内存
    function writeStringToMemory(ptr, str) {
        for (let i = 0; i < str.length; i++) {
            memoryView[ptr + i] = str.charCodeAt(i);
        }
        memoryView[ptr + str.length] = 0; // null 终止符
    }
    
    // 辅助函数：从 WASM 内存读取字符串
    function readStringFromMemory(ptr) {
        let str = '';
        let i = 0;
        while (memoryView[ptr + i] !== 0) {
            str += String.fromCharCode(memoryView[ptr + i]);
            i++;
        }
        return str;
    }
    
    // 测试字符串长度
    const str1Ptr = 0;
    const str2Ptr = 100;
    const str3Ptr = 200;
    
    writeStringToMemory(str1Ptr, "Hello");
    writeStringToMemory(str2Ptr, "World");
    writeStringToMemory(str3Ptr, "Hello");
    
    console.log('测试字符串长度:');
    console.log(`"Hello" 长度: ${string_length(str1Ptr)}`); // 应该是 5
    console.log(`"World" 长度: ${string_length(str2Ptr)}`); // 应该是 5
    
    // 测试字符串比较
    console.log('\n测试字符串比较:');
    console.log(`"Hello" vs "World": ${string_compare(str1Ptr, str2Ptr)}`); // < 0
    console.log(`"Hello" vs "Hello": ${string_compare(str1Ptr, str3Ptr)}`); // = 0
    console.log(`"World" vs "Hello": ${string_compare(str2Ptr, str1Ptr)}`); // > 0
    
    // 测试字符串复制
    console.log('\n测试字符串复制:');
    const copyPtr = 300;
    string_copy(str1Ptr, copyPtr);
    console.log(`复制的字符串: "${readStringFromMemory(copyPtr)}"`);
    
    // 测试字符串连接
    console.log('\n测试字符串连接:');
    const concatPtr = 400;
    writeStringToMemory(concatPtr, "Hello ");
    string_concat(concatPtr, str2Ptr);
    console.log(`连接后的字符串: "${readStringFromMemory(concatPtr)}"`);
    
    // 测试字符查找
    console.log('\n测试字符查找:');
    const findIndex = string_find_char(str1Ptr, 'l'.charCodeAt(0));
    console.log(`在 "Hello" 中查找 'l': 索引 ${findIndex}`); // 应该是 2
    
    const notFoundIndex = string_find_char(str1Ptr, 'x'.charCodeAt(0));
    console.log(`在 "Hello" 中查找 'x': 索引 ${notFoundIndex}`); // 应该是 -1
}

testStringFunctions();
```

**测试用例验证：**
- `string_length("Hello")` → 5
- `string_compare("Hello", "World")` → 负数
- `string_copy("Hello", dst)` → 复制成功
- `string_concat("Hello ", "World")` → "Hello World"
- `string_find_char("Hello", 'l')` → 2
</details>

## 评分标准

| 题目类型 | 分值分布 | 评分要点 |
|---------|---------|----------|
| **语法理解** | 35分 | WAT 语法正确性、执行流程理解 |
| **实践编程** | 40分 | 算法实现正确性、代码质量 |
| **综合应用** | 25分 | 内存操作、性能考虑、错误处理 |

**总分：100分**
**及格线：60分**

---

**🎯 核心要点**：
- 掌握 WAT 的基本语法和执行模型
- 理解栈式虚拟机的操作方式
- 能够实现基本的算法和数据结构
- 学会在 WebAssembly 中处理内存操作