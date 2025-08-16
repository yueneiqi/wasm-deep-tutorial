# 第5章 内存管理

WebAssembly 的内存系统是其高性能的关键基础。本章将深入探讨 WebAssembly 的线性内存模型、内存操作指令、以及高效的内存管理策略。

## 线性内存模型

### 5.1.1 内存基础概念

WebAssembly 使用线性内存模型，这是一个连续的字节数组：

```wat
(module
  ;; 定义最小1页（64KB），最大10页的内存
  (memory $main 1 10)
  
  ;; 导出内存供外部访问
  (export "memory" (memory $main))
  
  ;; 简单的内存读写演示
  (func $memory_demo (param $offset i32) (param $value i32)
    ;; 写入32位整数到指定偏移
    (i32.store (local.get $offset) (local.get $value))
    
    ;; 读取并验证
    (i32.load (local.get $offset))
    drop)
  
  (export "memory_demo" (func $memory_demo)))
```

**内存组织结构：**

```
内存页 = 64KB (65536 字节)
地址空间 = 0 到 (页数 * 64KB - 1)

地址 0x0000: [字节 0] [字节 1] [字节 2] [字节 3] ...
地址 0x0004: [字节 4] [字节 5] [字节 6] [字节 7] ...
            ...
地址 0xFFFC: [倒数第4字节] [倒数第3字节] [倒数第2字节] [最后字节]
```

### 5.1.2 内存布局策略

有效的内存布局对性能至关重要：

```wat
(module
  (memory 1)  ;; 64KB 内存
  
  ;; 内存布局规划
  ;; 0x0000 - 0x0100: 系统保留区域 (256字节)
  ;; 0x0100 - 0x1000: 栈空间 (3840字节)
  ;; 0x1000 - 0x8000: 堆空间 (28KB)
  ;; 0x8000 - 0xFFFF: 静态数据区 (32KB)
  
  (global $RESERVED_START i32 (i32.const 0x0000))
  (global $STACK_START i32 (i32.const 0x0100))
  (global $HEAP_START i32 (i32.const 0x1000))
  (global $DATA_START i32 (i32.const 0x8000))
  
  ;; 当前栈指针
  (global $stack_ptr (mut i32) (i32.const 0x1000))
  
  ;; 堆分配指针
  (global $heap_ptr (mut i32) (i32.const 0x1000))
  
  ;; 栈操作：压栈
  (func $push (param $value i32)
    ;; 移动栈指针
    (global.set $stack_ptr
      (i32.sub (global.get $stack_ptr) (i32.const 4)))
    
    ;; 存储值
    (i32.store (global.get $stack_ptr) (local.get $value)))
  
  ;; 栈操作：弹栈
  (func $pop (result i32)
    (local $value i32)
    
    ;; 读取值
    (local.set $value (i32.load (global.get $stack_ptr)))
    
    ;; 移动栈指针
    (global.set $stack_ptr
      (i32.add (global.get $stack_ptr) (i32.const 4)))
    
    local.get $value)
  
  ;; 简单的堆分配器
  (func $malloc (param $size i32) (result i32)
    (local $ptr i32)
    
    ;; 获取当前堆指针
    (local.set $ptr (global.get $heap_ptr))
    
    ;; 对齐到4字节边界
    (local.set $size
      (i32.and
        (i32.add (local.get $size) (i32.const 3))
        (i32.const 0xFFFFFFFC)))
    
    ;; 更新堆指针
    (global.set $heap_ptr
      (i32.add (global.get $heap_ptr) (local.get $size)))
    
    ;; 检查是否超出堆空间
    (if (i32.gt_u (global.get $heap_ptr) (global.get $DATA_START))
      (then 
        ;; 分配失败，返回 NULL
        (global.set $heap_ptr (local.get $ptr))
        (return (i32.const 0))))
    
    local.get $ptr)
  
  (export "push" (func $push))
  (export "pop" (func $pop))
  (export "malloc" (func $malloc))
  (export "memory" (memory 0)))
```

### 5.1.3 内存增长机制

WebAssembly 支持运行时动态增长内存：

```wat
(module
  (memory 1 100)  ;; 初始1页，最大100页
  
  ;; 内存状态监控
  (func $get_memory_size (result i32)
    (memory.size))  ;; 返回当前页数
  
  ;; 增长内存
  (func $grow_memory (param $pages i32) (result i32)
    (local $old_size i32)
    
    ;; 获取增长前的大小
    (local.set $old_size (memory.size))
    
    ;; 尝试增长内存
    (memory.grow (local.get $pages))
    
    ;; memory.grow 返回增长前的页数，失败时返回 -1
    (if (result i32)
      (i32.eq (memory.grow (i32.const 0)) (i32.const -1))
      (then (i32.const 0))  ;; 失败
      (else (i32.const 1))))  ;; 成功
  
  ;; 检查内存是否足够
  (func $ensure_memory (param $required_bytes i32) (result i32)
    (local $current_bytes i32)
    (local $required_pages i32)
    (local $current_pages i32)
    
    ;; 计算当前总字节数
    (local.set $current_pages (memory.size))
    (local.set $current_bytes 
      (i32.mul (local.get $current_pages) (i32.const 65536)))
    
    ;; 检查是否需要增长
    (if (i32.ge_u (local.get $current_bytes) (local.get $required_bytes))
      (then (return (i32.const 1))))  ;; 已经足够
    
    ;; 计算需要的页数
    (local.set $required_pages
      (i32.div_u
        (i32.add (local.get $required_bytes) (i32.const 65535))
        (i32.const 65536)))
    
    ;; 尝试增长到所需大小
    (call $grow_memory
      (i32.sub (local.get $required_pages) (local.get $current_pages))))
  
  (export "get_memory_size" (func $get_memory_size))
  (export "grow_memory" (func $grow_memory))
  (export "ensure_memory" (func $ensure_memory))
  (export "memory" (memory 0)))
```

## 内存操作指令

### 5.2.1 加载指令详解

WebAssembly 提供多种粒度的内存加载指令：

```wat
(module
  (memory 1)
  
  ;; 初始化测试数据
  (data (i32.const 0) "\01\02\03\04\05\06\07\08\09\0A\0B\0C\0D\0E\0F\10")
  
  (func $load_operations (param $addr i32)
    ;; 8位加载
    (i32.load8_u (local.get $addr))    ;; 无符号8位 → i32
    (i32.load8_s (local.get $addr))    ;; 有符号8位 → i32
    
    ;; 16位加载  
    (i32.load16_u (local.get $addr))   ;; 无符号16位 → i32
    (i32.load16_s (local.get $addr))   ;; 有符号16位 → i32
    
    ;; 32位加载
    (i32.load (local.get $addr))       ;; 32位 → i32
    
    ;; 64位加载（到 i64）
    (i64.load8_u (local.get $addr))    ;; 无符号8位 → i64
    (i64.load8_s (local.get $addr))    ;; 有符号8位 → i64
    (i64.load16_u (local.get $addr))   ;; 无符号16位 → i64
    (i64.load16_s (local.get $addr))   ;; 有符号16位 → i64
    (i64.load32_u (local.get $addr))   ;; 无符号32位 → i64
    (i64.load32_s (local.get $addr))   ;; 有符号32位 → i64
    (i64.load (local.get $addr))       ;; 64位 → i64
    
    ;; 浮点数加载
    (f32.load (local.get $addr))       ;; 32位浮点
    (f64.load (local.get $addr))       ;; 64位浮点
    
    ;; 清空栈
    drop drop drop drop drop drop drop drop
    drop drop drop drop drop drop)
  
  (export "load_operations" (func $load_operations))
  (export "memory" (memory 0)))
```

### 5.2.2 存储指令详解

相应的存储指令支持不同的数据宽度：

```wat
(module
  (memory 1)
  
  (func $store_operations (param $addr i32) (param $value i32)
    ;; 8位存储
    (i32.store8 (local.get $addr) (local.get $value))
    
    ;; 16位存储
    (i32.store16 (local.get $addr) (local.get $value))
    
    ;; 32位存储
    (i32.store (local.get $addr) (local.get $value)))
  
  ;; 批量数据复制
  (func $memory_copy (param $dest i32) (param $src i32) (param $size i32)
    (local $i i32)
    
    (local.set $i (i32.const 0))
    
    (loop $copy_loop
      ;; 检查是否完成
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $copy_loop)))
      
      ;; 复制一个字节
      (i32.store8
        (i32.add (local.get $dest) (local.get $i))
        (i32.load8_u
          (i32.add (local.get $src) (local.get $i))))
      
      ;; 递增计数器
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      (br $copy_loop)))
  
  ;; 内存填充
  (func $memory_fill (param $addr i32) (param $value i32) (param $size i32)
    (local $i i32)
    
    (local.set $i (i32.const 0))
    
    (loop $fill_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $fill_loop)))
      
      (i32.store8
        (i32.add (local.get $addr) (local.get $i))
        (local.get $value))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      (br $fill_loop)))
  
  (export "store_operations" (func $store_operations))
  (export "memory_copy" (func $memory_copy))
  (export "memory_fill" (func $memory_fill))
  (export "memory" (memory 0)))
```

### 5.2.3 批量内存操作（WASM 扩展）

现代 WebAssembly 支持高效的批量内存操作：

```wat
(module
  (memory 1)
  
  ;; 使用 memory.copy 批量复制（需要 bulk-memory 提案）
  (func $fast_memory_copy (param $dest i32) (param $src i32) (param $size i32)
    (memory.copy 
      (local.get $dest) 
      (local.get $src) 
      (local.get $size)))
  
  ;; 使用 memory.fill 批量填充
  (func $fast_memory_fill (param $addr i32) (param $value i32) (param $size i32)
    (memory.fill 
      (local.get $addr) 
      (local.get $value) 
      (local.get $size)))
  
  ;; 初始化内存段
  (func $init_data_segment (param $dest i32) (param $segment_index i32) (param $size i32)
    (memory.init $segment_index
      (local.get $dest)
      (i32.const 0)
      (local.get $size)))
  
  (export "fast_memory_copy" (func $fast_memory_copy))
  (export "fast_memory_fill" (func $fast_memory_fill))
  (export "init_data_segment" (func $init_data_segment))
  (export "memory" (memory 0)))
```

## 数据段初始化

### 5.3.1 静态数据段

数据段用于在模块实例化时初始化内存：

```wat
(module
  (memory 1)
  
  ;; 字符串数据段
  (data $hello (i32.const 0x1000) "Hello, WebAssembly!")
  (data $numbers (i32.const 0x1020) "\01\02\03\04\05\06\07\08")
  
  ;; 结构化数据
  (data $person_record (i32.const 0x1100)
    ;; 年龄 (4字节)
    "\1A\00\00\00"      ;; 26岁
    ;; 身高 (4字节浮点)
    "\00\00\B4\42"      ;; 90.0
    ;; 名字长度 (4字节)
    "\05\00\00\00"      ;; 5个字符
    ;; 名字数据
    "Alice")
  
  ;; 查找表数据
  (data $lookup_table (i32.const 0x2000)
    ;; 平方表：0² 到 15²
    "\00\00\00\00"  ;; 0
    "\01\00\00\00"  ;; 1
    "\04\00\00\00"  ;; 4
    "\09\00\00\00"  ;; 9
    "\10\00\00\00"  ;; 16
    "\19\00\00\00"  ;; 25
    "\24\00\00\00"  ;; 36
    "\31\00\00\00"  ;; 49
    "\40\00\00\00"  ;; 64
    "\51\00\00\00"  ;; 81
    "\64\00\00\00"  ;; 100
    "\79\00\00\00"  ;; 121
    "\90\00\00\00"  ;; 144
    "\A9\00\00\00"  ;; 169
    "\C4\00\00\00"  ;; 196
    "\E1\00\00\00") ;; 225
  
  ;; 读取字符串
  (func $get_string_char (param $index i32) (result i32)
    (if (result i32)
      (i32.ge_u (local.get $index) (i32.const 20))
      (then (i32.const 0))  ;; 超出范围
      (else
        (i32.load8_u
          (i32.add (i32.const 0x1000) (local.get $index))))))
  
  ;; 快速平方查找
  (func $fast_square (param $n i32) (result i32)
    (if (result i32)
      (i32.ge_u (local.get $n) (i32.const 16))
      (then (i32.mul (local.get $n) (local.get $n)))  ;; 计算
      (else  ;; 查表
        (i32.load
          (i32.add
            (i32.const 0x2000)
            (i32.mul (local.get $n) (i32.const 4)))))))
  
  ;; 读取人员记录
  (func $get_person_age (result i32)
    (i32.load (i32.const 0x1100)))
  
  (func $get_person_height (result f32)
    (f32.load (i32.const 0x1104)))
  
  (func $get_person_name_length (result i32)
    (i32.load (i32.const 0x1108)))
  
  (export "get_string_char" (func $get_string_char))
  (export "fast_square" (func $fast_square))
  (export "get_person_age" (func $get_person_age))
  (export "get_person_height" (func $get_person_height))
  (export "get_person_name_length" (func $get_person_name_length))
  (export "memory" (memory 0)))
```

### 5.3.2 动态数据段（被动段）

被动数据段可以在运行时按需初始化：

```wat
(module
  (memory 1)
  
  ;; 被动数据段（不会自动初始化）
  (data $template_data passive "Template: ")
  (data $error_messages passive 
    "Error 1: Invalid input\00"
    "Error 2: Out of memory\00"  
    "Error 3: Division by zero\00")
  
  ;; 消息偏移表
  (data $message_offsets passive
    "\00\00\00\00"  ;; 错误1偏移: 0
    "\14\00\00\00"  ;; 错误2偏移: 20
    "\2B\00\00\00") ;; 错误3偏移: 43
  
  ;; 字符串工作缓冲区基址
  (global $string_buffer i32 (i32.const 0x3000))
  
  ;; 初始化错误消息系统
  (func $init_error_system
    ;; 初始化错误消息到缓冲区
    (memory.init $error_messages
      (global.get $string_buffer)  ;; 目标地址
      (i32.const 0)                ;; 源偏移
      (i32.const 60))              ;; 大小
    
    ;; 初始化偏移表
    (memory.init $message_offsets
      (i32.add (global.get $string_buffer) (i32.const 1000))
      (i32.const 0)
      (i32.const 12))
    
    ;; 删除数据段以释放内存
    (data.drop $error_messages)
    (data.drop $message_offsets))
  
  ;; 构建带模板的错误消息
  (func $build_error_message (param $error_code i32) (param $dest i32)
    (local $template_len i32)
    (local $msg_offset i32)
    (local $msg_addr i32)
    
    ;; 复制模板前缀
    (memory.init $template_data
      (local.get $dest)
      (i32.const 0)
      (i32.const 10))  ;; "Template: " 长度
    
    ;; 获取错误消息偏移
    (local.set $msg_offset
      (i32.load
        (i32.add
          (i32.add (global.get $string_buffer) (i32.const 1000))
          (i32.mul (local.get $error_code) (i32.const 4)))))
    
    ;; 计算消息实际地址
    (local.set $msg_addr
      (i32.add (global.get $string_buffer) (local.get $msg_offset)))
    
    ;; 复制错误消息（简化版，假设长度为20）
    (call $copy_string
      (i32.add (local.get $dest) (i32.const 10))
      (local.get $msg_addr)
      (i32.const 20)))
  
  ;; 辅助：复制字符串
  (func $copy_string (param $dest i32) (param $src i32) (param $len i32)
    (local $i i32)
    
    (loop $copy_loop
      (if (i32.ge_u (local.get $i) (local.get $len))
        (then (br $copy_loop)))
      
      (i32.store8
        (i32.add (local.get $dest) (local.get $i))
        (i32.load8_u
          (i32.add (local.get $src) (local.get $i))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $copy_loop)))
  
  (export "init_error_system" (func $init_error_system))
  (export "build_error_message" (func $build_error_message))
  (export "memory" (memory 0)))
```

## 内存对齐与性能

### 5.4.1 对齐原理

内存对齐对性能有重要影响：

```wat
(module
  (memory 1)
  
  ;; 演示对齐访问
  (func $alignment_demo
    ;; 对齐的32位访问（地址是4的倍数）
    (i32.store align=4 (i32.const 0x1000) (i32.const 0x12345678))
    (i32.load align=4 (i32.const 0x1000))
    
    ;; 非对齐访问（可能较慢，但仍然有效）
    (i32.store align=1 (i32.const 0x1001) (i32.const 0x87654321))
    (i32.load align=1 (i32.const 0x1001))
    
    ;; 64位对齐访问
    (i64.store align=8 (i32.const 0x2000) (i64.const 0x123456789ABCDEF0))
    (i64.load align=8 (i32.const 0x2000))
    
    drop drop drop)
  
  ;; 数据结构对齐
  (func $aligned_struct_demo
    (local $base_addr i32)
    (local.set $base_addr (i32.const 0x3000))
    
    ;; 结构体：
    ;; struct Person {
    ;;   i32 id;        // 0-3
    ;;   f64 height;    // 8-15 (对齐到8字节)
    ;;   i32 age;       // 16-19
    ;; } // 总大小：24字节（末尾填充到8字节对齐）
    
    ;; 存储 ID
    (i32.store align=4 
      (local.get $base_addr) 
      (i32.const 12345))
    
    ;; 存储身高（注意8字节对齐）
    (f64.store align=8 
      (i32.add (local.get $base_addr) (i32.const 8)) 
      (f64.const 175.5))
    
    ;; 存储年龄
    (i32.store align=4 
      (i32.add (local.get $base_addr) (i32.const 16)) 
      (i32.const 25)))
  
  ;; 内存对齐工具函数
  (func $align_up (param $addr i32) (param $alignment i32) (result i32)
    (local $mask i32)
    
    ;; 计算掩码（对齐-1）
    (local.set $mask (i32.sub (local.get $alignment) (i32.const 1)))
    
    ;; 对齐公式：(addr + mask) & ~mask
    (i32.and
      (i32.add (local.get $addr) (local.get $mask))
      (i32.xor (local.get $mask) (i32.const -1))))
  
  ;; 检查地址是否对齐
  (func $is_aligned (param $addr i32) (param $alignment i32) (result i32)
    (i32.eqz
      (i32.rem_u (local.get $addr) (local.get $alignment))))
  
  (export "alignment_demo" (func $alignment_demo))
  (export "aligned_struct_demo" (func $aligned_struct_demo))
  (export "align_up" (func $align_up))
  (export "is_aligned" (func $is_aligned))
  (export "memory" (memory 0)))
```

### 5.4.2 性能优化技巧

```wat
(module
  (memory 1)
  
  ;; 缓存友好的数据访问
  (func $cache_friendly_sum (param $array_ptr i32) (param $length i32) (result i32)
    (local $sum i32)
    (local $i i32)
    
    ;; 顺序访问，利用缓存局部性
    (loop $sum_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $sum_loop)))
      
      (local.set $sum
        (i32.add 
          (local.get $sum)
          (i32.load 
            (i32.add 
              (local.get $array_ptr)
              (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $sum_loop))
    
    local.get $sum)
  
  ;; 批量操作优化：一次处理多个元素
  (func $vectorized_add (param $a_ptr i32) (param $b_ptr i32) (param $result_ptr i32) (param $length i32)
    (local $i i32)
    (local $end i32)
    
    ;; 计算向量化结束位置（4的倍数）
    (local.set $end 
      (i32.and (local.get $length) (i32.const 0xFFFFFFFC)))
    
    ;; 向量化循环：一次处理4个元素
    (loop $vector_loop
      (if (i32.ge_u (local.get $i) (local.get $end))
        (then (br $vector_loop)))
      
      ;; 处理4个连续的32位整数
      (i32.store
        (i32.add (local.get $result_ptr) (i32.mul (local.get $i) (i32.const 4)))
        (i32.add
          (i32.load (i32.add (local.get $a_ptr) (i32.mul (local.get $i) (i32.const 4))))
          (i32.load (i32.add (local.get $b_ptr) (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $vector_loop))
    
    ;; 处理剩余元素
    (loop $remainder_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $remainder_loop)))
      
      (i32.store
        (i32.add (local.get $result_ptr) (i32.mul (local.get $i) (i32.const 4)))
        (i32.add
          (i32.load (i32.add (local.get $a_ptr) (i32.mul (local.get $i) (i32.const 4))))
          (i32.load (i32.add (local.get $b_ptr) (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $remainder_loop)))
  
  ;; 内存预取模拟（通过提前访问实现）
  (func $prefetch_demo (param $data_ptr i32) (param $length i32) (result i32)
    (local $sum i32)
    (local $i i32)
    (local $prefetch_distance i32)
    
    (local.set $prefetch_distance (i32.const 64))  ;; 提前64个元素
    
    (loop $prefetch_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $prefetch_loop)))
      
      ;; 预取未来的数据
      (if (i32.lt_u 
            (i32.add (local.get $i) (local.get $prefetch_distance))
            (local.get $length))
        (then
          (i32.load  ;; 触发缓存加载
            (i32.add 
              (local.get $data_ptr)
              (i32.mul 
                (i32.add (local.get $i) (local.get $prefetch_distance))
                (i32.const 4))))
          drop))
      
      ;; 处理当前数据
      (local.set $sum
        (i32.add 
          (local.get $sum)
          (i32.load 
            (i32.add 
              (local.get $data_ptr)
              (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $prefetch_loop))
    
    local.get $sum)
  
  (export "cache_friendly_sum" (func $cache_friendly_sum))
  (export "vectorized_add" (func $vectorized_add))
  (export "prefetch_demo" (func $prefetch_demo))
  (export "memory" (memory 0)))
```

## 高级内存管理

### 5.5.1 简单的内存分配器

```wat
(module
  (memory 1)
  
  ;; 内存块头结构（8字节）
  ;; [0-3]: 块大小
  ;; [4-7]: 下一个块的偏移（0表示最后一个块）
  
  (global $heap_start i32 (i32.const 0x1000))
  (global $heap_end i32 (i32.const 0xF000))
  
  ;; 初始化堆
  (func $init_heap
    ;; 创建初始空闲块
    (i32.store (global.get $heap_start) 
      (i32.sub (global.get $heap_end) (global.get $heap_start)))
    (i32.store (i32.add (global.get $heap_start) (i32.const 4)) 
      (i32.const 0)))
  
  ;; 分配内存
  (func $heap_alloc (param $size i32) (result i32)
    (local $current i32)
    (local $block_size i32)
    (local $next_offset i32)
    (local $aligned_size i32)
    
    ;; 对齐到8字节边界
    (local.set $aligned_size
      (i32.and
        (i32.add (local.get $size) (i32.const 15))
        (i32.const 0xFFFFFFF8)))
    
    (local.set $current (global.get $heap_start))
    
    ;; 遍历空闲块链表
    (loop $find_block
      ;; 检查当前块
      (local.set $block_size (i32.load (local.get $current)))
      (local.set $next_offset (i32.load (i32.add (local.get $current) (i32.const 4))))
      
      ;; 如果块足够大
      (if (i32.ge_u (local.get $block_size) 
                    (i32.add (local.get $aligned_size) (i32.const 8)))
        (then
          ;; 分割块
          (call $split_block (local.get $current) (local.get $aligned_size))
          ;; 返回数据指针（跳过头部）
          (return (i32.add (local.get $current) (i32.const 8)))))
      
      ;; 移动到下一块
      (if (i32.eqz (local.get $next_offset))
        (then (return (i32.const 0))))  ;; 没有找到合适的块
      
      (local.set $current (i32.add (global.get $heap_start) (local.get $next_offset)))
      (br $find_block)))
  
  ;; 分割内存块
  (func $split_block (param $block i32) (param $size i32)
    (local $block_size i32)
    (local $remaining_size i32)
    (local $new_block i32)
    
    (local.set $block_size (i32.load (local.get $block)))
    (local.set $remaining_size 
      (i32.sub (local.get $block_size) (i32.add (local.get $size) (i32.const 8))))
    
    ;; 如果剩余大小足够创建新块
    (if (i32.gt_u (local.get $remaining_size) (i32.const 16))
      (then
        ;; 更新当前块大小
        (i32.store (local.get $block) (i32.add (local.get $size) (i32.const 8)))
        
        ;; 创建新的空闲块
        (local.set $new_block 
          (i32.add (local.get $block) (i32.add (local.get $size) (i32.const 8))))
        
        (i32.store (local.get $new_block) (local.get $remaining_size))
        (i32.store (i32.add (local.get $new_block) (i32.const 4))
          (i32.load (i32.add (local.get $block) (i32.const 4))))
        
        ;; 更新链接
        (i32.store (i32.add (local.get $block) (i32.const 4))
          (i32.sub (local.get $new_block) (global.get $heap_start))))))
  
  ;; 释放内存
  (func $heap_free (param $ptr i32)
    (local $block i32)
    
    ;; 获取块头地址
    (local.set $block (i32.sub (local.get $ptr) (i32.const 8)))
    
    ;; 简化版：直接添加到空闲链表头部
    (i32.store (i32.add (local.get $block) (i32.const 4))
      (i32.sub (global.get $heap_start) (global.get $heap_start)))
    
    ;; 这里应该实现块合并逻辑，但为简化省略
    )
  
  ;; 获取堆统计信息
  (func $heap_stats (param $total_size_ptr i32) (param $free_blocks_ptr i32)
    (local $current i32)
    (local $total_free i32)
    (local $block_count i32)
    
    (local.set $current (global.get $heap_start))
    
    (loop $count_blocks
      (if (i32.eqz (local.get $current))
        (then (br $count_blocks)))
      
      (local.set $total_free 
        (i32.add (local.get $total_free) (i32.load (local.get $current))))
      (local.set $block_count (i32.add (local.get $block_count) (i32.const 1)))
      
      (local.set $current 
        (i32.add (global.get $heap_start) 
          (i32.load (i32.add (local.get $current) (i32.const 4)))))
      
      (br $count_blocks))
    
    (i32.store (local.get $total_size_ptr) (local.get $total_free))
    (i32.store (local.get $free_blocks_ptr) (local.get $block_count)))
  
  (export "init_heap" (func $init_heap))
  (export "heap_alloc" (func $heap_alloc))
  (export "heap_free" (func $heap_free))
  (export "heap_stats" (func $heap_stats))
  (export "memory" (memory 0)))
```

### 5.5.2 内存池分配器

```wat
(module
  (memory 1)
  
  ;; 固定大小内存池
  (global $pool_16_start i32 (i32.const 0x2000))   ;; 16字节块池
  (global $pool_32_start i32 (i32.const 0x4000))   ;; 32字节块池
  (global $pool_64_start i32 (i32.const 0x6000))   ;; 64字节块池
  
  (global $pool_16_free_head (mut i32) (i32.const 0))
  (global $pool_32_free_head (mut i32) (i32.const 0))
  (global $pool_64_free_head (mut i32) (i32.const 0))
  
  ;; 初始化内存池
  (func $init_pools
    ;; 初始化16字节池（128个块 = 2KB）
    (call $init_pool (global.get $pool_16_start) (i32.const 128) (i32.const 16))
    (global.set $pool_16_free_head (global.get $pool_16_start))
    
    ;; 初始化32字节池（64个块 = 2KB）
    (call $init_pool (global.get $pool_32_start) (i32.const 64) (i32.const 32))
    (global.set $pool_32_free_head (global.get $pool_32_start))
    
    ;; 初始化64字节池（32个块 = 2KB）
    (call $init_pool (global.get $pool_64_start) (i32.const 32) (i32.const 64))
    (global.set $pool_64_free_head (global.get $pool_64_start)))
  
  ;; 初始化单个池
  (func $init_pool (param $start_addr i32) (param $block_count i32) (param $block_size i32)
    (local $i i32)
    (local $current i32)
    (local $next i32)
    
    (local.set $current (local.get $start_addr))
    
    (loop $init_loop
      (if (i32.ge_u (local.get $i) (i32.sub (local.get $block_count) (i32.const 1)))
        (then (br $init_loop)))
      
      ;; 计算下一个块的地址
      (local.set $next (i32.add (local.get $current) (local.get $block_size)))
      
      ;; 在当前块的开头存储下一个块的地址
      (i32.store (local.get $current) (local.get $next))
      
      (local.set $current (local.get $next))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $init_loop))
    
    ;; 最后一个块指向NULL
    (i32.store (local.get $current) (i32.const 0)))
  
  ;; 池分配
  (func $pool_alloc (param $size i32) (result i32)
    (local $ptr i32)
    
    ;; 根据大小选择合适的池
    (if (i32.le_u (local.get $size) (i32.const 16))
      (then
        (local.set $ptr (global.get $pool_16_free_head))
        (if (local.get $ptr)
          (then
            (global.set $pool_16_free_head (i32.load (local.get $ptr)))
            (return (local.get $ptr))))))
    
    (if (i32.le_u (local.get $size) (i32.const 32))
      (then
        (local.set $ptr (global.get $pool_32_free_head))
        (if (local.get $ptr)
          (then
            (global.set $pool_32_free_head (i32.load (local.get $ptr)))
            (return (local.get $ptr))))))
    
    (if (i32.le_u (local.get $size) (i32.const 64))
      (then
        (local.set $ptr (global.get $pool_64_free_head))
        (if (local.get $ptr)
          (then
            (global.set $pool_64_free_head (i32.load (local.get $ptr)))
            (return (local.get $ptr))))))
    
    ;; 如果所有池都满了，返回NULL
    i32.const 0)
  
  ;; 池释放
  (func $pool_free (param $ptr i32) (param $size i32)
    ;; 根据大小确定池类型
    (if (i32.le_u (local.get $size) (i32.const 16))
      (then
        (i32.store (local.get $ptr) (global.get $pool_16_free_head))
        (global.set $pool_16_free_head (local.get $ptr))
        (return)))
    
    (if (i32.le_u (local.get $size) (i32.const 32))
      (then
        (i32.store (local.get $ptr) (global.get $pool_32_free_head))
        (global.set $pool_32_free_head (local.get $ptr))
        (return)))
    
    (if (i32.le_u (local.get $size) (i32.const 64))
      (then
        (i32.store (local.get $ptr) (global.get $pool_64_free_head))
        (global.set $pool_64_free_head (local.get $ptr)))))
  
  ;; 获取池状态
  (func $pool_stats (param $pool_size i32) (result i32)
    (local $free_count i32)
    (local $current i32)
    
    ;; 根据池大小选择对应的空闲链表头
    (if (i32.eq (local.get $pool_size) (i32.const 16))
      (then (local.set $current (global.get $pool_16_free_head))))
    (if (i32.eq (local.get $pool_size) (i32.const 32))
      (then (local.set $current (global.get $pool_32_free_head))))
    (if (i32.eq (local.get $pool_size) (i32.const 64))
      (then (local.set $current (global.get $pool_64_free_head))))
    
    ;; 计算空闲块数量
    (loop $count_loop
      (if (i32.eqz (local.get $current))
        (then (br $count_loop)))
      
      (local.set $free_count (i32.add (local.get $free_count) (i32.const 1)))
      (local.set $current (i32.load (local.get $current)))
      (br $count_loop))
    
    local.get $free_count)
  
  (export "init_pools" (func $init_pools))
  (export "pool_alloc" (func $pool_alloc))
  (export "pool_free" (func $pool_free))
  (export "pool_stats" (func $pool_stats))
  (export "memory" (memory 0)))
```

## 本章小结

通过本章学习，你已经全面掌握了：

1. **线性内存模型**：WebAssembly 的内存组织和布局策略
2. **内存操作**：加载、存储指令及其对齐优化
3. **数据段**：静态和动态数据初始化技术
4. **性能优化**：缓存友好访问和向量化技术
5. **内存管理**：分配器设计和内存池实现

这些技能为构建高性能的 WebAssembly 应用奠定了重要基础。

---

**📝 进入下一步**：[第6章 控制流](./chapter6-control-flow.md)

**🎯 重点技能**：
- ✅ 内存模型理解
- ✅ 内存操作优化
- ✅ 数据段应用
- ✅ 性能调优技巧
- ✅ 内存管理设计