# 附录A 常用 WAT 指令参考

本附录提供 WebAssembly 文本格式 (WAT) 的完整指令参考，按功能分类整理，便于开发时快速查阅。

## A.1 模块结构语法

### A.1.1 模块定义

```wat
(module
  ;; 类型定义
  (type $func_type (func (param i32) (result i32)))
  
  ;; 导入声明
  (import "env" "memory" (memory 1))
  (import "console" "log" (func $log (param i32)))
  
  ;; 函数定义
  (func $name (param $p1 i32) (result i32) ...)
  
  ;; 表定义
  (table $table 10 funcref)
  
  ;; 内存定义
  (memory 1 2)
  
  ;; 全局变量
  (global $counter (mut i32) (i32.const 0))
  
  ;; 导出声明
  (export "function_name" (func $name))
  (export "memory" (memory 0))
  
  ;; 起始函数
  (start $init)
  
  ;; 元素段（初始化表）
  (elem (i32.const 0) $func1 $func2)
  
  ;; 数据段（初始化内存）
  (data (i32.const 0) "Hello World"))
```

### A.1.2 函数定义语法

```wat
;; 完整形式
(func $name (param $arg1 i32) (param $arg2 f32) (result i64)
  (local $temp i32)
  ;; 函数体
  local.get $arg1
  i64.extend_i32_s)

;; 简化形式
(func $name (param i32 f32) (result i64)
  ;; 使用索引访问参数：local.get 0, local.get 1
  local.get 0
  i64.extend_i32_s)

;; 多返回值（WebAssembly 2.0+）
(func $swap (param i32 i32) (result i32 i32)
  local.get 1
  local.get 0)
```

## A.2 数据类型和常量

### A.2.1 基本数据类型

| 类型 | 描述 | 大小 | 取值范围 |
|------|------|------|----------|
| `i32` | 32位有符号整数 | 4字节 | -2³¹ ~ 2³¹-1 |
| `i64` | 64位有符号整数 | 8字节 | -2⁶³ ~ 2⁶³-1 |
| `f32` | 32位浮点数 | 4字节 | IEEE 754 单精度 |
| `f64` | 64位浮点数 | 8字节 | IEEE 754 双精度 |
| `v128` | 128位向量 | 16字节 | SIMD 向量类型 |
| `funcref` | 函数引用 | - | 函数表中的引用 |
| `externref` | 外部引用 | - | 宿主环境对象引用 |

### A.2.2 常量定义

```wat
;; 整数常量
i32.const 42              ;; 十进制
i32.const 0x2A            ;; 十六进制
i32.const 0o52            ;; 八进制
i32.const 0b101010        ;; 二进制
i32.const -123            ;; 负数

i64.const 1234567890123456789
i64.const 0x112210F47DE98115

;; 浮点数常量
f32.const 3.14159         ;; 标准形式
f32.const 1.23e-4         ;; 科学记数法
f32.const 0x1.921FB6p+1   ;; 十六进制浮点数
f32.const inf             ;; 正无穷
f32.const -inf            ;; 负无穷
f32.const nan             ;; NaN
f32.const nan:0x400000    ;; 带载荷的 NaN

f64.const 2.718281828459045
f64.const 0x1.5BF0A8B145769p+1
```

## A.3 算术指令

### A.3.1 整数算术指令

#### 基本算术运算

```wat
;; i32 算术指令
i32.add         ;; 加法：a + b
i32.sub         ;; 减法：a - b  
i32.mul         ;; 乘法：a * b
i32.div_s       ;; 有符号除法：a / b
i32.div_u       ;; 无符号除法：a / b
i32.rem_s       ;; 有符号取余：a % b
i32.rem_u       ;; 无符号取余：a % b

;; i64 算术指令（同 i32）
i64.add         i64.sub         i64.mul
i64.div_s       i64.div_u
i64.rem_s       i64.rem_u

;; 一元运算
i32.clz         ;; 前导零计数
i32.ctz         ;; 后导零计数
i32.popcnt      ;; 位计数（汉明重量）
i32.eqz         ;; 等于零测试 (i32 → i32)

i64.clz         i64.ctz         i64.popcnt      i64.eqz
```

#### 位运算指令

```wat
;; 按位逻辑运算
i32.and         ;; 按位与：a & b
i32.or          ;; 按位或：a | b
i32.xor         ;; 按位异或：a ^ b

;; 移位运算
i32.shl         ;; 左移：a << b
i32.shr_s       ;; 算术右移：a >> b (保持符号)
i32.shr_u       ;; 逻辑右移：a >>> b (补零)
i32.rotl        ;; 循环左移
i32.rotr        ;; 循环右移

;; i64 位运算（同 i32）
i64.and         i64.or          i64.xor
i64.shl         i64.shr_s       i64.shr_u
i64.rotl        i64.rotr
```

### A.3.2 浮点算术指令

```wat
;; f32/f64 基本算术
f32.add         f64.add         ;; 加法
f32.sub         f64.sub         ;; 减法
f32.mul         f64.mul         ;; 乘法
f32.div         f64.div         ;; 除法

;; 数学函数
f32.abs         f64.abs         ;; 绝对值
f32.neg         f64.neg         ;; 取负
f32.ceil        f64.ceil        ;; 向上取整
f32.floor       f64.floor       ;; 向下取整
f32.trunc       f64.trunc       ;; 截断取整
f32.nearest     f64.nearest     ;; 四舍五入到最近整数
f32.sqrt        f64.sqrt        ;; 平方根

;; 最值运算
f32.min         f64.min         ;; 最小值
f32.max         f64.max         ;; 最大值
f32.copysign    f64.copysign    ;; 复制符号位
```

## A.4 比较指令

### A.4.1 整数比较

```wat
;; i32 比较指令（返回 i32：1 为真，0 为假）
i32.eq          ;; 相等：a == b
i32.ne          ;; 不等：a != b
i32.lt_s        ;; 有符号小于：a < b
i32.lt_u        ;; 无符号小于：a < b
i32.gt_s        ;; 有符号大于：a > b
i32.gt_u        ;; 无符号大于：a > b
i32.le_s        ;; 有符号小于等于：a <= b
i32.le_u        ;; 无符号小于等于：a <= b
i32.ge_s        ;; 有符号大于等于：a >= b
i32.ge_u        ;; 无符号大于等于：a >= b

;; i64 比较指令（同 i32）
i64.eq          i64.ne
i64.lt_s        i64.lt_u        i64.gt_s        i64.gt_u
i64.le_s        i64.le_u        i64.ge_s        i64.ge_u
```

### A.4.2 浮点比较

```wat
;; f32/f64 比较指令（返回 i32）
f32.eq          f64.eq          ;; 相等
f32.ne          f64.ne          ;; 不等
f32.lt          f64.lt          ;; 小于
f32.gt          f64.gt          ;; 大于
f32.le          f64.le          ;; 小于等于
f32.ge          f64.ge          ;; 大于等于
```

## A.5 类型转换指令

### A.5.1 整数类型转换

```wat
;; 扩展和截断
i64.extend_i32_s        ;; i32 → i64 (有符号扩展)
i64.extend_i32_u        ;; i32 → i64 (无符号扩展)
i32.wrap_i64            ;; i64 → i32 (截断低32位)

;; 截断扩展（符号扩展）
i32.extend8_s           ;; i8 → i32 (有符号扩展)
i32.extend16_s          ;; i16 → i32 (有符号扩展)
i64.extend8_s           ;; i8 → i64 (有符号扩展)
i64.extend16_s          ;; i16 → i64 (有符号扩展)
i64.extend32_s          ;; i32 → i64 (有符号扩展)
```

### A.5.2 浮点类型转换

```wat
;; 浮点精度转换
f64.promote_f32         ;; f32 → f64 (提升精度)
f32.demote_f64          ;; f64 → f32 (降低精度)

;; 整数与浮点数转换
f32.convert_i32_s       ;; i32 → f32 (有符号)
f32.convert_i32_u       ;; i32 → f32 (无符号)
f32.convert_i64_s       ;; i64 → f32 (有符号)
f32.convert_i64_u       ;; i64 → f32 (无符号)
f64.convert_i32_s       ;; i32 → f64 (有符号)
f64.convert_i32_u       ;; i32 → f64 (无符号)
f64.convert_i64_s       ;; i64 → f64 (有符号)
f64.convert_i64_u       ;; i64 → f64 (无符号)

;; 浮点数到整数转换
i32.trunc_f32_s         ;; f32 → i32 (有符号截断)
i32.trunc_f32_u         ;; f32 → i32 (无符号截断)
i32.trunc_f64_s         ;; f64 → i32 (有符号截断)
i32.trunc_f64_u         ;; f64 → i32 (无符号截断)
i64.trunc_f32_s         ;; f32 → i64 (有符号截断)
i64.trunc_f32_u         ;; f32 → i64 (无符号截断)
i64.trunc_f64_s         ;; f64 → i64 (有符号截断)
i64.trunc_f64_u         ;; f64 → i64 (无符号截断)

;; 饱和截断（避免溢出异常）
i32.trunc_sat_f32_s     ;; f32 → i32 (有符号饱和)
i32.trunc_sat_f32_u     ;; f32 → i32 (无符号饱和)
i32.trunc_sat_f64_s     ;; f64 → i32 (有符号饱和)
i32.trunc_sat_f64_u     ;; f64 → i32 (无符号饱和)
i64.trunc_sat_f32_s     ;; f32 → i64 (有符号饱和)
i64.trunc_sat_f32_u     ;; f32 → i64 (无符号饱和)
i64.trunc_sat_f64_s     ;; f64 → i64 (有符号饱和)
i64.trunc_sat_f64_u     ;; f64 → i64 (无符号饱和)
```

### A.5.3 重新解释类型

```wat
;; 位模式重新解释（不改变位表示）
i32.reinterpret_f32     ;; f32 → i32 (位模式转换)
i64.reinterpret_f64     ;; f64 → i64 (位模式转换)
f32.reinterpret_i32     ;; i32 → f32 (位模式转换)
f64.reinterpret_i64     ;; i64 → f64 (位模式转换)
```

## A.6 局部变量和栈操作

### A.6.1 局部变量操作

```wat
;; 获取局部变量/参数
local.get $name         ;; 按名称获取
local.get 0             ;; 按索引获取（0是第一个参数）

;; 设置局部变量
local.set $name         ;; 按名称设置
local.set 0             ;; 按索引设置

;; 设置并获取局部变量
local.tee $name         ;; 设置变量并保留栈顶值
local.tee 0             ;; 按索引操作
```

### A.6.2 全局变量操作

```wat
;; 获取全局变量
global.get $name        ;; 按名称获取
global.get 0            ;; 按索引获取

;; 设置全局变量（仅限可变全局变量）
global.set $name        ;; 按名称设置
global.set 0            ;; 按索引设置
```

### A.6.3 栈操作指令

```wat
drop                    ;; 丢弃栈顶值
select                  ;; 条件选择：condition ? a : b
                        ;; 栈：[condition] [false_val] [true_val] → [result]
```

## A.7 控制流指令

### A.7.1 基本控制结构

```wat
;; 无条件块
(block $label
  ;; 代码块
  br $label)            ;; 跳出块

;; 循环块
(loop $label
  ;; 循环体
  br $label)            ;; 跳回循环开始

;; 条件分支
(if (result i32)        ;; 可选返回类型
  ;; 条件表达式
  (then
    ;; then 分支)
  (else
    ;; else 分支))        ;; else 分支可选
```

### A.7.2 跳转指令

```wat
br $label               ;; 无条件跳转到标签
br_if $label            ;; 条件跳转：如果栈顶非零则跳转
br_table $l1 $l2 $default   ;; 表跳转（switch 语句）
return                  ;; 函数返回
unreachable             ;; 标记不可达代码（触发 trap）
```

### A.7.3 函数调用

```wat
call $function_name     ;; 直接函数调用
call_indirect (type $sig) $table   ;; 间接函数调用（通过函数表）
```

## A.8 内存操作指令

### A.8.1 内存加载指令

```wat
;; 基本加载指令
i32.load                ;; 加载32位整数
i64.load                ;; 加载64位整数  
f32.load                ;; 加载32位浮点数
f64.load                ;; 加载64位浮点数

;; 带偏移和对齐的加载
i32.load offset=4 align=4
i64.load offset=8 align=8

;; 部分加载（扩展）
i32.load8_s             ;; 加载8位有符号扩展到32位
i32.load8_u             ;; 加载8位无符号扩展到32位
i32.load16_s            ;; 加载16位有符号扩展到32位
i32.load16_u            ;; 加载16位无符号扩展到32位
i64.load8_s             ;; 加载8位有符号扩展到64位
i64.load8_u             ;; 加载8位无符号扩展到64位
i64.load16_s            ;; 加载16位有符号扩展到64位
i64.load16_u            ;; 加载16位无符号扩展到64位
i64.load32_s            ;; 加载32位有符号扩展到64位
i64.load32_u            ;; 加载32位无符号扩展到64位
```

### A.8.2 内存存储指令

```wat
;; 基本存储指令
i32.store               ;; 存储32位整数
i64.store               ;; 存储64位整数
f32.store               ;; 存储32位浮点数
f64.store               ;; 存储64位浮点数

;; 带偏移和对齐的存储
i32.store offset=4 align=4
i64.store offset=8 align=8

;; 部分存储（截断）
i32.store8              ;; 存储32位整数的低8位
i32.store16             ;; 存储32位整数的低16位
i64.store8              ;; 存储64位整数的低8位
i64.store16             ;; 存储64位整数的低16位
i64.store32             ;; 存储64位整数的低32位
```

### A.8.3 内存管理指令

```wat
memory.size             ;; 获取内存大小（以页为单位，1页=64KB）
memory.grow             ;; 增长内存大小，返回之前的大小

;; 批量内存操作（bulk memory operations）
memory.init $data_segment    ;; 从数据段初始化内存
data.drop $data_segment      ;; 丢弃数据段
memory.copy                  ;; 复制内存区域  
memory.fill                  ;; 填充内存区域
```

## A.9 表操作指令

### A.9.1 基本表操作

```wat
table.get $table        ;; 获取表元素
table.set $table        ;; 设置表元素
table.size $table       ;; 获取表大小
table.grow $table       ;; 增长表大小
table.fill $table       ;; 填充表
table.copy $dest $src   ;; 复制表元素
table.init $table $elem ;; 从元素段初始化表
elem.drop $elem         ;; 丢弃元素段
```

## A.10 原子操作指令（线程扩展）

### A.10.1 原子内存操作

```wat
;; 原子加载/存储
i32.atomic.load         ;; 原子加载32位
i64.atomic.load         ;; 原子加载64位
i32.atomic.store        ;; 原子存储32位
i64.atomic.store        ;; 原子存储64位

;; 读-修改-写操作
i32.atomic.rmw.add      ;; 原子加法
i32.atomic.rmw.sub      ;; 原子减法
i32.atomic.rmw.and      ;; 原子与运算
i32.atomic.rmw.or       ;; 原子或运算
i32.atomic.rmw.xor      ;; 原子异或运算
i32.atomic.rmw.xchg     ;; 原子交换

;; 比较并交换
i32.atomic.rmw.cmpxchg  ;; 原子比较并交换

;; 内存屏障
memory.atomic.notify    ;; 通知等待线程
memory.atomic.wait32    ;; 等待32位值变化
memory.atomic.wait64    ;; 等待64位值变化
atomic.fence            ;; 内存屏障
```

## A.11 SIMD 指令（向量扩展）

### A.11.1 向量操作

```wat
;; v128 类型常量
v128.const i32x4 1 2 3 4        ;; 创建4个i32向量
v128.const f32x4 1.0 2.0 3.0 4.0 ;; 创建4个f32向量

;; 向量加载/存储
v128.load                       ;; 加载128位向量
v128.load8x8_s                  ;; 加载8个i8，扩展到i16
v128.load16x4_s                 ;; 加载4个i16，扩展到i32
v128.load32x2_s                 ;; 加载2个i32，扩展到i64
v128.store                      ;; 存储128位向量

;; 向量算术运算
i32x4.add                       ;; 4个i32并行加法
i32x4.sub                       ;; 4个i32并行减法
i32x4.mul                       ;; 4个i32并行乘法
f32x4.add                       ;; 4个f32并行加法
f32x4.sqrt                      ;; 4个f32并行平方根

;; 向量比较
i32x4.eq                        ;; 4个i32并行相等比较
f32x4.lt                        ;; 4个f32并行小于比较

;; 向量选择和混合
v128.bitselect                  ;; 按位选择
i8x16.shuffle                   ;; 字节shuffle重排
```

## A.12 异常处理指令（异常扩展）

### A.12.1 异常操作

```wat
;; 异常标签定义
(tag $my_exception (param i32))

;; 异常处理块
(try (result i32)
  ;; 可能抛出异常的代码
  (throw $my_exception (i32.const 42))
  (catch $my_exception
    ;; 异常处理代码
    drop    ;; 丢弃异常参数
    i32.const -1))

;; 异常指令
throw $tag                      ;; 抛出异常
rethrow $label                  ;; 重新抛出异常
```

## A.13 常用代码模式

### A.13.1 条件表达式模式

```wat
;; 三元运算符模式
(if (result i32)
  ;; 条件
  (then ;; 真值)
  (else ;; 假值))

;; 使用 select 的简化版本
(select
  ;; 真值
  ;; 假值
  ;; 条件)
```

### A.13.2 循环模式

```wat
;; 计数循环
(local $i i32)
(local.set $i (i32.const 0))
(loop $loop
  ;; 循环体
  
  ;; 递增计数器
  (local.set $i (i32.add (local.get $i) (i32.const 1)))
  
  ;; 条件检查
  (br_if $loop (i32.lt_s (local.get $i) (i32.const 10))))

;; while 循环模式
(loop $while
  (if (;; 条件)
    (then
      ;; 循环体
      (br $while))))

;; do-while 循环模式
(loop $do_while
  ;; 循环体
  
  (br_if $do_while (;; 条件)))
```

### A.13.3 函数指针和回调模式

```wat
;; 定义函数类型
(type $callback (func (param i32) (result i32)))

;; 函数表
(table $callbacks 10 funcref)

;; 回调调用
(func $call_callback (param $index i32) (param $value i32) (result i32)
  (call_indirect (type $callback)
    (local.get $value)
    (local.get $index)))
```

### A.13.4 错误处理模式

```wat
;; 返回错误码
(func $safe_divide (param $a i32) (param $b i32) (result i32)
  (if (result i32)
    (i32.eqz (local.get $b))
    (then (i32.const -1))  ;; 错误码
    (else (i32.div_s (local.get $a) (local.get $b)))))

;; 使用全局错误标志
(global $error_flag (mut i32) (i32.const 0))

(func $operation_with_error_flag
  ;; 重置错误标志
  (global.set $error_flag (i32.const 0))
  
  ;; 操作...
  ;; 如果出错
  (global.set $error_flag (i32.const 1)))
```

## A.14 性能优化提示

### A.14.1 指令选择优化

```wat
;; 优先使用高效指令
;; 好：使用移位代替乘法/除法（当可能时）
(i32.shl (local.get $x) (i32.const 3))  ;; x * 8

;; 避免：
(i32.mul (local.get $x) (i32.const 8))

;; 好：使用位运算检查奇偶
(i32.and (local.get $x) (i32.const 1))  ;; x % 2

;; 避免：
(i32.rem_s (local.get $x) (i32.const 2))
```

### A.14.2 内存访问优化

```wat
;; 好：按对齐边界访问
i32.load align=4        ;; 4字节对齐
i64.load align=8        ;; 8字节对齐

;; 避免：未对齐访问
i32.load align=1        ;; 可能较慢

;; 好：批量操作
memory.copy             ;; 比循环复制更快
memory.fill             ;; 比循环填充更快
```

### A.14.3 控制流优化

```wat
;; 好：减少跳转
(if (local.get $condition)
  (then
    ;; 直接计算))

;; 避免：过多嵌套
(if (local.get $a)
  (then
    (if (local.get $b)
      (then
        (if (local.get $c)
          ;; 过度嵌套)))))
```

## A.15 调试和开发技巧

### A.15.1 调试辅助模式

```wat
;; 使用 unreachable 标记错误路径
(if (i32.lt_s (local.get $index) (i32.const 0))
  (then
    unreachable))  ;; 触发 trap，便于调试

;; 使用导入函数进行调试输出
(import "debug" "log_i32" (func $log (param i32)))

(func $debug_example (param $value i32)
  ;; 记录参数值
  (call $log (local.get $value))
  
  ;; 继续处理...)
```

### A.15.2 代码组织建议

```wat
;; 使用有意义的函数和变量名
(func $calculate_fibonacci (param $n i32) (result i32)
  (local $prev i32)
  (local $curr i32)
  ;; 清晰的实现)

;; 添加注释说明复杂逻辑
;; 计算 x 的平方根（牛顿法）
(func $sqrt_newton (param $x f64) (result f64)
  ;; 实现...)

;; 将相关功能分组到同一模块
(module
  ;; 数学函数组
  (func $add ...)
  (func $multiply ...)
  (func $power ...)
  
  ;; 字符串处理组
  (func $strlen ...)
  (func $strcmp ...)
  (func $strcpy ...))
```

---

**📖 参考说明**：
- 所有指令都区分大小写
- 标签名（如 `$name`）是可选的，也可以使用数字索引
- 某些高级指令需要特定的 WebAssembly 提案支持
- 性能特性可能因不同的 WebAssembly 运行时而异

**🔗 相关章节**：
- [第4章 WebAssembly 文本格式 (WAT)](../part2/chapter4-wat.md)
- [第5章 内存管理](../part2/chapter5-memory.md)
- [第6章 控制流](../part2/chapter6-control-flow.md)
