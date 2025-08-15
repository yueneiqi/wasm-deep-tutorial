# 第4章 WebAssembly 文本格式 (WAT)

WebAssembly 文本格式（WAT）是 WebAssembly 的人类可读表示形式。本章将深入学习 WAT 的完整语法结构，为掌握 WebAssembly 编程打下坚实基础。

## 模块结构

### 4.1.1 模块的基本组成

WebAssembly 模块是 WebAssembly 的基本部署单元，具有以下基本结构：

```wat
(module
  ;; 类型定义
  (type ...)
  
  ;; 导入声明
  (import ...)
  
  ;; 函数定义
  (func ...)
  
  ;; 表定义
  (table ...)
  
  ;; 内存定义
  (memory ...)
  
  ;; 全局变量定义
  (global ...)
  
  ;; 导出声明
  (export ...)
  
  ;; 起始函数
  (start ...)
  
  ;; 元素段
  (elem ...)
  
  ;; 数据段
  (data ...))
```

### 4.1.2 完整模块示例

```wat
;; 完整的计算器模块
(module
  ;; 类型定义：二元运算函数类型
  (type $binary_op (func (param i32 i32) (result i32)))
  
  ;; 导入日志函数
  (import "console" "log" (func $log (param i32)))
  
  ;; 内存定义（1页 = 64KB）
  (memory (export "memory") 1)
  
  ;; 全局计数器
  (global $operation_count (mut i32) (i32.const 0))
  
  ;; 加法函数
  (func $add (type $binary_op)
    ;; 增加操作计数
    (global.set $operation_count
      (i32.add 
        (global.get $operation_count) 
        (i32.const 1)))
    
    ;; 记录操作
    (call $log (global.get $operation_count))
    
    ;; 执行加法
    (i32.add (local.get 0) (local.get 1)))
  
  ;; 减法函数
  (func $subtract (type $binary_op)
    (global.set $operation_count
      (i32.add 
        (global.get $operation_count) 
        (i32.const 1)))
    
    (call $log (global.get $operation_count))
    (i32.sub (local.get 0) (local.get 1)))
  
  ;; 除法函数（带错误检查）
  (func $divide (param $a i32) (param $b i32) (result i32)
    ;; 检查除零错误
    (if (i32.eqz (local.get $b))
      (then
        ;; 记录错误并返回 0
        (call $log (i32.const -1))
        (return (i32.const 0))))
    
    (global.set $operation_count
      (i32.add 
        (global.get $operation_count) 
        (i32.const 1)))
    
    (call $log (global.get $operation_count))
    (i32.div_s (local.get $a) (local.get $b)))
  
  ;; 获取操作计数
  (func $get_count (result i32)
    (global.get $operation_count))
  
  ;; 重置计数器
  (func $reset_count
    (global.set $operation_count (i32.const 0)))
  
  ;; 导出函数
  (export "add" (func $add))
  (export "subtract" (func $subtract))
  (export "divide" (func $divide))
  (export "get_count" (func $get_count))
  (export "reset_count" (func $reset_count))
  
  ;; 初始化函数
  (start $reset_count))
```

### 4.1.3 模块验证规则

WAT 模块必须满足以下验证规则：

1. **类型一致性**：所有表达式的类型必须匹配
2. **资源存在性**：引用的函数、变量等必须已定义
3. **栈平衡**：函数结束时栈必须只包含返回值
4. **控制流正确性**：所有控制流路径必须类型一致

**常见验证错误示例：**

```wat
;; 错误1: 类型不匹配
(module
  (func $type_error (result i32)
    f32.const 3.14))  ;; 错误：返回 f32 但期望 i32

;; 错误2: 未定义引用
(module
  (func $undefined_error
    call $non_existent))  ;; 错误：函数未定义

;; 错误3: 栈不平衡
(module
  (func $stack_error (param i32) (result i32)
    local.get 0
    local.get 0
    i32.add
    drop))  ;; 错误：栈为空但期望有返回值
```

## 函数定义与调用

### 4.2.1 函数签名详解

函数签名包含参数类型和返回类型：

```wat
;; 基本函数签名语法
(func $name (param $p1 type1) (param $p2 type2) ... (result result_type)
  ;; 函数体
)

;; 简化语法（省略参数名）
(func $name (param type1 type2) (result result_type)
  ;; 使用 local.get 0, local.get 1 访问参数
)

;; 多返回值（WebAssembly 2.0+）
(func $multi_return (param i32) (result i32 i32)
  local.get 0
  local.get 0
  i32.const 1
  i32.add)
```

**详细示例：**

```wat
(module
  ;; 无参数，无返回值
  (func $void_func
    ;; 执行一些副作用操作
    nop)
  
  ;; 单参数，单返回值
  (func $square (param $x i32) (result i32)
    (i32.mul (local.get $x) (local.get $x)))
  
  ;; 多参数，单返回值
  (func $max3 (param $a i32) (param $b i32) (param $c i32) (result i32)
    (local $temp i32)
    
    ;; 计算 max(a, b)
    (local.set $temp
      (if (result i32)
        (i32.gt_s (local.get $a) (local.get $b))
        (then (local.get $a))
        (else (local.get $b))))
    
    ;; 计算 max(temp, c)
    (if (result i32)
      (i32.gt_s (local.get $temp) (local.get $c))
      (then (local.get $temp))
      (else (local.get $c))))
  
  ;; 使用局部变量
  (func $fibonacci (param $n i32) (result i32)
    (local $a i32)
    (local $b i32)
    (local $temp i32)
    (local $i i32)
    
    ;; 处理特殊情况
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
          (local.set $temp (i32.add (local.get $a) (local.get $b)))
          (local.set $a (local.get $b))
          (local.set $b (local.get $temp))
          
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          
          (br_if $fib_loop (i32.lt_s (local.get $i) (local.get $n)))
        )
        
        local.get $b))))
```

### 4.2.2 函数调用机制

WebAssembly 支持直接调用和间接调用：

**直接调用：**

```wat
(module
  (func $helper (param i32) (result i32)
    (i32.mul (local.get 0) (i32.const 2)))
  
  (func $caller (param i32) (result i32)
    ;; 直接调用函数
    (call $helper (local.get 0)))
  
  (export "caller" (func $caller)))
```

**间接调用（通过函数表）：**

```wat
(module
  ;; 定义函数表
  (table $function_table 3 funcref)
  
  ;; 定义一些函数
  (func $add (param i32 i32) (result i32)
    (i32.add (local.get 0) (local.get 1)))
  
  (func $multiply (param i32 i32) (result i32)
    (i32.mul (local.get 0) (local.get 1)))
  
  (func $subtract (param i32 i32) (result i32)
    (i32.sub (local.get 0) (local.get 1)))
  
  ;; 初始化函数表
  (elem (i32.const 0) $add $multiply $subtract)
  
  ;; 间接调用函数
  (func $call_by_index (param $index i32) (param $a i32) (param $b i32) (result i32)
    (call_indirect (type (func (param i32 i32) (result i32)))
      (local.get $a)
      (local.get $b)
      (local.get $index)))
  
  (export "table" (table $function_table))
  (export "call_by_index" (func $call_by_index)))
```

### 4.2.3 递归函数

WebAssembly 支持递归调用，但需要注意栈溢出：

```wat
(module
  ;; 递归计算阶乘
  (func $factorial_recursive (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (i32.const 1))
      (else
        (i32.mul
          (local.get $n)
          (call $factorial_recursive
            (i32.sub (local.get $n) (i32.const 1)))))))
  
  ;; 尾递归优化版本
  (func $factorial_tail_recursive (param $n i32) (result i32)
    (call $factorial_helper (local.get $n) (i32.const 1)))
  
  (func $factorial_helper (param $n i32) (param $acc i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (local.get $acc))
      (else
        (call $factorial_helper
          (i32.sub (local.get $n) (i32.const 1))
          (i32.mul (local.get $n) (local.get $acc))))))
  
  ;; 互相递归示例
  (func $is_even (param $n i32) (result i32)
    (if (result i32)
      (i32.eqz (local.get $n))
      (then (i32.const 1))
      (else (call $is_odd (i32.sub (local.get $n) (i32.const 1))))))
  
  (func $is_odd (param $n i32) (result i32)
    (if (result i32)
      (i32.eqz (local.get $n))
      (then (i32.const 0))
      (else (call $is_even (i32.sub (local.get $n) (i32.const 1))))))
  
  (export "factorial_recursive" (func $factorial_recursive))
  (export "factorial_tail_recursive" (func $factorial_tail_recursive))
  (export "is_even" (func $is_even))
  (export "is_odd" (func $is_odd)))
```

## 数据类型系统

### 4.3.1 数值类型详解

WebAssembly 的核心数值类型及其操作：

**整数类型操作：**

```wat
(module
  (func $integer_operations (param $a i32) (param $b i32) (result i32)
    (local $result i32)
    
    ;; 基本算术运算
    (i32.add (local.get $a) (local.get $b))     ;; 加法
    (i32.sub (local.get $a) (local.get $b))     ;; 减法  
    (i32.mul (local.get $a) (local.get $b))     ;; 乘法
    (i32.div_s (local.get $a) (local.get $b))   ;; 有符号除法
    (i32.div_u (local.get $a) (local.get $b))   ;; 无符号除法
    (i32.rem_s (local.get $a) (local.get $b))   ;; 有符号取余
    (i32.rem_u (local.get $a) (local.get $b))   ;; 无符号取余
    
    ;; 位运算
    (i32.and (local.get $a) (local.get $b))     ;; 按位与
    (i32.or (local.get $a) (local.get $b))      ;; 按位或
    (i32.xor (local.get $a) (local.get $b))     ;; 按位异或
    (i32.shl (local.get $a) (local.get $b))     ;; 左移
    (i32.shr_s (local.get $a) (local.get $b))   ;; 算术右移
    (i32.shr_u (local.get $a) (local.get $b))   ;; 逻辑右移
    (i32.rotl (local.get $a) (local.get $b))    ;; 循环左移
    (i32.rotr (local.get $a) (local.get $b))    ;; 循环右移
    
    ;; 比较运算
    (i32.eq (local.get $a) (local.get $b))      ;; 相等
    (i32.ne (local.get $a) (local.get $b))      ;; 不等
    (i32.lt_s (local.get $a) (local.get $b))    ;; 有符号小于
    (i32.lt_u (local.get $a) (local.get $b))    ;; 无符号小于
    (i32.gt_s (local.get $a) (local.get $b))    ;; 有符号大于
    (i32.gt_u (local.get $a) (local.get $b))    ;; 无符号大于
    (i32.le_s (local.get $a) (local.get $b))    ;; 有符号小于等于
    (i32.le_u (local.get $a) (local.get $b))    ;; 无符号小于等于
    (i32.ge_s (local.get $a) (local.get $b))    ;; 有符号大于等于
    (i32.ge_u (local.get $a) (local.get $b))    ;; 无符号大于等于
    
    ;; 清空栈，只保留最后一个结果
    drop drop drop drop drop drop drop drop
    drop drop drop drop drop drop drop drop
    drop drop drop drop))
```

**浮点数类型操作：**

```wat
(module
  (func $float_operations (param $a f32) (param $b f32) (result f32)
    ;; 基本算术运算
    (f32.add (local.get $a) (local.get $b))     ;; 加法
    (f32.sub (local.get $a) (local.get $b))     ;; 减法
    (f32.mul (local.get $a) (local.get $b))     ;; 乘法
    (f32.div (local.get $a) (local.get $b))     ;; 除法
    
    ;; 数学函数
    (f32.abs (local.get $a))                    ;; 绝对值
    (f32.neg (local.get $a))                    ;; 取负
    (f32.ceil (local.get $a))                   ;; 向上取整
    (f32.floor (local.get $a))                  ;; 向下取整
    (f32.trunc (local.get $a))                  ;; 截断取整
    (f32.nearest (local.get $a))                ;; 四舍五入
    (f32.sqrt (local.get $a))                   ;; 平方根
    
    ;; 比较运算
    (f32.eq (local.get $a) (local.get $b))      ;; 相等
    (f32.ne (local.get $a) (local.get $b))      ;; 不等
    (f32.lt (local.get $a) (local.get $b))      ;; 小于
    (f32.gt (local.get $a) (local.get $b))      ;; 大于
    (f32.le (local.get $a) (local.get $b))      ;; 小于等于
    (f32.ge (local.get $a) (local.get $b))      ;; 大于等于
    
    ;; 最值运算
    (f32.min (local.get $a) (local.get $b))     ;; 最小值
    (f32.max (local.get $a) (local.get $b))     ;; 最大值
    (f32.copysign (local.get $a) (local.get $b)) ;; 复制符号
    
    ;; 清空栈，只保留最后一个结果
    drop drop drop drop drop drop drop drop
    drop drop drop drop drop drop drop drop
    drop drop))
```

### 4.3.2 类型转换

WebAssembly 提供显式的类型转换操作：

```wat
(module
  (func $type_conversions (param $i i32) (param $f f32) (result f64)
    ;; 整数转换
    (i64.extend_i32_s (local.get $i))           ;; i32 → i64 (有符号扩展)
    (i64.extend_i32_u (local.get $i))           ;; i32 → i64 (无符号扩展)
    (i32.wrap_i64 (i64.const 0x123456789))     ;; i64 → i32 (截断)
    
    ;; 浮点数转换
    (f64.promote_f32 (local.get $f))            ;; f32 → f64
    (f32.demote_f64 (f64.const 3.14159265359)) ;; f64 → f32
    
    ;; 整数转浮点数
    (f32.convert_i32_s (local.get $i))          ;; i32 → f32 (有符号)
    (f32.convert_i32_u (local.get $i))          ;; i32 → f32 (无符号)
    (f64.convert_i32_s (local.get $i))          ;; i32 → f64 (有符号)
    (f64.convert_i32_u (local.get $i))          ;; i32 → f64 (无符号)
    
    ;; 浮点数转整数
    (i32.trunc_f32_s (local.get $f))            ;; f32 → i32 (有符号截断)
    (i32.trunc_f32_u (local.get $f))            ;; f32 → i32 (无符号截断)
    (i32.trunc_sat_f32_s (local.get $f))        ;; f32 → i32 (饱和截断)
    (i32.trunc_sat_f32_u (local.get $f))        ;; f32 → i32 (饱和截断)
    
    ;; 位模式重新解释
    (f32.reinterpret_i32 (local.get $i))        ;; i32 位 → f32
    (i32.reinterpret_f32 (local.get $f))        ;; f32 位 → i32
    
    ;; 清空栈，返回最后的 f64 值
    drop drop drop drop drop drop drop drop
    drop drop drop drop drop))
```

### 4.3.3 常量和字面量

```wat
(module
  (func $constants_demo
    ;; 整数常量
    i32.const 42                    ;; 十进制
    i32.const 0x2A                  ;; 十六进制
    i32.const 0o52                  ;; 八进制
    i32.const 0b101010              ;; 二进制
    
    ;; 64位整数常量
    i64.const 1234567890123456789
    i64.const 0x112210F47DE98115
    
    ;; 浮点数常量
    f32.const 3.14159               ;; 十进制
    f32.const 0x1.921FB6p+1         ;; 十六进制（IEEE 754）
    f32.const nan                   ;; NaN
    f32.const inf                   ;; 正无穷
    f32.const -inf                  ;; 负无穷
    
    f64.const 2.718281828459045
    f64.const 0x1.5BF0A8B145769p+1
    
    ;; 特殊值
    f32.const nan:0x400000          ;; 指定 NaN 载荷
    f64.const nan:0x8000000000000   ;; 64位 NaN
    
    ;; 清空栈
    drop drop drop drop drop drop drop drop drop drop))
```

### 4.3.4 实用的数据类型函数

```wat
(module
  ;; 安全的整数除法（避免除零）
  (func $safe_divide (param $a i32) (param $b i32) (result i32)
    (if (result i32)
      (i32.eqz (local.get $b))
      (then (i32.const 0))  ;; 除零返回 0
      (else (i32.div_s (local.get $a) (local.get $b)))))
  
  ;; 计算两个数的幂
  (func $power (param $base i32) (param $exp i32) (result i32)
    (local $result i32)
    
    (local.set $result (i32.const 1))
    
    (loop $power_loop
      (if (i32.eqz (local.get $exp))
        (then (br $power_loop)))
      
      ;; 如果指数是奇数
      (if (i32.rem_u (local.get $exp) (i32.const 2))
        (then
          (local.set $result
            (i32.mul (local.get $result) (local.get $base)))))
      
      (local.set $base (i32.mul (local.get $base) (local.get $base)))
      (local.set $exp (i32.shr_u (local.get $exp) (i32.const 1)))
      
      (br $power_loop))
    
    local.get $result)
  
  ;; 浮点数相等性比较（考虑精度误差）
  (func $float_equals (param $a f32) (param $b f32) (param $epsilon f32) (result i32)
    (f32.le
      (f32.abs (f32.sub (local.get $a) (local.get $b)))
      (local.get $epsilon)))
  
  ;; 位操作：设置特定位
  (func $set_bit (param $value i32) (param $bit_pos i32) (result i32)
    (i32.or
      (local.get $value)
      (i32.shl (i32.const 1) (local.get $bit_pos))))
  
  ;; 位操作：清除特定位
  (func $clear_bit (param $value i32) (param $bit_pos i32) (result i32)
    (i32.and
      (local.get $value)
      (i32.xor
        (i32.const -1)
        (i32.shl (i32.const 1) (local.get $bit_pos)))))
  
  ;; 位操作：切换特定位
  (func $toggle_bit (param $value i32) (param $bit_pos i32) (result i32)
    (i32.xor
      (local.get $value)
      (i32.shl (i32.const 1) (local.get $bit_pos))))
  
  ;; 检查特定位是否设置
  (func $test_bit (param $value i32) (param $bit_pos i32) (result i32)
    (i32.ne
      (i32.and
        (local.get $value)
        (i32.shl (i32.const 1) (local.get $bit_pos)))
      (i32.const 0)))
  
  (export "safe_divide" (func $safe_divide))
  (export "power" (func $power))
  (export "float_equals" (func $float_equals))
  (export "set_bit" (func $set_bit))
  (export "clear_bit" (func $clear_bit))
  (export "toggle_bit" (func $toggle_bit))
  (export "test_bit" (func $test_bit)))
```

## 本章小结

通过本章学习，你已经深入掌握了：

1. **模块结构**：完整的 WAT 模块组成和验证规则
2. **函数系统**：函数定义、调用机制、递归等高级特性
3. **类型系统**：数值类型操作、类型转换、常量定义
4. **实用技巧**：位操作、安全编程、性能优化

这些知识为后续学习内存管理、控制流等高级主题奠定了坚实基础。

---

**📝 进入下一步**：[第5章 内存管理](./chapter5-memory.md)

**🎯 重点技能**：
- ✅ WAT 完整语法掌握
- ✅ 函数设计和调用
- ✅ 类型系统运用
- ✅ 位操作技巧
- ✅ 代码组织和模块化