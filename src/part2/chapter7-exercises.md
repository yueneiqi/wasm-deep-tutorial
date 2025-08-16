# 第7章 JavaScript 交互 - 练习题

> **本章学习目标**：掌握 WebAssembly 与 JavaScript 的深度集成，包括模块加载、数据传递、内存共享和性能优化技术。

---

## 基础练习

### 练习 7.1：模块加载器实现（20分）

**题目**：实现一个支持缓存和错误恢复的 WebAssembly 模块加载器。

要求：
1. 支持流式加载和传统加载两种方式
2. 实现模块缓存避免重复加载
3. 提供详细的错误信息和降级处理
4. 支持预加载多个模块

<details>
<summary>🔍 参考答案</summary>

```javascript
class EnhancedWasmLoader {
  constructor() {
    this.moduleCache = new Map();
    this.loadingPromises = new Map();
    this.loadAttempts = new Map();
    this.maxRetries = 3;
  }
  
  async loadModule(name, wasmPath, importObject = {}, options = {}) {
    // 检查缓存
    if (this.moduleCache.has(name)) {
      return this.moduleCache.get(name);
    }
    
    // 检查是否正在加载
    if (this.loadingPromises.has(name)) {
      return await this.loadingPromises.get(name);
    }
    
    const loadPromise = this._loadWithRetry(name, wasmPath, importObject, options);
    this.loadingPromises.set(name, loadPromise);
    
    try {
      const result = await loadPromise;
      this.moduleCache.set(name, result);
      this.loadingPromises.delete(name);
      return result;
    } catch (error) {
      this.loadingPromises.delete(name);
      throw error;
    }
  }
  
  async _loadWithRetry(name, wasmPath, importObject, options) {
    let lastError;
    const attempts = this.loadAttempts.get(name) || 0;
    
    for (let i = attempts; i < this.maxRetries; i++) {
      try {
        this.loadAttempts.set(name, i + 1);
        return await this._loadModuleInternal(name, wasmPath, importObject, options);
      } catch (error) {
        lastError = error;
        console.warn(`Loading attempt ${i + 1} failed for ${name}:`, error.message);
        
        if (i < this.maxRetries - 1) {
          await this._delay(Math.pow(2, i) * 1000); // 指数退避
        }
      }
    }
    
    throw new Error(`Failed to load ${name} after ${this.maxRetries} attempts: ${lastError.message}`);
  }
  
  async _loadModuleInternal(name, wasmPath, importObject, options) {
    console.log(`Loading WASM module: ${name}`);
    
    // 检查 WebAssembly 支持
    if (!WebAssembly || !WebAssembly.instantiateStreaming) {
      throw new Error('WebAssembly not supported');
    }
    
    try {
      // 尝试流式加载
      const response = await fetch(wasmPath, {
        method: 'GET',
        headers: options.headers || {},
        signal: options.signal
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const wasmModule = await WebAssembly.instantiateStreaming(response, importObject);
      console.log(`Successfully loaded ${name} via streaming`);
      return wasmModule.instance.exports;
      
    } catch (streamError) {
      console.warn(`Streaming failed for ${name}, falling back to traditional loading`);
      
      // 降级到传统加载
      const response = await fetch(wasmPath);
      const wasmBytes = await response.arrayBuffer();
      const wasmModule = await WebAssembly.instantiate(wasmBytes, importObject);
      
      console.log(`Successfully loaded ${name} via traditional method`);
      return wasmModule.instance.exports;
    }
  }
  
  async preloadModules(modules, concurrency = 3) {
    const chunks = this._chunkArray(modules, concurrency);
    const results = [];
    
    for (const chunk of chunks) {
      const chunkPromises = chunk.map(({ name, path, imports, options }) => 
        this.loadModule(name, path, imports, options)
          .then(exports => ({ name, success: true, exports }))
          .catch(error => ({ name, success: false, error: error.message }))
      );
      
      const chunkResults = await Promise.all(chunkPromises);
      results.push(...chunkResults);
    }
    
    return results;
  }
  
  _chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
  
  _delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  getLoadingStats() {
    return {
      cached: this.moduleCache.size,
      loading: this.loadingPromises.size,
      attempts: Object.fromEntries(this.loadAttempts)
    };
  }
  
  clearCache() {
    this.moduleCache.clear();
    this.loadAttempts.clear();
  }
}

// 使用示例
const loader = new EnhancedWasmLoader();

async function testLoader() {
  const modules = [
    { name: 'math', path: './math.wasm', imports: { env: { sin: Math.sin } } },
    { name: 'image', path: './image.wasm', imports: {} },
    { name: 'crypto', path: './crypto.wasm', imports: {} }
  ];
  
  console.log('Preloading modules...');
  const results = await loader.preloadModules(modules);
  
  results.forEach(result => {
    if (result.success) {
      console.log(`✅ ${result.name} loaded successfully`);
    } else {
      console.log(`❌ ${result.name} failed: ${result.error}`);
    }
  });
  
  console.log('Loading stats:', loader.getLoadingStats());
}
```

**关键要点**：
- 实现了智能重试机制和指数退避
- 支持并发控制的预加载
- 提供了详细的加载统计信息
- 实现了流式加载的降级处理

</details>

---

### 练习 7.2：类型安全的数据转换器（25分）

**题目**：创建一个类型安全的数据转换器，支持 JavaScript 和 WebAssembly 之间的复杂数据类型转换。

要求：
1. 支持所有基本类型的安全转换
2. 实现结构体和数组的序列化/反序列化
3. 提供类型验证和错误处理
4. 支持自定义类型定义

<details>
<summary>🔍 参考答案</summary>

```javascript
// 类型定义系统
class TypeDefinition {
  constructor(name, schema) {
    this.name = name;
    this.schema = schema;
    this.size = this._calculateSize(schema);
  }
  
  _calculateSize(schema) {
    if (typeof schema === 'string') {
      return this._getPrimitiveSize(schema);
    }
    
    if (schema.type === 'array') {
      return schema.length * this._calculateSize(schema.element);
    }
    
    if (schema.type === 'struct') {
      return schema.fields.reduce((sum, field) => {
        return sum + this._calculateSize(field.type);
      }, 0);
    }
    
    throw new Error(`Unknown schema type: ${JSON.stringify(schema)}`);
  }
  
  _getPrimitiveSize(type) {
    const sizes = {
      'i8': 1, 'u8': 1,
      'i16': 2, 'u16': 2,
      'i32': 4, 'u32': 4,
      'i64': 8, 'u64': 8,
      'f32': 4, 'f64': 8,
      'ptr': 4
    };
    
    if (!(type in sizes)) {
      throw new Error(`Unknown primitive type: ${type}`);
    }
    
    return sizes[type];
  }
}

// 类型安全转换器
class TypeSafeConverter {
  constructor(memory) {
    this.memory = memory;
    this.types = new Map();
    this.allocatedPointers = new Set();
    this.nextPtr = 1024; // 从 1KB 开始分配
    
    // 注册内置类型
    this._registerBuiltinTypes();
  }
  
  _registerBuiltinTypes() {
    // Point 类型
    this.registerType('Point', {
      type: 'struct',
      fields: [
        { name: 'x', type: 'f32' },
        { name: 'y', type: 'f32' }
      ]
    });
    
    // RGB 颜色类型
    this.registerType('RGB', {
      type: 'struct',
      fields: [
        { name: 'r', type: 'u8' },
        { name: 'g', type: 'u8' },
        { name: 'b', type: 'u8' },
        { name: 'a', type: 'u8' }
      ]
    });
    
    // 动态数组类型
    this.registerType('FloatArray', {
      type: 'struct',
      fields: [
        { name: 'ptr', type: 'ptr' },
        { name: 'length', type: 'u32' },
        { name: 'capacity', type: 'u32' }
      ]
    });
  }
  
  registerType(name, schema) {
    this.types.set(name, new TypeDefinition(name, schema));
  }
  
  getType(name) {
    const type = this.types.get(name);
    if (!type) {
      throw new Error(`Type not registered: ${name}`);
    }
    return type;
  }
  
  // 分配内存
  allocate(size) {
    const ptr = this.nextPtr;
    this.nextPtr += Math.ceil(size / 4) * 4; // 4字节对齐
    this.allocatedPointers.add(ptr);
    
    if (this.nextPtr >= this.memory.buffer.byteLength) {
      throw new Error('Out of memory');
    }
    
    return ptr;
  }
  
  // 基本类型转换
  convertToWasm(value, type) {
    switch (type) {
      case 'i8': return this._toInt8(value);
      case 'u8': return this._toUint8(value);
      case 'i16': return this._toInt16(value);
      case 'u16': return this._toUint16(value);
      case 'i32': return this._toInt32(value);
      case 'u32': return this._toUint32(value);
      case 'i64': return this._toInt64(value);
      case 'u64': return this._toUint64(value);
      case 'f32': return this._toFloat32(value);
      case 'f64': return this._toFloat64(value);
      default:
        if (this.types.has(type)) {
          return this.serializeStruct(value, type);
        }
        throw new Error(`Unsupported type: ${type}`);
    }
  }
  
  convertFromWasm(ptr, type) {
    switch (type) {
      case 'i8': return this._getInt8(ptr);
      case 'u8': return this._getUint8(ptr);
      case 'i16': return this._getInt16(ptr);
      case 'u16': return this._getUint16(ptr);
      case 'i32': return this._getInt32(ptr);
      case 'u32': return this._getUint32(ptr);
      case 'i64': return this._getInt64(ptr);
      case 'u64': return this._getUint64(ptr);
      case 'f32': return this._getFloat32(ptr);
      case 'f64': return this._getFloat64(ptr);
      default:
        if (this.types.has(type)) {
          return this.deserializeStruct(ptr, type);
        }
        throw new Error(`Unsupported type: ${type}`);
    }
  }
  
  // 结构体序列化
  serializeStruct(jsObject, typeName) {
    const typeDef = this.getType(typeName);
    const ptr = this.allocate(typeDef.size);
    let offset = 0;
    
    for (const field of typeDef.schema.fields) {
      if (!(field.name in jsObject)) {
        throw new Error(`Missing field: ${field.name} in ${typeName}`);
      }
      
      const value = jsObject[field.name];
      const fieldPtr = ptr + offset;
      
      this._writeValue(fieldPtr, value, field.type);
      offset += this._getPrimitiveSize(field.type);
    }
    
    return ptr;
  }
  
  // 结构体反序列化
  deserializeStruct(ptr, typeName) {
    const typeDef = this.getType(typeName);
    const result = {};
    let offset = 0;
    
    for (const field of typeDef.schema.fields) {
      const fieldPtr = ptr + offset;
      result[field.name] = this._readValue(fieldPtr, field.type);
      offset += this._getPrimitiveSize(field.type);
    }
    
    return result;
  }
  
  // 数组操作
  serializeArray(jsArray, elementType) {
    const elementSize = this._getPrimitiveSize(elementType);
    const totalSize = jsArray.length * elementSize;
    const ptr = this.allocate(totalSize);
    
    for (let i = 0; i < jsArray.length; i++) {
      const elementPtr = ptr + i * elementSize;
      this._writeValue(elementPtr, jsArray[i], elementType);
    }
    
    // 创建数组描述符
    const descriptorPtr = this.allocate(12); // ptr + length + capacity
    this._writeValue(descriptorPtr, ptr, 'ptr');
    this._writeValue(descriptorPtr + 4, jsArray.length, 'u32');
    this._writeValue(descriptorPtr + 8, jsArray.length, 'u32');
    
    return descriptorPtr;
  }
  
  deserializeArray(descriptorPtr, elementType) {
    const ptr = this._readValue(descriptorPtr, 'ptr');
    const length = this._readValue(descriptorPtr + 4, 'u32');
    const elementSize = this._getPrimitiveSize(elementType);
    
    const result = [];
    for (let i = 0; i < length; i++) {
      const elementPtr = ptr + i * elementSize;
      result.push(this._readValue(elementPtr, elementType));
    }
    
    return result;
  }
  
  // 类型验证
  validateType(value, type) {
    if (typeof type === 'string') {
      return this._validatePrimitive(value, type);
    }
    
    if (type.type === 'struct') {
      if (typeof value !== 'object' || value === null) {
        return false;
      }
      
      return type.fields.every(field => 
        field.name in value && this.validateType(value[field.name], field.type)
      );
    }
    
    if (type.type === 'array') {
      if (!Array.isArray(value)) {
        return false;
      }
      
      return value.every(item => this.validateType(item, type.element));
    }
    
    return false;
  }
  
  _validatePrimitive(value, type) {
    switch (type) {
      case 'i8': return Number.isInteger(value) && value >= -128 && value <= 127;
      case 'u8': return Number.isInteger(value) && value >= 0 && value <= 255;
      case 'i16': return Number.isInteger(value) && value >= -32768 && value <= 32767;
      case 'u16': return Number.isInteger(value) && value >= 0 && value <= 65535;
      case 'i32': return Number.isInteger(value) && value >= -2147483648 && value <= 2147483647;
      case 'u32': return Number.isInteger(value) && value >= 0 && value <= 4294967295;
      case 'i64': return typeof value === 'bigint';
      case 'u64': return typeof value === 'bigint' && value >= 0n;
      case 'f32': 
      case 'f64': return typeof value === 'number' && Number.isFinite(value);
      case 'ptr': return Number.isInteger(value) && value >= 0;
      default: return false;
    }
  }
  
  // 内部辅助方法
  _writeValue(ptr, value, type) {
    const view = new DataView(this.memory.buffer);
    
    switch (type) {
      case 'i8': view.setInt8(ptr, value); break;
      case 'u8': view.setUint8(ptr, value); break;
      case 'i16': view.setInt16(ptr, value, true); break;
      case 'u16': view.setUint16(ptr, value, true); break;
      case 'i32': view.setInt32(ptr, value, true); break;
      case 'u32': view.setUint32(ptr, value, true); break;
      case 'i64': view.setBigInt64(ptr, BigInt(value), true); break;
      case 'u64': view.setBigUint64(ptr, BigInt(value), true); break;
      case 'f32': view.setFloat32(ptr, value, true); break;
      case 'f64': view.setFloat64(ptr, value, true); break;
      case 'ptr': view.setUint32(ptr, value, true); break;
      default: throw new Error(`Cannot write type: ${type}`);
    }
  }
  
  _readValue(ptr, type) {
    const view = new DataView(this.memory.buffer);
    
    switch (type) {
      case 'i8': return view.getInt8(ptr);
      case 'u8': return view.getUint8(ptr);
      case 'i16': return view.getInt16(ptr, true);
      case 'u16': return view.getUint16(ptr, true);
      case 'i32': return view.getInt32(ptr, true);
      case 'u32': return view.getUint32(ptr, true);
      case 'i64': return view.getBigInt64(ptr, true);
      case 'u64': return view.getBigUint64(ptr, true);
      case 'f32': return view.getFloat32(ptr, true);
      case 'f64': return view.getFloat64(ptr, true);
      case 'ptr': return view.getUint32(ptr, true);
      default: throw new Error(`Cannot read type: ${type}`);
    }
  }
  
  _getPrimitiveSize(type) {
    const sizes = {
      'i8': 1, 'u8': 1, 'i16': 2, 'u16': 2,
      'i32': 4, 'u32': 4, 'i64': 8, 'u64': 8,
      'f32': 4, 'f64': 8, 'ptr': 4
    };
    return sizes[type] || 4;
  }
  
  // 内存管理
  free(ptr) {
    this.allocatedPointers.delete(ptr);
  }
  
  cleanup() {
    this.allocatedPointers.clear();
    this.nextPtr = 1024;
  }
  
  getMemoryUsage() {
    return {
      allocated: this.allocatedPointers.size,
      nextPtr: this.nextPtr,
      totalUsed: this.nextPtr - 1024
    };
  }
}

// 使用示例
async function testTypeConverter() {
  const memory = new WebAssembly.Memory({ initial: 1 });
  const converter = new TypeSafeConverter(memory);
  
  // 自定义类型注册
  converter.registerType('Person', {
    type: 'struct',
    fields: [
      { name: 'age', type: 'u8' },
      { name: 'height', type: 'f32' },
      { name: 'weight', type: 'f32' }
    ]
  });
  
  try {
    // 测试基本类型
    console.log('=== 基本类型测试 ===');
    const intPtr = converter.convertToWasm(42, 'i32');
    const intValue = converter.convertFromWasm(intPtr, 'i32');
    console.log('Integer conversion:', 42, '->', intValue);
    
    // 测试结构体
    console.log('=== 结构体测试 ===');
    const person = { age: 25, height: 175.5, weight: 70.2 };
    
    if (converter.validateType(person, converter.getType('Person').schema)) {
      const personPtr = converter.serializeStruct(person, 'Person');
      const deserializedPerson = converter.deserializeStruct(personPtr, 'Person');
      console.log('Person:', person, '->', deserializedPerson);
    } else {
      console.log('Person validation failed');
    }
    
    // 测试数组
    console.log('=== 数组测试 ===');
    const numbers = [1.1, 2.2, 3.3, 4.4, 5.5];
    const arrayPtr = converter.serializeArray(numbers, 'f32');
    const deserializedArray = converter.deserializeArray(arrayPtr, 'f32');
    console.log('Array:', numbers, '->', deserializedArray);
    
    // 内存使用情况
    console.log('=== 内存使用情况 ===');
    console.log('Memory usage:', converter.getMemoryUsage());
    
  } catch (error) {
    console.error('Conversion error:', error.message);
  } finally {
    converter.cleanup();
  }
}
```

**关键特性**：
- 支持自定义结构体和数组类型
- 提供完整的类型验证机制
- 实现内存对齐和高效的序列化
- 提供详细的错误信息和内存管理

</details>

---

## 进阶练习

### 练习 7.3：高性能内存池管理器（30分）

**题目**：设计并实现一个高性能的内存池管理器，用于优化 WebAssembly 内存分配。

要求：
1. 实现多种大小的内存池
2. 支持内存碎片整理
3. 提供内存使用统计和监控
4. 实现内存泄漏检测

<details>
<summary>🔍 参考答案</summary>

```javascript
// 内存块类
class MemoryBlock {
  constructor(ptr, size, pool) {
    this.ptr = ptr;
    this.size = size;
    this.pool = pool;
    this.allocated = false;
    this.allocatedAt = null;
    this.allocatedBy = null;
    this.next = null;
    this.prev = null;
  }
  
  allocate(allocatedBy = 'unknown') {
    this.allocated = true;
    this.allocatedAt = Date.now();
    this.allocatedBy = allocatedBy;
  }
  
  free() {
    this.allocated = false;
    this.allocatedAt = null;
    this.allocatedBy = null;
  }
  
  getAge() {
    return this.allocatedAt ? Date.now() - this.allocatedAt : 0;
  }
}

// 内存池类
class MemoryPool {
  constructor(blockSize, initialBlocks = 16) {
    this.blockSize = blockSize;
    this.blocks = [];
    this.freeBlocks = [];
    this.allocatedBlocks = new Set();
    this.totalAllocated = 0;
    this.peakAllocated = 0;
    this.allocationCount = 0;
    this.freeCount = 0;
    
    // 预分配初始块
    for (let i = 0; i < initialBlocks; i++) {
      this._createBlock();
    }
  }
  
  _createBlock() {
    // 这里应该从实际的 WebAssembly 内存分配
    // 为了演示，我们使用模拟指针
    const ptr = Math.floor(Math.random() * 1000000);
    const block = new MemoryBlock(ptr, this.blockSize, this);
    this.blocks.push(block);
    this.freeBlocks.push(block);
    return block;
  }
  
  allocate(allocatedBy = 'unknown') {
    if (this.freeBlocks.length === 0) {
      // 需要扩展池
      this._expandPool();
    }
    
    const block = this.freeBlocks.pop();
    block.allocate(allocatedBy);
    this.allocatedBlocks.add(block);
    
    this.totalAllocated += this.blockSize;
    this.peakAllocated = Math.max(this.peakAllocated, this.totalAllocated);
    this.allocationCount++;
    
    return block;
  }
  
  free(block) {
    if (!this.allocatedBlocks.has(block)) {
      throw new Error('Attempting to free unallocated block');
    }
    
    block.free();
    this.allocatedBlocks.delete(block);
    this.freeBlocks.push(block);
    
    this.totalAllocated -= this.blockSize;
    this.freeCount++;
  }
  
  _expandPool() {
    const expandSize = Math.max(8, Math.floor(this.blocks.length * 0.5));
    for (let i = 0; i < expandSize; i++) {
      this._createBlock();
    }
  }
  
  getStats() {
    return {
      blockSize: this.blockSize,
      totalBlocks: this.blocks.length,
      allocatedBlocks: this.allocatedBlocks.size,
      freeBlocks: this.freeBlocks.length,
      totalAllocated: this.totalAllocated,
      peakAllocated: this.peakAllocated,
      allocationCount: this.allocationCount,
      freeCount: this.freeCount,
      utilizationRate: this.totalAllocated / (this.blocks.length * this.blockSize)
    };
  }
  
  findLeaks(maxAge = 60000) {
    const leaks = [];
    for (const block of this.allocatedBlocks) {
      if (block.getAge() > maxAge) {
        leaks.push({
          ptr: block.ptr,
          size: block.size,
          age: block.getAge(),
          allocatedBy: block.allocatedBy,
          allocatedAt: new Date(block.allocatedAt)
        });
      }
    }
    return leaks;
  }
}

// 高性能内存池管理器
class HighPerformanceMemoryManager {
  constructor(wasmMemory, options = {}) {
    this.wasmMemory = wasmMemory;
    this.options = {
      poolSizes: [16, 32, 64, 128, 256, 512, 1024, 2048, 4096],
      initialBlocksPerPool: 16,
      enableLeakDetection: true,
      leakCheckInterval: 30000,
      maxLeakAge: 60000,
      enableFragmentationCheck: true,
      fragmentationThreshold: 0.3,
      ...options
    };
    
    // 创建内存池
    this.pools = new Map();
    this.largeAllocations = new Map();
    this.stats = {
      totalAllocations: 0,
      totalFrees: 0,
      largeAllocations: 0,
      fragmentationEvents: 0,
      leakDetectionRuns: 0,
      memoryGrowths: 0
    };
    
    this._initializePools();
    this._startMonitoring();
  }
  
  _initializePools() {
    for (const size of this.options.poolSizes) {
      this.pools.set(size, new MemoryPool(size, this.options.initialBlocksPerPool));
    }
  }
  
  allocate(size, allocatedBy = 'unknown') {
    this.stats.totalAllocations++;
    
    // 查找合适的池
    const poolSize = this._findBestPoolSize(size);
    
    if (poolSize) {
      const pool = this.pools.get(poolSize);
      const block = pool.allocate(allocatedBy);
      return {
        ptr: block.ptr,
        size: poolSize,
        actualSize: size,
        pooled: true,
        block: block
      };
    } else {
      // 大内存分配，直接从系统分配
      this.stats.largeAllocations++;
      return this._allocateLarge(size, allocatedBy);
    }
  }
  
  free(allocation) {
    this.stats.totalFrees++;
    
    if (allocation.pooled) {
      const pool = this.pools.get(allocation.size);
      pool.free(allocation.block);
    } else {
      this._freeLarge(allocation);
    }
  }
  
  _findBestPoolSize(size) {
    for (const poolSize of this.options.poolSizes) {
      if (size <= poolSize) {
        return poolSize;
      }
    }
    return null; // 需要大内存分配
  }
  
  _allocateLarge(size, allocatedBy) {
    // 模拟大内存分配
    const ptr = Math.floor(Math.random() * 1000000);
    const allocation = {
      ptr: ptr,
      size: size,
      actualSize: size,
      pooled: false,
      allocatedAt: Date.now(),
      allocatedBy: allocatedBy
    };
    
    this.largeAllocations.set(ptr, allocation);
    return allocation;
  }
  
  _freeLarge(allocation) {
    this.largeAllocations.delete(allocation.ptr);
  }
  
  // 内存碎片整理
  defragment() {
    console.log('Starting memory defragmentation...');
    let moved = 0;
    
    for (const [size, pool] of this.pools) {
      // 简化的碎片整理：重新组织空闲块
      const freeBlocks = [...pool.freeBlocks];
      const allocatedBlocks = [...pool.allocatedBlocks];
      
      // 按地址排序
      freeBlocks.sort((a, b) => a.ptr - b.ptr);
      allocatedBlocks.sort((a, b) => a.ptr - b.ptr);
      
      // 检查碎片化程度
      const fragmentationLevel = this._calculateFragmentation(pool);
      if (fragmentationLevel > this.options.fragmentationThreshold) {
        moved += this._compactPool(pool);
        this.stats.fragmentationEvents++;
      }
    }
    
    console.log(`Defragmentation completed. Moved ${moved} blocks.`);
    return moved;
  }
  
  _calculateFragmentation(pool) {
    if (pool.freeBlocks.length === 0) return 0;
    
    // 简化的碎片化计算
    const totalFree = pool.freeBlocks.length * pool.blockSize;
    const largestFreeBlock = pool.blockSize; // 假设所有块大小相同
    
    return 1 - (largestFreeBlock / totalFree);
  }
  
  _compactPool(pool) {
    // 简化的池压缩
    let moved = 0;
    
    // 重新排列空闲块
    pool.freeBlocks.sort((a, b) => a.ptr - b.ptr);
    
    // 在实际实现中，这里会移动内存中的数据
    // 这里我们只是模拟移动计数
    moved = Math.floor(pool.allocatedBlocks.size * 0.1);
    
    return moved;
  }
  
  // 内存泄漏检测
  detectLeaks() {
    this.stats.leakDetectionRuns++;
    const leaks = [];
    
    // 检查池中的泄漏
    for (const [size, pool] of this.pools) {
      const poolLeaks = pool.findLeaks(this.options.maxLeakAge);
      leaks.push(...poolLeaks.map(leak => ({ ...leak, pool: size })));
    }
    
    // 检查大内存分配的泄漏
    for (const [ptr, allocation] of this.largeAllocations) {
      const age = Date.now() - allocation.allocatedAt;
      if (age > this.options.maxLeakAge) {
        leaks.push({
          ptr: allocation.ptr,
          size: allocation.size,
          age: age,
          allocatedBy: allocation.allocatedBy,
          allocatedAt: new Date(allocation.allocatedAt),
          pool: 'large'
        });
      }
    }
    
    if (leaks.length > 0) {
      console.warn(`Detected ${leaks.length} potential memory leaks:`);
      leaks.forEach(leak => {
        console.warn(`  Leak: ${leak.size} bytes, age: ${leak.age}ms, by: ${leak.allocatedBy}`);
      });
    }
    
    return leaks;
  }
  
  // 获取详细统计信息
  getDetailedStats() {
    const poolStats = {};
    let totalPoolMemory = 0;
    let totalAllocatedMemory = 0;
    
    for (const [size, pool] of this.pools) {
      const stats = pool.getStats();
      poolStats[size] = stats;
      totalPoolMemory += stats.totalBlocks * stats.blockSize;
      totalAllocatedMemory += stats.totalAllocated;
    }
    
    const largeMemory = Array.from(this.largeAllocations.values())
      .reduce((sum, alloc) => sum + alloc.size, 0);
    
    return {
      pools: poolStats,
      largeAllocations: {
        count: this.largeAllocations.size,
        totalMemory: largeMemory
      },
      totals: {
        poolMemory: totalPoolMemory,
        allocatedMemory: totalAllocatedMemory + largeMemory,
        utilizationRate: (totalAllocatedMemory + largeMemory) / totalPoolMemory
      },
      statistics: this.stats
    };
  }
  
  // 内存使用建议
  getOptimizationSuggestions() {
    const suggestions = [];
    const stats = this.getDetailedStats();
    
    // 检查池利用率
    for (const [size, poolStats] of Object.entries(stats.pools)) {
      if (poolStats.utilizationRate < 0.2) {
        suggestions.push({
          type: 'underutilized_pool',
          message: `Pool ${size} is underutilized (${(poolStats.utilizationRate * 100).toFixed(1)}%)`,
          suggestion: 'Consider reducing initial block count or removing this pool size'
        });
      } else if (poolStats.utilizationRate > 0.9) {
        suggestions.push({
          type: 'pool_pressure',
          message: `Pool ${size} is under pressure (${(poolStats.utilizationRate * 100).toFixed(1)}%)`,
          suggestion: 'Consider increasing initial block count or pool expansion rate'
        });
      }
    }
    
    // 检查大内存分配
    if (stats.largeAllocations.count > stats.statistics.totalAllocations * 0.1) {
      suggestions.push({
        type: 'too_many_large_allocations',
        message: `${stats.largeAllocations.count} large allocations (${(stats.largeAllocations.count / stats.statistics.totalAllocations * 100).toFixed(1)}%)`,
        suggestion: 'Consider adding larger pool sizes'
      });
    }
    
    // 检查碎片化
    if (stats.statistics.fragmentationEvents > 10) {
      suggestions.push({
        type: 'high_fragmentation',
        message: `High fragmentation events: ${stats.statistics.fragmentationEvents}`,
        suggestion: 'Consider more frequent defragmentation or different allocation strategy'
      });
    }
    
    return suggestions;
  }
  
  _startMonitoring() {
    if (this.options.enableLeakDetection) {
      this.leakDetectionTimer = setInterval(() => {
        this.detectLeaks();
      }, this.options.leakCheckInterval);
    }
    
    if (this.options.enableFragmentationCheck) {
      this.fragmentationTimer = setInterval(() => {
        this.defragment();
      }, this.options.leakCheckInterval * 2);
    }
  }
  
  shutdown() {
    if (this.leakDetectionTimer) {
      clearInterval(this.leakDetectionTimer);
    }
    if (this.fragmentationTimer) {
      clearInterval(this.fragmentationTimer);
    }
    
    // 最终泄漏检测
    const leaks = this.detectLeaks();
    if (leaks.length > 0) {
      console.warn(`Shutdown with ${leaks.length} memory leaks`);
    }
  }
}

// 使用示例
function testMemoryManager() {
  const memory = new WebAssembly.Memory({ initial: 16 });
  const memManager = new HighPerformanceMemoryManager(memory, {
    enableLeakDetection: true,
    leakCheckInterval: 5000,
    maxLeakAge: 10000
  });
  
  console.log('=== 内存管理器测试 ===');
  
  // 模拟内存分配
  const allocations = [];
  
  // 分配各种大小的内存
  for (let i = 0; i < 100; i++) {
    const size = Math.floor(Math.random() * 1000) + 16;
    const allocation = memManager.allocate(size, `test_${i}`);
    allocations.push(allocation);
  }
  
  console.log('Initial stats:', memManager.getDetailedStats());
  
  // 释放一些内存
  for (let i = 0; i < 50; i++) {
    const allocation = allocations.pop();
    memManager.free(allocation);
  }
  
  console.log('After freeing 50 allocations:', memManager.getDetailedStats());
  
  // 强制内存整理
  memManager.defragment();
  
  // 检测泄漏
  const leaks = memManager.detectLeaks();
  console.log('Detected leaks:', leaks.length);
  
  // 获取优化建议
  const suggestions = memManager.getOptimizationSuggestions();
  console.log('Optimization suggestions:', suggestions);
  
  // 清理
  setTimeout(() => {
    memManager.shutdown();
  }, 15000);
}
```

**高级特性**：
- 多级内存池减少内存碎片
- 自动内存泄漏检测和报告
- 内存使用统计和性能监控
- 智能优化建议系统
- 支持内存碎片整理和压缩

</details>

---

### 练习 7.4：WebAssembly-JavaScript 性能基准测试套件（25分）

**题目**：创建一个全面的性能基准测试套件，用于评估不同数据传输和调用模式的性能。

要求：
1. 测试各种数据类型的传输性能
2. 比较不同调用模式的开销
3. 提供详细的性能分析报告
4. 支持性能回归检测

<details>
<summary>🔍 参考答案</summary>

```javascript
// 性能测试用的 WAT 模块
const benchmarkWat = `
(module
  (memory (export "memory") 16)
  
  ;; 简单函数调用测试
  (func $add (param $a i32) (param $b i32) (result i32)
    (i32.add (local.get $a) (local.get $b)))
  
  (func $multiply (param $a f64) (param $b f64) (result f64)
    (f64.mul (local.get $a) (local.get $b)))
  
  ;; 内存操作测试
  (func $memory_sum (param $ptr i32) (param $length i32) (result f64)
    (local $sum f64)
    (local $i i32)
    
    (loop $sum_loop
      (if (i32.ge_u (local.get $i) (local.get $length))
        (then (br $sum_loop)))
      
      (local.set $sum
        (f64.add
          (local.get $sum)
          (f64.load (i32.add (local.get $ptr) (i32.mul (local.get $i) (i32.const 8))))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $sum_loop))
    
    local.get $sum)
  
  ;; 复杂计算测试
  (func $fibonacci (param $n i32) (result i32)
    (local $a i32)
    (local $b i32)
    (local $temp i32)
    (local $i i32)
    
    (if (i32.le_s (local.get $n) (i32.const 1))
      (then (return (local.get $n))))
    
    (local.set $a (i32.const 0))
    (local.set $b (i32.const 1))
    (local.set $i (i32.const 2))
    
    (loop $fib_loop
      (if (i32.gt_s (local.get $i) (local.get $n))
        (then (br $fib_loop)))
      
      (local.set $temp (i32.add (local.get $a) (local.get $b)))
      (local.set $a (local.get $b))
      (local.set $b (local.get $temp))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $fib_loop))
    
    local.get $b)
  
  ;; 大量参数测试
  (func $many_params 
    (param $p1 i32) (param $p2 i32) (param $p3 i32) (param $p4 i32)
    (param $p5 f32) (param $p6 f32) (param $p7 f32) (param $p8 f32)
    (param $p9 f64) (param $p10 f64)
    (result f64)
    
    (f64.add
      (f64.add
        (f64.add
          (f64.convert_i32_s (i32.add (local.get $p1) (local.get $p2)))
          (f64.convert_i32_s (i32.add (local.get $p3) (local.get $p4))))
        (f64.add
          (f64.promote_f32 (f32.add (local.get $p5) (local.get $p6)))
          (f64.promote_f32 (f32.add (local.get $p7) (local.get $p8)))))
      (f64.add (local.get $p9) (local.get $p10))))
  
  (export "add" (func $add))
  (export "multiply" (func $multiply))
  (export "memory_sum" (func $memory_sum))
  (export "fibonacci" (func $fibonacci))
  (export "many_params" (func $many_params)))
`;

// 性能基准测试类
class PerformanceBenchmark {
  constructor(wasmExports, memory) {
    this.wasm = wasmExports;
    this.memory = memory;
    this.results = new Map();
    this.baselineResults = null;
  }
  
  // 运行单个基准测试
  async runBenchmark(name, testFunction, iterations = 10000, warmupIterations = 1000) {
    console.log(`Running benchmark: ${name}`);
    
    // 预热
    for (let i = 0; i < warmupIterations; i++) {
      testFunction();
    }
    
    // 强制垃圾回收（如果可用）
    if (window.gc) {
      window.gc();
    }
    
    const measurements = [];
    
    for (let run = 0; run < 10; run++) {
      const startTime = performance.now();
      
      for (let i = 0; i < iterations; i++) {
        testFunction();
      }
      
      const endTime = performance.now();
      const totalTime = endTime - startTime;
      measurements.push(totalTime);
    }
    
    const stats = this._calculateStats(measurements, iterations);
    this.results.set(name, stats);
    
    console.log(`${name}: ${stats.avgTimePerOp.toFixed(3)} μs/op`);
    return stats;
  }
  
  // 计算统计信息
  _calculateStats(measurements, iterations) {
    measurements.sort((a, b) => a - b);
    
    const min = Math.min(...measurements);
    const max = Math.max(...measurements);
    const avg = measurements.reduce((sum, val) => sum + val, 0) / measurements.length;
    const median = measurements[Math.floor(measurements.length / 2)];
    
    const variance = measurements.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / measurements.length;
    const stdDev = Math.sqrt(variance);
    
    return {
      iterations,
      runs: measurements.length,
      totalTimeMin: min,
      totalTimeMax: max,
      totalTimeAvg: avg,
      totalTimeMedian: median,
      totalTimeStdDev: stdDev,
      avgTimePerOp: (avg * 1000) / iterations, // 微秒
      medianTimePerOp: (median * 1000) / iterations,
      opsPerSecond: (iterations * 1000) / avg,
      measurements
    };
  }
  
  // 函数调用性能测试
  async benchmarkFunctionCalls() {
    console.log('=== Function Call Benchmarks ===');
    
    // 简单函数调用
    await this.runBenchmark('simple_add', () => {
      this.wasm.add(42, 58);
    });
    
    // 浮点运算
    await this.runBenchmark('float_multiply', () => {
      this.wasm.multiply(3.14159, 2.71828);
    });
    
    // 复杂计算
    await this.runBenchmark('fibonacci_20', () => {
      this.wasm.fibonacci(20);
    });
    
    // 多参数函数
    await this.runBenchmark('many_params', () => {
      this.wasm.many_params(1, 2, 3, 4, 1.1, 2.2, 3.3, 4.4, 5.5, 6.6);
    });
  }
  
  // 数据传输性能测试
  async benchmarkDataTransfer() {
    console.log('=== Data Transfer Benchmarks ===');
    
    const sizes = [100, 1000, 10000, 100000];
    
    for (const size of sizes) {
      // 创建测试数据
      const testData = new Float64Array(size);
      for (let i = 0; i < size; i++) {
        testData[i] = Math.random() * 1000;
      }
      
      // 分配 WebAssembly 内存
      const wasmArray = new Float64Array(this.memory.buffer, 1024, size);
      
      // 测试 JavaScript 到 WebAssembly 传输
      await this.runBenchmark(`js_to_wasm_${size}`, () => {
        wasmArray.set(testData);
      }, 1000);
      
      // 测试 WebAssembly 到 JavaScript 传输
      await this.runBenchmark(`wasm_to_js_${size}`, () => {
        const result = Array.from(wasmArray);
      }, 1000);
      
      // 测试 WebAssembly 内存操作
      await this.runBenchmark(`wasm_memory_sum_${size}`, () => {
        this.wasm.memory_sum(1024, size);
      }, 1000);
      
      // 对比 JavaScript 内存操作
      await this.runBenchmark(`js_array_sum_${size}`, () => {
        let sum = 0;
        for (let i = 0; i < testData.length; i++) {
          sum += testData[i];
        }
      }, 1000);
    }
  }
  
  // 不同调用模式的性能测试
  async benchmarkCallPatterns() {
    console.log('=== Call Pattern Benchmarks ===');
    
    // 直接调用
    await this.runBenchmark('direct_calls', () => {
      for (let i = 0; i < 100; i++) {
        this.wasm.add(i, i + 1);
      }
    }, 100);
    
    // 批量调用
    await this.runBenchmark('batched_calls', () => {
      const operations = [];
      for (let i = 0; i < 100; i++) {
        operations.push([i, i + 1]);
      }
      
      for (const [a, b] of operations) {
        this.wasm.add(a, b);
      }
    }, 100);
    
    // 函数引用缓存
    const addFunction = this.wasm.add;
    await this.runBenchmark('cached_function_ref', () => {
      for (let i = 0; i < 100; i++) {
        addFunction(i, i + 1);
      }
    }, 100);
  }
  
  // 内存访问模式测试
  async benchmarkMemoryPatterns() {
    console.log('=== Memory Access Pattern Benchmarks ===');
    
    const size = 10000;
    const data = new Float64Array(this.memory.buffer, 1024, size);
    
    // 填充测试数据
    for (let i = 0; i < size; i++) {
      data[i] = i;
    }
    
    // 顺序访问
    await this.runBenchmark('sequential_read', () => {
      let sum = 0;
      for (let i = 0; i < size; i++) {
        sum += data[i];
      }
    }, 100);
    
    // 随机访问
    const randomIndices = Array.from({ length: size }, () => Math.floor(Math.random() * size));
    await this.runBenchmark('random_read', () => {
      let sum = 0;
      for (let i = 0; i < size; i++) {
        sum += data[randomIndices[i]];
      }
    }, 100);
    
    // 步进访问
    await this.runBenchmark('strided_read', () => {
      let sum = 0;
      for (let i = 0; i < size; i += 10) {
        sum += data[i];
      }
    }, 100);
  }
  
  // 生成性能报告
  generateReport() {
    const report = {
      timestamp: new Date().toISOString(),
      environment: this._getEnvironmentInfo(),
      results: Object.fromEntries(this.results),
      summary: this._generateSummary(),
      recommendations: this._generateRecommendations()
    };
    
    return report;
  }
  
  _getEnvironmentInfo() {
    return {
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      concurrency: navigator.hardwareConcurrency,
      memory: performance.memory ? {
        usedJSHeapSize: performance.memory.usedJSHeapSize,
        totalJSHeapSize: performance.memory.totalJSHeapSize,
        jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
      } : null,
      wasmSupport: {
        instantiateStreaming: !!WebAssembly.instantiateStreaming,
        compileStreaming: !!WebAssembly.compileStreaming,
        threads: !!WebAssembly.Memory.prototype.grow
      }
    };
  }
  
  _generateSummary() {
    const functionCallTests = Array.from(this.results.entries())
      .filter(([name]) => ['simple_add', 'float_multiply', 'fibonacci_20', 'many_params'].includes(name));
    
    const dataTransferTests = Array.from(this.results.entries())
      .filter(([name]) => name.includes('_to_') || name.includes('_sum_'));
    
    return {
      totalTests: this.results.size,
      functionCallPerformance: {
        fastest: this._findFastest(functionCallTests),
        slowest: this._findSlowest(functionCallTests),
        average: this._calculateAverage(functionCallTests)
      },
      dataTransferPerformance: {
        fastest: this._findFastest(dataTransferTests),
        slowest: this._findSlowest(dataTransferTests),
        average: this._calculateAverage(dataTransferTests)
      }
    };
  }
  
  _findFastest(tests) {
    if (tests.length === 0) return null;
    return tests.reduce((fastest, [name, stats]) => {
      return !fastest || stats.avgTimePerOp < fastest.stats.avgTimePerOp
        ? { name, stats }
        : fastest;
    }, null);
  }
  
  _findSlowest(tests) {
    if (tests.length === 0) return null;
    return tests.reduce((slowest, [name, stats]) => {
      return !slowest || stats.avgTimePerOp > slowest.stats.avgTimePerOp
        ? { name, stats }
        : slowest;
    }, null);
  }
  
  _calculateAverage(tests) {
    if (tests.length === 0) return 0;
    const total = tests.reduce((sum, [, stats]) => sum + stats.avgTimePerOp, 0);
    return total / tests.length;
  }
  
  _generateRecommendations() {
    const recommendations = [];
    
    // 分析函数调用开销
    const simpleAdd = this.results.get('simple_add');
    const manyParams = this.results.get('many_params');
    
    if (simpleAdd && manyParams) {
      const overhead = manyParams.avgTimePerOp / simpleAdd.avgTimePerOp;
      if (overhead > 3) {
        recommendations.push({
          type: 'parameter_overhead',
          message: `函数参数过多会显著影响性能 (${overhead.toFixed(1)}x 开销)`,
          suggestion: '考虑使用结构体或减少参数数量'
        });
      }
    }
    
    // 分析内存访问模式
    const sequential = this.results.get('sequential_read');
    const random = this.results.get('random_read');
    
    if (sequential && random) {
      const ratio = random.avgTimePerOp / sequential.avgTimePerOp;
      if (ratio > 2) {
        recommendations.push({
          type: 'memory_access',
          message: `随机内存访问比顺序访问慢 ${ratio.toFixed(1)} 倍`,
          suggestion: '优化数据局部性，使用缓存友好的访问模式'
        });
      }
    }
    
    // 分析数据传输效率
    const transferTests = Array.from(this.results.entries())
      .filter(([name]) => name.includes('_to_'));
    
    if (transferTests.length > 0) {
      const avgTransferTime = this._calculateAverage(transferTests);
      if (avgTransferTime > 10) { // 10微秒阈值
        recommendations.push({
          type: 'data_transfer',
          message: '数据传输开销较高',
          suggestion: '考虑使用共享内存或减少数据传输频率'
        });
      }
    }
    
    return recommendations;
  }
  
  // 保存基准测试结果
  saveBaseline() {
    this.baselineResults = new Map(this.results);
    console.log('Baseline results saved');
  }
  
  // 与基准结果比较
  compareWithBaseline() {
    if (!this.baselineResults) {
      throw new Error('No baseline results available');
    }
    
    const comparison = {};
    
    for (const [testName, currentStats] of this.results) {
      const baselineStats = this.baselineResults.get(testName);
      if (baselineStats) {
        const ratio = currentStats.avgTimePerOp / baselineStats.avgTimePerOp;
        const change = ((ratio - 1) * 100);
        
        comparison[testName] = {
          current: currentStats.avgTimePerOp,
          baseline: baselineStats.avgTimePerOp,
          ratio: ratio,
          changePercent: change,
          isRegression: change > 5, // 5% 阈值
          isImprovement: change < -5
        };
      }
    }
    
    return comparison;
  }
  
  // 输出格式化的测试结果
  printResults() {
    console.log('\n=== Performance Benchmark Results ===');
    console.log('Test Name'.padEnd(25) + 'Time/Op (μs)'.padEnd(15) + 'Ops/Sec');
    console.log('-'.repeat(55));
    
    const sortedResults = Array.from(this.results.entries())
      .sort(([, a], [, b]) => a.avgTimePerOp - b.avgTimePerOp);
    
    for (const [name, stats] of sortedResults) {
      const timeStr = stats.avgTimePerOp.toFixed(3);
      const opsStr = Math.floor(stats.opsPerSecond).toLocaleString();
      console.log(name.padEnd(25) + timeStr.padEnd(15) + opsStr);
    }
    
    console.log('\n=== Environment Info ===');
    const env = this._getEnvironmentInfo();
    console.log(`Platform: ${env.platform}`);
    console.log(`Concurrency: ${env.concurrency} cores`);
    if (env.memory) {
      console.log(`JS Heap: ${(env.memory.usedJSHeapSize / 1024 / 1024).toFixed(1)} MB used`);
    }
  }
}

// 使用示例
async function runPerformanceTests() {
  console.log('Initializing WebAssembly module...');
  
  const wasmModule = await WebAssembly.instantiate(
    await WebAssembly.wat2wasm(benchmarkWat)
  );
  
  const benchmark = new PerformanceBenchmark(
    wasmModule.instance.exports,
    wasmModule.instance.exports.memory
  );
  
  console.log('Starting performance benchmarks...');
  
  try {
    // 运行各类基准测试
    await benchmark.benchmarkFunctionCalls();
    await benchmark.benchmarkDataTransfer();
    await benchmark.benchmarkCallPatterns();
    await benchmark.benchmarkMemoryPatterns();
    
    // 输出结果
    benchmark.printResults();
    
    // 生成详细报告
    const report = benchmark.generateReport();
    console.log('\n=== Performance Report ===');
    console.log(JSON.stringify(report, null, 2));
    
    // 保存基准
    benchmark.saveBaseline();
    
    // 模拟第二次运行来测试回归检测
    console.log('\n=== Running regression test ===');
    await benchmark.benchmarkFunctionCalls();
    
    const comparison = benchmark.compareWithBaseline();
    console.log('Baseline comparison:', comparison);
    
  } catch (error) {
    console.error('Benchmark failed:', error);
  }
}
```

**基准测试特性**：
- 全面的性能测试覆盖（函数调用、数据传输、内存访问）
- 统计学严谨的测量方法（多次运行、预热、统计分析）
- 详细的性能报告和优化建议
- 性能回归检测和基准比较
- 环境信息收集和跨平台兼容性测试

</details>

---

## 挑战项目

### 练习 7.5：实时数据流处理系统（35分）

**题目**：设计一个高性能的实时数据流处理系统，结合 WebAssembly 和 JavaScript 处理大量数据流。

要求：
1. 支持多种数据源（WebSocket、文件、模拟数据）
2. 实现流式数据处理管道
3. 提供实时性能监控和可视化
4. 支持背压控制和错误恢复

<details>
<summary>🔍 参考答案</summary>

```javascript
// 数据流处理的 WAT 模块
const streamProcessingWat = `
(module
  (memory (export "memory") 64)
  
  ;; 滑动窗口求和
  (func $sliding_window_sum (param $data_ptr i32) (param $window_size i32) (param $data_length i32) (param $output_ptr i32)
    (local $i i32)
    (local $sum f64)
    (local $window_start i32)
    (local $window_end i32)
    (local $j i32)
    
    ;; 为每个位置计算滑动窗口和
    (loop $outer_loop
      (if (i32.ge_u (local.get $i) (local.get $data_length))
        (then (br $outer_loop)))
      
      ;; 计算窗口范围
      (local.set $window_start (local.get $i))
      (local.set $window_end 
        (select
          (i32.add (local.get $i) (local.get $window_size))
          (local.get $data_length)
          (i32.le_u
            (i32.add (local.get $i) (local.get $window_size))
            (local.get $data_length))))
      
      ;; 计算窗口内的和
      (local.set $sum (f64.const 0))
      (local.set $j (local.get $window_start))
      
      (loop $inner_loop
        (if (i32.ge_u (local.get $j) (local.get $window_end))
          (then (br $inner_loop)))
        
        (local.set $sum
          (f64.add
            (local.get $sum)
            (f64.load (i32.add (local.get $data_ptr) (i32.mul (local.get $j) (i32.const 8))))))
        
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $inner_loop))
      
      ;; 存储结果
      (f64.store
        (i32.add (local.get $output_ptr) (i32.mul (local.get $i) (i32.const 8)))
        (local.get $sum))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $outer_loop)))
  
  ;; 移动平均
  (func $moving_average (param $data_ptr i32) (param $window_size i32) (param $data_length i32) (param $output_ptr i32)
    (local $i i32)
    (local $sum f64)
    (local $count f64)
    
    (call $sliding_window_sum (local.get $data_ptr) (local.get $window_size) (local.get $data_length) (local.get $output_ptr))
    
    ;; 除以窗口大小得到平均值
    (loop $avg_loop
      (if (i32.ge_u (local.get $i) (local.get $data_length))
        (then (br $avg_loop)))
      
      (local.set $count
        (f64.convert_i32_u
          (select
            (local.get $window_size)
            (i32.add (local.get $i) (i32.const 1))
            (i32.le_u (local.get $window_size) (i32.add (local.get $i) (i32.const 1))))))
      
      (f64.store
        (i32.add (local.get $output_ptr) (i32.mul (local.get $i) (i32.const 8)))
        (f64.div
          (f64.load (i32.add (local.get $output_ptr) (i32.mul (local.get $i) (i32.const 8))))
          (local.get $count)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $avg_loop)))
  
  ;; 异常检测（简单阈值）
  (func $detect_anomalies (param $data_ptr i32) (param $threshold f64) (param $data_length i32) (param $output_ptr i32) (result i32)
    (local $i i32)
    (local $anomaly_count i32)
    (local $value f64)
    
    (loop $anomaly_loop
      (if (i32.ge_u (local.get $i) (local.get $data_length))
        (then (br $anomaly_loop)))
      
      (local.set $value
        (f64.load (i32.add (local.get $data_ptr) (i32.mul (local.get $i) (i32.const 8)))))
      
      (if (f64.gt (f64.abs (local.get $value)) (local.get $threshold))
        (then
          (i32.store8
            (i32.add (local.get $output_ptr) (local.get $i))
            (i32.const 1))
          (local.set $anomaly_count (i32.add (local.get $anomaly_count) (i32.const 1))))
        (else
          (i32.store8
            (i32.add (local.get $output_ptr) (local.get $i))
            (i32.const 0))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $anomaly_loop))
    
    local.get $anomaly_count)
  
  ;; 数据聚合
  (func $aggregate_data (param $data_ptr i32) (param $data_length i32) (param $result_ptr i32)
    (local $sum f64)
    (local $min f64)
    (local $max f64)
    (local $i i32)
    (local $value f64)
    
    ;; 初始化
    (local.set $min (f64.const inf))
    (local.set $max (f64.const -inf))
    
    (loop $agg_loop
      (if (i32.ge_u (local.get $i) (local.get $data_length))
        (then (br $agg_loop)))
      
      (local.set $value
        (f64.load (i32.add (local.get $data_ptr) (i32.mul (local.get $i) (i32.const 8)))))
      
      (local.set $sum (f64.add (local.get $sum) (local.get $value)))
      (local.set $min (f64.min (local.get $min) (local.get $value)))
      (local.set $max (f64.max (local.get $max) (local.get $value)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $agg_loop))
    
    ;; 存储结果: sum, avg, min, max
    (f64.store (local.get $result_ptr) (local.get $sum))
    (f64.store
      (i32.add (local.get $result_ptr) (i32.const 8))
      (f64.div (local.get $sum) (f64.convert_i32_u (local.get $data_length))))
    (f64.store (i32.add (local.get $result_ptr) (i32.const 16)) (local.get $min))
    (f64.store (i32.add (local.get $result_ptr) (i32.const 24)) (local.get $max)))
  
  (export "sliding_window_sum" (func $sliding_window_sum))
  (export "moving_average" (func $moving_average))
  (export "detect_anomalies" (func $detect_anomalies))
  (export "aggregate_data" (func $aggregate_data)))
`;

// 实时数据流处理器
class RealTimeStreamProcessor {
  constructor(options = {}) {
    this.options = {
      bufferSize: 8192,
      windowSize: 100,
      maxLatency: 100, // ms
      enableBackpressure: true,
      anomalyThreshold: 3.0,
      ...options
    };
    
    this.wasmModule = null;
    this.memory = null;
    this.isRunning = false;
    
    // 数据缓冲区
    this.inputBuffer = [];
    this.processingBuffer = null;
    this.outputBuffer = [];
    
    // 性能监控
    this.metrics = {
      totalProcessed: 0,
      totalLatency: 0,
      maxLatency: 0,
      errorCount: 0,
      backpressureEvents: 0,
      anomaliesDetected: 0,
      startTime: null
    };
    
    // 事件监听器
    this.listeners = new Map();
    
    // 处理管道
    this.pipeline = [];
  }
  
  async initialize() {
    console.log('Initializing stream processor...');
    
    // 加载 WebAssembly 模块
    this.wasmModule = await WebAssembly.instantiate(
      await WebAssembly.wat2wasm(streamProcessingWat)
    );
    
    this.memory = this.wasmModule.instance.exports.memory;
    this.wasm = this.wasmModule.instance.exports;
    
    // 设置处理缓冲区
    this.processingBuffer = {
      data: new Float64Array(this.memory.buffer, 1024, this.options.bufferSize),
      output: new Float64Array(this.memory.buffer, 1024 + this.options.bufferSize * 8, this.options.bufferSize),
      anomalies: new Uint8Array(this.memory.buffer, 1024 + this.options.bufferSize * 16, this.options.bufferSize)
    };
    
    console.log('Stream processor initialized');
  }
  
  // 注册处理步骤
  addProcessor(name, processor) {
    this.pipeline.push({ name, processor });
  }
  
  // 开始数据流处理
  start() {
    if (this.isRunning) {
      throw new Error('Processor is already running');
    }
    
    this.isRunning = true;
    this.metrics.startTime = Date.now();
    
    // 启动处理循环
    this.processingLoop();
    
    console.log('Stream processor started');
    this.emit('started');
  }
  
  // 停止数据流处理
  stop() {
    this.isRunning = false;
    console.log('Stream processor stopped');
    this.emit('stopped', this.getMetrics());
  }
  
  // 主处理循环
  async processingLoop() {
    while (this.isRunning) {
      try {
        if (this.inputBuffer.length > 0) {
          await this.processChunk();
        } else {
          // 短暂休眠以避免 CPU 占用过高
          await this.sleep(1);
        }
      } catch (error) {
        this.metrics.errorCount++;
        this.emit('error', error);
        console.error('Processing error:', error);
      }
    }
  }
  
  // 处理数据块
  async processChunk() {
    const startTime = performance.now();
    
    // 检查背压
    if (this.options.enableBackpressure && this.shouldApplyBackpressure()) {
      this.metrics.backpressureEvents++;
      this.emit('backpressure', { bufferSize: this.inputBuffer.length });
      await this.sleep(10); // 等待缓解压力
      return;
    }
    
    // 获取处理数据
    const chunkSize = Math.min(this.inputBuffer.length, this.options.bufferSize);
    const chunk = this.inputBuffer.splice(0, chunkSize);
    
    if (chunk.length === 0) return;
    
    // 复制数据到 WebAssembly 内存
    this.processingBuffer.data.set(chunk);
    
    // 执行处理管道
    let processedData = {
      raw: chunk,
      processed: new Array(chunk.length),
      metadata: {
        timestamp: Date.now(),
        size: chunk.length
      }
    };
    
    // 运行 WebAssembly 处理步骤
    await this.runWasmProcessing(processedData, chunk.length);
    
    // 运行 JavaScript 处理步骤
    for (const { name, processor } of this.pipeline) {
      try {
        processedData = await processor(processedData);
      } catch (error) {
        console.error(`Processor ${name} failed:`, error);
        this.metrics.errorCount++;
      }
    }
    
    // 输出结果
    this.outputBuffer.push(processedData);
    
    // 更新指标
    const latency = performance.now() - startTime;
    this.metrics.totalProcessed += chunk.length;
    this.metrics.totalLatency += latency;
    this.metrics.maxLatency = Math.max(this.metrics.maxLatency, latency);
    
    // 发出处理完成事件
    this.emit('processed', {
      data: processedData,
      latency: latency,
      throughput: chunk.length / latency * 1000 // 每秒处理的数据点
    });
    
    // 检查延迟警告
    if (latency > this.options.maxLatency) {
      this.emit('latency_warning', { latency, threshold: this.options.maxLatency });
    }
  }
  
  // WebAssembly 处理步骤
  async runWasmProcessing(processedData, dataLength) {
    const dataPtr = 1024;
    const outputPtr = dataPtr + this.options.bufferSize * 8;
    const anomalyPtr = outputPtr + this.options.bufferSize * 8;
    const aggregatePtr = anomalyPtr + this.options.bufferSize;
    
    // 移动平均
    this.wasm.moving_average(dataPtr, this.options.windowSize, dataLength, outputPtr);
    processedData.movingAverage = Array.from(this.processingBuffer.output.slice(0, dataLength));
    
    // 异常检测
    const anomalyCount = this.wasm.detect_anomalies(
      dataPtr, 
      this.options.anomalyThreshold, 
      dataLength, 
      anomalyPtr
    );
    
    if (anomalyCount > 0) {
      this.metrics.anomaliesDetected += anomalyCount;
      processedData.anomalies = Array.from(this.processingBuffer.anomalies.slice(0, dataLength));
      this.emit('anomaly_detected', { count: anomalyCount, data: processedData });
    }
    
    // 数据聚合
    this.wasm.aggregate_data(dataPtr, dataLength, aggregatePtr);
    const aggregateView = new Float64Array(this.memory.buffer, aggregatePtr, 4);
    processedData.aggregate = {
      sum: aggregateView[0],
      average: aggregateView[1],
      min: aggregateView[2],
      max: aggregateView[3]
    };
  }
  
  // 背压控制
  shouldApplyBackpressure() {
    return this.inputBuffer.length > this.options.bufferSize * 2;
  }
  
  // 添加数据到输入缓冲区
  addData(data) {
    if (!this.isRunning) {
      throw new Error('Processor is not running');
    }
    
    if (Array.isArray(data)) {
      this.inputBuffer.push(...data);
    } else {
      this.inputBuffer.push(data);
    }
  }
  
  // 获取处理结果
  getResults(count = 10) {
    return this.outputBuffer.splice(0, count);
  }
  
  // 获取性能指标
  getMetrics() {
    const runtime = this.metrics.startTime ? Date.now() - this.metrics.startTime : 0;
    
    return {
      ...this.metrics,
      runtime,
      averageLatency: this.metrics.totalProcessed > 0 ? 
        this.metrics.totalLatency / this.metrics.totalProcessed : 0,
      throughput: runtime > 0 ? this.metrics.totalProcessed / runtime * 1000 : 0,
      errorRate: this.metrics.totalProcessed > 0 ? 
        this.metrics.errorCount / this.metrics.totalProcessed : 0
    };
  }
  
  // 事件系统
  on(event, listener) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event).push(listener);
  }
  
  emit(event, data) {
    const eventListeners = this.listeners.get(event) || [];
    eventListeners.forEach(listener => {
      try {
        listener(data);
      } catch (error) {
        console.error(`Event listener error for ${event}:`, error);
      }
    });
  }
  
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// 数据源类
class DataSource {
  constructor(type, options = {}) {
    this.type = type;
    this.options = options;
    this.isRunning = false;
    this.listeners = [];
  }
  
  onData(listener) {
    this.listeners.push(listener);
  }
  
  emit(data) {
    this.listeners.forEach(listener => listener(data));
  }
  
  start() {
    this.isRunning = true;
    
    switch (this.type) {
      case 'websocket':
        this.startWebSocket();
        break;
      case 'file':
        this.startFileStream();
        break;
      case 'simulation':
        this.startSimulation();
        break;
      default:
        throw new Error(`Unknown data source type: ${this.type}`);
    }
  }
  
  stop() {
    this.isRunning = false;
  }
  
  startWebSocket() {
    // WebSocket 数据源实现
    const ws = new WebSocket(this.options.url || 'wss://echo.websocket.org');
    
    ws.onmessage = (event) => {
      if (this.isRunning) {
        try {
          const data = JSON.parse(event.data);
          this.emit(data);
        } catch (error) {
          console.error('WebSocket data parse error:', error);
        }
      }
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }
  
  startFileStream() {
    // 文件流数据源实现（模拟）
    const reader = new FileReader();
    
    if (this.options.file) {
      reader.onload = (event) => {
        const content = event.target.result;
        const lines = content.split('\n');
        
        let index = 0;
        const interval = setInterval(() => {
          if (!this.isRunning || index >= lines.length) {
            clearInterval(interval);
            return;
          }
          
          try {
            const value = parseFloat(lines[index]);
            if (!isNaN(value)) {
              this.emit(value);
            }
          } catch (error) {
            console.error('File data parse error:', error);
          }
          
          index++;
        }, this.options.interval || 10);
      };
      
      reader.readAsText(this.options.file);
    }
  }
  
  startSimulation() {
    // 模拟数据源
    const interval = setInterval(() => {
      if (!this.isRunning) {
        clearInterval(interval);
        return;
      }
      
      // 生成模拟数据（正弦波 + 噪声 + 偶尔的异常值）
      const t = Date.now() / 1000;
      const baseValue = Math.sin(t * 0.1) * 10;
      const noise = (Math.random() - 0.5) * 2;
      const anomaly = Math.random() < 0.01 ? (Math.random() - 0.5) * 50 : 0; // 1% 异常概率
      
      const value = baseValue + noise + anomaly;
      this.emit(value);
      
    }, this.options.interval || 50); // 20Hz 采样率
  }
}

// 实时可视化组件
class RealTimeVisualizer {
  constructor(canvasId, options = {}) {
    this.canvas = document.getElementById(canvasId);
    this.ctx = this.canvas.getContext('2d');
    this.options = {
      maxPoints: 500,
      updateInterval: 50,
      showMovingAverage: true,
      showAnomalies: true,
      ...options
    };
    
    this.data = [];
    this.movingAverage = [];
    this.anomalies = [];
    this.metrics = null;
    
    this.setupCanvas();
    this.startAnimation();
  }
  
  setupCanvas() {
    this.canvas.width = this.canvas.offsetWidth;
    this.canvas.height = this.canvas.offsetHeight;
  }
  
  addData(processedData) {
    this.data.push(...processedData.raw);
    
    if (processedData.movingAverage) {
      this.movingAverage.push(...processedData.movingAverage);
    }
    
    if (processedData.anomalies) {
      this.anomalies.push(...processedData.anomalies);
    }
    
    // 保持数据长度在限制内
    if (this.data.length > this.options.maxPoints) {
      const excess = this.data.length - this.options.maxPoints;
      this.data.splice(0, excess);
      this.movingAverage.splice(0, excess);
      this.anomalies.splice(0, excess);
    }
  }
  
  updateMetrics(metrics) {
    this.metrics = metrics;
  }
  
  startAnimation() {
    const animate = () => {
      this.draw();
      setTimeout(() => {
        requestAnimationFrame(animate);
      }, this.options.updateInterval);
    };
    
    animate();
  }
  
  draw() {
    const { width, height } = this.canvas;
    this.ctx.clearRect(0, 0, width, height);
    
    if (this.data.length < 2) return;
    
    // 计算绘图范围
    const minValue = Math.min(...this.data);
    const maxValue = Math.max(...this.data);
    const range = maxValue - minValue;
    const margin = range * 0.1;
    
    const scaleY = (height - 60) / (range + margin * 2);
    const scaleX = (width - 60) / Math.max(this.data.length - 1, 1);
    
    // 绘制网格
    this.drawGrid(width, height, minValue - margin, maxValue + margin);
    
    // 绘制原始数据
    this.drawLine(this.data, scaleX, scaleY, minValue - margin, '#2196F3', 2);
    
    // 绘制移动平均
    if (this.options.showMovingAverage && this.movingAverage.length > 0) {
      this.drawLine(this.movingAverage, scaleX, scaleY, minValue - margin, '#FF9800', 1);
    }
    
    // 绘制异常点
    if (this.options.showAnomalies && this.anomalies.length > 0) {
      this.drawAnomalies(scaleX, scaleY, minValue - margin);
    }
    
    // 绘制图例和指标
    this.drawLegend();
    this.drawMetrics();
  }
  
  drawGrid(width, height, minValue, maxValue) {
    this.ctx.strokeStyle = '#E0E0E0';
    this.ctx.lineWidth = 1;
    
    // 水平网格线
    for (let i = 0; i <= 10; i++) {
      const y = 30 + (height - 60) * i / 10;
      this.ctx.beginPath();
      this.ctx.moveTo(30, y);
      this.ctx.lineTo(width - 30, y);
      this.ctx.stroke();
      
      // 标签
      const value = maxValue - (maxValue - minValue) * i / 10;
      this.ctx.fillStyle = '#666';
      this.ctx.font = '12px Arial';
      this.ctx.fillText(value.toFixed(1), 5, y + 4);
    }
    
    // 垂直网格线
    for (let i = 0; i <= 10; i++) {
      const x = 30 + (width - 60) * i / 10;
      this.ctx.beginPath();
      this.ctx.moveTo(x, 30);
      this.ctx.lineTo(x, height - 30);
      this.ctx.stroke();
    }
  }
  
  drawLine(data, scaleX, scaleY, minValue, color, lineWidth) {
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = lineWidth;
    this.ctx.beginPath();
    
    for (let i = 0; i < data.length; i++) {
      const x = 30 + i * scaleX;
      const y = 30 + (data[i] - minValue) * scaleY;
      
      if (i === 0) {
        this.ctx.moveTo(x, this.canvas.height - y);
      } else {
        this.ctx.lineTo(x, this.canvas.height - y);
      }
    }
    
    this.ctx.stroke();
  }
  
  drawAnomalies(scaleX, scaleY, minValue) {
    this.ctx.fillStyle = '#F44336';
    
    for (let i = 0; i < this.anomalies.length; i++) {
      if (this.anomalies[i]) {
        const x = 30 + i * scaleX;
        const y = 30 + (this.data[i] - minValue) * scaleY;
        
        this.ctx.beginPath();
        this.ctx.arc(x, this.canvas.height - y, 4, 0, Math.PI * 2);
        this.ctx.fill();
      }
    }
  }
  
  drawLegend() {
    this.ctx.font = '14px Arial';
    let y = 20;
    
    // 原始数据
    this.ctx.fillStyle = '#2196F3';
    this.ctx.fillRect(10, y - 8, 20, 3);
    this.ctx.fillStyle = '#333';
    this.ctx.fillText('原始数据', 35, y);
    y += 20;
    
    // 移动平均
    if (this.options.showMovingAverage) {
      this.ctx.fillStyle = '#FF9800';
      this.ctx.fillRect(10, y - 8, 20, 3);
      this.ctx.fillStyle = '#333';
      this.ctx.fillText('移动平均', 35, y);
      y += 20;
    }
    
    // 异常点
    if (this.options.showAnomalies) {
      this.ctx.fillStyle = '#F44336';
      this.ctx.beginPath();
      this.ctx.arc(20, y - 5, 4, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.fillStyle = '#333';
      this.ctx.fillText('异常点', 35, y);
    }
  }
  
  drawMetrics() {
    if (!this.metrics) return;
    
    this.ctx.font = '12px monospace';
    this.ctx.fillStyle = '#333';
    
    const metricsText = [
      `吞吐量: ${this.metrics.throughput.toFixed(1)} 点/秒`,
      `延迟: ${this.metrics.averageLatency.toFixed(2)} ms`,
      `异常: ${this.metrics.anomaliesDetected}`,
      `错误: ${this.metrics.errorCount}`
    ];
    
    let y = this.canvas.height - 60;
    metricsText.forEach(text => {
      this.ctx.fillText(text, this.canvas.width - 180, y);
      y += 15;
    });
  }
}

// 完整的使用示例
async function createRealTimeStreamProcessingSystem() {
  console.log('=== 实时数据流处理系统 ===');
  
  // 创建处理器
  const processor = new RealTimeStreamProcessor({
    bufferSize: 1000,
    windowSize: 50,
    maxLatency: 50,
    anomalyThreshold: 2.5
  });
  
  // 初始化
  await processor.initialize();
  
  // 添加自定义处理步骤
  processor.addProcessor('outlier_filter', async (data) => {
    // 简单的离群值过滤
    const threshold = 3 * Math.sqrt(data.aggregate.average);
    data.filtered = data.raw.filter(value => Math.abs(value) < threshold);
    return data;
  });
  
  processor.addProcessor('trend_detection', async (data) => {
    // 简单的趋势检测
    if (data.movingAverage && data.movingAverage.length > 10) {
      const recent = data.movingAverage.slice(-10);
      const older = data.movingAverage.slice(-20, -10);
      const recentAvg = recent.reduce((sum, v) => sum + v, 0) / recent.length;
      const olderAvg = older.reduce((sum, v) => sum + v, 0) / older.length;
      
      data.trend = recentAvg > olderAvg ? 'up' : 'down';
    }
    return data;
  });
  
  // 创建可视化组件（需要 HTML canvas 元素）
  // const visualizer = new RealTimeVisualizer('dataCanvas');
  
  // 设置事件监听
  processor.on('processed', (result) => {
    console.log(`处理了 ${result.data.raw.length} 个数据点，延迟 ${result.latency.toFixed(2)} ms`);
    // visualizer.addData(result.data);
    // visualizer.updateMetrics(processor.getMetrics());
  });
  
  processor.on('anomaly_detected', (event) => {
    console.warn(`检测到 ${event.count} 个异常值`);
  });
  
  processor.on('backpressure', (event) => {
    console.warn(`背压激活，缓冲区大小: ${event.bufferSize}`);
  });
  
  processor.on('latency_warning', (event) => {
    console.warn(`延迟过高: ${event.latency.toFixed(2)} ms`);
  });
  
  // 创建数据源
  const dataSource = new DataSource('simulation', {
    interval: 20 // 50Hz
  });
  
  // 连接数据源到处理器
  dataSource.onData((data) => {
    processor.addData(data);
  });
  
  // 启动系统
  console.log('启动数据源...');
  dataSource.start();
  
  console.log('启动处理器...');
  processor.start();
  
  // 运行一段时间后显示统计信息
  setTimeout(() => {
    console.log('=== 性能统计 ===');
    const metrics = processor.getMetrics();
    console.log(JSON.stringify(metrics, null, 2));
    
    // 获取一些处理结果
    const results = processor.getResults(5);
    console.log('=== 最近的处理结果 ===');
    results.forEach((result, index) => {
      console.log(`结果 ${index + 1}:`, {
        size: result.raw.length,
        aggregate: result.aggregate,
        trend: result.trend,
        anomalyCount: result.anomalies ? result.anomalies.filter(a => a).length : 0
      });
    });
    
    // 停止系统
    setTimeout(() => {
      dataSource.stop();
      processor.stop();
      console.log('系统已停止');
    }, 5000);
    
  }, 10000);
}
```

**系统特性**：
- 支持多种数据源（WebSocket、文件、模拟）
- 高性能的 WebAssembly 数据处理算法
- 可扩展的处理管道架构
- 实时性能监控和背压控制
- 异常检测和错误恢复机制
- 实时数据可视化（可选）
- 完整的事件系统和指标收集

</details>

---

## 总结与评分标准

### 🎯 学习目标检查表

完成本章练习后，你应该能够：

- [ ] **模块加载与管理**（练习 7.1-7.2）
  - 实现健壮的模块加载器
  - 处理类型安全的数据转换
  - 管理内存分配和释放

- [ ] **性能优化技术**（练习 7.3-7.4）
  - 设计高效的内存池管理
  - 实现性能基准测试
  - 分析和优化数据传输

- [ ] **实际应用开发**（练习 7.5）
  - 构建实时数据处理系统
  - 实现流式数据处理
  - 集成监控和可视化

### 📊 评分标准

| 练习类型 | 分值分布 | 评分要点 |
|---------|---------|---------|
| **基础练习** | 45分 | 正确性(60%) + 代码质量(25%) + 文档完整性(15%) |
| **进阶练习** | 55分 | 性能优化(35%) + 创新性(30%) + 健壮性(35%) |
| **挑战项目** | 35分 | 系统设计(40%) + 实现完整性(35%) + 实用性(25%) |

### 🔧 实践建议

1. **循序渐进**：先完成基础练习，理解核心概念
2. **注重性能**：在进阶练习中专注于性能测量和优化
3. **系统思维**：在挑战项目中考虑完整的系统架构
4. **实际应用**：尝试将练习中的技术应用到实际项目中

### 📚 扩展学习

- **WebAssembly System Interface (WASI)**：了解系统级接口
- **Web Workers 集成**：学习多线程 WebAssembly 应用
- **编译器工具链**：深入学习 Emscripten 和 wasm-pack
- **性能调试工具**：掌握 WebAssembly 性能分析工具

---

**🎉 恭喜！** 完成这些练习后，你已经具备了深度掌握 WebAssembly 与 JavaScript 交互的能力，可以构建高性能的 Web 应用程序！
