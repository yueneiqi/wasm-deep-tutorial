# 第6章 控制流

WebAssembly 的控制流指令构成了程序逻辑的骨架。本章将深入学习条件分支、循环结构、异常处理等高级控制流技术，掌握编写复杂程序逻辑的核心技能。

## 结构化控制流

### 6.1.1 控制流基础

WebAssembly 采用结构化控制流，所有控制结构都有明确的开始和结束：

```wat
(module
  ;; 基本的控制流结构演示
  (func $basic_control_flow (param $x i32) (result i32)
    ;; 块（block）：创建标签作用域
    (block $exit
      ;; 条件分支（if-then-else）
      (if (i32.gt_s (local.get $x) (i32.const 10))
        (then
          ;; 如果 x > 10，跳出块并返回 x*2
          (br $exit (i32.mul (local.get $x) (i32.const 2)))))
      
      ;; 循环（loop）
      (loop $increment
        ;; 递增 x
        (local.set $x (i32.add (local.get $x) (i32.const 1)))
        
        ;; 如果 x < 10，继续循环
        (br_if $increment (i32.lt_s (local.get $x) (i32.const 10))))
      
      ;; 默认返回值
      local.get $x))
  
  (export "basic_control_flow" (func $basic_control_flow)))
```

**控制流指令概览：**

```
控制结构：
- block    : 创建标签块，可以跳出
- loop     : 创建循环标签，可以跳回
- if       : 条件分支，支持 then 和 else

跳转指令：
- br       : 无条件跳转
- br_if    : 条件跳转
- br_table : 多路跳转（类似 switch）
- return   : 函数返回

异常处理：
- try      : 异常捕获块
- catch    : 异常处理
- throw    : 抛出异常
```

### 6.1.2 条件分支的高级用法

```wat
(module
  ;; 复杂条件判断
  (func $complex_conditions (param $a i32) (param $b i32) (param $c i32) (result i32)
    ;; 嵌套条件分支
    (if (result i32)
      (i32.gt_s (local.get $a) (i32.const 0))
      (then
        ;; a > 0 的情况
        (if (result i32)
          (i32.gt_s (local.get $b) (i32.const 0))
          (then
            ;; a > 0 && b > 0
            (if (result i32)
              (i32.gt_s (local.get $c) (i32.const 0))
              (then (i32.const 1))    ;; 全部为正
              (else (i32.const 2))))  ;; a,b 为正，c 非正
          (else
            ;; a > 0 && b <= 0
            (i32.const 3))))
      (else
        ;; a <= 0 的情况
        (if (result i32)
          (i32.eqz (local.get $a))
          (then (i32.const 0))    ;; a == 0
          (else (i32.const -1))))))   ;; a < 0
  
  ;; 使用 select 指令进行简单条件选择
  (func $conditional_select (param $condition i32) (param $true_val i32) (param $false_val i32) (result i32)
    ;; select 相当于三元运算符 condition ? true_val : false_val
    (select 
      (local.get $true_val) 
      (local.get $false_val) 
      (local.get $condition)))
  
  ;; 条件链式判断
  (func $grade_calculator (param $score i32) (result i32)
    ;; 返回等级：A=90+, B=80+, C=70+, D=60+, F<60
    (if (result i32)
      (i32.ge_s (local.get $score) (i32.const 90))
      (then (i32.const 65))  ;; 'A'
      (else
        (if (result i32)
          (i32.ge_s (local.get $score) (i32.const 80))
          (then (i32.const 66))  ;; 'B'
          (else
            (if (result i32)
              (i32.ge_s (local.get $score) (i32.const 70))
              (then (i32.const 67))  ;; 'C'
              (else
                (if (result i32)
                  (i32.ge_s (local.get $score) (i32.const 60))
                  (then (i32.const 68))  ;; 'D'
                  (else (i32.const 70)))))))))  ;; 'F'
  
  ;; 短路求值模拟
  (func $short_circuit_and (param $a i32) (param $b i32) (result i32)
    ;; 模拟 a && b 的短路求值
    (if (result i32)
      (local.get $a)
      (then (local.get $b))  ;; 如果 a 为真，返回 b
      (else (i32.const 0))))  ;; 如果 a 为假，返回 0
  
  (func $short_circuit_or (param $a i32) (param $b i32) (result i32)
    ;; 模拟 a || b 的短路求值
    (if (result i32)
      (local.get $a)
      (then (local.get $a))   ;; 如果 a 为真，返回 a
      (else (local.get $b))))  ;; 如果 a 为假，返回 b
  
  (export "complex_conditions" (func $complex_conditions))
  (export "conditional_select" (func $conditional_select))
  (export "grade_calculator" (func $grade_calculator))
  (export "short_circuit_and" (func $short_circuit_and))
  (export "short_circuit_or" (func $short_circuit_or)))
```

### 6.1.3 多路分支与跳转表

```wat
(module
  ;; 使用 br_table 实现多路分支
  (func $switch_statement (param $value i32) (result i32)
    ;; br_table 类似于 C 语言的 switch 语句
    (block $default
      (block $case_3
        (block $case_2
          (block $case_1
            (block $case_0
              ;; 检查值的范围并跳转
              (br_table $case_0 $case_1 $case_2 $case_3 $default
                (local.get $value)))
            
            ;; case 0: 返回 100
            (return (i32.const 100)))
          
          ;; case 1: 返回 200
          (return (i32.const 200)))
        
        ;; case 2: 返回 300
        (return (i32.const 300)))
      
      ;; case 3: 返回 400
      (return (i32.const 400)))
    
    ;; default: 返回 -1
    i32.const -1)
  
  ;; 函数指针模拟：通过跳转表调用不同函数
  (func $operation_add (param $a i32) (param $b i32) (result i32)
    (i32.add (local.get $a) (local.get $b)))
  
  (func $operation_sub (param $a i32) (param $b i32) (result i32)
    (i32.sub (local.get $a) (local.get $b)))
  
  (func $operation_mul (param $a i32) (param $b i32) (result i32)
    (i32.mul (local.get $a) (local.get $b)))
  
  (func $operation_div (param $a i32) (param $b i32) (result i32)
    (if (result i32)
      (i32.eqz (local.get $b))
      (then (i32.const 0))  ;; 除零保护
      (else (i32.div_s (local.get $a) (local.get $b)))))
  
  ;; 通过操作码调用相应函数
  (func $calculator (param $op i32) (param $a i32) (param $b i32) (result i32)
    (block $invalid
      (block $div
        (block $mul
          (block $sub
            (block $add
              ;; 根据操作码跳转: 0=add, 1=sub, 2=mul, 3=div
              (br_table $add $sub $mul $div $invalid (local.get $op)))
            
            ;; 加法
            (return (call $operation_add (local.get $a) (local.get $b))))
          
          ;; 减法
          (return (call $operation_sub (local.get $a) (local.get $b))))
        
        ;; 乘法
        (return (call $operation_mul (local.get $a) (local.get $b))))
      
      ;; 除法
      (return (call $operation_div (local.get $a) (local.get $b))))
    
    ;; 无效操作
    i32.const -999)
  
  ;; 状态机实现
  (func $state_machine (param $current_state i32) (param $input i32) (result i32)
    ;; 状态转换表：根据当前状态和输入决定下一个状态
    ;; 状态：0=初始, 1=处理中, 2=完成, 3=错误
    (block $error_state
      (block $complete_state
        (block $processing_state
          (block $initial_state
            (br_table $initial_state $processing_state $complete_state $error_state
              (local.get $current_state)))
          
          ;; 初始状态 (0)
          (if (result i32)
            (i32.eq (local.get $input) (i32.const 1))  ;; 开始信号
            (then (i32.const 1))  ;; 转到处理中
            (else 
              (if (result i32)
                (i32.eq (local.get $input) (i32.const 99))  ;; 错误信号
                (then (i32.const 3))  ;; 转到错误
                (else (i32.const 0)))))  ;; 保持初始状态
          (return))
        
        ;; 处理中状态 (1)
        (if (result i32)
          (i32.eq (local.get $input) (i32.const 2))  ;; 完成信号
          (then (i32.const 2))  ;; 转到完成
          (else
            (if (result i32)
              (i32.eq (local.get $input) (i32.const 99))  ;; 错误信号
              (then (i32.const 3))  ;; 转到错误
              (else (i32.const 1)))))  ;; 保持处理中
        (return))
      
      ;; 完成状态 (2)
      (if (result i32)
        (i32.eq (local.get $input) (i32.const 0))  ;; 重置信号
        (then (i32.const 0))  ;; 转到初始
        (else (i32.const 2)))  ;; 保持完成状态
      (return))
    
    ;; 错误状态 (3)
    (if (result i32)
      (i32.eq (local.get $input) (i32.const 0))  ;; 重置信号
      (then (i32.const 0))  ;; 转到初始
      (else (i32.const 3))))  ;; 保持错误状态
  
  (export "switch_statement" (func $switch_statement))
  (export "calculator" (func $calculator))
  (export "state_machine" (func $state_machine)))
```

## 循环控制

### 6.2.1 循环的基本形式

```wat
(module
  ;; while 循环模拟
  (func $while_loop_sum (param $n i32) (result i32)
    (local $sum i32)
    (local $i i32)
    
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 1))
    
    ;; while (i <= n)
    (loop $while_loop
      ;; 检查循环条件
      (if (i32.gt_s (local.get $i) (local.get $n))
        (then (br $while_loop)))  ;; 跳出循环
      
      ;; 循环体
      (local.set $sum 
        (i32.add (local.get $sum) (local.get $i)))
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; 继续循环
      (br $while_loop))
    
    local.get $sum)
  
  ;; do-while 循环模拟
  (func $do_while_factorial (param $n i32) (result i32)
    (local $result i32)
    (local $i i32)
    
    (local.set $result (i32.const 1))
    (local.set $i (local.get $n))
    
    ;; do { ... } while (i > 0)
    (loop $do_while_loop
      ;; 循环体
      (local.set $result 
        (i32.mul (local.get $result) (local.get $i)))
      
      ;; 递减计数器
      (local.set $i (i32.sub (local.get $i) (i32.const 1)))
      
      ;; 检查继续条件
      (br_if $do_while_loop (i32.gt_s (local.get $i) (i32.const 0))))
    
    local.get $result)
  
  ;; for 循环模拟
  (func $for_loop_power (param $base i32) (param $exp i32) (result i32)
    (local $result i32)
    (local $i i32)
    
    (local.set $result (i32.const 1))
    (local.set $i (i32.const 0))
    
    ;; for (i = 0; i < exp; i++)
    (loop $for_loop
      ;; 检查循环条件
      (if (i32.ge_s (local.get $i) (local.get $exp))
        (then (br $for_loop)))  ;; 跳出循环
      
      ;; 循环体
      (local.set $result 
        (i32.mul (local.get $result) (local.get $base)))
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; 继续循环
      (br $for_loop))
    
    local.get $result)
  
  ;; 无限循环与 break 模拟
  (func $infinite_loop_with_break (param $target i32) (result i32)
    (local $counter i32)
    
    (local.set $counter (i32.const 0))
    
    ;; 无限循环
    (loop $infinite_loop
      ;; 递增计数器
      (local.set $counter (i32.add (local.get $counter) (i32.const 1)))
      
      ;; break 条件
      (if (i32.eq (local.get $counter) (local.get $target))
        (then (br $infinite_loop)))  ;; 跳出循环
      
      ;; continue 条件示例
      (if (i32.rem_s (local.get $counter) (i32.const 2))
        (then (br $infinite_loop)))  ;; 跳过奇数，继续循环
      
      ;; 这里可以添加其他处理逻辑
      
      ;; 继续循环
      (br $infinite_loop))
    
    local.get $counter)
  
  (export "while_loop_sum" (func $while_loop_sum))
  (export "do_while_factorial" (func $do_while_factorial))
  (export "for_loop_power" (func $for_loop_power))
  (export "infinite_loop_with_break" (func $infinite_loop_with_break)))
```

### 6.2.2 嵌套循环与复杂控制

```wat
(module
  ;; 嵌套循环：矩阵操作
  (func $matrix_multiply_trace (param $size i32) (param $matrix_a i32) (param $matrix_b i32) (result i32)
    ;; 计算两个方阵相乘后的对角线元素之和
    (local $trace i32)
    (local $i i32)
    (local $j i32)
    (local $k i32)
    (local $sum i32)
    (local $a_elem i32)
    (local $b_elem i32)
    
    (local.set $trace (i32.const 0))
    (local.set $i (i32.const 0))
    
    ;; 外层循环：遍历对角线元素
    (loop $outer_loop
      (if (i32.ge_s (local.get $i) (local.get $size))
        (then (br $outer_loop)))
      
      (local.set $sum (i32.const 0))
      (local.set $k (i32.const 0))
      
      ;; 内层循环：计算 C[i][i] = Σ A[i][k] * B[k][i]
      (loop $inner_loop
        (if (i32.ge_s (local.get $k) (local.get $size))
          (then (br $inner_loop)))
        
        ;; 读取 A[i][k]
        (local.set $a_elem
          (i32.load
            (i32.add
              (local.get $matrix_a)
              (i32.mul
                (i32.add
                  (i32.mul (local.get $i) (local.get $size))
                  (local.get $k))
                (i32.const 4)))))
        
        ;; 读取 B[k][i]
        (local.set $b_elem
          (i32.load
            (i32.add
              (local.get $matrix_b)
              (i32.mul
                (i32.add
                  (i32.mul (local.get $k) (local.get $size))
                  (local.get $i))
                (i32.const 4)))))
        
        ;; 累加乘积
        (local.set $sum
          (i32.add 
            (local.get $sum)
            (i32.mul (local.get $a_elem) (local.get $b_elem))))
        
        (local.set $k (i32.add (local.get $k) (i32.const 1)))
        (br $inner_loop))
      
      ;; 累加到对角线和
      (local.set $trace (i32.add (local.get $trace) (local.get $sum)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $outer_loop))
    
    local.get $trace)
  
  ;; 多重 break 和 continue
  (func $complex_nested_loops (param $rows i32) (param $cols i32) (result i32)
    (local $found i32)
    (local $i i32)
    (local $j i32)
    (local $value i32)
    
    (local.set $found (i32.const 0))
    (local.set $i (i32.const 0))
    
    ;; 外层循环标签
    (block $outer_break
      (loop $outer_loop
        (if (i32.ge_s (local.get $i) (local.get $rows))
          (then (br $outer_break)))
        
        (local.set $j (i32.const 0))
        
        ;; 内层循环
        (loop $inner_loop
          (if (i32.ge_s (local.get $j) (local.get $cols))
            (then (br $inner_loop)))
          
          ;; 模拟一些计算
          (local.set $value 
            (i32.add
              (i32.mul (local.get $i) (local.get $cols))
              (local.get $j)))
          
          ;; 跳过偶数值（类似 continue）
          (if (i32.eqz (i32.rem_s (local.get $value) (i32.const 2)))
            (then
              (local.set $j (i32.add (local.get $j) (i32.const 1)))
              (br $inner_loop)))
          
          ;; 找到特定条件时跳出所有循环
          (if (i32.eq (local.get $value) (i32.const 15))
            (then
              (local.set $found (i32.const 1))
              (br $outer_break)))
          
          (local.set $j (i32.add (local.get $j) (i32.const 1)))
          (br $inner_loop))
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $outer_loop)))
    
    local.get $found)
  
  ;; 循环展开优化示例
  (func $unrolled_sum (param $array_ptr i32) (param $length i32) (result i32)
    (local $sum i32)
    (local $i i32)
    (local $remaining i32)
    
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 0))
    
    ;; 计算可以4路展开的循环次数
    (local.set $remaining (i32.rem_u (local.get $length) (i32.const 4)))
    
    ;; 4路展开的主循环
    (loop $unrolled_loop
      (if (i32.ge_u (local.get $i) 
                    (i32.sub (local.get $length) (local.get $remaining)))
        (then (br $unrolled_loop)))
      
      ;; 一次处理4个元素
      (local.set $sum
        (i32.add (local.get $sum)
          (i32.add
            (i32.add
              (i32.load (i32.add (local.get $array_ptr) 
                                 (i32.mul (local.get $i) (i32.const 4))))
              (i32.load (i32.add (local.get $array_ptr) 
                                 (i32.mul (i32.add (local.get $i) (i32.const 1)) (i32.const 4)))))
            (i32.add
              (i32.load (i32.add (local.get $array_ptr) 
                                 (i32.mul (i32.add (local.get $i) (i32.const 2)) (i32.const 4))))
              (i32.load (i32.add (local.get $array_ptr) 
                                 (i32.mul (i32.add (local.get $i) (i32.const 3)) (i32.const 4))))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 4)))
      (br $unrolled_loop))
    
    ;; 处理剩余元素
    (loop $remainder_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $remainder_loop)))
      
      (local.set $sum
        (i32.add (local.get $sum)
          (i32.load (i32.add (local.get $array_ptr) 
                             (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $remainder_loop))
    
    local.get $sum)
  
  (export "matrix_multiply_trace" (func $matrix_multiply_trace))
  (export "complex_nested_loops" (func $complex_nested_loops))
  (export "unrolled_sum" (func $unrolled_sum)))
```

## 异常处理（实验性）

### 6.3.1 异常处理基础

WebAssembly 的异常处理仍在发展中，以下是基本概念：

```wat
(module
  ;; 定义异常标签
  (tag $division_by_zero_error)
  (tag $overflow_error (param i32))
  
  ;; 可能抛出异常的除法函数
  (func $safe_divide (param $a i32) (param $b i32) (result i32)
    ;; 检查除零
    (if (i32.eqz (local.get $b))
      (then (throw $division_by_zero_error)))
    
    ;; 检查溢出（简化检查）
    (if (i32.and 
          (i32.eq (local.get $a) (i32.const 0x80000000))
          (i32.eq (local.get $b) (i32.const -1)))
      (then (throw $overflow_error (local.get $a))))
    
    ;; 正常除法
    i32.div_s (local.get $a) (local.get $b))
  
  ;; 异常处理示例
  (func $division_with_error_handling (param $a i32) (param $b i32) (result i32)
    ;; try-catch 块
    (try (result i32)
      ;; try 块：尝试执行可能出错的代码
      (do 
        (call $safe_divide (local.get $a) (local.get $b)))
      
      ;; catch 块：处理除零异常
      (catch $division_by_zero_error
        ;; 返回特殊值表示除零错误
        (i32.const -1))
      
      ;; catch 块：处理溢出异常
      (catch $overflow_error
        ;; 参数已经在栈上，直接丢弃并返回最小值
        drop
        (i32.const 0x80000000))))
  
  ;; 嵌套异常处理
  (func $nested_exception_handling (param $values_ptr i32) (param $count i32) (result i32)
    (local $i i32)
    (local $sum i32)
    (local $value i32)
    
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 0))
    
    ;; 外层异常处理
    (try (result i32)
      (do
        ;; 遍历数组
        (loop $process_loop
          (if (i32.ge_u (local.get $i) (local.get $count))
            (then (br $process_loop)))
          
          ;; 读取值
          (local.set $value
            (i32.load 
              (i32.add (local.get $values_ptr) 
                       (i32.mul (local.get $i) (i32.const 4)))))
          
          ;; 内层异常处理：处理每个元素
          (try
            (do
              ;; 尝试用当前和除以当前值
              (local.set $sum 
                (call $safe_divide (local.get $sum) (local.get $value))))
            
            ;; 处理除零：跳过这个值
            (catch $division_by_zero_error
              nop)
            
            ;; 处理溢出：使用安全值
            (catch $overflow_error
              drop
              (local.set $sum (i32.const 1))))
          
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $process_loop))
        
        ;; 返回最终和
        local.get $sum)
      
      ;; 外层捕获：处理意外情况
      (catch_all
        ;; 返回错误码
        (i32.const -999))))
  
  ;; 资源清理模式（模拟 finally）
  (func $resource_management (param $resource_id i32) (result i32)
    (local $result i32)
    (local $resource_acquired i32)
    
    ;; 获取资源
    (local.set $resource_acquired (i32.const 1))
    
    ;; 主要逻辑（可能抛出异常）
    (try (result i32)
      (do
        ;; 模拟可能失败的操作
        (if (i32.eq (local.get $resource_id) (i32.const 13))
          (then (throw $division_by_zero_error)))
        
        ;; 正常处理
        (local.set $result (i32.mul (local.get $resource_id) (i32.const 10)))
        local.get $result)
      
      ;; 异常处理
      (catch_all
        (local.set $result (i32.const -1))
        local.get $result))
    
    ;; 资源清理（无论是否有异常都会执行）
    (if (local.get $resource_acquired)
      (then
        ;; 释放资源的逻辑
        (local.set $resource_acquired (i32.const 0))))
    
    local.get $result)
  
  (export "safe_divide" (func $safe_divide))
  (export "division_with_error_handling" (func $division_with_error_handling))
  (export "nested_exception_handling" (func $nested_exception_handling))
  (export "resource_management" (func $resource_management)))
```

### 6.3.2 错误处理最佳实践

在异常处理不可用时，使用传统的错误处理模式：

```wat
(module
  ;; 错误码定义
  (global $ERROR_NONE i32 (i32.const 0))
  (global $ERROR_INVALID_PARAM i32 (i32.const 1))
  (global $ERROR_OUT_OF_MEMORY i32 (i32.const 2))
  (global $ERROR_DIVISION_BY_ZERO i32 (i32.const 3))
  (global $ERROR_OVERFLOW i32 (i32.const 4))
  
  ;; 全局错误状态
  (global $last_error (mut i32) (i32.const 0))
  
  ;; 设置错误状态
  (func $set_error (param $error_code i32)
    (global.set $last_error (local.get $error_code)))
  
  ;; 获取错误状态
  (func $get_error (result i32)
    (global.get $last_error))
  
  ;; 清除错误状态
  (func $clear_error
    (global.set $last_error (global.get $ERROR_NONE)))
  
  ;; 结果和错误组合类型（模拟 Result<T, E>）
  ;; 使用内存布局：[error_code][value]
  (func $create_result (param $error_code i32) (param $value i32) (param $result_ptr i32)
    (i32.store (local.get $result_ptr) (local.get $error_code))
    (i32.store (i32.add (local.get $result_ptr) (i32.const 4)) (local.get $value)))
  
  ;; 检查结果是否成功
  (func $result_is_ok (param $result_ptr i32) (result i32)
    (i32.eqz (i32.load (local.get $result_ptr))))
  
  ;; 获取结果值（假设已检查成功）
  (func $result_get_value (param $result_ptr i32) (result i32)
    (i32.load (i32.add (local.get $result_ptr) (i32.const 4))))
  
  ;; 获取错误码
  (func $result_get_error (param $result_ptr i32) (result i32)
    (i32.load (local.get $result_ptr)))
  
  ;; 安全的数学操作
  (func $safe_add (param $a i32) (param $b i32) (param $result_ptr i32)
    (local $sum i64)
    
    ;; 使用64位运算检查32位溢出
    (local.set $sum 
      (i64.add 
        (i64.extend_i32_s (local.get $a))
        (i64.extend_i32_s (local.get $b))))
    
    ;; 检查是否超出32位范围
    (if (i64.or
          (i64.gt_s (local.get $sum) (i64.const 0x7FFFFFFF))
          (i64.lt_s (local.get $sum) (i64.const -0x80000000)))
      (then
        ;; 溢出错误
        (call $create_result 
          (global.get $ERROR_OVERFLOW) 
          (i32.const 0) 
          (local.get $result_ptr)))
      (else
        ;; 成功
        (call $create_result 
          (global.get $ERROR_NONE) 
          (i32.wrap_i64 (local.get $sum))
          (local.get $result_ptr)))))
  
  (func $safe_multiply (param $a i32) (param $b i32) (param $result_ptr i32)
    (local $product i64)
    
    ;; 使用64位运算检查32位溢出
    (local.set $product 
      (i64.mul 
        (i64.extend_i32_s (local.get $a))
        (i64.extend_i32_s (local.get $b))))
    
    ;; 检查是否超出32位范围
    (if (i64.or
          (i64.gt_s (local.get $product) (i64.const 0x7FFFFFFF))
          (i64.lt_s (local.get $product) (i64.const -0x80000000)))
      (then
        ;; 溢出错误
        (call $create_result 
          (global.get $ERROR_OVERFLOW) 
          (i32.const 0) 
          (local.get $result_ptr)))
      (else
        ;; 成功
        (call $create_result 
          (global.get $ERROR_NONE) 
          (i32.wrap_i64 (local.get $product))
          (local.get $result_ptr)))))
  
  (func $safe_divide (param $a i32) (param $b i32) (param $result_ptr i32)
    ;; 检查除零
    (if (i32.eqz (local.get $b))
      (then
        (call $create_result 
          (global.get $ERROR_DIVISION_BY_ZERO) 
          (i32.const 0) 
          (local.get $result_ptr))
        (return)))
    
    ;; 检查最小值除以-1的特殊情况
    (if (i32.and
          (i32.eq (local.get $a) (i32.const 0x80000000))
          (i32.eq (local.get $b) (i32.const -1)))
      (then
        (call $create_result 
          (global.get $ERROR_OVERFLOW) 
          (i32.const 0) 
          (local.get $result_ptr))
        (return)))
    
    ;; 正常除法
    (call $create_result 
      (global.get $ERROR_NONE) 
      (i32.div_s (local.get $a) (local.get $b))
      (local.get $result_ptr)))
  
  ;; 错误传播示例
  (func $complex_calculation (param $a i32) (param $b i32) (param $c i32) (param $result_ptr i32)
    (local $temp_result i64)  ;; 8字节临时结果
    (local $intermediate i32)
    
    ;; 分配临时结果空间
    (local.set $temp_result (i64.const 0))
    
    ;; 第一步：a + b
    (call $safe_add (local.get $a) (local.get $b) (i32.wrap_i64 (local.get $temp_result)))
    
    ;; 检查第一步是否成功
    (if (i32.eqz (call $result_is_ok (i32.wrap_i64 (local.get $temp_result))))
      (then
        ;; 传播错误
        (call $create_result 
          (call $result_get_error (i32.wrap_i64 (local.get $temp_result)))
          (i32.const 0)
          (local.get $result_ptr))
        (return)))
    
    ;; 获取中间结果
    (local.set $intermediate (call $result_get_value (i32.wrap_i64 (local.get $temp_result))))
    
    ;; 第二步：result * c
    (call $safe_multiply (local.get $intermediate) (local.get $c) (i32.wrap_i64 (local.get $temp_result)))
    
    ;; 检查第二步是否成功
    (if (i32.eqz (call $result_is_ok (i32.wrap_i64 (local.get $temp_result))))
      (then
        ;; 传播错误
        (call $create_result 
          (call $result_get_error (i32.wrap_i64 (local.get $temp_result)))
          (i32.const 0)
          (local.get $result_ptr))
        (return)))
    
    ;; 所有操作都成功，复制最终结果
    (call $create_result 
      (global.get $ERROR_NONE)
      (call $result_get_value (i32.wrap_i64 (local.get $temp_result)))
      (local.get $result_ptr)))
  
  (export "set_error" (func $set_error))
  (export "get_error" (func $get_error))
  (export "clear_error" (func $clear_error))
  (export "result_is_ok" (func $result_is_ok))
  (export "result_get_value" (func $result_get_value))
  (export "result_get_error" (func $result_get_error))
  (export "safe_add" (func $safe_add))
  (export "safe_multiply" (func $safe_multiply))
  (export "safe_divide" (func $safe_divide))
  (export "complex_calculation" (func $complex_calculation)))
```

## 性能优化技巧

### 6.4.1 分支预测优化

```wat
(module
  ;; 分支预测友好的代码结构
  (func $optimized_search (param $array_ptr i32) (param $length i32) (param $target i32) (result i32)
    (local $i i32)
    (local $value i32)
    
    ;; 将最常见的情况放在 then 分支
    (loop $search_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $search_loop)))  ;; 跳出循环（不常见）
      
      (local.set $value 
        (i32.load (i32.add (local.get $array_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      
      ;; 大多数情况下不会找到目标（继续循环）
      (if (i32.ne (local.get $value) (local.get $target))
        (then
          ;; 常见情况：继续搜索
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $search_loop))
        (else
          ;; 不常见情况：找到目标
          (return (local.get $i))))
      
      ;; 这里不会执行到
      unreachable)
    
    ;; 没找到
    i32.const -1)
  
  ;; 减少分支的优化
  (func $branchless_max (param $a i32) (param $b i32) (result i32)
    ;; 使用 select 指令避免分支
    (select 
      (local.get $a) 
      (local.get $b) 
      (i32.gt_s (local.get $a) (local.get $b))))
  
  (func $branchless_abs (param $x i32) (result i32)
    (local $mask i32)
    
    ;; 算术右移获取符号掩码
    (local.set $mask (i32.shr_s (local.get $x) (i32.const 31)))
    
    ;; 无分支绝对值：(x ^ mask) - mask
    (i32.sub
      (i32.xor (local.get $x) (local.get $mask))
      (local.get $mask)))
  
  ;; 分支表优化
  (func $optimized_state_machine (param $state i32) (param $input i32) (result i32)
    ;; 将状态转换表存储在内存中以提高效率
    (local $table_offset i32)
    
    ;; 状态转换表基址
    (local.set $table_offset (i32.const 0x1000))
    
    ;; 计算表索引：state * 4 + input
    ;; 假设每个状态有4个可能的输入
    (i32.load
      (i32.add
        (local.get $table_offset)
        (i32.mul
          (i32.add
            (i32.mul (local.get $state) (i32.const 4))
            (local.get $input))
          (i32.const 4)))))
  
  (export "optimized_search" (func $optimized_search))
  (export "branchless_max" (func $branchless_max))
  (export "branchless_abs" (func $branchless_abs))
  (export "optimized_state_machine" (func $optimized_state_machine)))
```

### 6.4.2 循环优化技术

```wat
(module
  ;; 循环强度减少
  (func $strength_reduction (param $array_ptr i32) (param $length i32) (result i32)
    (local $sum i32)
    (local $i i32)
    (local $current_ptr i32)
    
    ;; 使用指针递增代替乘法
    (local.set $current_ptr (local.get $array_ptr))
    
    (loop $strength_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $strength_loop)))
      
      ;; 直接使用指针，避免地址计算
      (local.set $sum
        (i32.add (local.get $sum) (i32.load (local.get $current_ptr))))
      
      ;; 指针递增（比乘法更快）
      (local.set $current_ptr (i32.add (local.get $current_ptr) (i32.const 4)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      (br $strength_loop))
    
    local.get $sum)
  
  ;; 循环分割优化
  (func $loop_splitting (param $array_ptr i32) (param $length i32) (param $threshold i32) (result i32)
    (local $sum i32)
    (local $i i32)
    (local $value i32)
    
    ;; 第一个循环：处理小于阈值的元素
    (local.set $i (i32.const 0))
    (loop $small_values_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $small_values_loop)))
      
      (local.set $value 
        (i32.load (i32.add (local.get $array_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      
      ;; 只处理小值
      (if (i32.lt_s (local.get $value) (local.get $threshold))
        (then
          (local.set $sum (i32.add (local.get $sum) (local.get $value)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $small_values_loop))
    
    ;; 第二个循环：处理大于等于阈值的元素
    (local.set $i (i32.const 0))
    (loop $large_values_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $large_values_loop)))
      
      (local.set $value 
        (i32.load (i32.add (local.get $array_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      
      ;; 只处理大值
      (if (i32.ge_s (local.get $value) (local.get $threshold))
        (then
          (local.set $sum (i32.add (local.get $sum) (local.get $value)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $large_values_loop))
    
    local.get $sum)
  
  ;; 循环融合
  (func $loop_fusion (param $a_ptr i32) (param $b_ptr i32) (param $c_ptr i32) (param $length i32)
    (local $i i32)
    (local $a_val i32)
    (local $b_val i32)
    
    ;; 融合两个独立的循环到一个
    (loop $fused_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $fused_loop)))
      
      ;; 原本的第一个循环：A[i] = A[i] * 2
      (local.set $a_val 
        (i32.load (i32.add (local.get $a_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      (i32.store 
        (i32.add (local.get $a_ptr) (i32.mul (local.get $i) (i32.const 4)))
        (i32.mul (local.get $a_val) (i32.const 2)))
      
      ;; 原本的第二个循环：C[i] = A[i] + B[i]
      (local.set $a_val 
        (i32.load (i32.add (local.get $a_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      (local.set $b_val 
        (i32.load (i32.add (local.get $b_ptr) 
                           (i32.mul (local.get $i) (i32.const 4)))))
      (i32.store 
        (i32.add (local.get $c_ptr) (i32.mul (local.get $i) (i32.const 4)))
        (i32.add (local.get $a_val) (local.get $b_val)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $fused_loop)))
  
  (export "strength_reduction" (func $strength_reduction))
  (export "loop_splitting" (func $loop_splitting))
  (export "loop_fusion" (func $loop_fusion)))
```

## 本章小结

通过本章学习，你已经掌握了：

1. **结构化控制流**：条件分支、多路跳转的高级技巧
2. **循环控制**：各种循环模式和嵌套循环的高效实现
3. **异常处理**：现代异常机制和传统错误处理模式
4. **性能优化**：分支预测、循环优化等关键技术

这些技能为编写高效、可维护的 WebAssembly 程序奠定了坚实基础。

---

**📝 进入下一步**：[第7章 JavaScript 交互](./chapter7-js-interaction.md)

**🎯 重点技能**：
- ✅ 条件分支优化
- ✅ 循环设计模式  
- ✅ 异常处理策略
- ✅ 控制流性能调优
- ✅ 复杂逻辑实现