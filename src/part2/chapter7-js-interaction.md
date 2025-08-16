# 第7章 JavaScript 交互

WebAssembly 与 JavaScript 的紧密集成是其强大之处。本章将深入探讨两种环境之间的数据传递、函数调用、内存共享等核心技术，以及性能优化的最佳实践。

## WebAssembly JavaScript API

### 7.1.1 模块加载与实例化

WebAssembly 模块的加载和实例化是使用的第一步：

**基础加载模式：**

```javascript
// 方法1：使用 WebAssembly.instantiate（推荐）
async function loadWasm() {
  const wasmModule = await WebAssembly.instantiateStreaming(
    fetch('module.wasm')
  );
  return wasmModule.instance.exports;
}

// 方法2：分步加载
async function loadWasmStep() {
  const wasmBytes = await fetch('module.wasm').then(r => r.arrayBuffer());
  const wasmModule = await WebAssembly.instantiate(wasmBytes);
  return wasmModule.instance.exports;
}

// 方法3：预编译模块（适合重复使用）
async function loadWasmPrecompiled() {
  const wasmBytes = await fetch('module.wasm').then(r => r.arrayBuffer());
  const module = await WebAssembly.compile(wasmBytes);
  const instance = await WebAssembly.instantiate(module);
  return instance.exports;
}
```

**带导入的模块加载：**

```javascript
// JavaScript 函数供 WebAssembly 调用
const importObject = {
  env: {
    // 数学函数
    js_sin: Math.sin,
    js_cos: Math.cos,
    js_log: Math.log,
    
    // 控制台输出
    console_log: (value) => console.log('WASM:', value),
    console_error: (ptr, len) => {
      const memory = wasmInstance.exports.memory;
      const message = new TextDecoder().decode(
        new Uint8Array(memory.buffer, ptr, len)
      );
      console.error('WASM Error:', message);
    },
    
    // 内存分配辅助
    js_malloc: (size) => {
      // 简化的内存分配记录
      console.log(`Allocating ${size} bytes`);
      return 0; // 实际应该返回内存地址
    },
    
    // 时间函数
    current_time_ms: () => Date.now(),
    
    // 随机数生成
    random: () => Math.random()
  },
  
  // 内存导入（如果需要）
  memory: new WebAssembly.Memory({ initial: 256, maximum: 512 })
};

// 对应的 WAT 模块
const watSource = `
(module
  ;; 导入 JavaScript 函数
  (import "env" "js_sin" (func $js_sin (param f64) (result f64)))
  (import "env" "console_log" (func $console_log (param i32)))
  (import "env" "current_time_ms" (func $current_time_ms (result f64)))
  
  ;; 导入内存
  (import "env" "memory" (memory 256 512))
  
  ;; 使用导入函数的 WebAssembly 函数
  (func $math_demo (param $angle f64) (result f64)
    ;; 记录计算开始
    (call $console_log (i32.const 1))
    
    ;; 计算 sin(angle)
    (call $js_sin (local.get $angle)))
  
  (func $benchmark_demo (result f64)
    (local $start_time f64)
    (local $end_time f64)
    (local $i i32)
    (local $sum f64)
    
    ;; 记录开始时间
    (local.set $start_time (call $current_time_ms))
    
    ;; 执行一些计算
    (loop $calc_loop
      (if (i32.ge_s (local.get $i) (i32.const 1000000))
        (then (br $calc_loop)))
      
      (local.set $sum 
        (f64.add 
          (local.get $sum)
          (call $js_sin (f64.convert_i32_s (local.get $i)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $calc_loop))
    
    ;; 记录结束时间
    (local.set $end_time (call $current_time_ms))
    
    ;; 返回耗时
    (f64.sub (local.get $end_time) (local.get $start_time)))
  
  (export "math_demo" (func $math_demo))
  (export "benchmark_demo" (func $benchmark_demo))
  (export "memory" (memory 0)))
`;

// 加载并实例化
async function loadWasmWithImports() {
  const wasmBytes = await WebAssembly.wat2wasm(watSource);
  const wasmModule = await WebAssembly.instantiate(wasmBytes, importObject);
  return wasmModule.instance.exports;
}
```

### 7.1.2 异步加载和错误处理

```javascript
class WasmLoader {
  constructor() {
    this.modules = new Map();
    this.loading = new Map();
  }
  
  // 单例加载，避免重复请求
  async loadModule(name, wasmPath, importObject = {}) {
    // 如果已经加载，直接返回
    if (this.modules.has(name)) {
      return this.modules.get(name);
    }
    
    // 如果正在加载，等待完成
    if (this.loading.has(name)) {
      return await this.loading.get(name);
    }
    
    // 开始加载
    const loadPromise = this._loadModuleInternal(name, wasmPath, importObject);
    this.loading.set(name, loadPromise);
    
    try {
      const exports = await loadPromise;
      this.modules.set(name, exports);
      this.loading.delete(name);
      return exports;
    } catch (error) {
      this.loading.delete(name);
      throw error;
    }
  }
  
  async _loadModuleInternal(name, wasmPath, importObject) {
    try {
      console.log(`Loading WASM module: ${name}`);
      
      // 检查 WebAssembly 支持
      if (!WebAssembly) {
        throw new Error('WebAssembly not supported in this environment');
      }
      
      // 加载并实例化
      const response = await fetch(wasmPath);
      
      if (!response.ok) {
        throw new Error(`Failed to fetch ${wasmPath}: ${response.statusText}`);
      }
      
      const wasmModule = await WebAssembly.instantiateStreaming(response, importObject);
      
      console.log(`Successfully loaded WASM module: ${name}`);
      return wasmModule.instance.exports;
      
    } catch (error) {
      // 如果 instantiateStreaming 失败，尝试传统方法
      if (error.name === 'TypeError' && error.message.includes('streaming')) {
        console.warn('Falling back to non-streaming WASM loading');
        return await this._loadModuleFallback(wasmPath, importObject);
      }
      
      console.error(`Failed to load WASM module ${name}:`, error);
      throw new Error(`WASM loading failed: ${error.message}`);
    }
  }
  
  async _loadModuleFallback(wasmPath, importObject) {
    const response = await fetch(wasmPath);
    const wasmBytes = await response.arrayBuffer();
    const wasmModule = await WebAssembly.instantiate(wasmBytes, importObject);
    return wasmModule.instance.exports;
  }
  
  // 预加载多个模块
  async preloadModules(modules) {
    const loadPromises = modules.map(({ name, path, imports }) => 
      this.loadModule(name, path, imports)
    );
    
    return await Promise.all(loadPromises);
  }
  
  // 获取已加载的模块
  getModule(name) {
    return this.modules.get(name);
  }
  
  // 检查模块是否已加载
  hasModule(name) {
    return this.modules.has(name);
  }
  
  // 卸载模块
  unloadModule(name) {
    this.modules.delete(name);
  }
}

// 使用示例
const wasmLoader = new WasmLoader();

async function initializeApp() {
  try {
    // 定义要加载的模块
    const modules = [
      {
        name: 'math',
        path: './math.wasm',
        imports: {
          env: {
            sin: Math.sin,
            cos: Math.cos,
            sqrt: Math.sqrt
          }
        }
      },
      {
        name: 'image',
        path: './image.wasm',
        imports: {
          env: {
            memory: new WebAssembly.Memory({ initial: 64 })
          }
        }
      }
    ];
    
    // 预加载所有模块
    await wasmLoader.preloadModules(modules);
    
    console.log('All WASM modules loaded successfully');
    
    // 使用模块
    const mathModule = wasmLoader.getModule('math');
    const result = mathModule.calculate(3.14159);
    console.log('Calculation result:', result);
    
  } catch (error) {
    console.error('Failed to initialize app:', error);
    // 实现降级方案
    fallbackToJavaScript();
  }
}

function fallbackToJavaScript() {
  console.log('Using JavaScript fallback implementation');
  // 纯 JavaScript 实现
}
```

## 数据类型转换

### 7.2.1 基本类型传递

WebAssembly 和 JavaScript 之间的数据类型转换：

```javascript
// 对应的 WAT 模块
const basicTypesWat = `
(module
  ;; 基本数据类型函数
  (func $add_i32 (param $a i32) (param $b i32) (result i32)
    (i32.add (local.get $a) (local.get $b)))
  
  (func $add_i64 (param $a i64) (param $b i64) (result i64)
    (i64.add (local.get $a) (local.get $b)))
  
  (func $add_f32 (param $a f32) (param $b f32) (result f32)
    (f32.add (local.get $a) (local.get $b)))
  
  (func $add_f64 (param $a f64) (param $b f64) (result f64)
    (f64.add (local.get $a) (local.get $b)))
  
  ;; 类型转换示例
  (func $int_to_float (param $x i32) (result f32)
    (f32.convert_i32_s (local.get $x)))
  
  (func $float_to_int (param $x f32) (result i32)
    (i32.trunc_f32_s (local.get $x)))
  
  ;; 布尔逻辑（使用 i32）
  (func $logical_and (param $a i32) (param $b i32) (result i32)
    (i32.and (local.get $a) (local.get $b)))
  
  (func $is_even (param $x i32) (result i32)
    (i32.eqz (i32.rem_u (local.get $x) (i32.const 2))))
  
  ;; 多返回值（需要较新的 WebAssembly 版本）
  (func $divmod (param $a i32) (param $b i32) (result i32 i32)
    (i32.div_s (local.get $a) (local.get $b))
    (i32.rem_s (local.get $a) (local.get $b)))
  
  (export "add_i32" (func $add_i32))
  (export "add_i64" (func $add_i64))
  (export "add_f32" (func $add_f32))
  (export "add_f64" (func $add_f64))
  (export "int_to_float" (func $int_to_float))
  (export "float_to_int" (func $float_to_int))
  (export "logical_and" (func $logical_and))
  (export "is_even" (func $is_even))
  (export "divmod" (func $divmod)))
`;

// JavaScript 类型转换辅助工具
class TypeConverter {
  constructor(wasmExports) {
    this.wasm = wasmExports;
  }
  
  // 安全的整数转换
  toWasmI32(jsValue) {
    if (typeof jsValue === 'boolean') {
      return jsValue ? 1 : 0;
    }
    
    const num = Number(jsValue);
    if (!Number.isFinite(num)) {
      throw new Error(`Cannot convert ${jsValue} to i32`);
    }
    
    // 确保在 32 位有符号整数范围内
    return Math.trunc(num) | 0;
  }
  
  // BigInt 到 i64 转换
  toWasmI64(jsValue) {
    if (typeof jsValue === 'bigint') {
      return jsValue;
    }
    
    if (typeof jsValue === 'number') {
      if (!Number.isFinite(jsValue)) {
        throw new Error(`Cannot convert ${jsValue} to i64`);
      }
      return BigInt(Math.trunc(jsValue));
    }
    
    return BigInt(jsValue);
  }
  
  // 浮点数转换
  toWasmF32(jsValue) {
    const num = Number(jsValue);
    if (!Number.isFinite(num) && !Number.isNaN(num)) {
      throw new Error(`Cannot convert ${jsValue} to f32`);
    }
    return Math.fround(num); // 强制转换为 32 位浮点
  }
  
  toWasmF64(jsValue) {
    const num = Number(jsValue);
    if (!Number.isFinite(num) && !Number.isNaN(num)) {
      throw new Error(`Cannot convert ${jsValue} to f64`);
    }
    return num;
  }
  
  // 从 WASM 返回值转换
  fromWasmI32(wasmValue) {
    return wasmValue | 0; // 确保是 32 位整数
  }
  
  fromWasmI64(wasmValue) {
    return BigInt.asIntN(64, wasmValue);
  }
  
  fromWasmF32(wasmValue) {
    return Math.fround(wasmValue);
  }
  
  fromWasmF64(wasmValue) {
    return wasmValue;
  }
  
  // 布尔值转换
  toWasmBool(jsValue) {
    return jsValue ? 1 : 0;
  }
  
  fromWasmBool(wasmValue) {
    return wasmValue !== 0;
  }
}

// 使用示例
async function demonstrateTypeConversion() {
  const wasmModule = await WebAssembly.instantiate(
    await WebAssembly.wat2wasm(basicTypesWat)
  );
  
  const converter = new TypeConverter(wasmModule.instance.exports);
  const { exports } = wasmModule.instance;
  
  // 基本运算
  console.log('32-bit addition:', exports.add_i32(10, 20)); // 30
  console.log('64-bit addition:', exports.add_i64(10n, 20n)); // 30n
  console.log('32-bit float addition:', exports.add_f32(3.14, 2.86)); // 6.0
  console.log('64-bit float addition:', exports.add_f64(3.14159, 2.71828)); // 5.85987
  
  // 类型转换
  console.log('Int to float:', exports.int_to_float(42)); // 42.0
  console.log('Float to int:', exports.float_to_int(3.99)); // 3
  
  // 布尔逻辑
  console.log('Logical AND:', converter.fromWasmBool(exports.logical_and(
    converter.toWasmBool(true),
    converter.toWasmBool(false)
  ))); // false
  
  console.log('Is even:', converter.fromWasmBool(exports.is_even(42))); // true
  
  // 边界情况处理
  try {
    console.log('Large number conversion:', converter.toWasmI32(2**50));
  } catch (error) {
    console.warn('Conversion error:', error.message);
  }
  
  // 多返回值（如果支持）
  if (exports.divmod) {
    const [quotient, remainder] = exports.divmod(17, 5);
    console.log(`17 ÷ 5 = ${quotient} remainder ${remainder}`); // 3 remainder 2
  }
}
```

### 7.2.2 复杂数据结构

```javascript
// 复杂数据结构的 WAT 模块
const structuresWat = `
(module
  (memory (export "memory") 1)
  
  ;; 结构体操作：Point { x: f32, y: f32 }
  (func $create_point (param $x f32) (param $y f32) (param $ptr i32)
    (f32.store (local.get $ptr) (local.get $x))
    (f32.store (i32.add (local.get $ptr) (i32.const 4)) (local.get $y)))
  
  (func $get_point_x (param $ptr i32) (result f32)
    (f32.load (local.get $ptr)))
  
  (func $get_point_y (param $ptr i32) (result f32)
    (f32.load (i32.add (local.get $ptr) (i32.const 4))))
  
  (func $point_distance (param $p1 i32) (param $p2 i32) (result f32)
    (local $dx f32)
    (local $dy f32)
    
    ;; dx = p2.x - p1.x
    (local.set $dx
      (f32.sub
        (f32.load (local.get $p2))
        (f32.load (local.get $p1))))
    
    ;; dy = p2.y - p1.y
    (local.set $dy
      (f32.sub
        (f32.load (i32.add (local.get $p2) (i32.const 4)))
        (f32.load (i32.add (local.get $p1) (i32.const 4)))))
    
    ;; sqrt(dx*dx + dy*dy)
    (f32.sqrt
      (f32.add
        (f32.mul (local.get $dx) (local.get $dx))
        (f32.mul (local.get $dy) (local.get $dy)))))
  
  ;; 数组操作
  (func $sum_array (param $ptr i32) (param $length i32) (result f32)
    (local $sum f32)
    (local $i i32)
    
    (loop $sum_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $sum_loop)))
      
      (local.set $sum
        (f32.add
          (local.get $sum)
          (f32.load
            (i32.add
              (local.get $ptr)
              (i32.mul (local.get $i) (i32.const 4))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $sum_loop))
    
    local.get $sum)
  
  (func $reverse_array (param $ptr i32) (param $length i32)
    (local $i i32)
    (local $j i32)
    (local $temp f32)
    
    (local.set $j (i32.sub (local.get $length) (i32.const 1)))
    
    (loop $reverse_loop
      (if (i32.ge_u (local.get $i) (local.get $j))
        (then (br $reverse_loop)))
      
      ;; 交换 arr[i] 和 arr[j]
      (local.set $temp
        (f32.load
          (i32.add (local.get $ptr) (i32.mul (local.get $i) (i32.const 4)))))
      
      (f32.store
        (i32.add (local.get $ptr) (i32.mul (local.get $i) (i32.const 4)))
        (f32.load
          (i32.add (local.get $ptr) (i32.mul (local.get $j) (i32.const 4)))))
      
      (f32.store
        (i32.add (local.get $ptr) (i32.mul (local.get $j) (i32.const 4)))
        (local.get $temp))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (local.set $j (i32.sub (local.get $j) (i32.const 1)))
      (br $reverse_loop)))
  
  ;; 字符串操作
  (func $string_length (param $ptr i32) (result i32)
    (local $len i32)
    
    (loop $strlen_loop
      (if (i32.eqz (i32.load8_u (i32.add (local.get $ptr) (local.get $len))))
        (then (br $strlen_loop)))
      
      (local.set $len (i32.add (local.get $len) (i32.const 1)))
      (br $strlen_loop))
    
    local.get $len)
  
  (func $string_compare (param $str1 i32) (param $str2 i32) (result i32)
    (local $i i32)
    (local $char1 i32)
    (local $char2 i32)
    
    (loop $strcmp_loop
      (local.set $char1 (i32.load8_u (i32.add (local.get $str1) (local.get $i))))
      (local.set $char2 (i32.load8_u (i32.add (local.get $str2) (local.get $i))))
      
      ;; 如果字符不同，返回差值
      (if (i32.ne (local.get $char1) (local.get $char2))
        (then (return (i32.sub (local.get $char1) (local.get $char2)))))
      
      ;; 如果到达字符串末尾，返回 0
      (if (i32.eqz (local.get $char1))
        (then (return (i32.const 0))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $strcmp_loop))
    
    i32.const 0)
  
  (export "create_point" (func $create_point))
  (export "get_point_x" (func $get_point_x))
  (export "get_point_y" (func $get_point_y))
  (export "point_distance" (func $point_distance))
  (export "sum_array" (func $sum_array))
  (export "reverse_array" (func $reverse_array))
  (export "string_length" (func $string_length))
  (export "string_compare" (func $string_compare)))
`;

// JavaScript 数据结构包装器
class StructureManager {
  constructor(wasmExports, memory) {
    this.wasm = wasmExports;
    this.memory = memory;
    this.heap = new Uint8Array(memory.buffer);
    this.heapF32 = new Float32Array(memory.buffer);
    this.heapI32 = new Int32Array(memory.buffer);
    this.allocatedPointers = new Set();
    this.nextPointer = 1024; // 从 1KB 开始分配
  }
  
  // 简单的内存分配器
  allocate(bytes) {
    const ptr = this.nextPointer;
    this.nextPointer += Math.ceil(bytes / 4) * 4; // 4字节对齐
    this.allocatedPointers.add(ptr);
    
    // 检查内存溢出
    if (this.nextPointer >= this.memory.buffer.byteLength) {
      throw new Error('Out of WebAssembly memory');
    }
    
    return ptr;
  }
  
  // 释放内存
  free(ptr) {
    this.allocatedPointers.delete(ptr);
  }
  
  // Point 结构体包装
  createPoint(x, y) {
    const ptr = this.allocate(8); // 2 个 f32 = 8 字节
    this.wasm.create_point(x, y, ptr);
    return new PointWrapper(this, ptr);
  }
  
  // 数组包装
  createFloatArray(jsArray) {
    const ptr = this.allocate(jsArray.length * 4);
    const wasmArray = new Float32Array(this.memory.buffer, ptr, jsArray.length);
    wasmArray.set(jsArray);
    return new FloatArrayWrapper(this, ptr, jsArray.length);
  }
  
  // 字符串包装
  createString(jsString) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(jsString + '\0'); // 添加 null 终止符
    const ptr = this.allocate(bytes.length);
    const wasmBytes = new Uint8Array(this.memory.buffer, ptr, bytes.length);
    wasmBytes.set(bytes);
    return new StringWrapper(this, ptr);
  }
  
  // 从内存读取字符串
  readString(ptr) {
    const length = this.wasm.string_length(ptr);
    const bytes = new Uint8Array(this.memory.buffer, ptr, length);
    return new TextDecoder().decode(bytes);
  }
  
  // 清理所有分配的内存
  cleanup() {
    this.allocatedPointers.clear();
    this.nextPointer = 1024;
  }
}

// Point 包装器
class PointWrapper {
  constructor(manager, ptr) {
    this.manager = manager;
    this.ptr = ptr;
  }
  
  get x() {
    return this.manager.wasm.get_point_x(this.ptr);
  }
  
  get y() {
    return this.manager.wasm.get_point_y(this.ptr);
  }
  
  distanceTo(other) {
    return this.manager.wasm.point_distance(this.ptr, other.ptr);
  }
  
  toObject() {
    return { x: this.x, y: this.y };
  }
  
  free() {
    this.manager.free(this.ptr);
  }
}

// 浮点数组包装器
class FloatArrayWrapper {
  constructor(manager, ptr, length) {
    this.manager = manager;
    this.ptr = ptr;
    this.length = length;
    this.view = new Float32Array(manager.memory.buffer, ptr, length);
  }
  
  get(index) {
    if (index < 0 || index >= this.length) {
      throw new Error('Array index out of bounds');
    }
    return this.view[index];
  }
  
  set(index, value) {
    if (index < 0 || index >= this.length) {
      throw new Error('Array index out of bounds');
    }
    this.view[index] = value;
  }
  
  sum() {
    return this.manager.wasm.sum_array(this.ptr, this.length);
  }
  
  reverse() {
    this.manager.wasm.reverse_array(this.ptr, this.length);
    return this;
  }
  
  toArray() {
    return Array.from(this.view);
  }
  
  free() {
    this.manager.free(this.ptr);
  }
}

// 字符串包装器
class StringWrapper {
  constructor(manager, ptr) {
    this.manager = manager;
    this.ptr = ptr;
  }
  
  length() {
    return this.manager.wasm.string_length(this.ptr);
  }
  
  compareTo(other) {
    return this.manager.wasm.string_compare(this.ptr, other.ptr);
  }
  
  toString() {
    return this.manager.readString(this.ptr);
  }
  
  free() {
    this.manager.free(this.ptr);
  }
}

// 使用示例
async function demonstrateStructures() {
  const wasmModule = await WebAssembly.instantiate(
    await WebAssembly.wat2wasm(structuresWat)
  );
  
  const manager = new StructureManager(
    wasmModule.instance.exports,
    wasmModule.instance.exports.memory
  );
  
  try {
    // Point 结构体
    const point1 = manager.createPoint(3.0, 4.0);
    const point2 = manager.createPoint(0.0, 0.0);
    
    console.log('Point 1:', point1.toObject()); // { x: 3, y: 4 }
    console.log('Point 2:', point2.toObject()); // { x: 0, y: 0 }
    console.log('Distance:', point1.distanceTo(point2)); // 5.0
    
    // 数组操作
    const array = manager.createFloatArray([1.5, 2.5, 3.5, 4.5, 5.5]);
    console.log('Original array:', array.toArray()); // [1.5, 2.5, 3.5, 4.5, 5.5]
    console.log('Sum:', array.sum()); // 17.5
    
    array.reverse();
    console.log('Reversed array:', array.toArray()); // [5.5, 4.5, 3.5, 2.5, 1.5]
    
    // 字符串操作
    const str1 = manager.createString('Hello');
    const str2 = manager.createString('World');
    const str3 = manager.createString('Hello');
    
    console.log('String 1 length:', str1.length()); // 5
    console.log('String 1 content:', str1.toString()); // "Hello"
    console.log('Compare Hello vs World:', str1.compareTo(str2)); // < 0
    console.log('Compare Hello vs Hello:', str1.compareTo(str3)); // 0
    
    // 清理内存
    point1.free();
    point2.free();
    array.free();
    str1.free();
    str2.free();
    str3.free();
    
  } finally {
    manager.cleanup();
  }
}
```

## 内存共享

### 7.3.1 共享内存操作

```javascript
// 高级内存管理的 WAT 模块
const memoryManagementWat = `
(module
  (memory (export "memory") 16 256)  ;; 1MB 初始，16MB 最大
  
  ;; 全局内存状态
  (global $heap_base (mut i32) (i32.const 65536))  ;; 64KB 后开始堆
  (global $heap_top (mut i32) (i32.const 65536))
  (global $memory_size (mut i32) (i32.const 16))   ;; 当前页数
  
  ;; 内存统计
  (func $get_heap_base (result i32)
    (global.get $heap_base))
  
  (func $get_heap_top (result i32)
    (global.get $heap_top))
  
  (func $get_heap_size (result i32)
    (i32.sub (global.get $heap_top) (global.get $heap_base)))
  
  (func $get_memory_pages (result i32)
    (memory.size))
  
  ;; 简单的 bump 分配器
  (func $malloc (param $size i32) (result i32)
    (local $ptr i32)
    (local $new_top i32)
    
    ;; 对齐到 8 字节边界
    (local.set $size
      (i32.and
        (i32.add (local.get $size) (i32.const 7))
        (i32.const 0xFFFFFFF8)))
    
    ;; 获取当前指针
    (local.set $ptr (global.get $heap_top))
    (local.set $new_top (i32.add (local.get $ptr) (local.get $size)))
    
    ;; 检查是否需要增长内存
    (if (i32.gt_u (local.get $new_top) (i32.mul (memory.size) (i32.const 65536)))
      (then
        ;; 计算需要的页数
        (local.set $size 
          (i32.div_u
            (i32.add (local.get $new_top) (i32.const 65535))
            (i32.const 65536)))
        
        ;; 尝试增长内存
        (if (i32.eq (memory.grow (i32.sub (local.get $size) (memory.size))) (i32.const -1))
          (then (return (i32.const 0))))))  ;; 分配失败
    
    ;; 更新堆顶
    (global.set $heap_top (local.get $new_top))
    
    local.get $ptr)
  
  ;; 批量数据操作
  (func $memcpy (param $dest i32) (param $src i32) (param $size i32)
    (memory.copy (local.get $dest) (local.get $src) (local.get $size)))
  
  (func $memset (param $dest i32) (param $value i32) (param $size i32)
    (memory.fill (local.get $dest) (local.get $value) (local.get $size)))
  
  (func $memcmp (param $ptr1 i32) (param $ptr2 i32) (param $size i32) (result i32)
    (local $i i32)
    (local $byte1 i32)
    (local $byte2 i32)
    
    (loop $cmp_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $cmp_loop)))
      
      (local.set $byte1 (i32.load8_u (i32.add (local.get $ptr1) (local.get $i))))
      (local.set $byte2 (i32.load8_u (i32.add (local.get $ptr2) (local.get $i))))
      
      (if (i32.ne (local.get $byte1) (local.get $byte2))
        (then (return (i32.sub (local.get $byte1) (local.get $byte2)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $cmp_loop))
    
    i32.const 0)
  
  ;; 内存模式填充
  (func $pattern_fill (param $dest i32) (param $pattern i32) (param $pattern_size i32) (param $total_size i32)
    (local $written i32)
    (local $copy_size i32)
    
    (loop $pattern_loop
      (if (i32.ge_u (local.get $written) (local.get $total_size))
        (then (br $pattern_loop)))
      
      ;; 计算这次要复制的大小
      (local.set $copy_size 
        (select
          (local.get $pattern_size)
          (i32.sub (local.get $total_size) (local.get $written))
          (i32.le_u
            (i32.add (local.get $written) (local.get $pattern_size))
            (local.get $total_size))))
      
      ;; 复制模式
      (memory.copy
        (i32.add (local.get $dest) (local.get $written))
        (local.get $pattern)
        (local.get $copy_size))
      
      (local.set $written (i32.add (local.get $written) (local.get $copy_size)))
      (br $pattern_loop)))
  
  ;; 内存检查和验证
  (func $memory_checksum (param $ptr i32) (param $size i32) (result i32)
    (local $checksum i32)
    (local $i i32)
    
    (loop $checksum_loop
      (if (i32.ge_u (local.get $i) (local.get $size))
        (then (br $checksum_loop)))
      
      (local.set $checksum
        (i32.add
          (local.get $checksum)
          (i32.load8_u (i32.add (local.get $ptr) (local.get $i)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $checksum_loop))
    
    local.get $checksum)
  
  (export "malloc" (func $malloc))
  (export "get_heap_base" (func $get_heap_base))
  (export "get_heap_top" (func $get_heap_top))
  (export "get_heap_size" (func $get_heap_size))
  (export "get_memory_pages" (func $get_memory_pages))
  (export "memcpy" (func $memcpy))
  (export "memset" (func $memset))
  (export "memcmp" (func $memcmp))
  (export "pattern_fill" (func $pattern_fill))
  (export "memory_checksum" (func $memory_checksum)))
`;

// 高级内存管理器
class AdvancedMemoryManager {
  constructor(wasmExports, memory) {
    this.wasm = wasmExports;
    this.memory = memory;
    this.memoryViews = new Map();
    this.allocations = new Map();
    this.nextId = 1;
    
    // 创建不同类型的视图
    this.updateMemoryViews();
  }
  
  updateMemoryViews() {
    const buffer = this.memory.buffer;
    this.memoryViews.set('uint8', new Uint8Array(buffer));
    this.memoryViews.set('uint16', new Uint16Array(buffer));
    this.memoryViews.set('uint32', new Uint32Array(buffer));
    this.memoryViews.set('int8', new Int8Array(buffer));
    this.memoryViews.set('int16', new Int16Array(buffer));
    this.memoryViews.set('int32', new Int32Array(buffer));
    this.memoryViews.set('float32', new Float32Array(buffer));
    this.memoryViews.set('float64', new Float64Array(buffer));
  }
  
  // 检查内存是否发生了增长
  checkMemoryGrowth() {
    const currentPages = this.wasm.get_memory_pages();
    const currentSize = currentPages * 65536;
    
    if (currentSize !== this.memory.buffer.byteLength) {
      console.log(`Memory grew from ${this.memory.buffer.byteLength} to ${currentSize} bytes`);
      this.updateMemoryViews();
    }
  }
  
  // 分配内存并跟踪
  allocate(size, description = '') {
    this.checkMemoryGrowth();
    
    const ptr = this.wasm.malloc(size);
    if (ptr === 0) {
      throw new Error(`Failed to allocate ${size} bytes`);
    }
    
    const id = this.nextId++;
    this.allocations.set(id, {
      ptr,
      size,
      description,
      timestamp: Date.now()
    });
    
    return { id, ptr, size };
  }
  
  // 获取内存视图
  getView(type, ptr, length) {
    this.checkMemoryGrowth();
    
    const view = this.memoryViews.get(type);
    if (!view) {
      throw new Error(`Unknown view type: ${type}`);
    }
    
    const elementSize = view.BYTES_PER_ELEMENT;
    const start = Math.floor(ptr / elementSize);
    
    return view.subarray(start, start + length);
  }
  
  // 写入 JavaScript 数组到 WebAssembly 内存
  writeArray(jsArray, type = 'uint8') {
    const allocation = this.allocate(jsArray.length * this.getTypeSize(type));
    const view = this.getView(type, allocation.ptr, jsArray.length);
    view.set(jsArray);
    return allocation;
  }
  
  // 从 WebAssembly 内存读取到 JavaScript 数组
  readArray(ptr, length, type = 'uint8') {
    const view = this.getView(type, ptr, length);
    return Array.from(view);
  }
  
  // 获取类型大小
  getTypeSize(type) {
    const sizes = {
      'uint8': 1, 'int8': 1,
      'uint16': 2, 'int16': 2,
      'uint32': 4, 'int32': 4,
      'float32': 4, 'float64': 8
    };
    return sizes[type] || 1;
  }
  
  // 内存操作包装
  copy(destPtr, srcPtr, size) {
    this.wasm.memcpy(destPtr, srcPtr, size);
  }
  
  fill(ptr, value, size) {
    this.wasm.memset(ptr, value, size);
  }
  
  compare(ptr1, ptr2, size) {
    return this.wasm.memcmp(ptr1, ptr2, size);
  }
  
  // 模式填充
  fillPattern(destPtr, pattern, totalSize) {
    // 先分配模式数据
    const patternAlloc = this.writeArray(pattern);
    this.wasm.pattern_fill(destPtr, patternAlloc.ptr, pattern.length, totalSize);
    return patternAlloc;
  }
  
  // 计算校验和
  checksum(ptr, size) {
    return this.wasm.memory_checksum(ptr, size);
  }
  
  // 内存状态信息
  getMemoryStatus() {
    this.checkMemoryGrowth();
    
    return {
      heapBase: this.wasm.get_heap_base(),
      heapTop: this.wasm.get_heap_top(),
      heapSize: this.wasm.get_heap_size(),
      memoryPages: this.wasm.get_memory_pages(),
      totalMemory: this.memory.buffer.byteLength,
      allocations: this.allocations.size,
      allocatedBytes: Array.from(this.allocations.values())
        .reduce((sum, alloc) => sum + alloc.size, 0)
    };
  }
  
  // 分配统计
  getAllocationStats() {
    const stats = {
      total: this.allocations.size,
      totalBytes: 0,
      byDescription: new Map()
    };
    
    for (const alloc of this.allocations.values()) {
      stats.totalBytes += alloc.size;
      
      const desc = alloc.description || 'unknown';
      if (!stats.byDescription.has(desc)) {
        stats.byDescription.set(desc, { count: 0, bytes: 0 });
      }
      
      const descStats = stats.byDescription.get(desc);
      descStats.count++;
      descStats.bytes += alloc.size;
    }
    
    return stats;
  }
  
  // 内存泄漏检测
  detectLeaks(maxAge = 60000) { // 1分钟
    const now = Date.now();
    const leaks = [];
    
    for (const [id, alloc] of this.allocations) {
      if (now - alloc.timestamp > maxAge) {
        leaks.push({ id, ...alloc, age: now - alloc.timestamp });
      }
    }
    
    return leaks;
  }
  
  // 内存碎片分析
  analyzeFragmentation() {
    // 简化的碎片分析
    const status = this.getMemoryStatus();
    const usedRatio = status.heapSize / status.totalMemory;
    const allocationCount = this.allocations.size;
    
    return {
      usedRatio,
      allocationCount,
      averageAllocationSize: allocationCount > 0 ? status.heapSize / allocationCount : 0,
      fragmentation: allocationCount > 10 ? 'high' : allocationCount > 5 ? 'medium' : 'low'
    };
  }
}

// 使用示例
async function demonstrateAdvancedMemory() {
  const wasmModule = await WebAssembly.instantiate(
    await WebAssembly.wat2wasm(memoryManagementWat)
  );
  
  const memManager = new AdvancedMemoryManager(
    wasmModule.instance.exports,
    wasmModule.instance.exports.memory
  );
  
  console.log('Initial memory status:', memManager.getMemoryStatus());
  
  // 分配一些数据
  const dataAlloc = memManager.writeArray([1, 2, 3, 4, 5], 'uint32');
  console.log('Allocated array:', dataAlloc);
  
  // 读取数据
  const readData = memManager.readArray(dataAlloc.ptr, 5, 'uint32');
  console.log('Read back:', readData); // [1, 2, 3, 4, 5]
  
  // 复制数据
  const copyAlloc = memManager.allocate(20, 'copy of array');
  memManager.copy(copyAlloc.ptr, dataAlloc.ptr, 20);
  
  const copiedData = memManager.readArray(copyAlloc.ptr, 5, 'uint32');
  console.log('Copied data:', copiedData); // [1, 2, 3, 4, 5]
  
  // 填充模式
  const patternAlloc = memManager.allocate(40, 'pattern filled');
  memManager.fillPattern(patternAlloc.ptr, [0xAA, 0xBB], 40);
  
  const patternData = memManager.readArray(patternAlloc.ptr, 40, 'uint8');
  console.log('Pattern data:', patternData); // [0xAA, 0xBB, 0xAA, 0xBB, ...]
  
  // 计算校验和
  const checksum1 = memManager.checksum(dataAlloc.ptr, 20);
  const checksum2 = memManager.checksum(copyAlloc.ptr, 20);
  console.log('Checksums match:', checksum1 === checksum2); // true
  
  // 内存状态
  console.log('Final memory status:', memManager.getMemoryStatus());
  console.log('Allocation stats:', memManager.getAllocationStats());
  console.log('Fragmentation analysis:', memManager.analyzeFragmentation());
  
  // 泄漏检测（这里应该没有泄漏）
  setTimeout(() => {
    const leaks = memManager.detectLeaks(1000); // 1秒
    console.log('Memory leaks detected:', leaks);
  }, 2000);
}
```

### 7.3.2 高性能数据传输

```javascript
// 高性能数据传输示例
class HighPerformanceTransfer {
  constructor(wasmExports, memory) {
    this.wasm = wasmExports;
    this.memory = memory;
    this.transferBuffers = new Map();
    this.compressionEnabled = false;
  }
  
  // 创建传输缓冲区
  createTransferBuffer(name, size) {
    const buffer = {
      ptr: this.wasm.malloc(size),
      size: size,
      view: new Uint8Array(this.memory.buffer, this.wasm.malloc(size), size),
      position: 0
    };
    
    if (buffer.ptr === 0) {
      throw new Error(`Failed to allocate transfer buffer: ${size} bytes`);
    }
    
    this.transferBuffers.set(name, buffer);
    return buffer;
  }
  
  // 批量传输数据
  transferBatch(bufferName, dataChunks) {
    const buffer = this.transferBuffers.get(bufferName);
    if (!buffer) {
      throw new Error(`Transfer buffer not found: ${bufferName}`);
    }
    
    const results = [];
    let totalBytes = 0;
    const startTime = performance.now();
    
    for (const chunk of dataChunks) {
      if (buffer.position + chunk.byteLength > buffer.size) {
        // 缓冲区满了，处理当前内容
        results.push(this.processBuffer(bufferName));
        buffer.position = 0;
      }
      
      // 复制数据到缓冲区
      buffer.view.set(new Uint8Array(chunk), buffer.position);
      buffer.position += chunk.byteLength;
      totalBytes += chunk.byteLength;
    }
    
    // 处理剩余数据
    if (buffer.position > 0) {
      results.push(this.processBuffer(bufferName));
    }
    
    const endTime = performance.now();
    
    return {
      results,
      totalBytes,
      transferTime: endTime - startTime,
      throughput: totalBytes / (endTime - startTime) * 1000 // bytes/second
    };
  }
  
  // 处理缓冲区数据
  processBuffer(bufferName) {
    const buffer = this.transferBuffers.get(bufferName);
    const checksum = this.wasm.memory_checksum(buffer.ptr, buffer.position);
    
    // 重置缓冲区位置
    const processedBytes = buffer.position;
    buffer.position = 0;
    
    return {
      bytes: processedBytes,
      checksum: checksum
    };
  }
  
  // 零拷贝数据访问
  getZeroCopyView(type, ptr, length) {
    const TypedArray = {
      'uint8': Uint8Array,
      'uint16': Uint16Array,
      'uint32': Uint32Array,
      'int8': Int8Array,
      'int16': Int16Array,
      'int32': Int32Array,
      'float32': Float32Array,
      'float64': Float64Array
    }[type];
    
    if (!TypedArray) {
      throw new Error(`Unsupported type: ${type}`);
    }
    
    return new TypedArray(this.memory.buffer, ptr, length);
  }
  
  // 流式数据处理
  async processStream(dataSource, chunkSize = 8192) {
    const buffer = this.createTransferBuffer('stream', chunkSize * 2);
    const results = [];
    
    try {
      const reader = dataSource.getReader();
      let totalProcessed = 0;
      
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        // 确保缓冲区足够大
        if (value.length > buffer.size) {
          throw new Error('Chunk size exceeds buffer capacity');
        }
        
        // 如果缓冲区空间不足，先处理现有数据
        if (buffer.position + value.length > buffer.size) {
          results.push(this.processBuffer('stream'));
        }
        
        // 复制新数据
        buffer.view.set(value, buffer.position);
        buffer.position += value.length;
        totalProcessed += value.length;
        
        // 可选：定期处理缓冲区以避免内存压力
        if (buffer.position >= chunkSize) {
          results.push(this.processBuffer('stream'));
        }
      }
      
      // 处理剩余数据
      if (buffer.position > 0) {
        results.push(this.processBuffer('stream'));
      }
      
      return {
        success: true,
        totalProcessed,
        results
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message,
        results
      };
    }
  }
  
  // 并行数据处理
  async processParallel(dataArrays, workerCount = 4) {
    const chunkSize = Math.ceil(dataArrays.length / workerCount);
    const promises = [];
    
    for (let i = 0; i < workerCount; i++) {
      const start = i * chunkSize;
      const end = Math.min(start + chunkSize, dataArrays.length);
      const chunk = dataArrays.slice(start, end);
      
      if (chunk.length > 0) {
        promises.push(this.processChunk(chunk, i));
      }
    }
    
    const results = await Promise.all(promises);
    
    return {
      workerResults: results,
      totalResults: results.reduce((sum, r) => sum + r.processedCount, 0),
      totalTime: Math.max(...results.map(r => r.processingTime))
    };
  }
  
  // 处理数据块
  async processChunk(dataChunk, workerId) {
    const bufferName = `worker_${workerId}`;
    
    // 为这个工作器创建专用缓冲区
    if (!this.transferBuffers.has(bufferName)) {
      this.createTransferBuffer(bufferName, 64 * 1024); // 64KB
    }
    
    const startTime = performance.now();
    const result = this.transferBatch(bufferName, dataChunk);
    const endTime = performance.now();
    
    return {
      workerId,
      processedCount: dataChunk.length,
      processingTime: endTime - startTime,
      throughput: result.throughput,
      results: result.results
    };
  }
  
  // 内存映射文件访问（模拟）
  mapFile(fileBuffer, readonly = true) {
    const size = fileBuffer.byteLength;
    const ptr = this.wasm.malloc(size);
    
    if (ptr === 0) {
      throw new Error(`Failed to map file: ${size} bytes`);
    }
    
    // 复制文件数据到 WebAssembly 内存
    const wasmView = new Uint8Array(this.memory.buffer, ptr, size);
    wasmView.set(new Uint8Array(fileBuffer));
    
    return {
      ptr,
      size,
      view: readonly ? wasmView : new Uint8Array(this.memory.buffer, ptr, size),
      readonly,
      
      // 同步更改回原文件缓冲区（如果可写）
      sync: () => {
        if (!readonly && fileBuffer instanceof ArrayBuffer) {
          new Uint8Array(fileBuffer).set(wasmView);
        }
      },
      
      // 取消映射
      unmap: () => {
        // 在实际实现中这里应该调用 free
        // this.wasm.free(ptr);
      }
    };
  }
  
  // 性能基准测试
  benchmark() {
    const testSizes = [1024, 8192, 65536, 524288]; // 1KB to 512KB
    const results = [];
    
    for (const size of testSizes) {
      const testData = new Uint8Array(size);
      
      // 填充测试数据
      for (let i = 0; i < size; i++) {
        testData[i] = i % 256;
      }
      
      // 测试传输性能
      const startTime = performance.now();
      const allocation = {
        ptr: this.wasm.malloc(size),
        size: size
      };
      
      const view = new Uint8Array(this.memory.buffer, allocation.ptr, size);
      view.set(testData);
      
      const checksum = this.wasm.memory_checksum(allocation.ptr, size);
      const endTime = performance.now();
      
      results.push({
        size,
        transferTime: endTime - startTime,
        throughput: size / (endTime - startTime) * 1000,
        checksum
      });
    }
    
    return results;
  }
}

// 使用示例
async function demonstrateHighPerformanceTransfer() {
  // 假设已经加载了 WASM 模块
  const wasmModule = await WebAssembly.instantiate(
    await WebAssembly.wat2wasm(memoryManagementWat)
  );
  
  const transfer = new HighPerformanceTransfer(
    wasmModule.instance.exports,
    wasmModule.instance.exports.memory
  );
  
  // 创建测试数据
  const testData = Array.from({ length: 10 }, (_, i) => {
    const chunk = new Uint8Array(1024);
    chunk.fill(i);
    return chunk.buffer;
  });
  
  console.log('=== 批量传输测试 ===');
  transfer.createTransferBuffer('test', 4096);
  const batchResult = transfer.transferBatch('test', testData);
  console.log('Batch transfer result:', batchResult);
  
  console.log('=== 并行处理测试 ===');
  const parallelResult = await transfer.processParallel(testData, 3);
  console.log('Parallel processing result:', parallelResult);
  
  console.log('=== 性能基准测试 ===');
  const benchmarkResults = transfer.benchmark();
  console.log('Benchmark results:', benchmarkResults);
  
  // 性能分析
  console.log('=== 性能分析 ===');
  benchmarkResults.forEach(result => {
    console.log(`Size: ${result.size} bytes`);
    console.log(`Transfer time: ${result.transferTime.toFixed(2)} ms`);
    console.log(`Throughput: ${(result.throughput / 1024 / 1024).toFixed(2)} MB/s`);
    console.log(`Checksum: ${result.checksum}`);
    console.log('---');
  });
}
```

## 本章小结

通过本章学习，你已经全面掌握了：

1. **WebAssembly JavaScript API**：模块加载、实例化和错误处理
2. **数据类型转换**：基本类型和复杂结构的双向转换
3. **内存共享**：高效的内存管理和数据传输技术
4. **性能优化**：零拷贝访问、批量处理和并行计算

这些技能为构建高性能的 WebAssembly 应用程序提供了强大的基础。

---

**📝 进入下一步**：[第8章 从 C/C++ 编译](../part3/chapter8-c-cpp.md)

**🎯 重点技能**：
- ✅ JavaScript API 熟练运用
- ✅ 数据转换机制
- ✅ 内存管理策略
- ✅ 高性能数据传输
- ✅ 跨语言集成技巧