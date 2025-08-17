# 第4章 练习题

## 4.1 模块结构练习

### 练习 4.1.1 基础模块创建 (10分)

**题目**: 创建一个完整的 WebAssembly 模块，包含以下要求：
- 导入一个名为 "env.print" 的函数，接受 i32 参数
- 定义一个内存段，大小为 1 页
- 实现一个名为 "hello" 的函数，调用导入的 print 函数输出数字 42
- 导出 "hello" 函数和内存

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 导入环境函数
  (import "env" "print" (func $print (param i32)))
  
  ;; 定义内存
  (memory (export "memory") 1)
  
  ;; 实现 hello 函数
  (func $hello
    (call $print (i32.const 42)))
  
  ;; 导出函数
  (export "hello" (func $hello)))
```

**解释**: 
- `import` 声明必须在模块定义的前面
- `memory` 定义了 1 页内存（64KB）并同时导出
- `func` 定义函数，使用 `call` 指令调用导入的函数
- `export` 使函数可从外部访问

</details>

### 练习 4.1.2 模块验证错误修复 (15分)

**题目**: 以下 WAT 代码包含多个验证错误，请找出并修复所有错误：

```wat
(module
  (func $broken (result i32)
    f32.const 3.14
    i32.add))
```

<details>
<summary>🔍 参考答案</summary>

**错误分析**:
1. 函数返回类型是 i32，但提供了 f32 常量
2. i32.add 需要两个 i32 操作数，但栈上只有一个 f32 值
3. 类型不匹配

**修复版本1** (返回整数):
```wat
(module
  (func $fixed (result i32)
    i32.const 42))
```

**修复版本2** (进行类型转换):
```wat
(module
  (func $fixed (result i32)
    f32.const 3.14
    i32.trunc_f32_s))
```

**修复版本3** (实际的加法操作):
```wat
(module
  (func $fixed (result i32)
    i32.const 10
    i32.const 32
    i32.add))
```

</details>

### 练习 4.1.3 复杂模块设计 (20分)

**题目**: 设计一个数学运算库模块，要求：
- 定义一个表示二元运算的类型
- 实现加法、减法、乘法、除法四个函数
- 使用全局变量记录运算次数
- 提供重置计数器的函数
- 所有运算函数使用相同的类型签名

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 定义二元运算类型
  (type $binary_op (func (param i32 i32) (result i32)))
  
  ;; 全局运算计数器
  (global $operation_count (mut i32) (i32.const 0))
  
  ;; 递增计数器的辅助函数
  (func $increment_count
    (global.set $operation_count
      (i32.add (global.get $operation_count) (i32.const 1))))
  
  ;; 加法函数
  (func $add (type $binary_op)
    (call $increment_count)
    (i32.add (local.get 0) (local.get 1)))
  
  ;; 减法函数
  (func $subtract (type $binary_op)
    (call $increment_count)
    (i32.sub (local.get 0) (local.get 1)))
  
  ;; 乘法函数
  (func $multiply (type $binary_op)
    (call $increment_count)
    (i32.mul (local.get 0) (local.get 1)))
  
  ;; 除法函数（带除零检查）
  (func $divide (type $binary_op)
    (call $increment_count)
    (if (result i32)
      (i32.eqz (local.get 1))
      (then (i32.const 0))  ;; 除零返回0
      (else (i32.div_s (local.get 0) (local.get 1)))))
  
  ;; 获取运算次数
  (func $get_count (result i32)
    (global.get $operation_count))
  
  ;; 重置计数器
  (func $reset_count
    (global.set $operation_count (i32.const 0)))
  
  ;; 导出函数
  (export "add" (func $add))
  (export "subtract" (func $subtract))
  (export "multiply" (func $multiply))
  (export "divide" (func $divide))
  (export "get_count" (func $get_count))
  (export "reset_count" (func $reset_count)))
```

**设计要点**:
- 使用 `type` 定义统一的函数签名
- 全局变量使用 `mut` 关键字标记为可变
- 除法函数包含安全检查避免除零错误
- 模块化设计，职责清晰

</details>

## 4.2 函数定义与调用练习

### 练习 4.2.1 多参数函数 (10分)

**题目**: 实现一个函数 `calculate_average`，计算三个整数的平均值（返回整数）。

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (func $calculate_average (param $a i32) (param $b i32) (param $c i32) (result i32)
    ;; 计算总和
    (i32.add
      (i32.add (local.get $a) (local.get $b))
      (local.get $c))
    ;; 除以3
    (i32.div_s (i32.const 3)))
  
  (export "calculate_average" (func $calculate_average)))
```

**优化版本**（使用局部变量）:
```wat
(module
  (func $calculate_average (param $a i32) (param $b i32) (param $c i32) (result i32)
    (local $sum i32)
    
    ;; 计算总和
    (local.set $sum
      (i32.add
        (i32.add (local.get $a) (local.get $b))
        (local.get $c)))
    
    ;; 返回平均值
    (i32.div_s (local.get $sum) (i32.const 3)))
  
  (export "calculate_average" (func $calculate_average)))
```

</details>

### 练习 4.2.2 递归函数实现 (15分)

**题目**: 实现递归和迭代两个版本的斐波那契数列计算函数。

<details>
<summary>🔍 参考答案</summary>

**递归版本**:
```wat
(module
  (func $fibonacci_recursive (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (local.get $n))
      (else
        (i32.add
          (call $fibonacci_recursive
            (i32.sub (local.get $n) (i32.const 1)))
          (call $fibonacci_recursive
            (i32.sub (local.get $n) (i32.const 2)))))))
  
  (export "fibonacci_recursive" (func $fibonacci_recursive)))
```

**迭代版本**:
```wat
(module
  (func $fibonacci_iterative (param $n i32) (result i32)
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
        (loop $fib_loop
          ;; temp = a + b
          (local.set $temp (i32.add (local.get $a) (local.get $b)))
          ;; a = b
          (local.set $a (local.get $b))
          ;; b = temp
          (local.set $b (local.get $temp))
          
          ;; i++
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          
          ;; 继续循环条件
          (br_if $fib_loop (i32.le_s (local.get $i) (local.get $n))))
        
        local.get $b)))
  
  (export "fibonacci_iterative" (func $fibonacci_iterative)))
```

**性能对比**:
- 递归版本：简洁但时间复杂度 O(2^n)
- 迭代版本：高效，时间复杂度 O(n)，空间复杂度 O(1)

</details>

### 练习 4.2.3 间接调用实现 (20分)

**题目**: 创建一个计算器，使用函数表实现间接调用：
- 定义加、减、乘、除四个操作函数
- 创建函数表并初始化
- 实现一个 `calculate` 函数，根据操作码调用对应的运算

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 定义二元运算类型
  (type $binary_op (func (param i32 i32) (result i32)))
  
  ;; 定义函数表，存储4个函数
  (table $op_table 4 funcref)
  
  ;; 加法函数
  (func $add (type $binary_op)
    (i32.add (local.get 0) (local.get 1)))
  
  ;; 减法函数
  (func $sub (type $binary_op)
    (i32.sub (local.get 0) (local.get 1)))
  
  ;; 乘法函数
  (func $mul (type $binary_op)
    (i32.mul (local.get 0) (local.get 1)))
  
  ;; 除法函数（带安全检查）
  (func $div (type $binary_op)
    (if (result i32)
      (i32.eqz (local.get 1))
      (then (i32.const 0))
      (else (i32.div_s (local.get 0) (local.get 1)))))
  
  ;; 初始化函数表
  (elem (i32.const 0) $add $sub $mul $div)
  
  ;; 计算器主函数
  ;; op: 0=加法, 1=减法, 2=乘法, 3=除法
  (func $calculate (param $op i32) (param $a i32) (param $b i32) (result i32)
    ;; 检查操作码范围
    (if (result i32)
      (i32.or
        (i32.lt_s (local.get $op) (i32.const 0))
        (i32.ge_s (local.get $op) (i32.const 4)))
      (then (i32.const 0))  ;; 无效操作返回0
      (else
        ;; 间接调用
        (call_indirect (type $binary_op)
          (local.get $a)
          (local.get $b)
          (local.get $op)))))
  
  ;; 便利函数
  (func $add_values (param $a i32) (param $b i32) (result i32)
    (call $calculate (i32.const 0) (local.get $a) (local.get $b)))
  
  (func $subtract_values (param $a i32) (param $b i32) (result i32)
    (call $calculate (i32.const 1) (local.get $a) (local.get $b)))
  
  (func $multiply_values (param $a i32) (param $b i32) (result i32)
    (call $calculate (i32.const 2) (local.get $a) (local.get $b)))
  
  (func $divide_values (param $a i32) (param $b i32) (result i32)
    (call $calculate (i32.const 3) (local.get $a) (local.get $b)))
  
  ;; 导出函数
  (export "calculate" (func $calculate))
  (export "add" (func $add_values))
  (export "subtract" (func $subtract_values))
  (export "multiply" (func $multiply_values))
  (export "divide" (func $divide_values))
  (export "table" (table $op_table)))
```

**使用示例**:
```javascript
// JavaScript 调用示例
const result1 = instance.exports.calculate(0, 10, 5); // 加法: 15
const result2 = instance.exports.calculate(3, 10, 2); // 除法: 5
const result3 = instance.exports.add(10, 5);          // 便利函数: 15
```

</details>

## 4.3 数据类型系统练习

### 练习 4.3.1 类型转换综合 (15分)

**题目**: 实现一个类型转换工具集，包含以下函数：
- `int_to_float`: 将整数转换为浮点数
- `float_to_int_safe`: 安全地将浮点数转换为整数（处理溢出）
- `bits_to_float`: 将整数位模式重新解释为浮点数
- `float_to_bits`: 将浮点数位模式重新解释为整数

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 整数转浮点数
  (func $int_to_float (param $value i32) (result f32)
    (f32.convert_i32_s (local.get $value)))
  
  ;; 安全的浮点数转整数
  (func $float_to_int_safe (param $value f32) (result i32)
    (local $result i32)
    
    ;; 检查是否为 NaN
    (if (f32.ne (local.get $value) (local.get $value))
      (then (return (i32.const 0))))
    
    ;; 检查是否为无穷大
    (if (f32.eq (local.get $value) (f32.const inf))
      (then (return (i32.const 2147483647))))  ;; i32 最大值
    
    (if (f32.eq (local.get $value) (f32.const -inf))
      (then (return (i32.const -2147483648)))) ;; i32 最小值
    
    ;; 检查溢出范围
    (if (f32.gt (local.get $value) (f32.const 2147483647.0))
      (then (return (i32.const 2147483647))))
    
    (if (f32.lt (local.get $value) (f32.const -2147483648.0))
      (then (return (i32.const -2147483648))))
    
    ;; 安全转换
    (i32.trunc_sat_f32_s (local.get $value)))
  
  ;; 位模式重新解释：i32 → f32
  (func $bits_to_float (param $bits i32) (result f32)
    (f32.reinterpret_i32 (local.get $bits)))
  
  ;; 位模式重新解释：f32 → i32
  (func $float_to_bits (param $value f32) (result i32)
    (i32.reinterpret_f32 (local.get $value)))
  
  ;; 演示函数：分析浮点数的组成部分
  (func $analyze_float (param $value f32) (param $sign_ptr i32) (param $exp_ptr i32) (param $frac_ptr i32)
    (local $bits i32)
    (local $sign i32)
    (local $exponent i32)
    (local $fraction i32)
    
    ;; 获取位模式
    (local.set $bits (call $float_to_bits (local.get $value)))
    
    ;; 提取符号位（第31位）
    (local.set $sign (i32.shr_u (local.get $bits) (i32.const 31)))
    
    ;; 提取指数（第30-23位）
    (local.set $exponent
      (i32.and
        (i32.shr_u (local.get $bits) (i32.const 23))
        (i32.const 0xFF)))
    
    ;; 提取尾数（第22-0位）
    (local.set $fraction
      (i32.and (local.get $bits) (i32.const 0x7FFFFF)))
    
    ;; 存储结果（假设内存已分配）
    (i32.store (local.get $sign_ptr) (local.get $sign))
    (i32.store (local.get $exp_ptr) (local.get $exponent))
    (i32.store (local.get $frac_ptr) (local.get $fraction)))
  
  ;; 内存用于演示
  (memory (export "memory") 1)
  
  ;; 导出函数
  (export "int_to_float" (func $int_to_float))
  (export "float_to_int_safe" (func $float_to_int_safe))
  (export "bits_to_float" (func $bits_to_float))
  (export "float_to_bits" (func $float_to_bits))
  (export "analyze_float" (func $analyze_float)))
```

**测试用例**:
```javascript
// JavaScript 测试代码
const exports = instance.exports;

// 测试基本转换
console.log(exports.int_to_float(42));        // 42.0
console.log(exports.float_to_int_safe(3.14)); // 3

// 测试特殊值
console.log(exports.float_to_int_safe(NaN));      // 0
console.log(exports.float_to_int_safe(Infinity)); // 2147483647

// 测试位模式操作
const pi_bits = exports.float_to_bits(3.14159);
console.log(pi_bits.toString(16)); // 显示十六进制位模式
console.log(exports.bits_to_float(pi_bits)); // 应该等于 3.14159
```

</details>

### 练习 4.3.2 位操作实战 (20分)

**题目**: 实现一个位操作工具库，支持：
- 位字段操作（设置、清除、测试多个连续位）
- 字节序转换（大端⇄小端）
- 简单的位运算加密（XOR 密码）
- 计算整数中设置位的数量（popcount）

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 设置位字段（从 start_bit 开始的 num_bits 位设置为 value）
  (func $set_bit_field (param $original i32) (param $start_bit i32) (param $num_bits i32) (param $value i32) (result i32)
    (local $mask i32)
    (local $shifted_value i32)
    
    ;; 创建掩码：(1 << num_bits) - 1
    (local.set $mask
      (i32.sub
        (i32.shl (i32.const 1) (local.get $num_bits))
        (i32.const 1)))
    
    ;; 限制 value 到 mask 范围内
    (local.set $shifted_value
      (i32.shl
        (i32.and (local.get $value) (local.get $mask))
        (local.get $start_bit)))
    
    ;; 将 mask 移动到正确位置
    (local.set $mask (i32.shl (local.get $mask) (local.get $start_bit)))
    
    ;; 清除原始值中的目标位，然后设置新值
    (i32.or
      (i32.and (local.get $original) (i32.xor (local.get $mask) (i32.const -1)))
      (local.get $shifted_value)))
  
  ;; 获取位字段值
  (func $get_bit_field (param $value i32) (param $start_bit i32) (param $num_bits i32) (result i32)
    (local $mask i32)
    
    ;; 创建掩码
    (local.set $mask
      (i32.sub
        (i32.shl (i32.const 1) (local.get $num_bits))
        (i32.const 1)))
    
    ;; 右移并应用掩码
    (i32.and
      (i32.shr_u (local.get $value) (local.get $start_bit))
      (local.get $mask)))
  
  ;; 字节序转换（32位）
  (func $byte_swap_32 (param $value i32) (result i32)
    (i32.or
      (i32.or
        (i32.shl (i32.and (local.get $value) (i32.const 0xFF)) (i32.const 24))
        (i32.shl (i32.and (local.get $value) (i32.const 0xFF00)) (i32.const 8)))
      (i32.or
        (i32.shr_u (i32.and (local.get $value) (i32.const 0xFF0000)) (i32.const 8))
        (i32.shr_u (i32.and (local.get $value) (i32.const 0xFF000000)) (i32.const 24)))))
  
  ;; XOR 加密/解密
  (func $xor_encrypt (param $data_ptr i32) (param $key_ptr i32) (param $length i32)
    (local $i i32)
    (local $data_byte i32)
    (local $key_byte i32)
    (local $key_length i32)
    
    ;; 假设密钥长度为4字节
    (local.set $key_length (i32.const 4))
    
    (loop $encrypt_loop
      ;; 检查是否完成
      (br_if 1 (i32.ge_u (local.get $i) (local.get $length)))
      
      ;; 读取数据字节
      (local.set $data_byte
        (i32.load8_u
          (i32.add (local.get $data_ptr) (local.get $i))))
      
      ;; 读取密钥字节（循环使用密钥）
      (local.set $key_byte
        (i32.load8_u
          (i32.add
            (local.get $key_ptr)
            (i32.rem_u (local.get $i) (local.get $key_length)))))
      
      ;; XOR 操作并写回
      (i32.store8
        (i32.add (local.get $data_ptr) (local.get $i))
        (i32.xor (local.get $data_byte) (local.get $key_byte)))
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $encrypt_loop)))
  
  ;; 计算设置位数量（popcount）
  (func $popcount (param $value i32) (result i32)
    (local $count i32)
    (local $temp i32)
    
    (local.set $temp (local.get $value))
    
    (loop $count_loop
      ;; 如果 temp 为 0，退出循环
      (br_if 1 (i32.eqz (local.get $temp)))
      
      ;; temp = temp & (temp - 1) 清除最低位的1
      (local.set $temp
        (i32.and
          (local.get $temp)
          (i32.sub (local.get $temp) (i32.const 1))))
      
      ;; 递增计数
      (local.set $count (i32.add (local.get $count) (i32.const 1)))
      
      (br $count_loop))
    
    local.get $count)
  
  ;; 快速 popcount（使用位操作技巧）
  (func $popcount_fast (param $value i32) (result i32)
    (local $temp i32)
    
    (local.set $temp (local.get $value))
    
    ;; Brian Kernighan's algorithm 的优化版本
    ;; 每次迭代清除一个设置位
    
    ;; 使用并行位计数技术
    ;; temp = temp - ((temp >> 1) & 0x55555555)
    (local.set $temp
      (i32.sub
        (local.get $temp)
        (i32.and
          (i32.shr_u (local.get $temp) (i32.const 1))
          (i32.const 0x55555555))))
    
    ;; temp = (temp & 0x33333333) + ((temp >> 2) & 0x33333333)
    (local.set $temp
      (i32.add
        (i32.and (local.get $temp) (i32.const 0x33333333))
        (i32.and
          (i32.shr_u (local.get $temp) (i32.const 2))
          (i32.const 0x33333333))))
    
    ;; temp = (temp + (temp >> 4)) & 0x0F0F0F0F
    (local.set $temp
      (i32.and
        (i32.add
          (local.get $temp)
          (i32.shr_u (local.get $temp) (i32.const 4)))
        (i32.const 0x0F0F0F0F)))
    
    ;; temp = temp + (temp >> 8)
    (local.set $temp
      (i32.add
        (local.get $temp)
        (i32.shr_u (local.get $temp) (i32.const 8))))
    
    ;; temp = temp + (temp >> 16)
    (local.set $temp
      (i32.add
        (local.get $temp)
        (i32.shr_u (local.get $temp) (i32.const 16))))
    
    ;; 返回低8位
    (i32.and (local.get $temp) (i32.const 0x3F)))
  
  ;; 内存
  (memory (export "memory") 1)
  
  ;; 导出函数
  (export "set_bit_field" (func $set_bit_field))
  (export "get_bit_field" (func $get_bit_field))
  (export "byte_swap_32" (func $byte_swap_32))
  (export "xor_encrypt" (func $xor_encrypt))
  (export "popcount" (func $popcount))
  (export "popcount_fast" (func $popcount_fast)))
```

**测试用例**:
```javascript
const exports = instance.exports;
const memory = new Uint8Array(exports.memory.buffer);

// 测试位字段操作
let value = 0;
value = exports.set_bit_field(value, 4, 4, 0b1010); // 在第4-7位设置值1010
console.log(value.toString(2)); // 应该显示 10100000

const field_value = exports.get_bit_field(value, 4, 4);
console.log(field_value.toString(2)); // 应该显示 1010

// 测试字节序转换
const original = 0x12345678;
const swapped = exports.byte_swap_32(original);
console.log(swapped.toString(16)); // 应该显示 78563412

// 测试 popcount
console.log(exports.popcount(0b11010110)); // 应该是 5
console.log(exports.popcount_fast(0b11010110)); // 应该也是 5
```

</details>

## 4.4 综合实战练习

### 练习 4.4.1 字符串处理库 (25分)

**题目**: 实现一个基础的字符串处理库，包含：
- 字符串长度计算
- 字符串比较
- 字符串查找（子串搜索）
- 字符串复制
- 字符串反转

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 内存用于字符串操作
  (memory (export "memory") 1)
  
  ;; 计算字符串长度（以null结尾）
  (func $strlen (param $str_ptr i32) (result i32)
    (local $length i32)
    
    (loop $count_loop
      ;; 检查当前字符是否为null
      (br_if 1 (i32.eqz (i32.load8_u (i32.add (local.get $str_ptr) (local.get $length)))))
      
      ;; 增加长度计数
      (local.set $length (i32.add (local.get $length) (i32.const 1)))
      
      (br $count_loop))
    
    local.get $length)
  
  ;; 字符串比较
  (func $strcmp (param $str1_ptr i32) (param $str2_ptr i32) (result i32)
    (local $i i32)
    (local $c1 i32)
    (local $c2 i32)
    
    (loop $compare_loop
      ;; 读取当前字符
      (local.set $c1 (i32.load8_u (i32.add (local.get $str1_ptr) (local.get $i))))
      (local.set $c2 (i32.load8_u (i32.add (local.get $str2_ptr) (local.get $i))))
      
      ;; 如果字符不相等
      (if (i32.ne (local.get $c1) (local.get $c2))
        (then
          (return
            (if (result i32)
              (i32.lt_u (local.get $c1) (local.get $c2))
              (then (i32.const -1))
              (else (i32.const 1))))))
      
      ;; 如果到达字符串末尾
      (if (i32.eqz (local.get $c1))
        (then (return (i32.const 0))))
      
      ;; 移动到下一个字符
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $compare_loop)))
  
  ;; 字符串查找（KMP算法简化版）
  (func $strstr (param $haystack_ptr i32) (param $needle_ptr i32) (result i32)
    (local $haystack_len i32)
    (local $needle_len i32)
    (local $i i32)
    (local $j i32)
    (local $match i32)
    
    ;; 获取字符串长度
    (local.set $haystack_len (call $strlen (local.get $haystack_ptr)))
    (local.set $needle_len (call $strlen (local.get $needle_ptr)))
    
    ;; 如果needle为空，返回haystack开始位置
    (if (i32.eqz (local.get $needle_len))
      (then (return (local.get $haystack_ptr))))
    
    ;; 如果needle比haystack长，返回null
    (if (i32.gt_u (local.get $needle_len) (local.get $haystack_len))
      (then (return (i32.const 0))))
    
    ;; 朴素字符串搜索
    (loop $search_loop
      ;; 检查是否超出搜索范围
      (br_if 1 (i32.gt_u
        (i32.add (local.get $i) (local.get $needle_len))
        (local.get $haystack_len)))
      
      ;; 比较子串
      (local.set $match (i32.const 1))
      (local.set $j (i32.const 0))
      
      (loop $match_loop
        (br_if 1 (i32.ge_u (local.get $j) (local.get $needle_len)))
        
        (if (i32.ne
          (i32.load8_u (i32.add (local.get $haystack_ptr) (i32.add (local.get $i) (local.get $j))))
          (i32.load8_u (i32.add (local.get $needle_ptr) (local.get $j))))
          (then
            (local.set $match (i32.const 0))
            (br 1)))
        
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $match_loop))
      
      ;; 如果找到匹配
      (if (local.get $match)
        (then (return (i32.add (local.get $haystack_ptr) (local.get $i)))))
      
      ;; 移动到下一个位置
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $search_loop))
    
    ;; 未找到，返回null
    i32.const 0)
  
  ;; 字符串复制
  (func $strcpy (param $dest_ptr i32) (param $src_ptr i32) (result i32)
    (local $i i32)
    (local $c i32)
    
    (loop $copy_loop
      ;; 读取源字符
      (local.set $c (i32.load8_u (i32.add (local.get $src_ptr) (local.get $i))))
      
      ;; 写入目标位置
      (i32.store8 (i32.add (local.get $dest_ptr) (local.get $i)) (local.get $c))
      
      ;; 如果是null终止符，结束复制
      (if (i32.eqz (local.get $c))
        (then (return (local.get $dest_ptr))))
      
      ;; 移动到下一个字符
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $copy_loop)))
  
  ;; 字符串反转
  (func $strrev (param $str_ptr i32) (result i32)
    (local $length i32)
    (local $left i32)
    (local $right i32)
    (local $temp i32)
    
    ;; 获取字符串长度
    (local.set $length (call $strlen (local.get $str_ptr)))
    
    ;; 如果长度小于2，无需反转
    (if (i32.lt_u (local.get $length) (i32.const 2))
      (then (return (local.get $str_ptr))))
    
    ;; 设置左右指针
    (local.set $left (i32.const 0))
    (local.set $right (i32.sub (local.get $length) (i32.const 1)))
    
    ;; 反转字符
    (loop $reverse_loop
      ;; 如果左指针大于等于右指针，结束
      (br_if 1 (i32.ge_u (local.get $left) (local.get $right)))
      
      ;; 交换字符
      (local.set $temp
        (i32.load8_u (i32.add (local.get $str_ptr) (local.get $left))))
      
      (i32.store8
        (i32.add (local.get $str_ptr) (local.get $left))
        (i32.load8_u (i32.add (local.get $str_ptr) (local.get $right))))
      
      (i32.store8
        (i32.add (local.get $str_ptr) (local.get $right))
        (local.get $temp))
      
      ;; 移动指针
      (local.set $left (i32.add (local.get $left) (i32.const 1)))
      (local.set $right (i32.sub (local.get $right) (i32.const 1)))
      
      (br $reverse_loop))
    
    local.get $str_ptr)
  
  ;; 导出函数
  (export "strlen" (func $strlen))
  (export "strcmp" (func $strcmp))
  (export "strstr" (func $strstr))
  (export "strcpy" (func $strcpy))
  (export "strrev" (func $strrev)))
```

**测试用例**:
```javascript
const exports = instance.exports;
const memory = new Uint8Array(exports.memory.buffer);

// 辅助函数：将字符串写入内存
function writeString(ptr, str) {
  for (let i = 0; i < str.length; i++) {
    memory[ptr + i] = str.charCodeAt(i);
  }
  memory[ptr + str.length] = 0; // null终止符
}

// 辅助函数：从内存读取字符串
function readString(ptr) {
  let result = '';
  let i = 0;
  while (memory[ptr + i] !== 0) {
    result += String.fromCharCode(memory[ptr + i]);
    i++;
  }
  return result;
}

// 测试字符串操作
writeString(0, "Hello, World!");
writeString(100, "World");
writeString(200, "Hello");

console.log("Length:", exports.strlen(0)); // 13
console.log("Compare:", exports.strcmp(0, 200)); // > 0
console.log("Find:", exports.strstr(0, 100)); // 应该找到 "World"

// 测试字符串复制和反转
exports.strcpy(300, 0);
console.log("Copied:", readString(300)); // "Hello, World!"

exports.strrev(300);
console.log("Reversed:", readString(300)); // "!dlroW ,olleH"
```

</details>

### 练习 4.4.2 数学函数库实现 (30分)

**题目**: 创建一个数学函数库，实现以下功能：
- 基础数学函数（绝对值、最大值、最小值）
- 幂运算（整数和浮点数版本）
- 三角函数近似（sin, cos 使用泰勒级数）
- 平方根近似（牛顿法）
- 随机数生成器（线性同余生成器）

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 全局随机数种子
  (global $rand_seed (mut i32) (i32.const 1))
  
  ;; 常量定义
  (global $PI f32 (f32.const 3.14159265359))
  (global $E f32 (f32.const 2.71828182846))
  
  ;; 内存
  (memory (export "memory") 1)
  
  ;; ===== 基础数学函数 =====
  
  ;; 整数绝对值
  (func $abs_i32 (param $x i32) (result i32)
    (if (result i32)
      (i32.lt_s (local.get $x) (i32.const 0))
      (then (i32.sub (i32.const 0) (local.get $x)))
      (else (local.get $x))))
  
  ;; 浮点数绝对值
  (func $abs_f32 (param $x f32) (result f32)
    (f32.abs (local.get $x)))
  
  ;; 整数最大值
  (func $max_i32 (param $a i32) (param $b i32) (result i32)
    (if (result i32)
      (i32.gt_s (local.get $a) (local.get $b))
      (then (local.get $a))
      (else (local.get $b))))
  
  ;; 整数最小值
  (func $min_i32 (param $a i32) (param $b i32) (result i32)
    (if (result i32)
      (i32.lt_s (local.get $a) (local.get $b))
      (then (local.get $a))
      (else (local.get $b))))
  
  ;; 浮点数最大值
  (func $max_f32 (param $a f32) (param $b f32) (result f32)
    (f32.max (local.get $a) (local.get $b)))
  
  ;; 浮点数最小值
  (func $min_f32 (param $a f32) (param $b f32) (result f32)
    (f32.min (local.get $a) (local.get $b)))
  
  ;; ===== 幂运算 =====
  
  ;; 整数幂运算（快速幂算法）
  (func $pow_i32 (param $base i32) (param $exp i32) (result i32)
    (local $result i32)
    (local $current_base i32)
    (local $current_exp i32)
    
    ;; 处理负指数
    (if (i32.lt_s (local.get $exp) (i32.const 0))
      (then (return (i32.const 0))))
    
    ;; 初始化
    (local.set $result (i32.const 1))
    (local.set $current_base (local.get $base))
    (local.set $current_exp (local.get $exp))
    
    (loop $power_loop
      ;; 如果指数为0，结束
      (br_if 1 (i32.eqz (local.get $current_exp)))
      
      ;; 如果指数是奇数
      (if (i32.rem_u (local.get $current_exp) (i32.const 2))
        (then
          (local.set $result
            (i32.mul (local.get $result) (local.get $current_base)))))
      
      ;; 平方底数，除以2指数
      (local.set $current_base
        (i32.mul (local.get $current_base) (local.get $current_base)))
      (local.set $current_exp
        (i32.shr_u (local.get $current_exp) (i32.const 1)))
      
      (br $power_loop))
    
    local.get $result)
  
  ;; 浮点数幂运算（简化版，仅支持整数指数）
  (func $pow_f32 (param $base f32) (param $exp i32) (result f32)
    (local $result f32)
    (local $current_base f32)
    (local $current_exp i32)
    (local $is_negative i32)
    
    ;; 处理负指数
    (local.set $is_negative (i32.lt_s (local.get $exp) (i32.const 0)))
    (local.set $current_exp
      (if (result i32)
        (local.get $is_negative)
        (then (i32.sub (i32.const 0) (local.get $exp)))
        (else (local.get $exp))))
    
    ;; 初始化
    (local.set $result (f32.const 1.0))
    (local.set $current_base (local.get $base))
    
    (loop $power_loop
      ;; 如果指数为0，结束
      (br_if 1 (i32.eqz (local.get $current_exp)))
      
      ;; 如果指数是奇数
      (if (i32.rem_u (local.get $current_exp) (i32.const 2))
        (then
          (local.set $result
            (f32.mul (local.get $result) (local.get $current_base)))))
      
      ;; 平方底数，除以2指数
      (local.set $current_base
        (f32.mul (local.get $current_base) (local.get $current_base)))
      (local.set $current_exp
        (i32.shr_u (local.get $current_exp) (i32.const 1)))
      
      (br $power_loop))
    
    ;; 处理负指数结果
    (if (result f32)
      (local.get $is_negative)
      (then (f32.div (f32.const 1.0) (local.get $result)))
      (else (local.get $result))))
  
  ;; ===== 平方根（牛顿法） =====
  
  (func $sqrt_f32 (param $x f32) (result f32)
    (local $guess f32)
    (local $new_guess f32)
    (local $diff f32)
    (local $iterations i32)
    
    ;; 处理特殊情况
    (if (f32.lt (local.get $x) (f32.const 0.0))
      (then (return (f32.const nan))))
    
    (if (f32.eq (local.get $x) (f32.const 0.0))
      (then (return (f32.const 0.0))))
    
    ;; 初始猜测值
    (local.set $guess (f32.div (local.get $x) (f32.const 2.0)))
    
    ;; 牛顿迭代法：x_{n+1} = (x_n + a/x_n) / 2
    (loop $newton_loop
      ;; 计算新的猜测值
      (local.set $new_guess
        (f32.div
          (f32.add
            (local.get $guess)
            (f32.div (local.get $x) (local.get $guess)))
          (f32.const 2.0)))
      
      ;; 计算差值
      (local.set $diff
        (f32.abs (f32.sub (local.get $new_guess) (local.get $guess))))
      
      ;; 更新猜测值
      (local.set $guess (local.get $new_guess))
      
      ;; 增加迭代次数
      (local.set $iterations (i32.add (local.get $iterations) (i32.const 1)))
      
      ;; 检查收敛条件或最大迭代次数
      (br_if 1 (f32.lt (local.get $diff) (f32.const 0.000001)))
      (br_if 1 (i32.gt_s (local.get $iterations) (i32.const 20)))
      
      (br $newton_loop))
    
    local.get $guess)
  
  ;; ===== 三角函数（泰勒级数） =====
  
  ;; 阶乘函数（辅助函数）
  (func $factorial (param $n i32) (result f32)
    (local $result f32)
    (local $i i32)
    
    (local.set $result (f32.const 1.0))
    (local.set $i (i32.const 1))
    
    (loop $fact_loop
      (br_if 1 (i32.gt_s (local.get $i) (local.get $n)))
      
      (local.set $result
        (f32.mul (local.get $result) (f32.convert_i32_s (local.get $i))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $fact_loop))
    
    local.get $result)
  
  ;; 正弦函数（泰勒级数近似）
  (func $sin_f32 (param $x f32) (result f32)
    (local $result f32)
    (local $term f32)
    (local $x_power f32)
    (local $sign f32)
    (local $i i32)
    
    ;; 将角度标准化到 [-π, π] 范围
    (local.set $x
      (f32.sub
        (local.get $x)
        (f32.mul
          (f32.const 6.28318530718)  ;; 2π
          (f32.floor (f32.div (local.get $x) (f32.const 6.28318530718))))))
    
    (local.set $result (local.get $x))
    (local.set $x_power (local.get $x))
    (local.set $sign (f32.const -1.0))
    
    ;; 泰勒级数：sin(x) = x - x³/3! + x⁵/5! - x⁷/7! + ...
    (loop $sin_loop
      (br_if 1 (i32.gt_s (local.get $i) (i32.const 10)))  ;; 计算前10项
      
      ;; 计算 x^(2n+3)
      (local.set $x_power
        (f32.mul
          (f32.mul (local.get $x_power) (local.get $x))
          (local.get $x)))
      
      ;; 计算项：sign * x^(2n+3) / (2n+3)!
      (local.set $term
        (f32.div
          (f32.mul (local.get $sign) (local.get $x_power))
          (call $factorial (i32.add (i32.mul (local.get $i) (i32.const 2)) (i32.const 3)))))
      
      (local.set $result (f32.add (local.get $result) (local.get $term)))
      
      ;; 改变符号
      (local.set $sign (f32.neg (local.get $sign)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      (br $sin_loop))
    
    local.get $result)
  
  ;; 余弦函数
  (func $cos_f32 (param $x f32) (result f32)
    ;; cos(x) = sin(x + π/2)
    (call $sin_f32
      (f32.add (local.get $x) (f32.const 1.57079632679))))
  
  ;; ===== 随机数生成器 =====
  
  ;; 设置随机数种子
  (func $srand (param $seed i32)
    (global.set $rand_seed (local.get $seed)))
  
  ;; 生成随机数（线性同余生成器）
  (func $rand (result i32)
    (local $new_seed i32)
    
    ;; LCG: next = (a * current + c) % m
    ;; 使用参数：a = 1664525, c = 1013904223, m = 2^32
    (local.set $new_seed
      (i32.add
        (i32.mul (global.get $rand_seed) (i32.const 1664525))
        (i32.const 1013904223)))
    
    (global.set $rand_seed (local.get $new_seed))
    
    ;; 返回正数部分
    (i32.and (local.get $new_seed) (i32.const 0x7FFFFFFF)))
  
  ;; 生成指定范围内的随机数 [0, max)
  (func $rand_range (param $max i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $max) (i32.const 0))
      (then (i32.const 0))
      (else (i32.rem_u (call $rand) (local.get $max)))))
  
  ;; 生成浮点随机数 [0.0, 1.0)
  (func $rand_f32 (result f32)
    (f32.div
      (f32.convert_i32_u (call $rand))
      (f32.const 2147483647.0)))
  
  ;; ===== 导出函数 =====
  
  (export "abs_i32" (func $abs_i32))
  (export "abs_f32" (func $abs_f32))
  (export "max_i32" (func $max_i32))
  (export "min_i32" (func $min_i32))
  (export "max_f32" (func $max_f32))
  (export "min_f32" (func $min_f32))
  (export "pow_i32" (func $pow_i32))
  (export "pow_f32" (func $pow_f32))
  (export "sqrt_f32" (func $sqrt_f32))
  (export "sin_f32" (func $sin_f32))
  (export "cos_f32" (func $cos_f32))
  (export "srand" (func $srand))
  (export "rand" (func $rand))
  (export "rand_range" (func $rand_range))
  (export "rand_f32" (func $rand_f32)))
```

**测试用例**:
```javascript
const exports = instance.exports;

// 测试基础数学函数
console.log("abs(-42):", exports.abs_i32(-42)); // 42
console.log("max(10, 20):", exports.max_i32(10, 20)); // 20
console.log("min(3.14, 2.71):", exports.min_f32(3.14, 2.71)); // 2.71

// 测试幂运算
console.log("2^10:", exports.pow_i32(2, 10)); // 1024
console.log("2.0^3:", exports.pow_f32(2.0, 3)); // 8.0

// 测试平方根
console.log("sqrt(25):", exports.sqrt_f32(25.0)); // ~5.0
console.log("sqrt(2):", exports.sqrt_f32(2.0)); // ~1.414

// 测试三角函数
console.log("sin(π/2):", exports.sin_f32(1.5708)); // ~1.0
console.log("cos(0):", exports.cos_f32(0)); // ~1.0

// 测试随机数
exports.srand(42); // 设置种子
console.log("Random number:", exports.rand());
console.log("Random 0-9:", exports.rand_range(10));
console.log("Random float:", exports.rand_f32());
```

</details>

## 总结

通过这些练习，你已经全面掌握了：

| 练习类型 | 核心技能 | 难度等级 |
|---------|----------|----------|
| **模块结构** | WAT 模块组织、验证规则、错误调试 | ⭐⭐ |
| **函数系统** | 函数定义、递归、间接调用、参数传递 | ⭐⭐⭐ |
| **类型系统** | 数值操作、类型转换、位运算技巧 | ⭐⭐⭐ |
| **综合实战** | 字符串处理、数学库、算法实现 | ⭐⭐⭐⭐ |

**🎯 重点掌握技能**：
- ✅ 完整的 WAT 语法和模块结构
- ✅ 高效的函数设计和调用机制
- ✅ 数据类型系统的深度运用
- ✅ 实际项目中的代码组织和优化
- ✅ 错误处理和边界情况考虑

**📚 进阶方向**：
- 内存管理和数据结构实现
- 控制流优化和性能调优
- 与 JavaScript 的高效交互
- 大型项目的模块化设计

---

**下一步**: [第5章 内存管理](./chapter5-memory.md)
EOF < /dev/null