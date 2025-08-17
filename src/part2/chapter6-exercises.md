# 第6章 控制流练习题

本章练习题旨在深入理解WebAssembly的控制流结构，包括条件分支、循环、异常处理和性能优化技术。通过这些练习，你将掌握WAT格式的控制流编程技巧。

## 练习1：基础条件分支 (10分)

**题目**：实现一个函数，根据输入参数的值返回不同的结果：
- 如果输入小于0，返回-1
- 如果输入等于0，返回0  
- 如果输入大于0，返回1

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 符号函数：返回输入数字的符号
  (func $sign (param $num i32) (result i32)
    (local $result i32)
    
    ;; 检查是否小于0
    (if (i32.lt_s (local.get $num) (i32.const 0))
      (then
        (local.set $result (i32.const -1))
      )
      (else
        ;; 检查是否等于0
        (if (i32.eq (local.get $num) (i32.const 0))
          (then
            (local.set $result (i32.const 0))
          )
          (else
            (local.set $result (i32.const 1))
          )
        )
      )
    )
    
    (local.get $result)
  )
  
  (export "sign" (func $sign))
)
```

**解答说明**：
1. 使用嵌套的if-else结构进行条件判断
2. `i32.lt_s`用于有符号整数比较
3. `i32.eq`用于相等性比较
4. 通过局部变量存储结果值

</details>

## 练习2：循环与累加 (15分)

**题目**：实现一个计算阶乘的函数，使用loop指令而不是递归。要求处理边界情况（0! = 1）。

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 计算阶乘函数
  (func $factorial (param $n i32) (result i32)
    (local $result i32)
    (local $counter i32)
    
    ;; 处理边界情况：0! = 1, 1! = 1
    (if (i32.le_u (local.get $n) (i32.const 1))
      (then
        (return (i32.const 1))
      )
    )
    
    ;; 初始化变量
    (local.set $result (i32.const 1))
    (local.set $counter (i32.const 2))
    
    ;; 循环计算阶乘
    (loop $factorial_loop
      ;; 累乘
      (local.set $result 
        (i32.mul 
          (local.get $result) 
          (local.get $counter)
        )
      )
      
      ;; 递增计数器
      (local.set $counter 
        (i32.add (local.get $counter) (i32.const 1))
      )
      
      ;; 检查是否继续循环
      (if (i32.le_u (local.get $counter) (local.get $n))
        (then
          (br $factorial_loop)
        )
      )
    )
    
    (local.get $result)
  )
  
  (export "factorial" (func $factorial))
)
```

**解答说明**：
1. 使用loop指令创建循环结构
2. 通过br指令实现循环跳转
3. 使用局部变量维护循环状态
4. 处理边界情况确保正确性

</details>

## 练习3：嵌套循环与二维数组 (20分)

**题目**：实现一个函数，计算3x3矩阵的所有元素之和。矩阵以一维数组形式存储在线性内存中。

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory 1)
  
  ;; 计算3x3矩阵元素之和
  (func $matrix_sum (param $matrix_ptr i32) (result i32)
    (local $sum i32)
    (local $row i32)
    (local $col i32)
    (local $offset i32)
    (local $value i32)
    
    (local.set $sum (i32.const 0))
    (local.set $row (i32.const 0))
    
    ;; 外层循环：遍历行
    (loop $row_loop
      (local.set $col (i32.const 0))
      
      ;; 内层循环：遍历列
      (loop $col_loop
        ;; 计算偏移量：offset = (row * 3 + col) * 4
        (local.set $offset
          (i32.mul
            (i32.add
              (i32.mul (local.get $row) (i32.const 3))
              (local.get $col)
            )
            (i32.const 4)
          )
        )
        
        ;; 从内存加载值
        (local.set $value
          (i32.load 
            (i32.add (local.get $matrix_ptr) (local.get $offset))
          )
        )
        
        ;; 累加
        (local.set $sum 
          (i32.add (local.get $sum) (local.get $value))
        )
        
        ;; 列计数器递增
        (local.set $col 
          (i32.add (local.get $col) (i32.const 1))
        )
        
        ;; 检查列循环条件
        (if (i32.lt_u (local.get $col) (i32.const 3))
          (then (br $col_loop))
        )
      )
      
      ;; 行计数器递增
      (local.set $row 
        (i32.add (local.get $row) (i32.const 1))
      )
      
      ;; 检查行循环条件
      (if (i32.lt_u (local.get $row) (i32.const 3))
        (then (br $row_loop))
      )
    )
    
    (local.get $sum)
  )
  
  ;; 辅助函数：初始化测试矩阵
  (func $init_test_matrix (param $ptr i32)
    ;; 设置3x3矩阵：
    ;; [1, 2, 3]
    ;; [4, 5, 6] 
    ;; [7, 8, 9]
    (i32.store (i32.add (local.get $ptr) (i32.const 0)) (i32.const 1))
    (i32.store (i32.add (local.get $ptr) (i32.const 4)) (i32.const 2))
    (i32.store (i32.add (local.get $ptr) (i32.const 8)) (i32.const 3))
    (i32.store (i32.add (local.get $ptr) (i32.const 12)) (i32.const 4))
    (i32.store (i32.add (local.get $ptr) (i32.const 16)) (i32.const 5))
    (i32.store (i32.add (local.get $ptr) (i32.const 20)) (i32.const 6))
    (i32.store (i32.add (local.get $ptr) (i32.const 24)) (i32.const 7))
    (i32.store (i32.add (local.get $ptr) (i32.const 28)) (i32.const 8))
    (i32.store (i32.add (local.get $ptr) (i32.const 32)) (i32.const 9))
  )
  
  (export "matrix_sum" (func $matrix_sum))
  (export "init_test_matrix" (func $init_test_matrix))
)
```

**解答说明**：
1. 使用嵌套循环遍历二维数组
2. 计算正确的内存偏移量（行优先存储）
3. 每个整数占用4字节内存空间
4. 提供测试数据初始化函数

</details>

## 练习4：异常处理与错误检查 (20分)

**题目**：实现一个安全的除法函数，需要检查除零错误。如果除数为0，返回一个特殊的错误码(-1)，否则返回正常的除法结果。

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 全局变量存储错误状态
  (global $error_flag (mut i32) (i32.const 0))
  
  ;; 错误码定义
  (global $ERR_NONE i32 (i32.const 0))
  (global $ERR_DIVIDE_BY_ZERO i32 (i32.const 1))
  
  ;; 安全除法函数
  (func $safe_divide (param $dividend i32) (param $divisor i32) (result i32)
    ;; 重置错误标志
    (global.set $error_flag (global.get $ERR_NONE))
    
    ;; 检查除数是否为0
    (if (i32.eq (local.get $divisor) (i32.const 0))
      (then
        ;; 设置错误标志
        (global.set $error_flag (global.get $ERR_DIVIDE_BY_ZERO))
        ;; 返回错误码
        (return (i32.const -1))
      )
    )
    
    ;; 执行正常除法
    (i32.div_s (local.get $dividend) (local.get $divisor))
  )
  
  ;; 获取最后的错误码
  (func $get_last_error (result i32)
    (global.get $error_flag)
  )
  
  ;; 检查操作是否成功
  (func $is_success (result i32)
    (i32.eq (global.get $error_flag) (global.get $ERR_NONE))
  )
  
  ;; 批量除法操作（演示错误传播）
  (func $batch_divide (param $a i32) (param $b i32) (param $c i32) (param $d i32) (result i32)
    (local $result1 i32)
    (local $result2 i32)
    
    ;; 第一次除法：a / b
    (local.set $result1 (call $safe_divide (local.get $a) (local.get $b)))
    
    ;; 检查是否有错误
    (if (i32.ne (call $is_success) (i32.const 1))
      (then
        ;; 传播错误
        (return (i32.const -1))
      )
    )
    
    ;; 第二次除法：c / d
    (local.set $result2 (call $safe_divide (local.get $c) (local.get $d)))
    
    ;; 检查是否有错误
    (if (i32.ne (call $is_success) (i32.const 1))
      (then
        ;; 传播错误
        (return (i32.const -1))
      )
    )
    
    ;; 返回两次除法结果的和
    (i32.add (local.get $result1) (local.get $result2))
  )
  
  (export "safe_divide" (func $safe_divide))
  (export "get_last_error" (func $get_last_error))
  (export "is_success" (func $is_success))
  (export "batch_divide" (func $batch_divide))
)
```

**解答说明**：
1. 使用全局变量维护错误状态
2. 定义错误码常量便于管理
3. 实现错误检查和传播机制
4. 提供错误状态查询函数

</details>

## 练习5：状态机实现 (25分)

**题目**：实现一个简单的状态机，模拟一个自动售货机的工作流程：
- 状态：IDLE(0), COIN_INSERTED(1), ITEM_SELECTED(2), DISPENSING(3)
- 事件：INSERT_COIN(0), SELECT_ITEM(1), DISPENSE(2), RESET(3)

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  ;; 状态定义
  (global $STATE_IDLE i32 (i32.const 0))
  (global $STATE_COIN_INSERTED i32 (i32.const 1))
  (global $STATE_ITEM_SELECTED i32 (i32.const 2))
  (global $STATE_DISPENSING i32 (i32.const 3))
  
  ;; 事件定义
  (global $EVENT_INSERT_COIN i32 (i32.const 0))
  (global $EVENT_SELECT_ITEM i32 (i32.const 1))
  (global $EVENT_DISPENSE i32 (i32.const 2))
  (global $EVENT_RESET i32 (i32.const 3))
  
  ;; 当前状态
  (global $current_state (mut i32) (i32.const 0))
  
  ;; 错误码
  (global $ERROR_INVALID_TRANSITION i32 (i32.const -1))
  (global $SUCCESS i32 (i32.const 0))
  
  ;; 状态机处理函数
  (func $process_event (param $event i32) (result i32)
    (local $new_state i32)
    (local $current i32)
    
    (local.set $current (global.get $current_state))
    
    ;; 根据当前状态和事件确定新状态
    (block $state_machine
      ;; IDLE状态的处理
      (if (i32.eq (local.get $current) (global.get $STATE_IDLE))
        (then
          (if (i32.eq (local.get $event) (global.get $EVENT_INSERT_COIN))
            (then
              (local.set $new_state (global.get $STATE_COIN_INSERTED))
              (br $state_machine)
            )
          )
          ;; 无效转换
          (return (global.get $ERROR_INVALID_TRANSITION))
        )
      )
      
      ;; COIN_INSERTED状态的处理
      (if (i32.eq (local.get $current) (global.get $STATE_COIN_INSERTED))
        (then
          (block $coin_inserted_block
            (if (i32.eq (local.get $event) (global.get $EVENT_SELECT_ITEM))
              (then
                (local.set $new_state (global.get $STATE_ITEM_SELECTED))
                (br $state_machine)
              )
            )
            (if (i32.eq (local.get $event) (global.get $EVENT_RESET))
              (then
                (local.set $new_state (global.get $STATE_IDLE))
                (br $state_machine)
              )
            )
            ;; 无效转换
            (return (global.get $ERROR_INVALID_TRANSITION))
          )
        )
      )
      
      ;; ITEM_SELECTED状态的处理
      (if (i32.eq (local.get $current) (global.get $STATE_ITEM_SELECTED))
        (then
          (block $item_selected_block
            (if (i32.eq (local.get $event) (global.get $EVENT_DISPENSE))
              (then
                (local.set $new_state (global.get $STATE_DISPENSING))
                (br $state_machine)
              )
            )
            (if (i32.eq (local.get $event) (global.get $EVENT_RESET))
              (then
                (local.set $new_state (global.get $STATE_IDLE))
                (br $state_machine)
              )
            )
            ;; 无效转换
            (return (global.get $ERROR_INVALID_TRANSITION))
          )
        )
      )
      
      ;; DISPENSING状态的处理
      (if (i32.eq (local.get $current) (global.get $STATE_DISPENSING))
        (then
          ;; 分发完成后自动回到IDLE状态
          (local.set $new_state (global.get $STATE_IDLE))
        )
        (else
          ;; 未知状态
          (return (global.get $ERROR_INVALID_TRANSITION))
        )
      )
    )
    
    ;; 更新状态
    (global.set $current_state (local.get $new_state))
    (global.get $SUCCESS)
  )
  
  ;; 获取当前状态
  (func $get_current_state (result i32)
    (global.get $current_state)
  )
  
  ;; 重置状态机
  (func $reset_state_machine
    (global.set $current_state (global.get $STATE_IDLE))
  )
  
  ;; 状态名称获取（返回状态码对应的数值）
  (func $get_state_name (param $state i32) (result i32)
    ;; 简单返回状态值，实际应用中可以返回字符串指针
    (local.get $state)
  )
  
  ;; 模拟完整的购买流程
  (func $simulate_purchase (result i32)
    (local $result i32)
    
    ;; 重置状态机
    (call $reset_state_machine)
    
    ;; 投币
    (local.set $result (call $process_event (global.get $EVENT_INSERT_COIN)))
    (if (i32.ne (local.get $result) (global.get $SUCCESS))
      (then (return (local.get $result)))
    )
    
    ;; 选择商品
    (local.set $result (call $process_event (global.get $EVENT_SELECT_ITEM)))
    (if (i32.ne (local.get $result) (global.get $SUCCESS))
      (then (return (local.get $result)))
    )
    
    ;; 分发商品
    (local.set $result (call $process_event (global.get $EVENT_DISPENSE)))
    (if (i32.ne (local.get $result) (global.get $SUCCESS))
      (then (return (local.get $result)))
    )
    
    ;; 自动完成分发
    (call $process_event (global.get $EVENT_RESET))
  )
  
  (export "process_event" (func $process_event))
  (export "get_current_state" (func $get_current_state))
  (export "reset_state_machine" (func $reset_state_machine))
  (export "simulate_purchase" (func $simulate_purchase))
)
```

**解答说明**：
1. 使用全局变量维护状态机当前状态
2. 通过嵌套的if-else实现状态转换逻辑
3. 使用block和br实现控制流跳转
4. 提供完整的状态机操作接口

</details>

## 练习6：性能优化的控制流 (30分)

**题目**：实现一个高性能的数组搜索函数，要求：
1. 使用二分搜索算法
2. 针对分支预测进行优化
3. 处理边界情况
4. 提供详细的性能分析

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory 1)
  
  ;; 二分搜索函数（优化版本）
  (func $binary_search_optimized (param $arr_ptr i32) (param $arr_len i32) (param $target i32) (result i32)
    (local $left i32)
    (local $right i32)
    (local $mid i32)
    (local $mid_value i32)
    (local $comparison i32)
    
    ;; 边界检查
    (if (i32.le_u (local.get $arr_len) (i32.const 0))
      (then (return (i32.const -1)))
    )
    
    ;; 初始化搜索范围
    (local.set $left (i32.const 0))
    (local.set $right (i32.sub (local.get $arr_len) (i32.const 1)))
    
    ;; 主搜索循环
    (loop $search_loop
      ;; 检查搜索范围是否有效
      (if (i32.gt_s (local.get $left) (local.get $right))
        (then (return (i32.const -1)))
      )
      
      ;; 计算中点（避免溢出的方法）
      (local.set $mid
        (i32.add
          (local.get $left)
          (i32.shr_u
            (i32.sub (local.get $right) (local.get $left))
            (i32.const 1)
          )
        )
      )
      
      ;; 加载中点元素值
      (local.set $mid_value
        (i32.load
          (i32.add
            (local.get $arr_ptr)
            (i32.mul (local.get $mid) (i32.const 4))
          )
        )
      )
      
      ;; 比较目标值与中点值
      (local.set $comparison (i32.sub (local.get $target) (local.get $mid_value)))
      
      ;; 优化的分支结构（减少分支错误预测）
      (if (i32.eq (local.get $comparison) (i32.const 0))
        (then
          ;; 找到目标值
          (return (local.get $mid))
        )
        (else
          ;; 根据比较结果调整搜索范围
          (if (i32.lt_s (local.get $comparison) (i32.const 0))
            (then
              ;; target < mid_value，搜索左半部分
              (local.set $right (i32.sub (local.get $mid) (i32.const 1)))
            )
            (else
              ;; target > mid_value，搜索右半部分
              (local.set $left (i32.add (local.get $mid) (i32.const 1)))
            )
          )
        )
      )
      
      ;; 继续循环
      (br $search_loop)
    )
    
    ;; 理论上不会执行到这里
    (i32.const -1)
  )
  
  ;; 线性搜索（用于性能对比）
  (func $linear_search (param $arr_ptr i32) (param $arr_len i32) (param $target i32) (result i32)
    (local $i i32)
    (local $current_value i32)
    
    (local.set $i (i32.const 0))
    
    (loop $linear_loop
      ;; 边界检查
      (if (i32.ge_u (local.get $i) (local.get $arr_len))
        (then (return (i32.const -1)))
      )
      
      ;; 加载当前元素
      (local.set $current_value
        (i32.load
          (i32.add
            (local.get $arr_ptr)
            (i32.mul (local.get $i) (i32.const 4))
          )
        )
      )
      
      ;; 检查是否匹配
      (if (i32.eq (local.get $current_value) (local.get $target))
        (then (return (local.get $i)))
      )
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $linear_loop)
    )
    
    (i32.const -1)
  )
  
  ;; 预测优化的搜索函数
  (func $predictive_search (param $arr_ptr i32) (param $arr_len i32) (param $target i32) (result i32)
    (local $left i32)
    (local $right i32)
    (local $mid i32)
    (local $mid_value i32)
    (local $likely_direction i32)
    
    ;; 边界检查
    (if (i32.le_u (local.get $arr_len) (i32.const 0))
      (then (return (i32.const -1)))
    )
    
    ;; 快速检查边界值
    (if (i32.eq 
          (local.get $target) 
          (i32.load (local.get $arr_ptr)))
      (then (return (i32.const 0)))
    )
    
    (if (i32.eq 
          (local.get $target)
          (i32.load 
            (i32.add 
              (local.get $arr_ptr)
              (i32.mul 
                (i32.sub (local.get $arr_len) (i32.const 1))
                (i32.const 4)
              )
            )
          ))
      (then (return (i32.sub (local.get $arr_len) (i32.const 1))))
    )
    
    ;; 使用标准二分搜索
    (call $binary_search_optimized 
          (local.get $arr_ptr) 
          (local.get $arr_len) 
          (local.get $target))
  )
  
  ;; 批量搜索测试函数
  (func $batch_search_test (param $arr_ptr i32) (param $arr_len i32) (result i32)
    (local $found_count i32)
    (local $i i32)
    (local $search_target i32)
    (local $result i32)
    
    (local.set $found_count (i32.const 0))
    (local.set $i (i32.const 0))
    
    ;; 搜索一系列目标值
    (loop $batch_loop
      (if (i32.ge_u (local.get $i) (i32.const 10))
        (then (return (local.get $found_count)))
      )
      
      ;; 设置搜索目标（搜索值i）
      (local.set $search_target (local.get $i))
      
      ;; 执行搜索
      (local.set $result
        (call $binary_search_optimized
              (local.get $arr_ptr)
              (local.get $arr_len)
              (local.get $search_target)))
      
      ;; 如果找到，增加计数
      (if (i32.ge_s (local.get $result) (i32.const 0))
        (then
          (local.set $found_count 
                     (i32.add (local.get $found_count) (i32.const 1)))
        )
      )
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $batch_loop)
    )
    
    (local.get $found_count)
  )
  
  ;; 数组初始化辅助函数
  (func $init_sorted_array (param $arr_ptr i32) (param $size i32)
    (local $i i32)
    
    (local.set $i (i32.const 0))
    
    (loop $init_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (return))
      )
      
      ;; 设置 arr[i] = i * 2
      (i32.store
        (i32.add
          (local.get $arr_ptr)
          (i32.mul (local.get $i) (i32.const 4))
        )
        (i32.mul (local.get $i) (i32.const 2))
      )
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $init_loop)
    )
  )
  
  (export "binary_search_optimized" (func $binary_search_optimized))
  (export "linear_search" (func $linear_search))
  (export "predictive_search" (func $predictive_search))
  (export "batch_search_test" (func $batch_search_test))
  (export "init_sorted_array" (func $init_sorted_array))
)
```

**解答说明**：

**性能优化技术**：
1. **避免整数溢出**：使用 `left + (right - left) / 2` 计算中点
2. **分支预测优化**：将最可能的情况放在前面
3. **边界值快速检查**：优先检查数组首尾元素
4. **减少内存访问**：缓存中间计算结果

**算法复杂度**：
- 二分搜索：O(log n) 时间复杂度
- 线性搜索：O(n) 时间复杂度（用于对比）

**优化策略**：
1. 使用局部变量减少全局状态访问
2. 优化循环结构减少分支开销
3. 提供批量处理接口提高缓存效率

</details>

## 练习总结

通过这些练习，你应该掌握了：

1. **基础控制流**：条件分支、循环结构的实现
2. **复杂控制逻辑**：嵌套结构、状态机设计
3. **错误处理**：异常检测、错误传播机制
4. **性能优化**：分支预测、算法复杂度优化
5. **实际应用**：数组操作、数值计算、状态管理

这些技能是开发高性能WebAssembly应用的基础，建议结合实际项目进行练习和应用。
