# 第12章 实战项目

本章将通过真实的 WebAssembly 项目案例和最佳实践，帮助你理解如何在生产环境中构建、部署和维护 WebAssembly 应用。我们将分析成功的开源项目、商业应用案例，并提供完整的项目架构设计指南。

## 12.1 经典项目案例分析

### 12.1.1 Figma - 高性能图形编辑器

Figma 是 WebAssembly 在浏览器端应用的经典成功案例，展示了如何将复杂的桌面级应用移植到 Web 平台。

#### 技术架构分析

**核心技术栈**:
```
渲染引擎:     C++ → WebAssembly
UI 层:        React + TypeScript  
通信层:       WebAssembly.Table + SharedArrayBuffer
图形处理:     Skia (C++) → WASM
数学计算:     高精度几何运算 (C++)
```

**架构设计模式**:
```rust
// 模拟 Figma 的渲染架构设计
use wasm_bindgen::prelude::*;
use std::collections::HashMap;

#[wasm_bindgen]
pub struct GraphicsRenderer {
    canvas_width: u32,
    canvas_height: u32,
    objects: Vec<GraphicsObject>,
    transform_stack: Vec<Transform>,
    viewport: Viewport,
}

#[wasm_bindgen]
pub struct GraphicsObject {
    id: u32,
    object_type: ObjectType,
    geometry: Geometry,
    style: Style,
    children: Vec<u32>,
}

#[wasm_bindgen]
#[derive(Clone)]
pub struct Transform {
    a: f64, b: f64, c: f64,
    d: f64, e: f64, f: f64,
}

#[wasm_bindgen]
pub enum ObjectType {
    Rectangle,
    Ellipse,
    Path,
    Text,
    Group,
    Frame,
}

#[wasm_bindgen]
impl GraphicsRenderer {
    #[wasm_bindgen(constructor)]
    pub fn new(width: u32, height: u32) -> GraphicsRenderer {
        GraphicsRenderer {
            canvas_width: width,
            canvas_height: height,
            objects: Vec::new(),
            transform_stack: vec![Transform::identity()],
            viewport: Viewport::new(0.0, 0.0, width as f64, height as f64),
        }
    }
    
    // 批量渲染优化 - 关键性能特性
    #[wasm_bindgen]
    pub fn render_frame(&mut self, object_ids: &[u32]) -> js_sys::Uint8Array {
        let mut frame_buffer = vec![0u8; (self.canvas_width * self.canvas_height * 4) as usize];
        
        // 视锥剔除 - 只渲染可见对象
        let visible_objects = self.cull_objects(object_ids);
        
        // 按 Z 顺序排序
        let mut sorted_objects = visible_objects;
        sorted_objects.sort_by_key(|obj| obj.z_index);
        
        // 批量渲染
        for object in sorted_objects {
            self.render_object(&object, &mut frame_buffer);
        }
        
        js_sys::Uint8Array::from(&frame_buffer[..])
    }
    
    // 高精度几何计算
    fn render_object(&self, object: &GraphicsObject, buffer: &mut [u8]) {
        match object.object_type {
            ObjectType::Rectangle => self.render_rectangle(object, buffer),
            ObjectType::Ellipse => self.render_ellipse(object, buffer),
            ObjectType::Path => self.render_path(object, buffer),
            ObjectType::Text => self.render_text(object, buffer),
            _ => {}
        }
    }
    
    // 向量化路径渲染
    fn render_path(&self, object: &GraphicsObject, buffer: &mut [u8]) {
        // 使用贝塞尔曲线细分算法
        let segments = object.geometry.path_segments();
        
        for segment in segments {
            match segment {
                PathSegment::MoveTo(x, y) => { /* 移动到指定点 */ }
                PathSegment::LineTo(x, y) => { 
                    self.draw_line_segment(buffer, segment.start(), (x, y));
                }
                PathSegment::CurveTo(cp1, cp2, end) => {
                    self.draw_bezier_curve(buffer, segment.start(), cp1, cp2, end);
                }
            }
        }
    }
    
    // 抗锯齿渲染
    fn draw_line_segment(&self, buffer: &mut [u8], start: (f64, f64), end: (f64, f64)) {
        // Wu's 线段抗锯齿算法实现
        let (x0, y0) = start;
        let (x1, y1) = end;
        
        let steep = (y1 - y0).abs() > (x1 - x0).abs();
        let (x0, y0, x1, y1) = if steep {
            (y0, x0, y1, x1)
        } else {
            (x0, y0, x1, y1)
        };
        
        let (x0, y0, x1, y1) = if x0 > x1 {
            (x1, y1, x0, y0)
        } else {
            (x0, y0, x1, y1)
        };
        
        let dx = x1 - x0;
        let dy = y1 - y0;
        let gradient = if dx == 0.0 { 1.0 } else { dy / dx };
        
        // 实际的像素绘制逻辑...
    }
    
    fn cull_objects(&self, object_ids: &[u32]) -> Vec<&GraphicsObject> {
        // 实现视锥剔除算法
        self.objects.iter()
            .filter(|obj| object_ids.contains(&obj.id))
            .filter(|obj| self.viewport.intersects(&obj.bounds()))
            .collect()
    }
}

// 支持的几何类型
#[wasm_bindgen]
pub struct Geometry {
    bounds: BoundingBox,
    path_data: Option<Vec<u8>>,
}

#[wasm_bindgen]
pub struct Viewport {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    scale: f64,
}

impl Viewport {
    pub fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Viewport { x, y, width, height, scale: 1.0 }
    }
    
    pub fn intersects(&self, bounds: &BoundingBox) -> bool {
        // AABB 相交检测
        bounds.x < self.x + self.width &&
        bounds.x + bounds.width > self.x &&
        bounds.y < self.y + self.height &&
        bounds.y + bounds.height > self.y
    }
}
```

**性能优化策略**:

1. **内存管理优化**:
```rust
use std::alloc::{GlobalAlloc, Layout, System};

// 自定义分配器用于图形对象
pub struct GraphicsAllocator {
    pool: Vec<u8>,
    free_blocks: Vec<(usize, usize)>, // (offset, size)
}

impl GraphicsAllocator {
    pub fn new(pool_size: usize) -> Self {
        GraphicsAllocator {
            pool: vec![0; pool_size],
            free_blocks: vec![(0, pool_size)],
        }
    }
    
    pub fn allocate_graphics_object(&mut self, size: usize) -> Option<*mut u8> {
        for i in 0..self.free_blocks.len() {
            let (offset, block_size) = self.free_blocks[i];
            if block_size >= size {
                // 分割块
                if block_size > size {
                    self.free_blocks[i] = (offset + size, block_size - size);
                } else {
                    self.free_blocks.remove(i);
                }
                
                return Some(unsafe { 
                    self.pool.as_mut_ptr().add(offset) 
                });
            }
        }
        None
    }
}
```

2. **多线程渲染** (使用 Web Workers):
```javascript
// 主线程代码
class FigmaLikeRenderer {
    constructor() {
        this.renderWorkers = [];
        this.taskQueue = [];
        
        // 创建多个渲染工作线程
        for (let i = 0; i < navigator.hardwareConcurrency || 4; i++) {
            const worker = new Worker('render-worker.js');
            worker.onmessage = this.handleWorkerMessage.bind(this);
            this.renderWorkers.push(worker);
        }
    }
    
    async renderScene(scene) {
        // 将场景分割为多个渲染任务
        const tiles = this.divideTiles(scene);
        const renderPromises = [];
        
        for (const tile of tiles) {
            const promise = this.assignRenderTask(tile);
            renderPromises.push(promise);
        }
        
        const renderedTiles = await Promise.all(renderPromises);
        return this.composeTiles(renderedTiles);
    }
    
    assignRenderTask(tile) {
        return new Promise((resolve) => {
            const worker = this.getAvailableWorker();
            const taskId = this.generateTaskId();
            
            this.taskQueue.push({ taskId, resolve });
            
            worker.postMessage({
                type: 'render_tile',
                taskId: taskId,
                tile: tile,
                timestamp: performance.now()
            });
        });
    }
    
    handleWorkerMessage(event) {
        const { type, taskId, result, renderTime } = event.data;
        
        if (type === 'render_complete') {
            const task = this.taskQueue.find(t => t.taskId === taskId);
            if (task) {
                task.resolve(result);
                this.taskQueue = this.taskQueue.filter(t => t.taskId !== taskId);
            }
            
            // 性能监控
            console.log(`Tile rendered in ${renderTime}ms`);
        }
    }
}
```

#### 关键技术要点

**1. 内存布局优化**:
- 紧凑的对象表示减少内存占用
- 空间分区算法提高碰撞检测效率
- 对象池模式减少 GC 压力

**2. 渲染管道优化**:
- 视锥剔除减少不必要的渲染
- 批处理减少 JS-WASM 边界开销
- 增量渲染只更新变化区域

**3. 交互响应性**:
- 时间分片避免阻塞主线程
- 预测性预加载提高用户体验
- 优先级队列处理紧急任务

### 12.1.2 AutoCAD Web App - CAD 引擎移植

AutoCAD Web 展示了如何将复杂的桌面 CAD 引擎成功移植到 WebAssembly。

#### 移植策略分析

**1. 模块化分离**:
```
核心引擎:     C++ 几何内核 → WASM
渲染引擎:     OpenGL → WebGL 桥接
文件格式:     DWG/DXF 解析器 → WASM  
UI 交互:      Web 前端 (React)
```

**2. 示例架构实现**:
```rust
// CAD 引擎核心模块
#[wasm_bindgen]
pub struct CADEngine {
    entities: Vec<CADEntity>,
    layers: HashMap<String, Layer>,
    coordinate_system: CoordinateSystem,
    precision: f64,
}

#[wasm_bindgen]
pub struct CADEntity {
    id: u64,
    entity_type: EntityType,
    geometry: GeometryData,
    properties: EntityProperties,
    layer_id: String,
}

#[wasm_bindgen]
pub enum EntityType {
    Line,
    Arc,
    Circle,
    Polyline,
    Spline,
    Text,
    Dimension,
    Block,
}

#[wasm_bindgen]
impl CADEngine {
    #[wasm_bindgen(constructor)]
    pub fn new() -> CADEngine {
        CADEngine {
            entities: Vec::new(),
            layers: HashMap::new(),
            coordinate_system: CoordinateSystem::new(),
            precision: 1e-10, // 高精度计算
        }
    }
    
    // 高精度几何计算
    #[wasm_bindgen]
    pub fn create_line(&mut self, x1: f64, y1: f64, x2: f64, y2: f64) -> u64 {
        let entity_id = self.generate_id();
        let geometry = GeometryData::Line(Point2D::new(x1, y1), Point2D::new(x2, y2));
        
        let entity = CADEntity {
            id: entity_id,
            entity_type: EntityType::Line,
            geometry,
            properties: EntityProperties::default(),
            layer_id: "0".to_string(),
        };
        
        self.entities.push(entity);
        entity_id
    }
    
    // 复杂几何运算
    #[wasm_bindgen]
    pub fn boolean_union(&mut self, entity1_id: u64, entity2_id: u64) -> Option<u64> {
        let entity1 = self.find_entity(entity1_id)?;
        let entity2 = self.find_entity(entity2_id)?;
        
        // 实现布尔并集算法
        let result_geometry = self.compute_boolean_union(&entity1.geometry, &entity2.geometry)?;
        
        let result_id = self.generate_id();
        let result_entity = CADEntity {
            id: result_id,
            entity_type: EntityType::Polyline, // 简化假设
            geometry: result_geometry,
            properties: EntityProperties::default(),
            layer_id: entity1.layer_id.clone(),
        };
        
        self.entities.push(result_entity);
        Some(result_id)
    }
    
    // 空间索引优化
    #[wasm_bindgen]
    pub fn spatial_query(&self, min_x: f64, min_y: f64, max_x: f64, max_y: f64) -> Vec<u64> {
        let query_bounds = BoundingBox::new(min_x, min_y, max_x, max_y);
        
        self.entities.iter()
            .filter(|entity| {
                let entity_bounds = entity.geometry.bounding_box();
                query_bounds.intersects(&entity_bounds)
            })
            .map(|entity| entity.id)
            .collect()
    }
    
    // 捕捉点计算
    #[wasm_bindgen]
    pub fn snap_point(&self, x: f64, y: f64, snap_distance: f64) -> Option<js_sys::Array> {
        let query_point = Point2D::new(x, y);
        let mut closest_distance = snap_distance;
        let mut snap_point = None;
        
        for entity in &self.entities {
            if let Some(snaps) = entity.geometry.get_snap_points() {
                for snap in snaps {
                    let distance = query_point.distance_to(&snap);
                    if distance < closest_distance {
                        closest_distance = distance;
                        snap_point = Some(snap);
                    }
                }
            }
        }
        
        if let Some(point) = snap_point {
            let result = js_sys::Array::new();
            result.push(&JsValue::from(point.x));
            result.push(&JsValue::from(point.y));
            Some(result)
        } else {
            None
        }
    }
    
    // 文件格式支持
    #[wasm_bindgen]
    pub fn import_dxf(&mut self, dxf_data: &[u8]) -> Result<(), JsValue> {
        let mut parser = DXFParser::new();
        let entities = parser.parse(dxf_data)
            .map_err(|e| JsValue::from_str(&format!("DXF 解析错误: {}", e)))?;
        
        for entity_data in entities {
            self.import_entity(entity_data);
        }
        
        Ok(())
    }
    
    #[wasm_bindgen]
    pub fn export_dxf(&self) -> Result<js_sys::Uint8Array, JsValue> {
        let mut writer = DXFWriter::new();
        
        // 写入文件头
        writer.write_header();
        
        // 写入图层定义
        for (name, layer) in &self.layers {
            writer.write_layer(name, layer);
        }
        
        // 写入实体数据
        for entity in &self.entities {
            writer.write_entity(entity);
        }
        
        // 写入文件尾
        writer.write_footer();
        
        let data = writer.get_data();
        Ok(js_sys::Uint8Array::from(data.as_slice()))
    }
    
    fn compute_boolean_union(&self, geom1: &GeometryData, geom2: &GeometryData) -> Option<GeometryData> {
        // 实现 Clipper 或 CGAL 算法
        // 这是一个简化版本
        match (geom1, geom2) {
            (GeometryData::Circle(c1), GeometryData::Circle(c2)) => {
                // 圆的并集计算
                self.circle_union(c1, c2)
            }
            _ => {
                // 通用多边形布尔运算
                self.polygon_boolean_union(geom1, geom2)
            }
        }
    }
}

// 高精度几何数据结构
#[wasm_bindgen]
#[derive(Clone)]
pub struct Point2D {
    pub x: f64,
    pub y: f64,
}

impl Point2D {
    pub fn new(x: f64, y: f64) -> Self {
        Point2D { x, y }
    }
    
    pub fn distance_to(&self, other: &Point2D) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }
}

// DXF 文件格式解析器
pub struct DXFParser {
    precision: f64,
}

impl DXFParser {
    pub fn new() -> Self {
        DXFParser { precision: 1e-10 }
    }
    
    pub fn parse(&mut self, data: &[u8]) -> Result<Vec<EntityData>, String> {
        // 实现 DXF 格式解析
        let content = std::str::from_utf8(data)
            .map_err(|_| "无效的 UTF-8 编码".to_string())?;
        
        let mut entities = Vec::new();
        let lines: Vec<&str> = content.lines().collect();
        let mut i = 0;
        
        while i < lines.len() {
            if lines[i].trim() == "ENTITIES" {
                i += 1;
                while i < lines.len() && lines[i].trim() != "ENDSEC" {
                    if let Some(entity) = self.parse_entity(&lines, &mut i)? {
                        entities.push(entity);
                    }
                }
                break;
            }
            i += 1;
        }
        
        Ok(entities)
    }
    
    fn parse_entity(&self, lines: &[&str], index: &mut usize) -> Result<Option<EntityData>, String> {
        // 具体的实体解析逻辑
        // 这里是简化版本
        if *index >= lines.len() {
            return Ok(None);
        }
        
        // 实际实现会更复杂，需要处理各种 DXF 代码
        *index += 1;
        Ok(None)
    }
}
```

#### 性能关键技术

**1. 空间数据结构**:
```rust
// R-Tree 空间索引实现
pub struct RTree {
    root: Option<Box<RTreeNode>>,
    max_children: usize,
}

pub struct RTreeNode {
    bounds: BoundingBox,
    children: Vec<RTreeNode>,
    entities: Vec<u64>, // 叶子节点存储实体ID
    is_leaf: bool,
}

impl RTree {
    pub fn new(max_children: usize) -> Self {
        RTree {
            root: None,
            max_children,
        }
    }
    
    pub fn insert(&mut self, entity_id: u64, bounds: BoundingBox) {
        if let Some(ref mut root) = self.root {
            if root.children.len() >= self.max_children {
                // 分裂根节点
                let new_root = self.split_root();
                self.root = Some(new_root);
            }
        } else {
            // 创建根节点
            self.root = Some(Box::new(RTreeNode::new_leaf()));
        }
        
        if let Some(ref mut root) = self.root {
            self.insert_into_node(root, entity_id, bounds);
        }
    }
    
    pub fn query(&self, query_bounds: &BoundingBox) -> Vec<u64> {
        let mut results = Vec::new();
        
        if let Some(ref root) = self.root {
            self.query_node(root, query_bounds, &mut results);
        }
        
        results
    }
    
    fn query_node(&self, node: &RTreeNode, query_bounds: &BoundingBox, results: &mut Vec<u64>) {
        if !node.bounds.intersects(query_bounds) {
            return;
        }
        
        if node.is_leaf {
            for &entity_id in &node.entities {
                results.push(entity_id);
            }
        } else {
            for child in &node.children {
                self.query_node(child, query_bounds, results);
            }
        }
    }
}
```

**2. 内存优化技术**:
```rust
// 对象池用于频繁创建的几何对象
pub struct GeometryPool {
    point_pool: Vec<Point2D>,
    line_pool: Vec<Line>,
    arc_pool: Vec<Arc>,
    used_points: Vec<bool>,
    used_lines: Vec<bool>,
    used_arcs: Vec<bool>,
}

impl GeometryPool {
    pub fn new(initial_capacity: usize) -> Self {
        GeometryPool {
            point_pool: Vec::with_capacity(initial_capacity),
            line_pool: Vec::with_capacity(initial_capacity),
            arc_pool: Vec::with_capacity(initial_capacity),
            used_points: Vec::new(),
            used_lines: Vec::new(),
            used_arcs: Vec::new(),
        }
    }
    
    pub fn get_point(&mut self) -> (usize, &mut Point2D) {
        // 寻找未使用的点对象
        for (i, &used) in self.used_points.iter().enumerate() {
            if !used {
                self.used_points[i] = true;
                return (i, &mut self.point_pool[i]);
            }
        }
        
        // 如果没有可用对象，创建新的
        let index = self.point_pool.len();
        self.point_pool.push(Point2D::new(0.0, 0.0));
        self.used_points.push(true);
        (index, &mut self.point_pool[index])
    }
    
    pub fn release_point(&mut self, index: usize) {
        if index < self.used_points.len() {
            self.used_points[index] = false;
        }
    }
}
```

### 12.1.3 Photoshop Web - 图像处理引擎

Adobe Photoshop Web 版本展示了如何将复杂的图像处理算法移植到 WebAssembly。

#### 图像处理架构

**1. 核心滤镜实现**:
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct ImageProcessor {
    width: u32,
    height: u32,
    channels: u32, // RGBA = 4
    data: Vec<u8>,
    temp_buffer: Vec<f32>, // 浮点计算缓冲区
    histogram: [u32; 256],
}

#[wasm_bindgen]
impl ImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: u32, height: u32) -> ImageProcessor {
        let pixel_count = (width * height * 4) as usize;
        ImageProcessor {
            width,
            height,
            channels: 4,
            data: vec![0; pixel_count],
            temp_buffer: vec![0.0; pixel_count],
            histogram: [0; 256],
        }
    }
    
    // 高斯模糊 - 分离式卷积优化
    #[wasm_bindgen]
    pub fn gaussian_blur(&mut self, radius: f32) {
        if radius <= 0.0 {
            return;
        }
        
        let sigma = radius / 3.0;
        let kernel_size = ((radius * 6.0) as usize) | 1; // 确保奇数
        let kernel = self.create_gaussian_kernel(kernel_size, sigma);
        
        // 水平方向模糊
        self.horizontal_blur(&kernel);
        
        // 垂直方向模糊
        self.vertical_blur(&kernel);
    }
    
    // 自适应直方图均衡化 (CLAHE)
    #[wasm_bindgen]
    pub fn adaptive_histogram_equalization(&mut self, clip_limit: f32, tile_size: u32) {
        let tile_x_count = (self.width + tile_size - 1) / tile_size;
        let tile_y_count = (self.height + tile_size - 1) / tile_size;
        
        // 为每个 tile 计算直方图
        let mut tile_histograms = Vec::new();
        
        for tile_y in 0..tile_y_count {
            for tile_x in 0..tile_x_count {
                let x_start = tile_x * tile_size;
                let y_start = tile_y * tile_size;
                let x_end = std::cmp::min(x_start + tile_size, self.width);
                let y_end = std::cmp::min(y_start + tile_size, self.height);
                
                let histogram = self.compute_tile_histogram(x_start, y_start, x_end, y_end);
                let clipped_histogram = self.clip_histogram(histogram, clip_limit);
                let equalized_mapping = self.compute_equalization_mapping(clipped_histogram);
                
                tile_histograms.push(equalized_mapping);
            }
        }
        
        // 双线性插值应用映射
        self.apply_adaptive_mapping(&tile_histograms, tile_size);
    }
    
    // 边缘检测 - Canny 算法
    #[wasm_bindgen]
    pub fn canny_edge_detection(&mut self, low_threshold: f32, high_threshold: f32) -> js_sys::Uint8Array {
        // 1. 高斯模糊预处理
        self.gaussian_blur(1.4);
        
        // 2. 计算梯度
        let (grad_magnitude, grad_direction) = self.compute_gradients();
        
        // 3. 非极大值抑制
        let suppressed = self.non_maximum_suppression(&grad_magnitude, &grad_direction);
        
        // 4. 双阈值检测
        let edges = self.double_threshold(&suppressed, low_threshold, high_threshold);
        
        // 5. 边缘连接
        let final_edges = self.hysteresis_edge_tracking(&edges);
        
        js_sys::Uint8Array::from(&final_edges[..])
    }
    
    // 内容感知缩放 (Seam Carving)
    #[wasm_bindgen]
    pub fn seam_carving_resize(&mut self, new_width: u32, new_height: u32) {
        let width_diff = self.width as i32 - new_width as i32;
        let height_diff = self.height as i32 - new_height as i32;
        
        // 移除垂直缝
        for _ in 0..width_diff.abs() {
            if width_diff > 0 {
                self.remove_vertical_seam();
            } else {
                self.add_vertical_seam();
            }
        }
        
        // 移除水平缝
        for _ in 0..height_diff.abs() {
            if height_diff > 0 {
                self.remove_horizontal_seam();
            } else {
                self.add_horizontal_seam();
            }
        }
    }
    
    // 智能选择工具 - 基于图论的分割
    #[wasm_bindgen]
    pub fn intelligent_select(&self, seed_x: u32, seed_y: u32, threshold: f32) -> js_sys::Uint8Array {
        let mut visited = vec![false; (self.width * self.height) as usize];
        let mut selection = vec![0u8; (self.width * self.height) as usize];
        let mut queue = std::collections::VecDeque::new();
        
        let seed_index = (seed_y * self.width + seed_x) as usize;
        let seed_color = self.get_pixel_color(seed_x, seed_y);
        
        queue.push_back((seed_x, seed_y));
        visited[seed_index] = true;
        selection[seed_index] = 255;
        
        while let Some((x, y)) = queue.pop_front() {
            // 检查8邻域
            for dy in -1..=1 {
                for dx in -1..=1 {
                    if dx == 0 && dy == 0 {
                        continue;
                    }
                    
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    
                    if nx >= 0 && nx < self.width as i32 && ny >= 0 && ny < self.height as i32 {
                        let nx = nx as u32;
                        let ny = ny as u32;
                        let neighbor_index = (ny * self.width + nx) as usize;
                        
                        if !visited[neighbor_index] {
                            let neighbor_color = self.get_pixel_color(nx, ny);
                            let color_diff = self.color_distance(&seed_color, &neighbor_color);
                            
                            if color_diff < threshold {
                                visited[neighbor_index] = true;
                                selection[neighbor_index] = 255;
                                queue.push_back((nx, ny));
                            }
                        }
                    }
                }
            }
        }
        
        js_sys::Uint8Array::from(&selection[..])
    }
    
    // 辅助方法实现
    fn create_gaussian_kernel(&self, size: usize, sigma: f32) -> Vec<f32> {
        let mut kernel = vec![0.0; size];
        let center = size / 2;
        let mut sum = 0.0;
        
        for (i, k) in kernel.iter_mut().enumerate() {
            let x = (i as i32 - center as i32) as f32;
            *k = (-x * x / (2.0 * sigma * sigma)).exp();
            sum += *k;
        }
        
        // 归一化
        for k in &mut kernel {
            *k /= sum;
        }
        
        kernel
    }
    
    fn horizontal_blur(&mut self, kernel: &[f32]) {
        let radius = kernel.len() / 2;
        self.temp_buffer.clear();
        self.temp_buffer.resize((self.width * self.height * 4) as usize, 0.0);
        
        for y in 0..self.height {
            for x in 0..self.width {
                for c in 0..self.channels {
                    let mut sum = 0.0;
                    
                    for (i, &k) in kernel.iter().enumerate() {
                        let sample_x = (x as i32 + i as i32 - radius as i32)
                            .max(0)
                            .min(self.width as i32 - 1) as u32;
                        
                        let pixel_index = ((y * self.width + sample_x) * self.channels + c) as usize;
                        sum += self.data[pixel_index] as f32 * k;
                    }
                    
                    let temp_index = ((y * self.width + x) * self.channels + c) as usize;
                    self.temp_buffer[temp_index] = sum;
                }
            }
        }
        
        // 复制回原数组
        for (i, &value) in self.temp_buffer.iter().enumerate() {
            self.data[i] = value.round().max(0.0).min(255.0) as u8;
        }
    }
    
    fn compute_gradients(&self) -> (Vec<f32>, Vec<f32>) {
        let mut magnitude = vec![0.0; (self.width * self.height) as usize];
        let mut direction = vec![0.0; (self.width * self.height) as usize];
        
        // Sobel 算子
        let sobel_x = [-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0];
        let sobel_y = [-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0];
        
        for y in 1..(self.height - 1) {
            for x in 1..(self.width - 1) {
                let mut gx = 0.0;
                let mut gy = 0.0;
                
                for ky in 0..3 {
                    for kx in 0..3 {
                        let pixel_x = x + kx - 1;
                        let pixel_y = y + ky - 1;
                        let pixel_index = (pixel_y * self.width + pixel_x) as usize * 4;
                        
                        // 转为灰度值
                        let gray = (self.data[pixel_index] as f32 * 0.299 +
                                  self.data[pixel_index + 1] as f32 * 0.587 +
                                  self.data[pixel_index + 2] as f32 * 0.114);
                        
                        let kernel_index = ky * 3 + kx;
                        gx += gray * sobel_x[kernel_index];
                        gy += gray * sobel_y[kernel_index];
                    }
                }
                
                let index = (y * self.width + x) as usize;
                magnitude[index] = (gx * gx + gy * gy).sqrt();
                direction[index] = gy.atan2(gx);
            }
        }
        
        (magnitude, direction)
    }
    
    fn remove_vertical_seam(&mut self) {
        // 计算能量函数
        let energy = self.compute_energy();
        
        // 动态规划找到最小能量缝
        let seam = self.find_min_vertical_seam(&energy);
        
        // 移除缝
        let mut new_data = Vec::new();
        for y in 0..self.height {
            for x in 0..self.width {
                if x != seam[y as usize] {
                    let pixel_index = (y * self.width + x) as usize * 4;
                    new_data.extend_from_slice(&self.data[pixel_index..pixel_index + 4]);
                }
            }
        }
        
        self.width -= 1;
        self.data = new_data;
    }
    
    fn compute_energy(&self) -> Vec<f32> {
        let mut energy = vec![0.0; (self.width * self.height) as usize];
        
        for y in 0..self.height {
            for x in 0..self.width {
                let mut total_energy = 0.0;
                
                // 计算 x 方向梯度
                if x > 0 && x < self.width - 1 {
                    let left_index = (y * self.width + x - 1) as usize * 4;
                    let right_index = (y * self.width + x + 1) as usize * 4;
                    
                    for c in 0..3 {
                        let diff = self.data[right_index + c] as f32 - self.data[left_index + c] as f32;
                        total_energy += diff * diff;
                    }
                }
                
                // 计算 y 方向梯度
                if y > 0 && y < self.height - 1 {
                    let up_index = ((y - 1) * self.width + x) as usize * 4;
                    let down_index = ((y + 1) * self.width + x) as usize * 4;
                    
                    for c in 0..3 {
                        let diff = self.data[down_index + c] as f32 - self.data[up_index + c] as f32;
                        total_energy += diff * diff;
                    }
                }
                
                energy[(y * self.width + x) as usize] = total_energy.sqrt();
            }
        }
        
        energy
    }
}
```

**2. 性能优化策略**:

```rust
// SIMD 优化的像素处理
#[cfg(target_arch = "wasm32")]
use std::arch::wasm32::*;

impl ImageProcessor {
    // SIMD 优化的亮度调整
    pub fn adjust_brightness_simd(&mut self, adjustment: f32) {
        let adjustment_vec = f32x4_splat(adjustment);
        let chunks = self.data.chunks_exact_mut(16); // 4 像素 = 16 字节
        let remainder = chunks.remainder();
        
        for chunk in chunks {
            // 加载 4 个像素 (16 字节)
            let pixels = v128_load(chunk.as_ptr() as *const v128);
            
            // 转换为浮点数
            let r = f32x4_convert_i32x4_u(u32x4_extend_low_u16x8(u16x8_extend_low_u8x16(pixels)));
            let g = f32x4_convert_i32x4_u(u32x4_extend_high_u16x8(u16x8_extend_low_u8x16(pixels)));
            let b = f32x4_convert_i32x4_u(u32x4_extend_low_u16x8(u16x8_extend_high_u8x16(pixels)));
            let a = f32x4_convert_i32x4_u(u32x4_extend_high_u16x8(u16x8_extend_high_u8x16(pixels)));
            
            // 应用亮度调整
            let r_adj = f32x4_add(r, adjustment_vec);
            let g_adj = f32x4_add(g, adjustment_vec);
            let b_adj = f32x4_add(b, adjustment_vec);
            
            // 限制到 0-255 范围
            let zero = f32x4_splat(0.0);
            let max_val = f32x4_splat(255.0);
            
            let r_clamped = f32x4_max(zero, f32x4_min(max_val, r_adj));
            let g_clamped = f32x4_max(zero, f32x4_min(max_val, g_adj));
            let b_clamped = f32x4_max(zero, f32x4_min(max_val, b_adj));
            
            // 转换回整数并存储
            let r_int = i32x4_trunc_sat_f32x4(r_clamped);
            let g_int = i32x4_trunc_sat_f32x4(g_clamped);
            let b_int = i32x4_trunc_sat_f32x4(b_clamped);
            let a_int = i32x4_trunc_sat_f32x4(a);
            
            let result = u8x16_narrow_i16x8(
                i16x8_narrow_i32x4(r_int, g_int),
                i16x8_narrow_i32x4(b_int, a_int)
            );
            
            v128_store(chunk.as_mut_ptr() as *mut v128, result);
        }
        
        // 处理剩余像素
        for pixel in remainder.chunks_exact_mut(4) {
            for channel in &mut pixel[0..3] {
                let new_value = *channel as f32 + adjustment;
                *channel = new_value.max(0.0).min(255.0) as u8;
            }
        }
    }
    
    // 多线程处理（通过 Web Workers）
    pub fn parallel_filter(&mut self, filter_type: FilterType) -> js_sys::Promise {
        let (tx, rx) = std::sync::mpsc::channel();
        let worker_count = 4; // 可配置
        let tile_height = self.height / worker_count;
        
        for worker_id in 0..worker_count {
            let y_start = worker_id * tile_height;
            let y_end = if worker_id == worker_count - 1 {
                self.height
            } else {
                (worker_id + 1) * tile_height
            };
            
            // 发送数据到 Web Worker
            let tile_data = self.extract_tile(0, y_start, self.width, y_end);
            
            // 这里需要与 JavaScript 配合实现 Web Worker 通信
            // 简化示例，实际需要通过 postMessage 发送到 worker
        }
        
        // 返回 Promise，在所有 worker 完成后 resolve
        js_sys::Promise::new(&mut |resolve, reject| {
            // 异步等待所有 worker 完成
        })
    }
}

// 滤镜类型枚举
#[wasm_bindgen]
pub enum FilterType {
    Blur,
    Sharpen,
    EdgeDetect,
    Emboss,
    Custom,
}

// 图像块数据结构
#[wasm_bindgen]
pub struct ImageTile {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    data: Vec<u8>,
}
```

#### JavaScript 集成层

```javascript
// Photoshop Web 的主要架构
class PhotoshopEngine {
    constructor() {
        this.wasmModule = null;
        this.imageProcessor = null;
        this.filterWorkers = [];
        this.undoStack = [];
        this.redoStack = [];
    }
    
    async initialize() {
        // 加载 WASM 模块
        this.wasmModule = await import('./photoshop_engine.js');
        await this.wasmModule.default();
        
        // 初始化工作线程池
        this.initializeWorkerPool();
        
        console.log('Photoshop Engine initialized');
    }
    
    initializeWorkerPool() {
        const workerCount = navigator.hardwareConcurrency || 4;
        
        for (let i = 0; i < workerCount; i++) {
            const worker = new Worker('filter-worker.js');
            worker.onmessage = this.handleWorkerMessage.bind(this);
            this.filterWorkers.push({
                worker: worker,
                busy: false,
                id: i
            });
        }
    }
    
    loadImage(imageData) {
        const { width, height, data } = imageData;
        
        // 创建 WASM 图像处理器实例
        this.imageProcessor = new this.wasmModule.ImageProcessor(width, height);
        
        // 传输图像数据到 WASM
        const wasmData = new Uint8Array(this.wasmModule.memory.buffer, 
                                       this.imageProcessor.get_data_ptr(), 
                                       width * height * 4);
        wasmData.set(data);
        
        // 保存到撤销栈
        this.saveState();
    }
    
    async applyFilter(filterName, parameters = {}) {
        if (!this.imageProcessor) {
            throw new Error('No image loaded');
        }
        
        // 保存当前状态以支持撤销
        this.saveState();
        
        const startTime = performance.now();
        
        try {
            switch (filterName) {
                case 'gaussianBlur':
                    this.imageProcessor.gaussian_blur(parameters.radius || 5.0);
                    break;
                    
                case 'cannyEdge':
                    const edges = this.imageProcessor.canny_edge_detection(
                        parameters.lowThreshold || 50,
                        parameters.highThreshold || 150
                    );
                    return new Uint8Array(edges);
                    
                case 'adaptiveHistogram':
                    this.imageProcessor.adaptive_histogram_equalization(
                        parameters.clipLimit || 2.0,
                        parameters.tileSize || 8
                    );
                    break;
                    
                case 'seamCarving':
                    this.imageProcessor.seam_carving_resize(
                        parameters.newWidth,
                        parameters.newHeight
                    );
                    break;
                    
                default:
                    throw new Error(`Unknown filter: ${filterName}`);
            }
            
            const endTime = performance.now();
            console.log(`Filter ${filterName} applied in ${endTime - startTime}ms`);
            
            return this.getImageData();
            
        } catch (error) {
            // 如果出错，恢复上一个状态
            this.undo();
            throw error;
        }
    }
    
    // 智能选择工具
    intelligentSelect(x, y, threshold = 30) {
        if (!this.imageProcessor) {
            return null;
        }
        
        const selection = this.imageProcessor.intelligent_select(x, y, threshold);
        return new Uint8Array(selection);
    }
    
    // 批量处理支持
    async batchProcess(operations) {
        const results = [];
        
        for (const operation of operations) {
            const result = await this.applyFilter(operation.filter, operation.parameters);
            results.push(result);
            
            // 可以添加进度回调
            if (operation.onProgress) {
                operation.onProgress(results.length / operations.length);
            }
        }
        
        return results;
    }
    
    // 撤销/重做系统
    saveState() {
        if (this.imageProcessor) {
            const imageData = this.getImageData();
            this.undoStack.push({
                data: new Uint8Array(imageData.data),
                width: imageData.width,
                height: imageData.height,
                timestamp: Date.now()
            });
            
            // 限制撤销栈大小
            if (this.undoStack.length > 20) {
                this.undoStack.shift();
            }
            
            // 清空重做栈
            this.redoStack = [];
        }
    }
    
    undo() {
        if (this.undoStack.length > 1) {
            const currentState = this.undoStack.pop();
            this.redoStack.push(currentState);
            
            const previousState = this.undoStack[this.undoStack.length - 1];
            this.restoreState(previousState);
        }
    }
    
    redo() {
        if (this.redoStack.length > 0) {
            const state = this.redoStack.pop();
            this.undoStack.push(state);
            this.restoreState(state);
        }
    }
    
    restoreState(state) {
        // 重新创建图像处理器
        this.imageProcessor = new this.wasmModule.ImageProcessor(state.width, state.height);
        
        // 恢复图像数据
        const wasmData = new Uint8Array(this.wasmModule.memory.buffer,
                                       this.imageProcessor.get_data_ptr(),
                                       state.width * state.height * 4);
        wasmData.set(state.data);
    }
    
    getImageData() {
        if (!this.imageProcessor) {
            return null;
        }
        
        const width = this.imageProcessor.get_width();
        const height = this.imageProcessor.get_height();
        const dataPtr = this.imageProcessor.get_data_ptr();
        const dataLen = width * height * 4;
        
        const data = new Uint8Array(this.wasmModule.memory.buffer, dataPtr, dataLen);
        
        return {
            width: width,
            height: height,
            data: new Uint8Array(data) // 创建副本
        };
    }
    
    // 性能监控
    getPerformanceMetrics() {
        return {
            memoryUsage: this.wasmModule.memory.buffer.byteLength,
            undoStackSize: this.undoStack.length,
            redoStackSize: this.redoStack.length,
            workerStatus: this.filterWorkers.map(w => ({ id: w.id, busy: w.busy }))
        };
    }
    
    // 清理资源
    dispose() {
        if (this.imageProcessor) {
            this.imageProcessor.free();
            this.imageProcessor = null;
        }
        
        this.filterWorkers.forEach(worker => {
            worker.worker.terminate();
        });
        this.filterWorkers = [];
        
        this.undoStack = [];
        this.redoStack = [];
    }
}

// 使用示例
async function main() {
    const engine = new PhotoshopEngine();
    await engine.initialize();
    
    // 加载图像
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    
    engine.loadImage(imageData);
    
    // 应用滤镜
    await engine.applyFilter('gaussianBlur', { radius: 3.0 });
    await engine.applyFilter('adaptiveHistogram', { clipLimit: 2.0, tileSize: 8 });
    
    // 获取结果
    const result = engine.getImageData();
    ctx.putImageData(new ImageData(result.data, result.width, result.height), 0, 0);
    
    // 性能监控
    console.log('Performance:', engine.getPerformanceMetrics());
}
```

## 12.2 项目架构设计模式

### 12.2.1 分层架构模式

在大型 WebAssembly 项目中，分层架构有助于管理复杂性和维护性。

```
┌─────────────────────────────────────┐
│           前端 UI 层                │
│   (React/Vue/Angular + TypeScript) │
├─────────────────────────────────────┤
│          业务逻辑层                 │
│     (JavaScript/TypeScript)         │
├─────────────────────────────────────┤
│          WASM 接口层                │
│      (wasm-bindgen/JS Glue)         │
├─────────────────────────────────────┤
│          核心计算层                 │
│        (Rust/C++/AssemblyScript)    │
├─────────────────────────────────────┤
│          系统资源层                 │
│   (WebGL/WebAudio/FileSystem API)   │
└─────────────────────────────────────┘
```

#### 示例实现

```rust
// 核心计算层 - 纯算法实现
pub mod core {
    pub trait Processor {
        type Input;
        type Output;
        type Error;
        
        fn process(&mut self, input: Self::Input) -> Result<Self::Output, Self::Error>;
    }
    
    // 数据处理管道
    pub struct ProcessingPipeline<T> {
        processors: Vec<Box<dyn Processor<Input = T, Output = T, Error = ProcessingError>>>,
    }
    
    impl<T> ProcessingPipeline<T> {
        pub fn new() -> Self {
            ProcessingPipeline {
                processors: Vec::new(),
            }
        }
        
        pub fn add_processor<P>(&mut self, processor: P) 
        where 
            P: Processor<Input = T, Output = T, Error = ProcessingError> + 'static,
        {
            self.processors.push(Box::new(processor));
        }
        
        pub fn execute(&mut self, mut data: T) -> Result<T, ProcessingError> {
            for processor in &mut self.processors {
                data = processor.process(data)?;
            }
            Ok(data)
        }
    }
}

// WASM 接口层 - 与 JavaScript 的桥接
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct WasmEngine {
    pipeline: core::ProcessingPipeline<Vec<f32>>,
    config: EngineConfig,
}

#[wasm_bindgen]
pub struct EngineConfig {
    buffer_size: usize,
    thread_count: usize,
    enable_simd: bool,
}

#[wasm_bindgen]
impl WasmEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(config: EngineConfig) -> WasmEngine {
        let mut pipeline = core::ProcessingPipeline::new();
        
        // 根据配置添加处理器
        if config.enable_simd {
            pipeline.add_processor(SimdProcessor::new());
        }
        
        WasmEngine { pipeline, config }
    }
    
    #[wasm_bindgen]
    pub fn process_data(&mut self, data: &[f32]) -> Result<js_sys::Float32Array, JsValue> {
        let result = self.pipeline.execute(data.to_vec())
            .map_err(|e| JsValue::from_str(&format!("处理错误: {}", e)))?;
        
        Ok(js_sys::Float32Array::from(&result[..]))
    }
    
    #[wasm_bindgen]
    pub fn get_performance_info(&self) -> js_sys::Object {
        let info = js_sys::Object::new();
        
        js_sys::Reflect::set(
            &info, 
            &"buffer_size".into(), 
            &(self.config.buffer_size as u32).into()
        ).unwrap();
        
        js_sys::Reflect::set(
            &info, 
            &"thread_count".into(), 
            &(self.config.thread_count as u32).into()
        ).unwrap();
        
        info
    }
}

// 业务逻辑层 - JavaScript/TypeScript
```

```typescript
// 业务逻辑层实现
export class DataProcessingService {
    private wasmEngine: WasmEngine | null = null;
    private isInitialized = false;
    
    async initialize(config: EngineConfig): Promise<void> {
        // 加载 WASM 模块
        const wasmModule = await import('./wasm_engine.js');
        await wasmModule.default();
        
        this.wasmEngine = new wasmModule.WasmEngine(config);
        this.isInitialized = true;
    }
    
    async processDataset(dataset: Float32Array[]): Promise<Float32Array[]> {
        if (!this.isInitialized || !this.wasmEngine) {
            throw new Error('Engine not initialized');
        }
        
        const results: Float32Array[] = [];
        
        for (const data of dataset) {
            try {
                const result = this.wasmEngine.process_data(data);
                results.push(result);
            } catch (error) {
                console.error('Processing failed:', error);
                throw error;
            }
        }
        
        return results;
    }
    
    getPerformanceMetrics(): PerformanceMetrics {
        if (!this.wasmEngine) {
            throw new Error('Engine not initialized');
        }
        
        const wasmInfo = this.wasmEngine.get_performance_info();
        
        return {
            bufferSize: wasmInfo.buffer_size,
            threadCount: wasmInfo.thread_count,
            memoryUsage: performance.memory?.usedJSHeapSize || 0,
            wasmMemoryUsage: this.getWasmMemoryUsage()
        };
    }
    
    private getWasmMemoryUsage(): number {
        // 获取 WASM 内存使用情况
        return 0; // 实际实现需要从 WASM 获取
    }
}

// 前端 UI 层集成
export class ProcessingUI {
    private service: DataProcessingService;
    private progressCallback?: (progress: number) => void;
    
    constructor() {
        this.service = new DataProcessingService();
    }
    
    async initializeEngine(): Promise<void> {
        const config = {
            buffer_size: 1024 * 1024, // 1MB
            thread_count: navigator.hardwareConcurrency || 4,
            enable_simd: this.checkSimdSupport()
        };
        
        await this.service.initialize(config);
    }
    
    async processFiles(files: File[]): Promise<void> {
        const datasets: Float32Array[] = [];
        
        // 读取文件数据
        for (const file of files) {
            const data = await this.readFileAsFloat32Array(file);
            datasets.push(data);
        }
        
        // 批量处理
        const results = await this.service.processDataset(datasets);
        
        // 显示结果
        this.displayResults(results);
    }
    
    setProgressCallback(callback: (progress: number) => void): void {
        this.progressCallback = callback;
    }
    
    private checkSimdSupport(): boolean {
        // 检测 SIMD 支持
        try {
            return typeof WebAssembly.Module.prototype.exports !== 'undefined';
        } catch {
            return false;
        }
    }
    
    private async readFileAsFloat32Array(file: File): Promise<Float32Array> {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            
            reader.onload = () => {
                try {
                    const arrayBuffer = reader.result as ArrayBuffer;
                    const float32Array = new Float32Array(arrayBuffer);
                    resolve(float32Array);
                } catch (error) {
                    reject(error);
                }
            };
            
            reader.onerror = () => reject(reader.error);
            reader.readAsArrayBuffer(file);
        });
    }
    
    private displayResults(results: Float32Array[]): void {
        // 实现结果显示逻辑
        console.log(`处理完成，共 ${results.length} 个结果`);
    }
}

// 类型定义
interface EngineConfig {
    buffer_size: number;
    thread_count: number;
    enable_simd: boolean;
}

interface PerformanceMetrics {
    bufferSize: number;
    threadCount: number;
    memoryUsage: number;
    wasmMemoryUsage: number;
}
```

### 12.2.2 微服务架构模式

对于复杂的 WebAssembly 应用，可以采用微服务架构，将不同功能模块独立部署。

```rust
// 模块化 WASM 服务设计
pub mod services {
    use wasm_bindgen::prelude::*;
    
    // 基础服务特征
    pub trait WasmService {
        fn initialize(&mut self) -> Result<(), ServiceError>;
        fn process(&mut self, request: ServiceRequest) -> Result<ServiceResponse, ServiceError>;
        fn shutdown(&mut self) -> Result<(), ServiceError>;
        fn get_status(&self) -> ServiceStatus;
    }
    
    // 图像处理服务
    #[wasm_bindgen]
    pub struct ImageProcessingService {
        initialized: bool,
        cache: std::collections::HashMap<String, Vec<u8>>,
        stats: ProcessingStats,
    }
    
    #[wasm_bindgen]
    impl ImageProcessingService {
        #[wasm_bindgen(constructor)]
        pub fn new() -> ImageProcessingService {
            ImageProcessingService {
                initialized: false,
                cache: std::collections::HashMap::new(),
                stats: ProcessingStats::new(),
            }
        }
        
        #[wasm_bindgen]
        pub fn resize_image(&mut self, data: &[u8], new_width: u32, new_height: u32) -> Result<js_sys::Uint8Array, JsValue> {
            if !self.initialized {
                return Err(JsValue::from_str("Service not initialized"));
            }
            
            self.stats.increment_request_count();
            let start_time = js_sys::Date::now();
            
            // 实际的图像缩放算法
            let result = self.perform_resize(data, new_width, new_height)
                .map_err(|e| JsValue::from_str(&format!("Resize failed: {}", e)))?;
            
            let duration = js_sys::Date::now() - start_time;
            self.stats.add_processing_time(duration);
            
            Ok(js_sys::Uint8Array::from(&result[..]))
        }
        
        #[wasm_bindgen]
        pub fn apply_filter(&mut self, data: &[u8], filter_type: &str, parameters: &js_sys::Object) -> Result<js_sys::Uint8Array, JsValue> {
            let filter_params = self.parse_filter_parameters(filter_type, parameters)?;
            
            match filter_type {
                "blur" => self.apply_blur_filter(data, &filter_params),
                "sharpen" => self.apply_sharpen_filter(data, &filter_params),
                "contrast" => self.apply_contrast_filter(data, &filter_params),
                _ => Err(JsValue::from_str("Unknown filter type"))
            }
        }
        
        #[wasm_bindgen]
        pub fn get_cache_stats(&self) -> js_sys::Object {
            let stats = js_sys::Object::new();
            
            js_sys::Reflect::set(&stats, &"cache_size".into(), &(self.cache.len() as u32).into()).unwrap();
            js_sys::Reflect::set(&stats, &"request_count".into(), &self.stats.request_count.into()).unwrap();
            js_sys::Reflect::set(&stats, &"average_processing_time".into(), &self.stats.average_processing_time().into()).unwrap();
            
            stats
        }
    }
    
    // 数据分析服务
    #[wasm_bindgen]
    pub struct DataAnalysisService {
        models: Vec<Box<dyn AnalysisModel>>,
        preprocessing_pipeline: Vec<Box<dyn DataPreprocessor>>,
    }
    
    #[wasm_bindgen]
    impl DataAnalysisService {
        #[wasm_bindgen(constructor)]
        pub fn new() -> DataAnalysisService {
            DataAnalysisService {
                models: Vec::new(),
                preprocessing_pipeline: Vec::new(),
            }
        }
        
        #[wasm_bindgen]
        pub fn train_model(&mut self, training_data: &[f32], labels: &[f32], model_type: &str) -> Result<String, JsValue> {
            let model_id = uuid::Uuid::new_v4().to_string();
            
            let model: Box<dyn AnalysisModel> = match model_type {
                "linear_regression" => Box::new(LinearRegressionModel::new()),
                "neural_network" => Box::new(NeuralNetworkModel::new()),
                "decision_tree" => Box::new(DecisionTreeModel::new()),
                _ => return Err(JsValue::from_str("Unsupported model type"))
            };
            
            // 训练模型的实现...
            
            self.models.push(model);
            Ok(model_id)
        }
        
        #[wasm_bindgen]
        pub fn predict(&self, model_id: &str, input_data: &[f32]) -> Result<js_sys::Float32Array, JsValue> {
            // 查找对应的模型并进行预测
            // 实现细节...
            Ok(js_sys::Float32Array::new(&js_sys::Object::new()))
        }
    }
    
    // 加密服务
    #[wasm_bindgen]
    pub struct CryptographyService {
        key_store: std::collections::HashMap<String, Vec<u8>>,
    }
    
    #[wasm_bindgen]
    impl CryptographyService {
        #[wasm_bindgen(constructor)]
        pub fn new() -> CryptographyService {
            CryptographyService {
                key_store: std::collections::HashMap::new(),
            }
        }
        
        #[wasm_bindgen]
        pub fn generate_key_pair(&mut self, algorithm: &str) -> Result<js_sys::Object, JsValue> {
            match algorithm {
                "rsa-2048" => self.generate_rsa_key_pair(2048),
                "ed25519" => self.generate_ed25519_key_pair(),
                "secp256k1" => self.generate_secp256k1_key_pair(),
                _ => Err(JsValue::from_str("Unsupported algorithm"))
            }
        }
        
        #[wasm_bindgen]
        pub fn encrypt(&self, data: &[u8], key_id: &str) -> Result<js_sys::Uint8Array, JsValue> {
            let key = self.key_store.get(key_id)
                .ok_or_else(|| JsValue::from_str("Key not found"))?;
            
            // 实际的加密实现
            let encrypted = self.perform_encryption(data, key)?;
            Ok(js_sys::Uint8Array::from(&encrypted[..]))
        }
        
        #[wasm_bindgen]
        pub fn decrypt(&self, encrypted_data: &[u8], key_id: &str) -> Result<js_sys::Uint8Array, JsValue> {
            let key = self.key_store.get(key_id)
                .ok_or_else(|| JsValue::from_str("Key not found"))?;
            
            // 实际的解密实现
            let decrypted = self.perform_decryption(encrypted_data, key)?;
            Ok(js_sys::Uint8Array::from(&decrypted[..]))
        }
    }
}

// 服务管理器
#[wasm_bindgen]
pub struct ServiceManager {
    services: std::collections::HashMap<String, Box<dyn services::WasmService>>,
    service_registry: ServiceRegistry,
}

#[wasm_bindgen]
impl ServiceManager {
    #[wasm_bindgen(constructor)]
    pub fn new() -> ServiceManager {
        ServiceManager {
            services: std::collections::HashMap::new(),
            service_registry: ServiceRegistry::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn register_service(&mut self, service_name: &str, service_type: &str) -> Result<(), JsValue> {
        let service: Box<dyn services::WasmService> = match service_type {
            "image_processing" => Box::new(services::ImageProcessingService::new()),
            "data_analysis" => Box::new(services::DataAnalysisService::new()),
            "cryptography" => Box::new(services::CryptographyService::new()),
            _ => return Err(JsValue::from_str("Unknown service type"))
        };
        
        self.services.insert(service_name.to_string(), service);
        self.service_registry.register(service_name, service_type);
        
        Ok(())
    }
    
    #[wasm_bindgen]
    pub fn get_service_status(&self, service_name: &str) -> Result<js_sys::Object, JsValue> {
        let service = self.services.get(service_name)
            .ok_or_else(|| JsValue::from_str("Service not found"))?;
        
        let status = service.get_status();
        let status_obj = js_sys::Object::new();
        
        js_sys::Reflect::set(&status_obj, &"name".into(), &service_name.into()).unwrap();
        js_sys::Reflect::set(&status_obj, &"status".into(), &status.state.into()).unwrap();
        js_sys::Reflect::set(&status_obj, &"uptime".into(), &status.uptime.into()).unwrap();
        
        Ok(status_obj)
    }
    
    #[wasm_bindgen]
    pub fn list_services(&self) -> js_sys::Array {
        let services = js_sys::Array::new();
        
        for service_name in self.services.keys() {
            services.push(&service_name.into());
        }
        
        services
    }
}
```

### 12.2.3 事件驱动架构

对于需要实时响应的应用，事件驱动架构提供了良好的扩展性。

```rust
// 事件系统设计
use std::collections::HashMap;
use wasm_bindgen::prelude::*;

// 事件类型定义
#[wasm_bindgen]
#[derive(Clone, Debug)]
pub struct Event {
    event_type: String,
    payload: String, // JSON serialized data
    timestamp: f64,
    source: String,
}

#[wasm_bindgen]
impl Event {
    #[wasm_bindgen(constructor)]
    pub fn new(event_type: String, payload: String, source: String) -> Event {
        Event {
            event_type,
            payload,
            timestamp: js_sys::Date::now(),
            source,
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn event_type(&self) -> String {
        self.event_type.clone()
    }
    
    #[wasm_bindgen(getter)]
    pub fn payload(&self) -> String {
        self.payload.clone()
    }
    
    #[wasm_bindgen(getter)]
    pub fn timestamp(&self) -> f64 {
        self.timestamp
    }
}

// 事件总线
#[wasm_bindgen]
pub struct EventBus {
    subscribers: HashMap<String, Vec<js_sys::Function>>,
    event_history: Vec<Event>,
    max_history_size: usize,
}

#[wasm_bindgen]
impl EventBus {
    #[wasm_bindgen(constructor)]
    pub fn new() -> EventBus {
        EventBus {
            subscribers: HashMap::new(),
            event_history: Vec::new(),
            max_history_size: 1000,
        }
    }
    
    #[wasm_bindgen]
    pub fn subscribe(&mut self, event_type: &str, callback: js_sys::Function) {
        self.subscribers
            .entry(event_type.to_string())
            .or_insert_with(Vec::new)
            .push(callback);
    }
    
    #[wasm_bindgen]
    pub fn unsubscribe(&mut self, event_type: &str, callback: &js_sys::Function) {
        if let Some(callbacks) = self.subscribers.get_mut(event_type) {
            callbacks.retain(|cb| !js_sys::Object::is(cb, callback));
        }
    }
    
    #[wasm_bindgen]
    pub fn emit(&mut self, event: Event) -> Result<(), JsValue> {
        // 记录事件历史
        self.event_history.push(event.clone());
        if self.event_history.len() > self.max_history_size {
            self.event_history.remove(0);
        }
        
        // 通知订阅者
        if let Some(callbacks) = self.subscribers.get(&event.event_type) {
            for callback in callbacks {
                let this = JsValue::NULL;
                let event_js = JsValue::from(event.clone());
                callback.call1(&this, &event_js)?;
            }
        }
        
        Ok(())
    }
    
    #[wasm_bindgen]
    pub fn get_event_history(&self, event_type: Option<String>) -> js_sys::Array {
        let history = js_sys::Array::new();
        
        for event in &self.event_history {
            if let Some(ref filter_type) = event_type {
                if &event.event_type != filter_type {
                    continue;
                }
            }
            
            history.push(&JsValue::from(event.clone()));
        }
        
        history
    }
}

// 实时数据处理器
#[wasm_bindgen]
pub struct RealTimeProcessor {
    event_bus: EventBus,
    processing_queue: Vec<Event>,
    batch_size: usize,
    processing_interval: f64,
}

#[wasm_bindgen]
impl RealTimeProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(batch_size: usize, processing_interval: f64) -> RealTimeProcessor {
        RealTimeProcessor {
            event_bus: EventBus::new(),
            processing_queue: Vec::new(),
            batch_size,
            processing_interval,
        }
    }
    
    #[wasm_bindgen]
    pub fn add_event(&mut self, event: Event) {
        self.processing_queue.push(event.clone());
        
        // 立即发布事件
        let _ = self.event_bus.emit(event);
        
        // 检查是否需要批处理
        if self.processing_queue.len() >= self.batch_size {
            self.process_batch();
        }
    }
    
    #[wasm_bindgen]
    pub fn process_batch(&mut self) {
        if self.processing_queue.is_empty() {
            return;
        }
        
        let batch = self.processing_queue.drain(..).collect::<Vec<_>>();
        
        // 分析事件模式
        let patterns = self.analyze_event_patterns(&batch);
        
        // 生成分析结果事件
        for pattern in patterns {
            let analysis_event = Event::new(
                "pattern_detected".to_string(),
                pattern.to_json(),
                "real_time_processor".to_string(),
            );
            
            let _ = self.event_bus.emit(analysis_event);
        }
    }
    
    #[wasm_bindgen]
    pub fn subscribe_to_events(&mut self, event_type: &str, callback: js_sys::Function) {
        self.event_bus.subscribe(event_type, callback);
    }
    
    fn analyze_event_patterns(&self, events: &[Event]) -> Vec<EventPattern> {
        let mut patterns = Vec::new();
        
        // 频率分析
        let mut type_counts = HashMap::new();
        for event in events {
            *type_counts.entry(&event.event_type).or_insert(0) += 1;
        }
        
        // 检测高频事件
        for (event_type, count) in type_counts {
            if count > 10 { // 阈值可配置
                patterns.push(EventPattern::HighFrequency {
                    event_type: event_type.clone(),
                    count,
                    time_window: self.processing_interval,
                });
            }
        }
        
        // 时间序列分析
        if events.len() > 2 {
            let time_diffs: Vec<f64> = events.windows(2)
                .map(|window| window[1].timestamp - window[0].timestamp)
                .collect();
            
            let avg_interval = time_diffs.iter().sum::<f64>() / time_diffs.len() as f64;
            
            if avg_interval < 100.0 { // 100ms 内的快速事件
                patterns.push(EventPattern::RapidSequence {
                    event_count: events.len(),
                    average_interval: avg_interval,
                });
            }
        }
        
        patterns
    }
}

// 事件模式定义
#[derive(Debug, Clone)]
pub enum EventPattern {
    HighFrequency {
        event_type: String,
        count: usize,
        time_window: f64,
    },
    RapidSequence {
        event_count: usize,
        average_interval: f64,
    },
    AnomalousPattern {
        description: String,
        confidence: f64,
    },
}

impl EventPattern {
    pub fn to_json(&self) -> String {
        match self {
            EventPattern::HighFrequency { event_type, count, time_window } => {
                format!(
                    r#"{{"type":"high_frequency","event_type":"{}","count":{},"time_window":{}}}"#,
                    event_type, count, time_window
                )
            }
            EventPattern::RapidSequence { event_count, average_interval } => {
                format!(
                    r#"{{"type":"rapid_sequence","event_count":{},"average_interval":{}}}"#,
                    event_count, average_interval
                )
            }
            EventPattern::AnomalousPattern { description, confidence } => {
                format!(
                    r#"{{"type":"anomalous","description":"{}","confidence":{}}}"#,
                    description, confidence
                )
            }
        }
    }
}
```

## 12.3 集成模式与最佳实践

### 12.3.1 渐进式增强模式

对于现有的 Web 应用，WebAssembly 可以作为性能增强的手段逐步引入。

```typescript
// 渐进式增强的实现策略
export class ProgressiveEnhancement {
    private wasmAvailable = false;
    private wasmModule: any = null;
    private fallbackImplementation: FallbackProcessor;
    
    constructor() {
        this.fallbackImplementation = new FallbackProcessor();
        this.detectWasmSupport();
    }
    
    private async detectWasmSupport(): Promise<void> {
        try {
            if (typeof WebAssembly === 'object' && typeof WebAssembly.instantiate === 'function') {
                // 尝试加载 WASM 模块
                const wasmModule = await import('./enhanced_processor.js');
                await wasmModule.default();
                
                this.wasmModule = wasmModule;
                this.wasmAvailable = true;
                
                console.log('WebAssembly 增强功能已启用');
            }
        } catch (error) {
            console.warn('WebAssembly 不可用，使用 JavaScript 回退:', error);
            this.wasmAvailable = false;
        }
    }
    
    // 智能处理方法选择
    async processData(data: Float32Array, options: ProcessingOptions): Promise<Float32Array> {
        // 根据数据大小和复杂度选择处理方式
        const complexity = this.assessComplexity(data, options);
        
        if (this.wasmAvailable && complexity.shouldUseWasm) {
            return this.processWithWasm(data, options);
        } else {
            return this.processWithJavaScript(data, options);
        }
    }
    
    private assessComplexity(data: Float32Array, options: ProcessingOptions): ComplexityAssessment {
        const dataSize = data.length;
        const algorithmComplexity = this.getAlgorithmComplexity(options.algorithm);
        
        // 简单的启发式规则
        const shouldUseWasm = dataSize > 10000 || algorithmComplexity > 2;
        
        return {
            dataSize,
            algorithmComplexity,
            shouldUseWasm,
            estimatedJsTime: this.estimateJavaScriptTime(dataSize, algorithmComplexity),
            estimatedWasmTime: this.estimateWasmTime(dataSize, algorithmComplexity)
        };
    }
    
    private async processWithWasm(data: Float32Array, options: ProcessingOptions): Promise<Float32Array> {
        if (!this.wasmModule) {
            throw new Error('WASM module not available');
        }
        
        const processor = new this.wasmModule.EnhancedProcessor();
        
        try {
            const result = processor.process(data, options);
            return result;
        } finally {
            processor.free(); // 清理 WASM 资源
        }
    }
    
    private async processWithJavaScript(data: Float32Array, options: ProcessingOptions): Promise<Float32Array> {
        return this.fallbackImplementation.process(data, options);
    }
    
    // 性能监控和自适应选择
    async processWithAdaptiveSelection(data: Float32Array, options: ProcessingOptions): Promise<Float32Array> {
        const wasmStart = performance.now();
        
        if (this.wasmAvailable) {
            try {
                const wasmResult = await this.processWithWasm(data, options);
                const wasmTime = performance.now() - wasmStart;
                
                // 记录 WASM 性能
                this.recordPerformance('wasm', wasmTime, data.length);
                
                return wasmResult;
            } catch (error) {
                console.warn('WASM 处理失败，切换到 JavaScript:', error);
            }
        }
        
        // 回退到 JavaScript
        const jsStart = performance.now();
        const jsResult = await this.processWithJavaScript(data, options);
        const jsTime = performance.now() - jsStart;
        
        this.recordPerformance('javascript', jsTime, data.length);
        
        return jsResult;
    }
    
    private recordPerformance(method: 'wasm' | 'javascript', time: number, dataSize: number): void {
        const metrics = {
            method,
            time,
            dataSize,
            timestamp: Date.now(),
            throughput: dataSize / time // 元素/毫秒
        };
        
        // 发送到分析服务或本地存储
        this.sendMetrics(metrics);
    }
    
    getPerformanceReport(): PerformanceReport {
        return {
            wasmAvailable: this.wasmAvailable,
            totalProcessingOperations: this.getTotalOperations(),
            averageWasmTime: this.getAverageTime('wasm'),
            averageJavaScriptTime: this.getAverageTime('javascript'),
            recommendedMethod: this.getRecommendedMethod()
        };
    }
}

// JavaScript 回退实现
class FallbackProcessor {
    process(data: Float32Array, options: ProcessingOptions): Promise<Float32Array> {
        return new Promise((resolve) => {
            // 使用 Web Workers 进行后台处理以避免阻塞主线程
            const worker = new Worker('js-processor-worker.js');
            
            worker.postMessage({ data, options });
            
            worker.onmessage = (event) => {
                resolve(new Float32Array(event.data.result));
                worker.terminate();
            };
        });
    }
}

// 功能检测和优雅降级
export class FeatureDetection {
    static async detectCapabilities(): Promise<BrowserCapabilities> {
        const capabilities: BrowserCapabilities = {
            webAssembly: false,
            sharedArrayBuffer: false,
            webWorkers: false,
            simd: false,
            threads: false,
            bigInt: false
        };
        
        // WebAssembly 基础支持
        capabilities.webAssembly = typeof WebAssembly === 'object';
        
        // SharedArrayBuffer 支持 (用于多线程)
        capabilities.sharedArrayBuffer = typeof SharedArrayBuffer !== 'undefined';
        
        // Web Workers 支持
        capabilities.webWorkers = typeof Worker !== 'undefined';
        
        // BigInt 支持
        capabilities.bigInt = typeof BigInt !== 'undefined';
        
        if (capabilities.webAssembly) {
            // SIMD 支持检测
            try {
                await WebAssembly.instantiate(new Uint8Array([
                    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
                    0x01, 0x04, 0x01, 0x60, 0x00, 0x00, 0x03, 0x02,
                    0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00, 0xfd,
                    0x0c, 0x00, 0x00, 0x00, 0x00, 0x0b
                ]));
                capabilities.simd = true;
            } catch {
                capabilities.simd = false;
            }
            
            // 线程支持检测
            capabilities.threads = capabilities.sharedArrayBuffer && capabilities.webWorkers;
        }
        
        return capabilities;
    }
    
    static createOptimalConfiguration(capabilities: BrowserCapabilities): ProcessingConfiguration {
        return {
            useWasm: capabilities.webAssembly,
            useSimd: capabilities.simd,
            useThreads: capabilities.threads,
            workerCount: capabilities.webWorkers ? (navigator.hardwareConcurrency || 4) : 0,
            batchSize: capabilities.webAssembly ? 1024 : 256,
            memoryStrategy: capabilities.sharedArrayBuffer ? 'shared' : 'copied'
        };
    }
}

// 类型定义
interface ProcessingOptions {
    algorithm: string;
    parameters: Record<string, any>;
    precision: 'float32' | 'float64';
    parallel: boolean;
}

interface ComplexityAssessment {
    dataSize: number;
    algorithmComplexity: number;
    shouldUseWasm: boolean;
    estimatedJsTime: number;
    estimatedWasmTime: number;
}

interface BrowserCapabilities {
    webAssembly: boolean;
    sharedArrayBuffer: boolean;
    webWorkers: boolean;
    simd: boolean;
    threads: boolean;
    bigInt: boolean;
}

interface ProcessingConfiguration {
    useWasm: boolean;
    useSimd: boolean;
    useThreads: boolean;
    workerCount: number;
    batchSize: number;
    memoryStrategy: 'shared' | 'copied';
}

interface PerformanceReport {
    wasmAvailable: boolean;
    totalProcessingOperations: number;
    averageWasmTime: number;
    averageJavaScriptTime: number;
    recommendedMethod: 'wasm' | 'javascript';
}
```

### 12.3.2 测试策略

完整的测试策略对于 WebAssembly 项目至关重要。

```rust
// WASM 模块的单元测试
#[cfg(test)]
mod tests {
    use super::*;
    use wasm_bindgen_test::*;
    
    wasm_bindgen_test_configure!(run_in_browser);
    
    #[wasm_bindgen_test]
    fn test_basic_computation() {
        let mut processor = ImageProcessor::new(100, 100);
        
        // 测试基本功能
        let result = processor.gaussian_blur(5.0);
        assert!(result.is_ok());
    }
    
    #[wasm_bindgen_test]
    fn test_performance_requirements() {
        let mut processor = ImageProcessor::new(1000, 1000);
        
        let start_time = js_sys::Date::now();
        processor.gaussian_blur(10.0);
        let end_time = js_sys::Date::now();
        
        let duration = end_time - start_time;
        
        // 性能要求：大图像处理应在 1 秒内完成
        assert!(duration < 1000.0, "处理时间超出要求: {}ms", duration);
    }
    
    #[wasm_bindgen_test]
    fn test_memory_usage() {
        let processor = ImageProcessor::new(500, 500);
        
        // 检查内存使用是否在合理范围内
        let memory_usage = get_wasm_memory_usage();
        let expected_max = 500 * 500 * 4 * 2; // 图像数据 + 临时缓冲区
        
        assert!(memory_usage < expected_max, "内存使用超出预期: {}", memory_usage);
    }
    
    #[wasm_bindgen_test]
    async fn test_concurrent_operations() {
        let mut processor1 = ImageProcessor::new(100, 100);
        let mut processor2 = ImageProcessor::new(100, 100);
        
        // 测试并发操作
        let future1 = async { processor1.gaussian_blur(3.0) };
        let future2 = async { processor2.gaussian_blur(5.0) };
        
        let (result1, result2) = futures::join!(future1, future2);
        
        assert!(result1.is_ok() && result2.is_ok());
    }
}

// 集成测试工具
#[wasm_bindgen]
pub struct TestHarness {
    test_results: Vec<TestResult>,
    performance_metrics: Vec<PerformanceMetric>,
}

#[wasm_bindgen]
impl TestHarness {
    #[wasm_bindgen(constructor)]
    pub fn new() -> TestHarness {
        TestHarness {
            test_results: Vec::new(),
            performance_metrics: Vec::new(),
        }
    }
    
    #[wasm_bindgen]
    pub fn run_benchmark_suite(&mut self) -> js_sys::Promise {
        let benchmarks = vec![
            ("small_image_blur", 100, 100),
            ("medium_image_blur", 500, 500),
            ("large_image_blur", 1000, 1000),
        ];
        
        // 返回 Promise 以支持异步测试
        js_sys::Promise::new(&mut |resolve, reject| {
            for (name, width, height) in benchmarks {
                match self.run_single_benchmark(name, width, height) {
                    Ok(metric) => {
                        self.performance_metrics.push(metric);
                    }
                    Err(e) => {
                        reject.call1(&JsValue::NULL, &JsValue::from_str(&e)).unwrap();
                        return;
                    }
                }
            }
            
            let results = self.get_benchmark_results();
            resolve.call1(&JsValue::NULL, &results).unwrap();
        })
    }
    
    fn run_single_benchmark(&self, name: &str, width: u32, height: u32) -> Result<PerformanceMetric, String> {
        let mut processor = ImageProcessor::new(width, height);
        
        let start_time = js_sys::Date::now();
        let start_memory = get_wasm_memory_usage();
        
        // 执行基准测试
        processor.gaussian_blur(5.0);
        
        let end_time = js_sys::Date::now();
        let end_memory = get_wasm_memory_usage();
        
        let duration = end_time - start_time;
        let memory_delta = end_memory - start_memory;
        
        Ok(PerformanceMetric {
            test_name: name.to_string(),
            duration,
            memory_delta,
            throughput: (width * height) as f64 / duration,
            success: true,
        })
    }
    
    #[wasm_bindgen]
    pub fn get_benchmark_results(&self) -> js_sys::Object {
        let results = js_sys::Object::new();
        
        let metrics_array = js_sys::Array::new();
        for metric in &self.performance_metrics {
            let metric_obj = js_sys::Object::new();
            
            js_sys::Reflect::set(&metric_obj, &"test_name".into(), &metric.test_name.clone().into()).unwrap();
            js_sys::Reflect::set(&metric_obj, &"duration".into(), &metric.duration.into()).unwrap();
            js_sys::Reflect::set(&metric_obj, &"memory_delta".into(), &(metric.memory_delta as f64).into()).unwrap();
            js_sys::Reflect::set(&metric_obj, &"throughput".into(), &metric.throughput.into()).unwrap();
            
            metrics_array.push(&metric_obj);
        }
        
        js_sys::Reflect::set(&results, &"metrics".into(), &metrics_array).unwrap();
        
        results
    }
}

#[derive(Clone, Debug)]
struct TestResult {
    test_name: String,
    passed: bool,
    error_message: Option<String>,
    duration: f64,
}

#[derive(Clone, Debug)]
struct PerformanceMetric {
    test_name: String,
    duration: f64,
    memory_delta: usize,
    throughput: f64,
    success: bool,
}

// 辅助函数
fn get_wasm_memory_usage() -> usize {
    // 实际实现需要通过 WebAssembly.Memory 获取
    0
}
```

**JavaScript 端的端到端测试**:

```typescript
// E2E 测试套件
import { test, expect } from '@playwright/test';

class WasmTestSuite {
    async runCompleteTestSuite() {
        await this.testModuleLoading();
        await this.testFunctionalCorrectness();
        await this.testPerformanceRequirements();
        await this.testErrorHandling();
        await this.testMemoryManagement();
        await this.testBrowserCompatibility();
    }
    
    async testModuleLoading() {
        test('WASM module should load successfully', async ({ page }) => {
            await page.goto('/wasm-app');
            
            // 等待 WASM 模块加载
            await page.waitForFunction(() => window.wasmLoaded === true);
            
            // 检查基本功能是否可用
            const result = await page.evaluate(() => {
                return window.wasmModule.test_basic_function();
            });
            
            expect(result).toBeTruthy();
        });
    }
    
    async testFunctionalCorrectness() {
        test('Image processing should produce correct results', async ({ page }) => {
            await page.goto('/image-editor');
            
            // 上传测试图像
            await page.setInputFiles('#image-input', 'test-image.png');
            
            // 应用模糊滤镜
            await page.click('#blur-filter');
            await page.fill('#blur-radius', '5');
            await page.click('#apply-filter');
            
            // 等待处理完成
            await page.waitForSelector('#processing-complete');
            
            // 验证结果
            const result = await page.evaluate(() => {
                const canvas = document.getElementById('result-canvas');
                return canvas.toDataURL();
            });
            
            expect(result).toContain('data:image/png');
        });
    }
    
    async testPerformanceRequirements() {
        test('Large image processing should meet performance requirements', async ({ page }) => {
            await page.goto('/performance-test');
            
            const startTime = Date.now();
            
            const result = await page.evaluate(() => {
                return window.runPerformanceTest('large_image_blur');
            });
            
            const endTime = Date.now();
            const duration = endTime - startTime;
            
            // 性能要求检查
            expect(duration).toBeLessThan(5000); // 5秒内完成
            expect(result.success).toBe(true);
        });
    }
    
    async testErrorHandling() {
        test('Should handle invalid input gracefully', async ({ page }) => {
            await page.goto('/error-test');
            
            // 测试各种错误情况
            const errorTests = [
                { input: null, expectedError: 'Invalid input' },
                { input: [], expectedError: 'Empty data' },
                { input: 'invalid', expectedError: 'Type error' }
            ];
            
            for (const errorTest of errorTests) {
                const result = await page.evaluate((test) => {
                    try {
                        window.wasmModule.process_data(test.input);
                        return { success: true, error: null };
                    } catch (error) {
                        return { success: false, error: error.message };
                    }
                }, errorTest);
                
                expect(result.success).toBe(false);
                expect(result.error).toContain(errorTest.expectedError);
            }
        });
    }
    
    async testMemoryManagement() {
        test('Should not have memory leaks', async ({ page }) => {
            await page.goto('/memory-test');
            
            // 获取初始内存使用
            const initialMemory = await page.evaluate(() => {
                return performance.memory.usedJSHeapSize;
            });
            
            // 执行大量操作
            await page.evaluate(() => {
                for (let i = 0; i < 1000; i++) {
                    const processor = new window.wasmModule.ImageProcessor(100, 100);
                    processor.gaussian_blur(3.0);
                    processor.free(); // 确保清理
                }
            });
            
            // 强制垃圾回收
            await page.evaluate(() => {
                if (window.gc) {
                    window.gc();
                }
            });
            
            // 检查内存使用
            const finalMemory = await page.evaluate(() => {
                return performance.memory.usedJSHeapSize;
            });
            
            const memoryGrowth = finalMemory - initialMemory;
            const acceptableGrowth = initialMemory * 0.1; // 10% 增长被认为可接受
            
            expect(memoryGrowth).toBeLessThan(acceptableGrowth);
        });
    }
    
    async testBrowserCompatibility() {
        const browsers = ['chromium', 'firefox', 'webkit'];
        
        for (const browserName of browsers) {
            test(`Should work correctly in ${browserName}`, async ({ page }) => {
                await page.goto('/compatibility-test');
                
                const capabilities = await page.evaluate(() => {
                    return window.detectBrowserCapabilities();
                });
                
                expect(capabilities.webAssembly).toBe(true);
                
                // 运行基本功能测试
                const result = await page.evaluate(() => {
                    return window.runBasicFunctionalityTest();
                });
                
                expect(result.success).toBe(true);
            });
        }
    }
}

// 性能回归测试
class PerformanceRegressionTest {
    private baselineMetrics: Map<string, number> = new Map();
    
    async establishBaseline() {
        const tests = [
            'image_blur_100x100',
            'image_blur_500x500',
            'image_blur_1000x1000',
            'matrix_multiply_100x100',
            'fft_1024_points'
        ];
        
        for (const testName of tests) {
            const metrics = await this.runPerformanceTest(testName);
            this.baselineMetrics.set(testName, metrics.averageDuration);
        }
    }
    
    async checkForRegressions() {
        const regressionThreshold = 1.2; // 20% 性能退化阈值
        const regressions: string[] = [];
        
        for (const [testName, baseline] of this.baselineMetrics) {
            const currentMetrics = await this.runPerformanceTest(testName);
            const regressionRatio = currentMetrics.averageDuration / baseline;
            
            if (regressionRatio > regressionThreshold) {
                regressions.push(`${testName}: ${(regressionRatio * 100 - 100).toFixed(1)}% slower`);
            }
        }
        
        if (regressions.length > 0) {
            throw new Error(`Performance regressions detected:\n${regressions.join('\n')}`);
        }
    }
    
    private async runPerformanceTest(testName: string): Promise<PerformanceMetrics> {
        const iterations = 10;
        const durations: number[] = [];
        
        for (let i = 0; i < iterations; i++) {
            const start = performance.now();
            
            // 运行具体的测试
            await this.executeTest(testName);
            
            const end = performance.now();
            durations.push(end - start);
        }
        
        return {
            testName,
            averageDuration: durations.reduce((a, b) => a + b, 0) / durations.length,
            minDuration: Math.min(...durations),
            maxDuration: Math.max(...durations),
            standardDeviation: this.calculateStdDev(durations)
        };
    }
    
    private calculateStdDev(values: number[]): number {
        const mean = values.reduce((a, b) => a + b, 0) / values.length;
        const squaredDiffs = values.map(value => Math.pow(value - mean, 2));
        const avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b, 0) / squaredDiffs.length;
        return Math.sqrt(avgSquaredDiff);
    }
}

interface PerformanceMetrics {
    testName: string;
    averageDuration: number;
    minDuration: number;
    maxDuration: number;
    standardDeviation: number;
}
```

### 12.3.3 部署和 CI/CD

```yaml
# .github/workflows/wasm-ci.yml
name: WebAssembly CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        rust-version: [stable, beta]
        node-version: [16, 18, 20]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: ${{ matrix.rust-version }}
        target: wasm32-unknown-unknown
        override: true
        components: rustfmt, clippy
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'
    
    - name: Install wasm-pack
      run: curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
    
    - name: Install dependencies
      run: npm ci
    
    - name: Lint Rust code
      run: cargo clippy --target wasm32-unknown-unknown -- -D warnings
    
    - name: Format check
      run: cargo fmt -- --check
    
    - name: Build WASM module
      run: wasm-pack build --target web --out-dir pkg
    
    - name: Run Rust tests
      run: wasm-pack test --headless --chrome
    
    - name: Build TypeScript
      run: npm run build
    
    - name: Run JavaScript tests
      run: npm test
    
    - name: Run E2E tests
      run: npm run test:e2e
    
    - name: Performance regression tests
      run: npm run test:performance
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.rust-version }}-${{ matrix.node-version }}
        path: |
          test-results/
          coverage/
          benchmarks/

  build:
    needs: test
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup build environment
      run: |
        curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
        npm ci
    
    - name: Build optimized WASM
      run: |
        wasm-pack build --target web --release --out-dir dist/pkg
        wasm-opt -O4 dist/pkg/*.wasm -o dist/pkg/optimized.wasm
    
    - name: Build production bundle
      run: npm run build:production
    
    - name: Analyze bundle size
      run: |
        npm run analyze:bundle
        npm run analyze:wasm-size
    
    - name: Upload build artifacts
      uses: actions/upload-artifact@v3
      with:
        name: production-build
        path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Download build artifacts
      uses: actions/download-artifact@v3
      with:
        name: production-build
        path: dist/
    
    - name: Deploy to staging
      run: |
        # 部署到测试环境
        aws s3 sync dist/ s3://staging-bucket/
        aws cloudfront create-invalidation --distribution-id $STAGING_DISTRIBUTION_ID --paths "/*"
    
    - name: Run smoke tests
      run: |
        # 对部署的应用运行基本的烟雾测试
        npm run test:smoke -- --url https://staging.example.com
    
    - name: Deploy to production
      if: success()
      run: |
        # 部署到生产环境
        aws s3 sync dist/ s3://production-bucket/
        aws cloudfront create-invalidation --distribution-id $PRODUCTION_DISTRIBUTION_ID --paths "/*"

  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Security audit
      run: |
        cargo audit
        npm audit
    
    - name: WASM security scan
      run: |
        # 检查 WASM 模块的安全问题
        wasm-validate dist/pkg/*.wasm
        
    - name: Dependency vulnerability scan
      uses: snyk/actions/node@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

通过本章的学习，你现在应该对如何构建、架构和部署真实的 WebAssembly 项目有了深入的理解。从经典案例分析到具体的架构模式，再到完整的测试和部署策略，这些知识将帮助你在实际项目中成功应用 WebAssembly 技术。

记住以下关键要点：

1. **渐进式采用**：不要一次性重写整个应用，而是从性能关键部分开始
2. **架构设计**：选择合适的架构模式以管理复杂性
3. **性能监控**：建立完善的性能监控和回归检测机制
4. **测试策略**：实现全面的测试覆盖，包括单元、集成和端到端测试
5. **持续集成**：建立自动化的构建、测试和部署流程

在下一个练习章节中，你将有机会实践这些概念，构建自己的 WebAssembly 实战项目。
