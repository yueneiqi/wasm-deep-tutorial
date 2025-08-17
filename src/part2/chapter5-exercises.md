# 第5章 内存管理 - 练习题

本章练习旨在巩固 WebAssembly 内存管理的核心概念，包括线性内存模型、内存操作、数据段和性能优化等关键技能。

## 基础练习

### 练习 5.1 内存基础操作 (★★☆☆☆ 10分)

**题目**: 编写一个 WebAssembly 模块，实现基本的内存读写操作。

**要求**:
1. 定义一个 64KB 的内存空间
2. 实现一个函数 `store_values`，在内存偏移 0x1000 处存储四个 32 位整数：42, 84, 168, 336
3. 实现一个函数 `load_sum`，读取这四个值并返回它们的和

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 1)  ;; 64KB 内存
  
  (func $store_values
    ;; 在 0x1000 处存储四个值
    (i32.store (i32.const 0x1000) (i32.const 42))
    (i32.store (i32.const 0x1004) (i32.const 84))
    (i32.store (i32.const 0x1008) (i32.const 168))
    (i32.store (i32.const 0x100C) (i32.const 336)))
  
  (func $load_sum (result i32)
    (i32.add
      (i32.add
        (i32.load (i32.const 0x1000))
        (i32.load (i32.const 0x1004)))
      (i32.add
        (i32.load (i32.const 0x1008))
        (i32.load (i32.const 0x100C)))))
  
  (export "store_values" (func $store_values))
  (export "load_sum" (func $load_sum)))
```

**解析**: 
- 使用 `i32.store` 按4字节对齐存储整数
- 地址递增4字节以避免覆盖
- `load_sum` 读取所有值并计算总和 (630)
</details>

### 练习 5.2 内存布局设计 (★★★☆☆ 15分)

**题目**: 设计一个合理的内存布局，支持栈、堆和静态数据区域。

**要求**:
1. 在 64KB 内存中划分不同区域
2. 实现栈的 push/pop 操作
3. 实现简单的堆分配器
4. 实现获取内存使用统计的函数

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 1)
  
  ;; 内存布局
  ;; 0x0000-0x0400: 栈区 (1KB)
  ;; 0x0400-0x8000: 堆区 (30KB) 
  ;; 0x8000-0xFFFF: 静态数据区 (32KB)
  
  (global $stack_base i32 (i32.const 0x0400))
  (global $stack_ptr (mut i32) (i32.const 0x0400))
  (global $heap_start i32 (i32.const 0x0400))
  (global $heap_ptr (mut i32) (i32.const 0x0400))
  (global $static_start i32 (i32.const 0x8000))
  
  ;; 栈操作
  (func $push (param $value i32)
    (global.set $stack_ptr (i32.sub (global.get $stack_ptr) (i32.const 4)))
    (i32.store (global.get $stack_ptr) (local.get $value)))
  
  (func $pop (result i32)
    (local $value i32)
    (local.set $value (i32.load (global.get $stack_ptr)))
    (global.set $stack_ptr (i32.add (global.get $stack_ptr) (i32.const 4)))
    local.get $value)
  
  ;; 堆分配
  (func $malloc (param $size i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (global.get $heap_ptr))
    
    ;; 4字节对齐
    (local.set $size
      (i32.and (i32.add (local.get $size) (i32.const 3)) (i32.const 0xFFFFFFFC)))
    
    ;; 检查空间
    (if (i32.lt_u (i32.add (global.get $heap_ptr) (local.get $size)) (global.get $static_start))
      (then
        (global.set $heap_ptr (i32.add (global.get $heap_ptr) (local.get $size)))
        (return (local.get $ptr))))
    
    i32.const 0)  ;; 分配失败
  
  ;; 内存统计
  (func $get_stack_usage (result i32)
    (i32.sub (global.get $stack_base) (global.get $stack_ptr)))
  
  (func $get_heap_usage (result i32)
    (i32.sub (global.get $heap_ptr) (global.get $heap_start)))
  
  (export "push" (func $push))
  (export "pop" (func $pop))
  (export "malloc" (func $malloc))
  (export "get_stack_usage" (func $get_stack_usage))
  (export "get_heap_usage" (func $get_heap_usage)))
```

**解析**:
- 合理划分内存区域，避免冲突
- 栈向下增长，堆向上增长
- 实现边界检查防止溢出
- 提供内存使用监控功能
</details>

## 进阶练习

### 练习 5.3 数据段应用 (★★★☆☆ 20分)

**题目**: 使用数据段存储配置信息和查找表。

**要求**:
1. 在数据段中存储应用配置（版本号、最大用户数等）
2. 创建一个查找表用于快速计算平方根的整数近似值
3. 实现读取配置和查表函数

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 1)
  
  ;; 配置数据段
  (data $config (i32.const 0x1000)
    "\01\00\00\00"    ;; 版本号: 1
    "\E8\03\00\00"    ;; 最大用户数: 1000
    "\0A\00\00\00"    ;; 最大连接数: 10
    "\3C\00\00\00")   ;; 超时时间: 60秒
  
  ;; 平方根查找表 (0-255 的平方根整数近似值)
  (data $sqrt_table (i32.const 0x2000)
    "\00\01\01\02\02\02\02\03\03\03\03\03\03\04\04\04"
    "\04\04\04\04\04\05\05\05\05\05\05\05\05\05\06\06"
    "\06\06\06\06\06\06\06\06\06\07\07\07\07\07\07\07"
    "\07\07\07\07\07\07\08\08\08\08\08\08\08\08\08\08"
    "\08\08\08\08\08\09\09\09\09\09\09\09\09\09\09\09"
    "\09\09\09\09\09\09\0A\0A\0A\0A\0A\0A\0A\0A\0A\0A"
    "\0A\0A\0A\0A\0A\0A\0A\0A\0A\0B\0B\0B\0B\0B\0B\0B"
    "\0B\0B\0B\0B\0B\0B\0B\0B\0B\0B\0B\0B\0B\0B\0C\0C"
    "\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C\0C"
    "\0C\0C\0C\0C\0C\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D"
    "\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0D\0E\0E"
    "\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E\0E"
    "\0E\0E\0E\0E\0E\0E\0E\0E\0E\0F\0F\0F\0F\0F\0F\0F"
    "\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F\0F"
    "\0F\0F\0F\0F\0F\0F\10\10\10\10\10\10\10\10\10\10"
    "\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10")
  
  ;; 读取配置
  (func $get_version (result i32)
    (i32.load (i32.const 0x1000)))
  
  (func $get_max_users (result i32)
    (i32.load (i32.const 0x1004)))
  
  (func $get_max_connections (result i32)
    (i32.load (i32.const 0x1008)))
  
  (func $get_timeout (result i32)
    (i32.load (i32.const 0x100C)))
  
  ;; 快速平方根查表
  (func $fast_sqrt (param $n i32) (result i32)
    (if (result i32)
      (i32.ge_u (local.get $n) (i32.const 256))
      (then
        ;; 超出查表范围，使用近似计算
        (i32.shr_u (local.get $n) (i32.const 4)))
      (else
        ;; 查表
        (i32.load8_u
          (i32.add (i32.const 0x2000) (local.get $n))))))
  
  ;; 验证配置完整性
  (func $validate_config (result i32)
    (local $version i32)
    (local $max_users i32)
    
    (local.set $version (call $get_version))
    (local.set $max_users (call $get_max_users))
    
    ;; 检查版本和用户数是否合理
    (i32.and
      (i32.and
        (i32.gt_u (local.get $version) (i32.const 0))
        (i32.le_u (local.get $version) (i32.const 10)))
      (i32.and
        (i32.gt_u (local.get $max_users) (i32.const 0))
        (i32.le_u (local.get $max_users) (i32.const 10000)))))
  
  (export "get_version" (func $get_version))
  (export "get_max_users" (func $get_max_users))
  (export "get_max_connections" (func $get_max_connections))
  (export "get_timeout" (func $get_timeout))
  (export "fast_sqrt" (func $fast_sqrt))
  (export "validate_config" (func $validate_config)))
```

**解析**:
- 使用数据段存储结构化配置信息
- 预计算的查找表提供 O(1) 查询性能
- 实现配置验证确保数据有效性
- 查表法比计算更快，适合频繁调用的场景
</details>

### 练习 5.4 内存对齐优化 (★★★★☆ 25分)

**题目**: 实现一个性能优化的结构体操作库。

**要求**:
1. 定义 Person 结构体：id(i32), name(20字节), age(i32), height(f32)
2. 实现对齐优化的存储和读取
3. 实现批量操作函数
4. 对比对齐和非对齐访问的性能

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 1)
  
  ;; Person 结构体布局 (对齐优化):
  ;; [0-3]: id (i32)
  ;; [4-23]: name (20 bytes, 填充到4字节边界)
  ;; [24-27]: age (i32) 
  ;; [28-31]: height (f32)
  ;; 总大小: 32字节 (8字节对齐)
  
  (global $PERSON_SIZE i32 (i32.const 32))
  (global $person_count (mut i32) (i32.const 0))
  (global $persons_base i32 (i32.const 0x2000))
  
  ;; 创建 Person
  (func $create_person (param $id i32) (param $name_ptr i32) (param $age i32) (param $height f32) (result i32)
    (local $person_ptr i32)
    (local $i i32)
    
    ;; 分配空间
    (local.set $person_ptr
      (i32.add
        (global.get $persons_base)
        (i32.mul (global.get $person_count) (global.get $PERSON_SIZE))))
    
    ;; 检查空间
    (if (i32.gt_u (i32.add (local.get $person_ptr) (global.get $PERSON_SIZE)) (i32.const 0x8000))
      (then (return (i32.const 0))))  ;; 空间不足
    
    ;; 存储字段 (对齐访问)
    (i32.store align=4 (local.get $person_ptr) (local.get $id))
    
    ;; 复制名字 (最多20字节)
    (loop $copy_name
      (if (i32.ge_u (local.get $i) (i32.const 20))
        (then (br $copy_name)))
      
      (i32.store8
        (i32.add (i32.add (local.get $person_ptr) (i32.const 4)) (local.get $i))
        (i32.load8_u (i32.add (local.get $name_ptr) (local.get $i))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $copy_name))
    
    (i32.store align=4 (i32.add (local.get $person_ptr) (i32.const 24)) (local.get $age))
    (f32.store align=4 (i32.add (local.get $person_ptr) (i32.const 28)) (local.get $height))
    
    ;; 增加计数
    (global.set $person_count (i32.add (global.get $person_count) (i32.const 1)))
    
    local.get $person_ptr)
  
  ;; 读取 Person 字段
  (func $get_person_id (param $person_ptr i32) (result i32)
    (i32.load align=4 (local.get $person_ptr)))
  
  (func $get_person_age (param $person_ptr i32) (result i32)
    (i32.load align=4 (i32.add (local.get $person_ptr) (i32.const 24))))
  
  (func $get_person_height (param $person_ptr i32) (result f32)
    (f32.load align=4 (i32.add (local.get $person_ptr) (i32.const 28))))
  
  ;; 批量操作：计算平均年龄
  (func $calculate_average_age (result f32)
    (local $total_age i32)
    (local $i i32)
    (local $person_ptr i32)
    
    (if (i32.eqz (global.get $person_count))
      (then (return (f32.const 0))))
    
    (loop $sum_ages
      (if (i32.ge_u (local.get $i) (global.get $person_count))
        (then (br $sum_ages)))
      
      (local.set $person_ptr
        (i32.add
          (global.get $persons_base)
          (i32.mul (local.get $i) (global.get $PERSON_SIZE))))
      
      (local.set $total_age
        (i32.add (local.get $total_age) (call $get_person_age (local.get $person_ptr))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $sum_ages))
    
    (f32.div
      (f32.convert_i32_s (local.get $total_age))
      (f32.convert_i32_s (global.get $person_count))))
  
  ;; 性能测试：对齐 vs 非对齐访问
  (func $benchmark_aligned_access (param $iterations i32) (result i32)
    (local $i i32)
    (local $sum i32)
    (local $person_ptr i32)
    
    (loop $benchmark_loop
      (if (i32.ge_u (local.get $i) (local.get $iterations))
        (then (br $benchmark_loop)))
      
      (local.set $person_ptr (global.get $persons_base))
      
      ;; 对齐访问
      (local.set $sum
        (i32.add (local.get $sum)
          (i32.load align=4 (local.get $person_ptr))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $benchmark_loop))
    
    local.get $sum)
  
  (func $benchmark_unaligned_access (param $iterations i32) (result i32)
    (local $i i32)
    (local $sum i32)
    (local $person_ptr i32)
    
    (loop $benchmark_loop
      (if (i32.ge_u (local.get $i) (local.get $iterations))
        (then (br $benchmark_loop)))
      
      (local.set $person_ptr (i32.add (global.get $persons_base) (i32.const 1)))
      
      ;; 非对齐访问
      (local.set $sum
        (i32.add (local.get $sum)
          (i32.load align=1 (local.get $person_ptr))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $benchmark_loop))
    
    local.get $sum)
  
  (func $get_person_count (result i32)
    (global.get $person_count))
  
  (export "create_person" (func $create_person))
  (export "get_person_id" (func $get_person_id))
  (export "get_person_age" (func $get_person_age))
  (export "get_person_height" (func $get_person_height))
  (export "calculate_average_age" (func $calculate_average_age))
  (export "benchmark_aligned_access" (func $benchmark_aligned_access))
  (export "benchmark_unaligned_access" (func $benchmark_unaligned_access))
  (export "get_person_count" (func $get_person_count)))
```

**解析**:
- 结构体字段按对齐要求排列，提高访问效率
- 使用 `align=4` 显式指定对齐访问
- 批量操作利用顺序内存访问的缓存优势
- 性能测试对比验证对齐访问的优势
</details>

## 挑战练习

### 练习 5.5 内存池分配器 (★★★★★ 30分)

**题目**: 实现一个高效的固定大小内存池分配器。

**要求**:
1. 支持 16, 32, 64 字节三种固定大小的内存池
2. 实现快速分配和释放
3. 支持内存池统计和碎片分析
4. 实现内存池的自动扩展

<details>
<summary>🔍 参考答案</summary>

```wat
(module
  (memory (export "memory") 2)  ;; 128KB，为池扩展预留空间
  
  ;; 内存池配置
  (global $POOL_16_SIZE i32 (i32.const 16))
  (global $POOL_32_SIZE i32 (i32.const 32))
  (global $POOL_64_SIZE i32 (i32.const 64))
  (global $POOL_16_COUNT i32 (i32.const 128))  ;; 每池初始块数
  (global $POOL_32_COUNT i32 (i32.const 64))
  (global $POOL_64_COUNT i32 (i32.const 32))
  
  ;; 池基地址
  (global $pool_16_base i32 (i32.const 0x1000))
  (global $pool_32_base i32 (i32.const 0x3000))  
  (global $pool_64_base i32 (i32.const 0x5000))
  
  ;; 空闲链表头
  (global $pool_16_free_head (mut i32) (i32.const 0))
  (global $pool_32_free_head (mut i32) (i32.const 0))
  (global $pool_64_free_head (mut i32) (i32.const 0))
  
  ;; 统计信息
  (global $pool_16_allocated (mut i32) (i32.const 0))
  (global $pool_32_allocated (mut i32) (i32.const 0))
  (global $pool_64_allocated (mut i32) (i32.const 0))
  (global $pool_16_total (mut i32) (i32.const 0))
  (global $pool_32_total (mut i32) (i32.const 0))
  (global $pool_64_total (mut i32) (i32.const 0))
  
  ;; 初始化内存池
  (func $init_memory_pools
    (call $init_pool_16)
    (call $init_pool_32)
    (call $init_pool_64))
  
  ;; 初始化16字节池
  (func $init_pool_16
    (local $i i32)
    (local $current i32)
    (local $next i32)
    
    (local.set $current (global.get $pool_16_base))
    (global.set $pool_16_total (global.get $POOL_16_COUNT))
    
    (loop $init_16_loop
      (if (i32.ge_u (local.get $i) (i32.sub (global.get $POOL_16_COUNT) (i32.const 1)))
        (then (br $init_16_loop)))
      
      (local.set $next (i32.add (local.get $current) (global.get $POOL_16_SIZE)))
      (i32.store (local.get $current) (local.get $next))
      
      (local.set $current (local.get $next))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $init_16_loop))
    
    ;; 最后一个块指向NULL
    (i32.store (local.get $current) (i32.const 0))
    (global.set $pool_16_free_head (global.get $pool_16_base)))
  
  ;; 初始化32字节池
  (func $init_pool_32
    (local $i i32)
    (local $current i32)
    (local $next i32)
    
    (local.set $current (global.get $pool_32_base))
    (global.set $pool_32_total (global.get $POOL_32_COUNT))
    
    (loop $init_32_loop
      (if (i32.ge_u (local.get $i) (i32.sub (global.get $POOL_32_COUNT) (i32.const 1)))
        (then (br $init_32_loop)))
      
      (local.set $next (i32.add (local.get $current) (global.get $POOL_32_SIZE)))
      (i32.store (local.get $current) (local.get $next))
      
      (local.set $current (local.get $next))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $init_32_loop))
    
    (i32.store (local.get $current) (i32.const 0))
    (global.set $pool_32_free_head (global.get $pool_32_base)))
  
  ;; 初始化64字节池
  (func $init_pool_64
    (local $i i32)
    (local $current i32)
    (local $next i32)
    
    (local.set $current (global.get $pool_64_base))
    (global.set $pool_64_total (global.get $POOL_64_COUNT))
    
    (loop $init_64_loop
      (if (i32.ge_u (local.get $i) (i32.sub (global.get $POOL_64_COUNT) (i32.const 1)))
        (then (br $init_64_loop)))
      
      (local.set $next (i32.add (local.get $current) (global.get $POOL_64_SIZE)))
      (i32.store (local.get $current) (local.get $next))
      
      (local.set $current (local.get $next))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $init_64_loop))
    
    (i32.store (local.get $current) (i32.const 0))
    (global.set $pool_64_free_head (global.get $pool_64_base)))
  
  ;; 通用分配函数
  (func $pool_alloc (param $size i32) (result i32)
    (if (i32.le_u (local.get $size) (global.get $POOL_16_SIZE))
      (then (return (call $alloc_from_pool_16))))
    
    (if (i32.le_u (local.get $size) (global.get $POOL_32_SIZE))
      (then (return (call $alloc_from_pool_32))))
    
    (if (i32.le_u (local.get $size) (global.get $POOL_64_SIZE))
      (then (return (call $alloc_from_pool_64))))
    
    i32.const 0)  ;; 大小超出支持范围
  
  ;; 从16字节池分配
  (func $alloc_from_pool_16 (result i32)
    (local $ptr i32)
    
    (local.set $ptr (global.get $pool_16_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_16_free_head (i32.load (local.get $ptr)))
        (global.set $pool_16_allocated 
          (i32.add (global.get $pool_16_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    ;; 尝试扩展池
    (call $expand_pool_16)
    
    ;; 再次尝试分配
    (local.set $ptr (global.get $pool_16_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_16_free_head (i32.load (local.get $ptr)))
        (global.set $pool_16_allocated 
          (i32.add (global.get $pool_16_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    i32.const 0)  ;; 扩展失败
  
  ;; 从32字节池分配
  (func $alloc_from_pool_32 (result i32)
    (local $ptr i32)
    
    (local.set $ptr (global.get $pool_32_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_32_free_head (i32.load (local.get $ptr)))
        (global.set $pool_32_allocated 
          (i32.add (global.get $pool_32_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    (call $expand_pool_32)
    
    (local.set $ptr (global.get $pool_32_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_32_free_head (i32.load (local.get $ptr)))
        (global.set $pool_32_allocated 
          (i32.add (global.get $pool_32_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    i32.const 0)
  
  ;; 从64字节池分配
  (func $alloc_from_pool_64 (result i32)
    (local $ptr i32)
    
    (local.set $ptr (global.get $pool_64_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_64_free_head (i32.load (local.get $ptr)))
        (global.set $pool_64_allocated 
          (i32.add (global.get $pool_64_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    (call $expand_pool_64)
    
    (local.set $ptr (global.get $pool_64_free_head))
    (if (local.get $ptr)
      (then
        (global.set $pool_64_free_head (i32.load (local.get $ptr)))
        (global.set $pool_64_allocated 
          (i32.add (global.get $pool_64_allocated) (i32.const 1)))
        (return (local.get $ptr))))
    
    i32.const 0)
  
  ;; 扩展16字节池 (简化实现)
  (func $expand_pool_16
    ;; 简化：不实现动态扩展，实际应用中需要内存增长逻辑
    nop)
  
  (func $expand_pool_32
    nop)
  
  (func $expand_pool_64
    nop)
  
  ;; 释放到对应池
  (func $pool_free (param $ptr i32) (param $size i32)
    (if (i32.le_u (local.get $size) (global.get $POOL_16_SIZE))
      (then
        (call $free_to_pool_16 (local.get $ptr))
        (return)))
    
    (if (i32.le_u (local.get $size) (global.get $POOL_32_SIZE))
      (then
        (call $free_to_pool_32 (local.get $ptr))
        (return)))
    
    (if (i32.le_u (local.get $size) (global.get $POOL_64_SIZE))
      (then
        (call $free_to_pool_64 (local.get $ptr)))))
  
  ;; 释放到16字节池
  (func $free_to_pool_16 (param $ptr i32)
    (i32.store (local.get $ptr) (global.get $pool_16_free_head))
    (global.set $pool_16_free_head (local.get $ptr))
    (global.set $pool_16_allocated 
      (i32.sub (global.get $pool_16_allocated) (i32.const 1))))
  
  ;; 释放到32字节池
  (func $free_to_pool_32 (param $ptr i32)
    (i32.store (local.get $ptr) (global.get $pool_32_free_head))
    (global.set $pool_32_free_head (local.get $ptr))
    (global.set $pool_32_allocated 
      (i32.sub (global.get $pool_32_allocated) (i32.const 1))))
  
  ;; 释放到64字节池
  (func $free_to_pool_64 (param $ptr i32)
    (i32.store (local.get $ptr) (global.get $pool_64_free_head))
    (global.set $pool_64_free_head (local.get $ptr))
    (global.set $pool_64_allocated 
      (i32.sub (global.get $pool_64_allocated) (i32.const 1))))
  
  ;; 统计信息
  (func $get_pool_stats (param $pool_size i32) (param $total_ptr i32) (param $allocated_ptr i32) (param $free_ptr i32)
    (if (i32.eq (local.get $pool_size) (global.get $POOL_16_SIZE))
      (then
        (i32.store (local.get $total_ptr) (global.get $pool_16_total))
        (i32.store (local.get $allocated_ptr) (global.get $pool_16_allocated))
        (i32.store (local.get $free_ptr) 
          (i32.sub (global.get $pool_16_total) (global.get $pool_16_allocated)))
        (return)))
    
    (if (i32.eq (local.get $pool_size) (global.get $POOL_32_SIZE))
      (then
        (i32.store (local.get $total_ptr) (global.get $pool_32_total))
        (i32.store (local.get $allocated_ptr) (global.get $pool_32_allocated))
        (i32.store (local.get $free_ptr) 
          (i32.sub (global.get $pool_32_total) (global.get $pool_32_allocated)))
        (return)))
    
    (if (i32.eq (local.get $pool_size) (global.get $POOL_64_SIZE))
      (then
        (i32.store (local.get $total_ptr) (global.get $pool_64_total))
        (i32.store (local.get $allocated_ptr) (global.get $pool_64_allocated))
        (i32.store (local.get $free_ptr) 
          (i32.sub (global.get $pool_64_total) (global.get $pool_64_allocated))))))
  
  ;; 碎片分析：计算使用率
  (func $calculate_utilization (param $pool_size i32) (result f32)
    (local $total i32)
    (local $allocated i32)
    
    (if (i32.eq (local.get $pool_size) (global.get $POOL_16_SIZE))
      (then
        (local.set $total (global.get $pool_16_total))
        (local.set $allocated (global.get $pool_16_allocated))))
    
    (if (i32.eq (local.get $pool_size) (global.get $POOL_32_SIZE))
      (then
        (local.set $total (global.get $pool_32_total))
        (local.set $allocated (global.get $pool_32_allocated))))
    
    (if (i32.eq (local.get $pool_size) (global.get $POOL_64_SIZE))
      (then
        (local.set $total (global.get $pool_64_total))
        (local.set $allocated (global.get $pool_64_allocated))))
    
    (if (i32.eqz (local.get $total))
      (then (return (f32.const 0))))
    
    (f32.div
      (f32.convert_i32_u (local.get $allocated))
      (f32.convert_i32_u (local.get $total))))
  
  (export "init_memory_pools" (func $init_memory_pools))
  (export "pool_alloc" (func $pool_alloc))
  (export "pool_free" (func $pool_free))
  (export "get_pool_stats" (func $get_pool_stats))
  (export "calculate_utilization" (func $calculate_utilization)))
```

**解析**:
- 三个固定大小池提供快速O(1)分配/释放
- 空闲链表维护可用块，分配时直接从头部取用
- 完整的统计系统支持性能监控和调优
- 预留扩展接口支持动态增长（需要配合内存增长实现）
- 利用率计算帮助分析内存使用效率和碎片情况
</details>

## 综合项目

### 练习 5.6 内存管理系统 (★★★★★ 40分)

**题目**: 设计一个完整的内存管理系统，集成多种分配策略。

**要求**:
1. 集成栈、堆、池三种内存管理方式
2. 实现内存使用监控和泄漏检测
3. 支持内存压缩和垃圾回收
4. 提供统一的管理接口

<details>
<summary>🔍 参考答案</summary>

这是一个复杂的综合项目，需要将前面所有技术整合。由于篇幅限制，这里提供核心框架：

```wat
(module
  (memory (export "memory") 4)  ;; 256KB，支持各种管理策略
  
  ;; 内存布局
  ;; 0x0000-0x1000: 系统控制区
  ;; 0x1000-0x2000: 栈区
  ;; 0x2000-0x8000: 堆区  
  ;; 0x8000-0x20000: 池区
  ;; 0x20000-0x40000: 静态数据区
  
  ;; 分配策略枚举
  (global $ALLOC_STACK i32 (i32.const 1))
  (global $ALLOC_HEAP i32 (i32.const 2))
  (global $ALLOC_POOL i32 (i32.const 3))
  
  ;; 统一分配接口
  (func $mem_alloc (param $size i32) (param $strategy i32) (result i32)
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_STACK))
      (then (return (call $stack_alloc (local.get $size)))))
    
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_HEAP))
      (then (return (call $heap_alloc (local.get $size)))))
    
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_POOL))
      (then (return (call $pool_alloc (local.get $size)))))
    
    i32.const 0)
  
  ;; 统一释放接口
  (func $mem_free (param $ptr i32) (param $strategy i32)
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_STACK))
      (then (call $stack_free (local.get $ptr))))
    
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_HEAP))
      (then (call $heap_free (local.get $ptr))))
    
    (if (i32.eq (local.get $strategy) (global.get $ALLOC_POOL))
      (then (call $pool_free_auto (local.get $ptr)))))
  
  ;; 内存监控
  (func $get_memory_usage (param $total_ptr i32) (param $used_ptr i32) (param $free_ptr i32)
    ;; 计算各区域使用情况并汇总
    ;; 实现细节略...)
  
  ;; 泄漏检测
  (func $detect_leaks (result i32)
    ;; 扫描已分配但长时间未使用的内存块
    ;; 实现细节略...)
  
  ;; 内存压缩
  (func $compact_memory
    ;; 整理堆内存，消除碎片
    ;; 实现细节略...)
  
  ;; 垃圾回收
  (func $garbage_collect (result i32)
    ;; 标记-清除式垃圾回收
    ;; 实现细节略...)
  
  ;; 其他必要的辅助函数...
  ;; stack_alloc, heap_alloc, pool_alloc_auto 等
  
  (export "mem_alloc" (func $mem_alloc))
  (export "mem_free" (func $mem_free))
  (export "get_memory_usage" (func $get_memory_usage))
  (export "detect_leaks" (func $detect_leaks))
  (export "compact_memory" (func $compact_memory))
  (export "garbage_collect" (func $garbage_collect)))
```

**实现指导**:
1. **分层设计**: 底层实现各种分配器，上层提供统一接口
2. **元数据管理**: 维护分配记录，支持泄漏检测和统计
3. **性能平衡**: 在分配速度和内存利用率之间找到平衡
4. **错误处理**: 完善的边界检查和错误恢复机制
5. **可扩展性**: 模块化设计，便于添加新的分配策略
</details>

## 总结

通过这些练习，你应该能够：

1. ✅ **掌握基础内存操作**：读写、布局设计、对齐优化
2. ✅ **理解数据段应用**：静态数据、查找表、配置管理
3. ✅ **实现性能优化**：缓存友好访问、批量操作、向量化
4. ✅ **设计内存分配器**：堆分配、内存池、统一管理
5. ✅ **构建完整系统**：集成多种策略、监控和优化

**进阶建议**：
- 研究现代内存分配器算法（如 jemalloc、tcmalloc）
- 学习内存访问模式优化技术
- 掌握 SIMD 指令在 WebAssembly 中的应用
- 了解内存安全和漏洞防护技术

---

📝 **下一步**: [第6章 控制流练习](./chapter6-exercises.md)