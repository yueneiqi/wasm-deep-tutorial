# 第12章 练习题

## 实战项目开发题

### 1. WebAssembly 游戏引擎搭建 (30分)

**题目**：使用 Rust 和 WebAssembly 构建一个简单的 2D 游戏引擎，要求实现以下功能：

1. 基本的渲染系统（Canvas 2D 或 WebGL）
2. 游戏对象管理系统
3. 简单的物理计算（碰撞检测）
4. 输入处理系统

**技术要求**：
- 使用 `wasm-bindgen` 进行 JavaScript 绑定
- 实现高性能的游戏循环
- 支持至少 60 FPS 的渲染

<details>
<summary>🔍 参考答案</summary>

**项目结构设置：**

```toml
# Cargo.toml
[package]
name = "wasm-game-engine"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = "0.3"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
  "CanvasRenderingContext2d",
  "Document",
  "Element",
  "EventTarget",
  "HtmlCanvasElement",
  "Window",
  "KeyboardEvent",
  "MouseEvent",
  "Performance",
]
```

**核心引擎代码：**

```rust
// src/lib.rs
use wasm_bindgen::prelude::*;
use web_sys::{CanvasRenderingContext2d, HtmlCanvasElement, KeyboardEvent};
use std::collections::HashMap;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
    
    #[wasm_bindgen(js_namespace = performance)]
    fn now() -> f64;
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 2D 向量结构
#[wasm_bindgen]
#[derive(Clone, Copy, Debug)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

#[wasm_bindgen]
impl Vec2 {
    #[wasm_bindgen(constructor)]
    pub fn new(x: f32, y: f32) -> Vec2 {
        Vec2 { x, y }
    }
    
    pub fn length(&self) -> f32 {
        (self.x * self.x + self.y * self.y).sqrt()
    }
    
    pub fn normalize(&self) -> Vec2 {
        let len = self.length();
        if len > 0.0 {
            Vec2 { x: self.x / len, y: self.y / len }
        } else {
            Vec2 { x: 0.0, y: 0.0 }
        }
    }
    
    pub fn distance_to(&self, other: &Vec2) -> f32 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }
}

// 游戏对象
#[wasm_bindgen]
pub struct GameObject {
    id: u32,
    position: Vec2,
    velocity: Vec2,
    size: Vec2,
    color: String,
    active: bool,
}

#[wasm_bindgen]
impl GameObject {
    #[wasm_bindgen(constructor)]
    pub fn new(id: u32, x: f32, y: f32, width: f32, height: f32) -> GameObject {
        GameObject {
            id,
            position: Vec2::new(x, y),
            velocity: Vec2::new(0.0, 0.0),
            size: Vec2::new(width, height),
            color: "blue".to_string(),
            active: true,
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> u32 { self.id }
    
    #[wasm_bindgen(getter)]
    pub fn x(&self) -> f32 { self.position.x }
    
    #[wasm_bindgen(getter)]
    pub fn y(&self) -> f32 { self.position.y }
    
    #[wasm_bindgen(setter)]
    pub fn set_x(&mut self, x: f32) { self.position.x = x; }
    
    #[wasm_bindgen(setter)]
    pub fn set_y(&mut self, y: f32) { self.position.y = y; }
    
    pub fn set_velocity(&mut self, vx: f32, vy: f32) {
        self.velocity = Vec2::new(vx, vy);
    }
    
    pub fn set_color(&mut self, color: &str) {
        self.color = color.to_string();
    }
    
    pub fn update(&mut self, delta_time: f32) {
        if !self.active { return; }
        
        self.position.x += self.velocity.x * delta_time;
        self.position.y += self.velocity.y * delta_time;
    }
    
    pub fn check_collision(&self, other: &GameObject) -> bool {
        if !self.active || !other.active { return false; }
        
        let dx = self.position.x - other.position.x;
        let dy = self.position.y - other.position.y;
        let min_distance = (self.size.x + other.size.x) / 2.0;
        
        dx * dx + dy * dy < min_distance * min_distance
    }
}

// 输入管理器
#[wasm_bindgen]
pub struct InputManager {
    keys_pressed: HashMap<String, bool>,
    mouse_position: Vec2,
}

#[wasm_bindgen]
impl InputManager {
    #[wasm_bindgen(constructor)]
    pub fn new() -> InputManager {
        InputManager {
            keys_pressed: HashMap::new(),
            mouse_position: Vec2::new(0.0, 0.0),
        }
    }
    
    pub fn set_key_pressed(&mut self, key: &str, pressed: bool) {
        self.keys_pressed.insert(key.to_string(), pressed);
    }
    
    pub fn is_key_pressed(&self, key: &str) -> bool {
        *self.keys_pressed.get(key).unwrap_or(&false)
    }
    
    pub fn set_mouse_position(&mut self, x: f32, y: f32) {
        self.mouse_position = Vec2::new(x, y);
    }
    
    #[wasm_bindgen(getter)]
    pub fn mouse_x(&self) -> f32 { self.mouse_position.x }
    
    #[wasm_bindgen(getter)]
    pub fn mouse_y(&self) -> f32 { self.mouse_position.y }
}

// 游戏引擎主类
#[wasm_bindgen]
pub struct GameEngine {
    canvas: HtmlCanvasElement,
    context: CanvasRenderingContext2d,
    game_objects: Vec<GameObject>,
    input_manager: InputManager,
    last_frame_time: f64,
    fps_counter: f64,
    frame_count: u32,
}

#[wasm_bindgen]
impl GameEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(canvas: HtmlCanvasElement) -> Result<GameEngine, JsValue> {
        let context = canvas
            .get_context("2d")?
            .unwrap()
            .dyn_into::<CanvasRenderingContext2d>()?;
        
        Ok(GameEngine {
            canvas,
            context,
            game_objects: Vec::new(),
            input_manager: InputManager::new(),
            last_frame_time: now(),
            fps_counter: 0.0,
            frame_count: 0,
        })
    }
    
    pub fn add_game_object(&mut self, object: GameObject) {
        self.game_objects.push(object);
    }
    
    pub fn remove_game_object(&mut self, id: u32) {
        self.game_objects.retain(|obj| obj.id != id);
    }
    
    pub fn get_input_manager(&mut self) -> &mut InputManager {
        &mut self.input_manager
    }
    
    pub fn update(&mut self) {
        let current_time = now();
        let delta_time = (current_time - self.last_frame_time) as f32 / 1000.0;
        self.last_frame_time = current_time;
        
        // 更新游戏对象
        for object in &mut self.game_objects {
            object.update(delta_time);
            
            // 边界检查
            let canvas_width = self.canvas.width() as f32;
            let canvas_height = self.canvas.height() as f32;
            
            if object.position.x < 0.0 || object.position.x > canvas_width {
                object.velocity.x *= -1.0;
                object.position.x = object.position.x.max(0.0).min(canvas_width);
            }
            
            if object.position.y < 0.0 || object.position.y > canvas_height {
                object.velocity.y *= -1.0;
                object.position.y = object.position.y.max(0.0).min(canvas_height);
            }
        }
        
        // 碰撞检测
        for i in 0..self.game_objects.len() {
            for j in (i + 1)..self.game_objects.len() {
                if self.game_objects[i].check_collision(&self.game_objects[j]) {
                    console_log!("碰撞检测: 对象 {} 与对象 {} 发生碰撞", 
                               self.game_objects[i].id, self.game_objects[j].id);
                }
            }
        }
        
        // 处理输入
        self.handle_input(delta_time);
        
        // 更新 FPS 计数
        self.frame_count += 1;
        if self.frame_count % 60 == 0 {
            self.fps_counter = 60.0 / delta_time;
        }
    }
    
    fn handle_input(&mut self, delta_time: f32) {
        let speed = 200.0; // 像素/秒
        
        if let Some(player) = self.game_objects.get_mut(0) {
            let mut vx = 0.0;
            let mut vy = 0.0;
            
            if self.input_manager.is_key_pressed("ArrowLeft") || 
               self.input_manager.is_key_pressed("KeyA") {
                vx = -speed;
            }
            if self.input_manager.is_key_pressed("ArrowRight") || 
               self.input_manager.is_key_pressed("KeyD") {
                vx = speed;
            }
            if self.input_manager.is_key_pressed("ArrowUp") || 
               self.input_manager.is_key_pressed("KeyW") {
                vy = -speed;
            }
            if self.input_manager.is_key_pressed("ArrowDown") || 
               self.input_manager.is_key_pressed("KeyS") {
                vy = speed;
            }
            
            player.set_velocity(vx, vy);
        }
    }
    
    pub fn render(&self) {
        // 清除画布
        let canvas_width = self.canvas.width() as f64;
        let canvas_height = self.canvas.height() as f64;
        self.context.clear_rect(0.0, 0.0, canvas_width, canvas_height);
        
        // 设置背景色
        self.context.set_fill_style(&"#f0f0f0".into());
        self.context.fill_rect(0.0, 0.0, canvas_width, canvas_height);
        
        // 渲染游戏对象
        for object in &self.game_objects {
            if !object.active { continue; }
            
            self.context.set_fill_style(&object.color.clone().into());
            self.context.fill_rect(
                (object.position.x - object.size.x / 2.0) as f64,
                (object.position.y - object.size.y / 2.0) as f64,
                object.size.x as f64,
                object.size.y as f64,
            );
        }
        
        // 显示 FPS
        self.context.set_fill_style(&"black".into());
        self.context.set_font("16px Arial");
        self.context.fill_text(&format!("FPS: {:.1}", self.fps_counter), 10.0, 25.0).unwrap();
        
        // 显示对象数量
        self.context.fill_text(
            &format!("游戏对象: {}", self.game_objects.len()), 
            10.0, 45.0
        ).unwrap();
    }
    
    pub fn get_fps(&self) -> f32 {
        self.fps_counter as f32
    }
    
    pub fn get_object_count(&self) -> usize {
        self.game_objects.len()
    }
}
```

**JavaScript 集成代码：**

```html
<!DOCTYPE html>
<html>
<head>
    <title>WebAssembly 游戏引擎</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background: #222;
            color: white;
        }
        canvas {
            border: 2px solid #444;
            background: white;
        }
        .controls {
            margin-top: 20px;
        }
        button {
            margin: 5px;
            padding: 10px 20px;
            font-size: 16px;
        }
    </style>
</head>
<body>
    <h1>WebAssembly 2D 游戏引擎演示</h1>
    <canvas id="gameCanvas" width="800" height="600"></canvas>
    
    <div class="controls">
        <button onclick="addRandomObject()">添加随机对象</button>
        <button onclick="clearObjects()">清除所有对象</button>
        <button onclick="togglePause()">暂停/继续</button>
        <p>使用 WASD 或箭头键控制蓝色方块</p>
        <p id="stats">统计信息将显示在这里</p>
    </div>

    <script type="module">
        import init, { 
            GameEngine, 
            GameObject, 
            Vec2 
        } from './pkg/wasm_game_engine.js';

        let gameEngine;
        let animationId;
        let isPaused = false;

        async function run() {
            await init();
            
            const canvas = document.getElementById('gameCanvas');
            gameEngine = new GameEngine(canvas);
            
            // 添加玩家对象（蓝色方块）
            const player = new GameObject(0, 400, 300, 40, 40);
            player.set_color("blue");
            gameEngine.add_game_object(player);
            
            // 添加一些初始对象
            for (let i = 1; i <= 5; i++) {
                addRandomObject();
            }
            
            // 设置输入事件监听
            setupInputHandlers();
            
            // 开始游戏循环
            gameLoop();
        }

        function setupInputHandlers() {
            const inputManager = gameEngine.get_input_manager();
            
            // 键盘事件
            document.addEventListener('keydown', (event) => {
                inputManager.set_key_pressed(event.code, true);
                event.preventDefault();
            });
            
            document.addEventListener('keyup', (event) => {
                inputManager.set_key_pressed(event.code, false);
                event.preventDefault();
            });
            
            // 鼠标事件
            const canvas = document.getElementById('gameCanvas');
            canvas.addEventListener('mousemove', (event) => {
                const rect = canvas.getBoundingClientRect();
                const x = event.clientX - rect.left;
                const y = event.clientY - rect.top;
                inputManager.set_mouse_position(x, y);
            });
        }

        function gameLoop() {
            if (!isPaused) {
                gameEngine.update();
                gameEngine.render();
                
                // 更新统计信息
                const stats = document.getElementById('stats');
                stats.innerHTML = `
                    FPS: ${gameEngine.get_fps().toFixed(1)} | 
                    对象数量: ${gameEngine.get_object_count()}
                `;
            }
            
            animationId = requestAnimationFrame(gameLoop);
        }

        window.addRandomObject = function() {
            const id = Date.now() + Math.random();
            const x = Math.random() * 750 + 25;
            const y = Math.random() * 550 + 25;
            const size = Math.random() * 30 + 20;
            
            const obj = new GameObject(id, x, y, size, size);
            
            // 随机颜色
            const colors = ['red', 'green', 'yellow', 'purple', 'orange', 'cyan'];
            obj.set_color(colors[Math.floor(Math.random() * colors.length)]);
            
            // 随机速度
            const vx = (Math.random() - 0.5) * 200;
            const vy = (Math.random() - 0.5) * 200;
            obj.set_velocity(vx, vy);
            
            gameEngine.add_game_object(obj);
        };

        window.clearObjects = function() {
            // 保留玩家对象（ID = 0）
            for (let i = 1; i < 1000; i++) {
                gameEngine.remove_game_object(i);
            }
        };

        window.togglePause = function() {
            isPaused = !isPaused;
            const button = event.target;
            button.textContent = isPaused ? '继续' : '暂停';
        };

        run();
    </script>
</body>
</html>
```

**性能优化建议：**

1. **对象池模式**：重用游戏对象，减少内存分配
2. **空间分割**：使用四叉树优化碰撞检测
3. **批量渲染**：减少 JavaScript 与 WASM 的调用次数
4. **SIMD 指令**：使用 SIMD 加速向量计算

**验证测试**：
- 确保游戏能维持 60 FPS
- 验证碰撞检测的准确性
- 测试输入响应的流畅度
- 检查内存使用的稳定性
</details>

### 2. 图像处理应用开发 (25分)

**题目**：开发一个基于 WebAssembly 的在线图像处理应用，要求实现：

1. 基本滤镜（模糊、锐化、边缘检测）
2. 色彩调整（亮度、对比度、饱和度）
3. 图像变换（旋转、缩放、裁剪）
4. 批量处理功能

<details>
<summary>🔍 参考答案</summary>

**Rust 图像处理库：**

```rust
// src/lib.rs
use wasm_bindgen::prelude::*;
use web_sys::ImageData;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 图像数据结构
#[wasm_bindgen]
pub struct ImageProcessor {
    width: u32,
    height: u32,
    data: Vec<u8>,
}

#[wasm_bindgen]
impl ImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: u32, height: u32, data: Vec<u8>) -> ImageProcessor {
        ImageProcessor { width, height, data }
    }
    
    #[wasm_bindgen(getter)]
    pub fn width(&self) -> u32 { self.width }
    
    #[wasm_bindgen(getter)]
    pub fn height(&self) -> u32 { self.height }
    
    #[wasm_bindgen(getter)]
    pub fn data(&self) -> Vec<u8> { self.data.clone() }
    
    // 高斯模糊滤镜
    pub fn gaussian_blur(&mut self, radius: f32) {
        let kernel_size = (radius * 6.0) as usize + 1;
        let kernel = self.generate_gaussian_kernel(radius, kernel_size);
        
        // 水平模糊
        let temp_data = self.apply_horizontal_kernel(&kernel);
        
        // 垂直模糊
        self.data = self.apply_vertical_kernel(&temp_data, &kernel);
        
        console_log!("高斯模糊处理完成，半径: {}", radius);
    }
    
    fn generate_gaussian_kernel(&self, sigma: f32, size: usize) -> Vec<f32> {
        let mut kernel = vec![0.0; size];
        let center = size / 2;
        let mut sum = 0.0;
        
        for i in 0..size {
            let x = (i as i32 - center as i32) as f32;
            kernel[i] = (-x * x / (2.0 * sigma * sigma)).exp();
            sum += kernel[i];
        }
        
        // 归一化
        for value in &mut kernel {
            *value /= sum;
        }
        
        kernel
    }
    
    fn apply_horizontal_kernel(&self, kernel: &[f32]) -> Vec<u8> {
        let mut result = vec![0u8; self.data.len()];
        let kernel_center = kernel.len() / 2;
        
        for y in 0..self.height {
            for x in 0..self.width {
                for channel in 0..4 { // RGBA
                    let mut sum = 0.0;
                    
                    for k in 0..kernel.len() {
                        let sample_x = (x as i32 + k as i32 - kernel_center as i32)
                            .max(0)
                            .min(self.width as i32 - 1) as u32;
                        
                        let idx = ((y * self.width + sample_x) * 4 + channel) as usize;
                        sum += self.data[idx] as f32 * kernel[k];
                    }
                    
                    let result_idx = ((y * self.width + x) * 4 + channel) as usize;
                    result[result_idx] = sum.round().max(0.0).min(255.0) as u8;
                }
            }
        }
        
        result
    }
    
    fn apply_vertical_kernel(&self, data: &[u8], kernel: &[f32]) -> Vec<u8> {
        let mut result = vec![0u8; data.len()];
        let kernel_center = kernel.len() / 2;
        
        for y in 0..self.height {
            for x in 0..self.width {
                for channel in 0..4 {
                    let mut sum = 0.0;
                    
                    for k in 0..kernel.len() {
                        let sample_y = (y as i32 + k as i32 - kernel_center as i32)
                            .max(0)
                            .min(self.height as i32 - 1) as u32;
                        
                        let idx = ((sample_y * self.width + x) * 4 + channel) as usize;
                        sum += data[idx] as f32 * kernel[k];
                    }
                    
                    let result_idx = ((y * self.width + x) * 4 + channel) as usize;
                    result[result_idx] = sum.round().max(0.0).min(255.0) as u8;
                }
            }
        }
        
        result
    }
    
    // 锐化滤镜
    pub fn sharpen(&mut self, strength: f32) {
        let kernel = [
            0.0, -strength, 0.0,
            -strength, 1.0 + 4.0 * strength, -strength,
            0.0, -strength, 0.0,
        ];
        
        self.apply_3x3_kernel(&kernel);
        console_log!("锐化处理完成，强度: {}", strength);
    }
    
    // 边缘检测（Sobel 算子）
    pub fn edge_detection(&mut self) {
        // 先转换为灰度
        self.to_grayscale();
        
        let sobel_x = [
            -1.0, 0.0, 1.0,
            -2.0, 0.0, 2.0,
            -1.0, 0.0, 1.0,
        ];
        
        let sobel_y = [
            -1.0, -2.0, -1.0,
             0.0,  0.0,  0.0,
             1.0,  2.0,  1.0,
        ];
        
        let gx = self.apply_3x3_kernel_to_grayscale(&sobel_x);
        let gy = self.apply_3x3_kernel_to_grayscale(&sobel_y);
        
        // 计算梯度幅度
        for i in 0..self.width * self.height {
            let idx = (i * 4) as usize;
            let magnitude = ((gx[idx] as f32).powi(2) + (gy[idx] as f32).powi(2)).sqrt();
            let value = magnitude.min(255.0) as u8;
            
            self.data[idx] = value;     // R
            self.data[idx + 1] = value; // G
            self.data[idx + 2] = value; // B
            // Alpha 保持不变
        }
        
        console_log!("边缘检测处理完成");
    }
    
    fn apply_3x3_kernel(&mut self, kernel: &[f32; 9]) {
        let mut result = self.data.clone();
        
        for y in 1..(self.height - 1) {
            for x in 1..(self.width - 1) {
                for channel in 0..3 { // 跳过 Alpha 通道
                    let mut sum = 0.0;
                    
                    for ky in 0..3 {
                        for kx in 0..3 {
                            let pixel_y = y + ky - 1;
                            let pixel_x = x + kx - 1;
                            let idx = ((pixel_y * self.width + pixel_x) * 4 + channel) as usize;
                            sum += self.data[idx] as f32 * kernel[ky * 3 + kx];
                        }
                    }
                    
                    let result_idx = ((y * self.width + x) * 4 + channel) as usize;
                    result[result_idx] = sum.round().max(0.0).min(255.0) as u8;
                }
            }
        }
        
        self.data = result;
    }
    
    fn apply_3x3_kernel_to_grayscale(&self, kernel: &[f32; 9]) -> Vec<u8> {
        let mut result = vec![0u8; self.data.len()];
        
        for y in 1..(self.height - 1) {
            for x in 1..(self.width - 1) {
                let mut sum = 0.0;
                
                for ky in 0..3 {
                    for kx in 0..3 {
                        let pixel_y = y + ky - 1;
                        let pixel_x = x + kx - 1;
                        let idx = ((pixel_y * self.width + pixel_x) * 4) as usize;
                        sum += self.data[idx] as f32 * kernel[ky * 3 + kx];
                    }
                }
                
                let result_idx = ((y * self.width + x) * 4) as usize;
                let value = sum.abs().min(255.0) as u8;
                result[result_idx] = value;
                result[result_idx + 1] = value;
                result[result_idx + 2] = value;
                result[result_idx + 3] = self.data[result_idx + 3]; // 保持 Alpha
            }
        }
        
        result
    }
    
    // 亮度调整
    pub fn adjust_brightness(&mut self, delta: i32) {
        for i in (0..self.data.len()).step_by(4) {
            for channel in 0..3 {
                let new_value = (self.data[i + channel] as i32 + delta)
                    .max(0)
                    .min(255) as u8;
                self.data[i + channel] = new_value;
            }
        }
        console_log!("亮度调整完成，变化值: {}", delta);
    }
    
    // 对比度调整
    pub fn adjust_contrast(&mut self, factor: f32) {
        for i in (0..self.data.len()).step_by(4) {
            for channel in 0..3 {
                let pixel = self.data[i + channel] as f32;
                let new_value = ((pixel - 128.0) * factor + 128.0)
                    .round()
                    .max(0.0)
                    .min(255.0) as u8;
                self.data[i + channel] = new_value;
            }
        }
        console_log!("对比度调整完成，因子: {}", factor);
    }
    
    // 转换为灰度
    pub fn to_grayscale(&mut self) {
        for i in (0..self.data.len()).step_by(4) {
            let r = self.data[i] as f32;
            let g = self.data[i + 1] as f32;
            let b = self.data[i + 2] as f32;
            
            // 使用标准 RGB 到灰度的转换公式
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as u8;
            
            self.data[i] = gray;
            self.data[i + 1] = gray;
            self.data[i + 2] = gray;
        }
        console_log!("灰度转换完成");
    }
    
    // 图像旋转（90度的倍数）
    pub fn rotate_90_clockwise(&mut self) {
        let old_width = self.width;
        let old_height = self.height;
        let mut new_data = vec![0u8; self.data.len()];
        
        for y in 0..old_height {
            for x in 0..old_width {
                let old_idx = ((y * old_width + x) * 4) as usize;
                let new_x = old_height - 1 - y;
                let new_y = x;
                let new_idx = ((new_y * old_height + new_x) * 4) as usize;
                
                for channel in 0..4 {
                    new_data[new_idx + channel] = self.data[old_idx + channel];
                }
            }
        }
        
        self.width = old_height;
        self.height = old_width;
        self.data = new_data;
        
        console_log!("图像顺时针旋转90度完成");
    }
    
    // 图像缩放（双线性插值）
    pub fn resize(&mut self, new_width: u32, new_height: u32) {
        let mut new_data = vec![0u8; (new_width * new_height * 4) as usize];
        
        let x_ratio = self.width as f32 / new_width as f32;
        let y_ratio = self.height as f32 / new_height as f32;
        
        for y in 0..new_height {
            for x in 0..new_width {
                let src_x = x as f32 * x_ratio;
                let src_y = y as f32 * y_ratio;
                
                let x1 = src_x.floor() as u32;
                let y1 = src_y.floor() as u32;
                let x2 = (x1 + 1).min(self.width - 1);
                let y2 = (y1 + 1).min(self.height - 1);
                
                let fx = src_x - x1 as f32;
                let fy = src_y - y1 as f32;
                
                for channel in 0..4 {
                    let p1 = self.data[((y1 * self.width + x1) * 4 + channel) as usize] as f32;
                    let p2 = self.data[((y1 * self.width + x2) * 4 + channel) as usize] as f32;
                    let p3 = self.data[((y2 * self.width + x1) * 4 + channel) as usize] as f32;
                    let p4 = self.data[((y2 * self.width + x2) * 4 + channel) as usize] as f32;
                    
                    let interpolated = p1 * (1.0 - fx) * (1.0 - fy) +
                                     p2 * fx * (1.0 - fy) +
                                     p3 * (1.0 - fx) * fy +
                                     p4 * fx * fy;
                    
                    let new_idx = ((y * new_width + x) * 4 + channel) as usize;
                    new_data[new_idx] = interpolated.round() as u8;
                }
            }
        }
        
        self.width = new_width;
        self.height = new_height;
        self.data = new_data;
        
        console_log!("图像缩放完成，新尺寸: {}x{}", new_width, new_height);
    }
}

// 批量处理器
#[wasm_bindgen]
pub struct BatchProcessor {
    images: Vec<ImageProcessor>,
}

#[wasm_bindgen]
impl BatchProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> BatchProcessor {
        BatchProcessor {
            images: Vec::new(),
        }
    }
    
    pub fn add_image(&mut self, image: ImageProcessor) {
        self.images.push(image);
    }
    
    pub fn apply_brightness_to_all(&mut self, delta: i32) {
        for image in &mut self.images {
            image.adjust_brightness(delta);
        }
        console_log!("批量亮度调整完成，处理了 {} 张图像", self.images.len());
    }
    
    pub fn apply_blur_to_all(&mut self, radius: f32) {
        for image in &mut self.images {
            image.gaussian_blur(radius);
        }
        console_log!("批量模糊处理完成，处理了 {} 张图像", self.images.len());
    }
    
    pub fn get_image(&self, index: usize) -> Option<ImageProcessor> {
        self.images.get(index).cloned()
    }
    
    pub fn get_image_count(&self) -> usize {
        self.images.len()
    }
}
```

**性能优化要点**：
1. **SIMD 指令**：使用 Rust 的 SIMD 功能加速向量运算
2. **多线程处理**：使用 Web Workers 进行并行图像处理
3. **内存优化**：避免不必要的数据复制
4. **算法优化**：使用分离卷积优化模糊算法
</details>

### 3. 科学计算应用 (20分)

**题目**：开发一个基于 WebAssembly 的科学计算平台，要求实现：

1. 矩阵运算（加法、乘法、求逆）
2. 数值积分（梯形法则、辛普森法则）
3. 线性方程组求解（高斯消元法）
4. 统计分析功能（均值、方差、回归分析）

<details>
<summary>🔍 参考答案</summary>

**科学计算库实现：**

```rust
// src/lib.rs
use wasm_bindgen::prelude::*;
use std::f64::consts::PI;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 矩阵结构
#[wasm_bindgen]
#[derive(Clone, Debug)]
pub struct Matrix {
    rows: usize,
    cols: usize,
    data: Vec<f64>,
}

#[wasm_bindgen]
impl Matrix {
    #[wasm_bindgen(constructor)]
    pub fn new(rows: usize, cols: usize) -> Matrix {
        Matrix {
            rows,
            cols,
            data: vec![0.0; rows * cols],
        }
    }
    
    pub fn from_array(rows: usize, cols: usize, data: Vec<f64>) -> Matrix {
        if data.len() != rows * cols {
            panic!("数据长度与矩阵维度不匹配");
        }
        Matrix { rows, cols, data }
    }
    
    #[wasm_bindgen(getter)]
    pub fn rows(&self) -> usize { self.rows }
    
    #[wasm_bindgen(getter)]
    pub fn cols(&self) -> usize { self.cols }
    
    #[wasm_bindgen(getter)]
    pub fn data(&self) -> Vec<f64> { self.data.clone() }
    
    pub fn get(&self, row: usize, col: usize) -> f64 {
        if row >= self.rows || col >= self.cols {
            panic!("矩阵索引越界");
        }
        self.data[row * self.cols + col]
    }
    
    pub fn set(&mut self, row: usize, col: usize, value: f64) {
        if row >= self.rows || col >= self.cols {
            panic!("矩阵索引越界");
        }
        self.data[row * self.cols + col] = value;
    }
    
    // 矩阵加法
    pub fn add(&self, other: &Matrix) -> Result<Matrix, String> {
        if self.rows != other.rows || self.cols != other.cols {
            return Err("矩阵维度不匹配".to_string());
        }
        
        let mut result = Matrix::new(self.rows, self.cols);
        for i in 0..self.data.len() {
            result.data[i] = self.data[i] + other.data[i];
        }
        
        Ok(result)
    }
    
    // 矩阵乘法
    pub fn multiply(&self, other: &Matrix) -> Result<Matrix, String> {
        if self.cols != other.rows {
            return Err("矩阵维度不匹配，无法相乘".to_string());
        }
        
        let mut result = Matrix::new(self.rows, other.cols);
        
        for i in 0..self.rows {
            for j in 0..other.cols {
                let mut sum = 0.0;
                for k in 0..self.cols {
                    sum += self.get(i, k) * other.get(k, j);
                }
                result.set(i, j, sum);
            }
        }
        
        Ok(result)
    }
    
    // 矩阵转置
    pub fn transpose(&self) -> Matrix {
        let mut result = Matrix::new(self.cols, self.rows);
        
        for i in 0..self.rows {
            for j in 0..self.cols {
                result.set(j, i, self.get(i, j));
            }
        }
        
        result
    }
    
    // 高斯消元法求逆矩阵
    pub fn inverse(&self) -> Result<Matrix, String> {
        if self.rows != self.cols {
            return Err("只能计算方阵的逆矩阵".to_string());
        }
        
        let n = self.rows;
        let mut augmented = Matrix::new(n, 2 * n);
        
        // 构造增广矩阵 [A|I]
        for i in 0..n {
            for j in 0..n {
                augmented.set(i, j, self.get(i, j));
                augmented.set(i, j + n, if i == j { 1.0 } else { 0.0 });
            }
        }
        
        // 前向消元
        for i in 0..n {
            // 寻找主元
            let mut max_row = i;
            for k in (i + 1)..n {
                if augmented.get(k, i).abs() > augmented.get(max_row, i).abs() {
                    max_row = k;
                }
            }
            
            // 交换行
            if max_row != i {
                for j in 0..(2 * n) {
                    let temp = augmented.get(i, j);
                    augmented.set(i, j, augmented.get(max_row, j));
                    augmented.set(max_row, j, temp);
                }
            }
            
            // 检查奇异性
            if augmented.get(i, i).abs() < 1e-10 {
                return Err("矩阵是奇异的，无法求逆".to_string());
            }
            
            // 归一化主元行
            let pivot = augmented.get(i, i);
            for j in 0..(2 * n) {
                augmented.set(i, j, augmented.get(i, j) / pivot);
            }
            
            // 消元
            for k in 0..n {
                if k != i {
                    let factor = augmented.get(k, i);
                    for j in 0..(2 * n) {
                        let new_val = augmented.get(k, j) - factor * augmented.get(i, j);
                        augmented.set(k, j, new_val);
                    }
                }
            }
        }
        
        // 提取逆矩阵
        let mut inverse = Matrix::new(n, n);
        for i in 0..n {
            for j in 0..n {
                inverse.set(i, j, augmented.get(i, j + n));
            }
        }
        
        Ok(inverse)
    }
    
    // 计算行列式
    pub fn determinant(&self) -> Result<f64, String> {
        if self.rows != self.cols {
            return Err("只能计算方阵的行列式".to_string());
        }
        
        let mut matrix = self.clone();
        let n = self.rows;
        let mut det = 1.0;
        
        for i in 0..n {
            // 寻找主元
            let mut max_row = i;
            for k in (i + 1)..n {
                if matrix.get(k, i).abs() > matrix.get(max_row, i).abs() {
                    max_row = k;
                }
            }
            
            // 交换行（改变行列式符号）
            if max_row != i {
                for j in 0..n {
                    let temp = matrix.get(i, j);
                    matrix.set(i, j, matrix.get(max_row, j));
                    matrix.set(max_row, j, temp);
                }
                det *= -1.0;
            }
            
            let pivot = matrix.get(i, i);
            if pivot.abs() < 1e-10 {
                return Ok(0.0); // 奇异矩阵
            }
            
            det *= pivot;
            
            // 消元
            for k in (i + 1)..n {
                let factor = matrix.get(k, i) / pivot;
                for j in i..n {
                    let new_val = matrix.get(k, j) - factor * matrix.get(i, j);
                    matrix.set(k, j, new_val);
                }
            }
        }
        
        Ok(det)
    }
}

// 数值积分器
#[wasm_bindgen]
pub struct NumericalIntegrator;

#[wasm_bindgen]
impl NumericalIntegrator {
    // 梯形法则
    pub fn trapezoidal_rule(
        coefficients: Vec<f64>, // 多项式系数
        a: f64,                  // 积分下限
        b: f64,                  // 积分上限
        n: u32,                  // 分割数
    ) -> f64 {
        let h = (b - a) / n as f64;
        let mut sum = 0.0;
        
        // 计算多项式值的函数
        let polynomial = |x: f64| -> f64 {
            coefficients.iter().enumerate()
                .map(|(i, &coeff)| coeff * x.powi(i as i32))
                .sum()
        };
        
        sum += polynomial(a) + polynomial(b);
        
        for i in 1..n {
            let x = a + i as f64 * h;
            sum += 2.0 * polynomial(x);
        }
        
        sum * h / 2.0
    }
    
    // 辛普森法则
    pub fn simpson_rule(
        coefficients: Vec<f64>,
        a: f64,
        b: f64,
        n: u32,
    ) -> f64 {
        if n % 2 != 0 {
            panic!("辛普森法则要求 n 为偶数");
        }
        
        let h = (b - a) / n as f64;
        let mut sum = 0.0;
        
        let polynomial = |x: f64| -> f64 {
            coefficients.iter().enumerate()
                .map(|(i, &coeff)| coeff * x.powi(i as i32))
                .sum()
        };
        
        sum += polynomial(a) + polynomial(b);
        
        for i in 1..n {
            let x = a + i as f64 * h;
            let factor = if i % 2 == 0 { 2.0 } else { 4.0 };
            sum += factor * polynomial(x);
        }
        
        sum * h / 3.0
    }
    
    // 自适应积分
    pub fn adaptive_simpson(
        coefficients: Vec<f64>,
        a: f64,
        b: f64,
        tolerance: f64,
    ) -> f64 {
        Self::adaptive_simpson_recursive(&coefficients, a, b, tolerance, 0)
    }
    
    fn adaptive_simpson_recursive(
        coefficients: &[f64],
        a: f64,
        b: f64,
        tolerance: f64,
        depth: u32,
    ) -> f64 {
        if depth > 50 {
            return Self::simpson_rule(coefficients.to_vec(), a, b, 10);
        }
        
        let c = (a + b) / 2.0;
        let s1 = Self::simpson_rule(coefficients.to_vec(), a, b, 2);
        let s2 = Self::simpson_rule(coefficients.to_vec(), a, c, 2) +
                 Self::simpson_rule(coefficients.to_vec(), c, b, 2);
        
        if (s1 - s2).abs() < tolerance {
            s2
        } else {
            Self::adaptive_simpson_recursive(coefficients, a, c, tolerance / 2.0, depth + 1) +
            Self::adaptive_simpson_recursive(coefficients, c, b, tolerance / 2.0, depth + 1)
        }
    }
}

// 线性方程组求解器
#[wasm_bindgen]
pub struct LinearSolver;

#[wasm_bindgen]
impl LinearSolver {
    // 高斯消元法解线性方程组 Ax = b
    pub fn gaussian_elimination(a: &Matrix, b: Vec<f64>) -> Result<Vec<f64>, String> {
        if a.rows != a.cols {
            return Err("系数矩阵必须是方阵".to_string());
        }
        
        if a.rows != b.len() {
            return Err("系数矩阵和常数向量维度不匹配".to_string());
        }
        
        let n = a.rows;
        let mut aug_matrix = Matrix::new(n, n + 1);
        
        // 构造增广矩阵
        for i in 0..n {
            for j in 0..n {
                aug_matrix.set(i, j, a.get(i, j));
            }
            aug_matrix.set(i, n, b[i]);
        }
        
        // 前向消元
        for i in 0..n {
            // 部分主元选择
            let mut max_row = i;
            for k in (i + 1)..n {
                if aug_matrix.get(k, i).abs() > aug_matrix.get(max_row, i).abs() {
                    max_row = k;
                }
            }
            
            // 交换行
            if max_row != i {
                for j in 0..=n {
                    let temp = aug_matrix.get(i, j);
                    aug_matrix.set(i, j, aug_matrix.get(max_row, j));
                    aug_matrix.set(max_row, j, temp);
                }
            }
            
            // 检查奇异性
            if aug_matrix.get(i, i).abs() < 1e-10 {
                return Err("系数矩阵是奇异的".to_string());
            }
            
            // 消元
            for k in (i + 1)..n {
                let factor = aug_matrix.get(k, i) / aug_matrix.get(i, i);
                for j in i..=n {
                    let new_val = aug_matrix.get(k, j) - factor * aug_matrix.get(i, j);
                    aug_matrix.set(k, j, new_val);
                }
            }
        }
        
        // 回代求解
        let mut x = vec![0.0; n];
        for i in (0..n).rev() {
            let mut sum = aug_matrix.get(i, n);
            for j in (i + 1)..n {
                sum -= aug_matrix.get(i, j) * x[j];
            }
            x[i] = sum / aug_matrix.get(i, i);
        }
        
        Ok(x)
    }
    
    // LU 分解
    pub fn lu_decomposition(matrix: &Matrix) -> Result<(Matrix, Matrix), String> {
        if matrix.rows != matrix.cols {
            return Err("只能对方阵进行 LU 分解".to_string());
        }
        
        let n = matrix.rows;
        let mut l = Matrix::new(n, n);
        let mut u = Matrix::new(n, n);
        
        // 初始化 L 矩阵的对角线为 1
        for i in 0..n {
            l.set(i, i, 1.0);
        }
        
        for i in 0..n {
            // 计算 U 矩阵的第 i 行
            for j in i..n {
                let mut sum = 0.0;
                for k in 0..i {
                    sum += l.get(i, k) * u.get(k, j);
                }
                u.set(i, j, matrix.get(i, j) - sum);
            }
            
            // 计算 L 矩阵的第 i 列
            for j in (i + 1)..n {
                let mut sum = 0.0;
                for k in 0..i {
                    sum += l.get(j, k) * u.get(k, i);
                }
                
                if u.get(i, i).abs() < 1e-10 {
                    return Err("矩阵是奇异的，无法进行 LU 分解".to_string());
                }
                
                l.set(j, i, (matrix.get(j, i) - sum) / u.get(i, i));
            }
        }
        
        Ok((l, u))
    }
}

// 统计分析器
#[wasm_bindgen]
pub struct StatisticalAnalyzer;

#[wasm_bindgen]
impl StatisticalAnalyzer {
    // 计算均值
    pub fn mean(data: &[f64]) -> f64 {
        if data.is_empty() {
            return 0.0;
        }
        data.iter().sum::<f64>() / data.len() as f64
    }
    
    // 计算方差
    pub fn variance(data: &[f64], sample: bool) -> f64 {
        if data.len() <= 1 {
            return 0.0;
        }
        
        let mean = Self::mean(data);
        let sum_squared_diff: f64 = data.iter()
            .map(|x| (x - mean).powi(2))
            .sum();
        
        let denominator = if sample { data.len() - 1 } else { data.len() };
        sum_squared_diff / denominator as f64
    }
    
    // 计算标准差
    pub fn standard_deviation(data: &[f64], sample: bool) -> f64 {
        Self::variance(data, sample).sqrt()
    }
    
    // 计算协方差
    pub fn covariance(x: &[f64], y: &[f64], sample: bool) -> Result<f64, String> {
        if x.len() != y.len() {
            return Err("数据长度不匹配".to_string());
        }
        
        if x.len() <= 1 {
            return Ok(0.0);
        }
        
        let mean_x = Self::mean(x);
        let mean_y = Self::mean(y);
        
        let sum: f64 = x.iter().zip(y.iter())
            .map(|(xi, yi)| (xi - mean_x) * (yi - mean_y))
            .sum();
        
        let denominator = if sample { x.len() - 1 } else { x.len() };
        Ok(sum / denominator as f64)
    }
    
    // 线性回归
    pub fn linear_regression(x: &[f64], y: &[f64]) -> Result<(f64, f64, f64), String> {
        if x.len() != y.len() || x.len() < 2 {
            return Err("数据不足或长度不匹配".to_string());
        }
        
        let n = x.len() as f64;
        let sum_x: f64 = x.iter().sum();
        let sum_y: f64 = y.iter().sum();
        let sum_xy: f64 = x.iter().zip(y.iter()).map(|(xi, yi)| xi * yi).sum();
        let sum_x2: f64 = x.iter().map(|xi| xi * xi).sum();
        
        let denominator = n * sum_x2 - sum_x * sum_x;
        if denominator.abs() < 1e-10 {
            return Err("无法计算回归系数，x 值方差为 0".to_string());
        }
        
        // 计算斜率和截距
        let slope = (n * sum_xy - sum_x * sum_y) / denominator;
        let intercept = (sum_y - slope * sum_x) / n;
        
        // 计算相关系数
        let mean_x = sum_x / n;
        let mean_y = sum_y / n;
        
        let numerator: f64 = x.iter().zip(y.iter())
            .map(|(xi, yi)| (xi - mean_x) * (yi - mean_y))
            .sum();
        
        let sum_sq_x: f64 = x.iter().map(|xi| (xi - mean_x).powi(2)).sum();
        let sum_sq_y: f64 = y.iter().map(|yi| (yi - mean_y).powi(2)).sum();
        
        let correlation = numerator / (sum_sq_x * sum_sq_y).sqrt();
        
        Ok((slope, intercept, correlation))
    }
    
    // 计算直方图
    pub fn histogram(data: &[f64], bins: u32) -> (Vec<f64>, Vec<u32>) {
        if data.is_empty() || bins == 0 {
            return (vec![], vec![]);
        }
        
        let min_val = data.iter().fold(f64::INFINITY, |a, &b| a.min(b));
        let max_val = data.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
        
        let bin_width = (max_val - min_val) / bins as f64;
        let mut bin_edges = vec![0.0; (bins + 1) as usize];
        let mut bin_counts = vec![0u32; bins as usize];
        
        // 计算 bin 边界
        for i in 0..=bins {
            bin_edges[i as usize] = min_val + i as f64 * bin_width;
        }
        
        // 统计每个 bin 的计数
        for &value in data {
            let mut bin_index = ((value - min_val) / bin_width) as usize;
            if bin_index >= bins as usize {
                bin_index = bins as usize - 1; // 处理边界情况
            }
            bin_counts[bin_index] += 1;
        }
        
        (bin_edges, bin_counts)
    }
}
```

**JavaScript 测试代码：**

```javascript
// 测试科学计算功能
async function testScientificComputing() {
    const { Matrix, NumericalIntegrator, LinearSolver, StatisticalAnalyzer } = 
          await import('./pkg/scientific_computing.js');
    
    console.log('=== 矩阵运算测试 ===');
    
    // 创建测试矩阵
    const matrixA = Matrix.from_array(2, 2, [1, 2, 3, 4]);
    const matrixB = Matrix.from_array(2, 2, [5, 6, 7, 8]);
    
    console.log('矩阵 A:', matrixA.data());
    console.log('矩阵 B:', matrixB.data());
    
    // 矩阵加法
    const sum = matrixA.add(matrixB);
    console.log('A + B =', sum.data());
    
    // 矩阵乘法
    const product = matrixA.multiply(matrixB);
    console.log('A × B =', product.data());
    
    // 行列式
    const det = matrixA.determinant();
    console.log('det(A) =', det);
    
    console.log('\n=== 数值积分测试 ===');
    
    // 计算 x^2 在 [0, 1] 上的积分（解析解为 1/3）
    const coeffs = [0, 0, 1]; // x^2
    const integral_trap = NumericalIntegrator.trapezoidal_rule(coeffs, 0, 1, 1000);
    const integral_simp = NumericalIntegrator.simpson_rule(coeffs, 0, 1, 1000);
    
    console.log('∫₀¹ x² dx (梯形法则):', integral_trap);
    console.log('∫₀¹ x² dx (辛普森法则):', integral_simp);
    console.log('解析解:', 1/3);
    
    console.log('\n=== 线性方程组求解测试 ===');
    
    // 求解 2x + 3y = 7, x - y = 1
    const A = Matrix.from_array(2, 2, [2, 3, 1, -1]);
    const b = [7, 1];
    const solution = LinearSolver.gaussian_elimination(A, b);
    console.log('方程组解:', solution);
    
    console.log('\n=== 统计分析测试 ===');
    
    const data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    console.log('数据:', data);
    console.log('均值:', StatisticalAnalyzer.mean(data));
    console.log('方差:', StatisticalAnalyzer.variance(data, true));
    console.log('标准差:', StatisticalAnalyzer.standard_deviation(data, true));
    
    // 线性回归测试
    const x_data = [1, 2, 3, 4, 5];
    const y_data = [2, 4, 6, 8, 10]; // y = 2x
    const [slope, intercept, correlation] = StatisticalAnalyzer.linear_regression(x_data, y_data);
    console.log(`回归方程: y = ${slope}x + ${intercept}`);
    console.log(`相关系数: ${correlation}`);
}
```

**性能优化建议**：
1. **并行计算**：使用 SIMD 指令优化矩阵运算
2. **内存布局**：优化数据结构的内存访问模式
3. **算法选择**：根据矩阵特性选择最优算法
4. **缓存策略**：合理利用 CPU 缓存提高性能
</details>

### 4. 性能优化综合题 (25分)

**题目**：针对一个现有的 WebAssembly 应用进行全面性能优化，要求：

1. 进行性能分析和瓶颈识别
2. 实现内存优化策略
3. 应用 SIMD 指令优化
4. 实现多线程优化
5. 进行构建和部署优化

<details>
<summary>🔍 参考答案</summary>

**性能分析工具设置：**

```rust
// src/performance.rs
use wasm_bindgen::prelude::*;
use web_sys::{console, Performance};

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = performance)]
    fn now() -> f64;
    
    #[wasm_bindgen(js_namespace = performance)]
    fn mark(name: &str);
    
    #[wasm_bindgen(js_namespace = performance)]
    fn measure(name: &str, start_mark: &str, end_mark: &str);
}

// 性能监控器
#[wasm_bindgen]
pub struct PerformanceMonitor {
    start_times: std::collections::HashMap<String, f64>,
}

#[wasm_bindgen]
impl PerformanceMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceMonitor {
        PerformanceMonitor {
            start_times: std::collections::HashMap::new(),
        }
    }
    
    pub fn start_timer(&mut self, name: &str) {
        let start_time = now();
        self.start_times.insert(name.to_string(), start_time);
        mark(&format!("{}_start", name));
    }
    
    pub fn end_timer(&mut self, name: &str) -> f64 {
        let end_time = now();
        mark(&format!("{}_end", name));
        measure(name, &format!("{}_start", name), &format!("{}_end", name));
        
        if let Some(&start_time) = self.start_times.get(name) {
            let duration = end_time - start_time;
            console::log_1(&format!("⏱️ {}: {:.3}ms", name, duration).into());
            duration
        } else {
            0.0
        }
    }
    
    pub fn memory_usage(&self) -> f64 {
        // 获取当前内存使用情况
        web_sys::js_sys::eval("performance.memory ? performance.memory.usedJSHeapSize : 0")
            .unwrap_or_else(|_| 0.into())
            .as_f64()
            .unwrap_or(0.0)
    }
}

// SIMD 优化的向量运算
#[cfg(target_arch = "wasm32")]
use std::arch::wasm32::*;

#[wasm_bindgen]
pub struct SIMDProcessor;

#[wasm_bindgen]
impl SIMDProcessor {
    // SIMD 优化的向量加法
    pub fn vector_add_simd(a: &[f32], b: &[f32]) -> Vec<f32> {
        assert_eq!(a.len(), b.len());
        let len = a.len();
        let mut result = vec![0.0f32; len];
        
        let simd_len = len & !3; // 4 的倍数
        
        // SIMD 处理
        for i in (0..simd_len).step_by(4) {
            unsafe {
                let va = v128_load(a.as_ptr().add(i) as *const v128);
                let vb = v128_load(b.as_ptr().add(i) as *const v128);
                let vr = f32x4_add(va, vb);
                v128_store(result.as_mut_ptr().add(i) as *mut v128, vr);
            }
        }
        
        // 处理剩余元素
        for i in simd_len..len {
            result[i] = a[i] + b[i];
        }
        
        result
    }
    
    // SIMD 优化的矩阵乘法
    pub fn matrix_multiply_simd(
        a: &[f32], 
        b: &[f32], 
        rows_a: usize, 
        cols_a: usize, 
        cols_b: usize
    ) -> Vec<f32> {
        let mut result = vec![0.0f32; rows_a * cols_b];
        
        for i in 0..rows_a {
            for j in (0..cols_b).step_by(4) {
                let end_j = (j + 4).min(cols_b);
                let mut sum = unsafe { f32x4_splat(0.0) };
                
                for k in 0..cols_a {
                    let a_val = unsafe { f32x4_splat(a[i * cols_a + k]) };
                    
                    if end_j - j == 4 {
                        let b_vals = unsafe {
                            v128_load(&b[k * cols_b + j] as *const f32 as *const v128)
                        };
                        sum = unsafe { f32x4_add(sum, f32x4_mul(a_val, b_vals)) };
                    } else {
                        // 处理边界情况
                        for jj in j..end_j {
                            result[i * cols_b + jj] += a[i * cols_a + k] * b[k * cols_b + jj];
                        }
                    }
                }
                
                if end_j - j == 4 {
                    unsafe {
                        v128_store(
                            &mut result[i * cols_b + j] as *mut f32 as *mut v128, 
                            sum
                        );
                    }
                }
            }
        }
        
        result
    }
    
    // SIMD 优化的图像滤波
    pub fn apply_filter_simd(
        image: &[u8], 
        width: u32, 
        height: u32, 
        kernel: &[f32]
    ) -> Vec<u8> {
        let mut result = vec![0u8; image.len()];
        let kernel_size = (kernel.len() as f32).sqrt() as usize;
        let half_kernel = kernel_size / 2;
        
        for y in half_kernel..(height as usize - half_kernel) {
            for x in (half_kernel..(width as usize - half_kernel)).step_by(4) {
                let end_x = (x + 4).min(width as usize - half_kernel);
                
                for channel in 0..4 { // RGBA
                    let mut sum = unsafe { f32x4_splat(0.0) };
                    
                    for ky in 0..kernel_size {
                        for kx in 0..kernel_size {
                            let iy = y + ky - half_kernel;
                            let kernel_val = unsafe { 
                                f32x4_splat(kernel[ky * kernel_size + kx]) 
                            };
                            
                            if end_x - x == 4 {
                                let mut pixel_vals = [0.0f32; 4];
                                for i in 0..4 {
                                    let ix = x + i + kx - half_kernel;
                                    let idx = (iy * width as usize + ix) * 4 + channel;
                                    pixel_vals[i] = image[idx] as f32;
                                }
                                
                                let pixels = unsafe {
                                    v128_load(pixel_vals.as_ptr() as *const v128)
                                };
                                sum = unsafe { f32x4_add(sum, f32x4_mul(kernel_val, pixels)) };
                            }
                        }
                    }
                    
                    if end_x - x == 4 {
                        let result_vals = [
                            unsafe { f32x4_extract_lane::<0>(sum) },
                            unsafe { f32x4_extract_lane::<1>(sum) },
                            unsafe { f32x4_extract_lane::<2>(sum) },
                            unsafe { f32x4_extract_lane::<3>(sum) },
                        ];
                        
                        for i in 0..4 {
                            let idx = (y * width as usize + x + i) * 4 + channel;
                            result[idx] = result_vals[i].max(0.0).min(255.0) as u8;
                        }
                    }
                }
            }
        }
        
        result
    }
}

// 内存池优化
#[wasm_bindgen]
pub struct MemoryPool {
    pools: std::collections::HashMap<usize, Vec<Vec<u8>>>,
    allocated: usize,
    max_size: usize,
}

#[wasm_bindgen]
impl MemoryPool {
    #[wasm_bindgen(constructor)]
    pub fn new(max_size: usize) -> MemoryPool {
        MemoryPool {
            pools: std::collections::HashMap::new(),
            allocated: 0,
            max_size,
        }
    }
    
    pub fn allocate(&mut self, size: usize) -> Vec<u8> {
        // 查找最接近的 2 的幂
        let pool_size = size.next_power_of_two();
        
        if let Some(pool) = self.pools.get_mut(&pool_size) {
            if let Some(buffer) = pool.pop() {
                return buffer;
            }
        }
        
        // 如果超过最大限制，触发垃圾回收
        if self.allocated + pool_size > self.max_size {
            self.garbage_collect();
        }
        
        self.allocated += pool_size;
        vec![0u8; size]
    }
    
    pub fn deallocate(&mut self, mut buffer: Vec<u8>) {
        let capacity = buffer.capacity();
        let pool_size = capacity.next_power_of_two();
        
        // 清零缓冲区（可选，用于安全性）
        buffer.fill(0);
        buffer.resize(pool_size, 0);
        
        self.pools.entry(pool_size).or_insert_with(Vec::new).push(buffer);
    }
    
    fn garbage_collect(&mut self) {
        // 清理最大的池
        if let Some(max_size) = self.pools.keys().max().copied() {
            if let Some(pool) = self.pools.get_mut(&max_size) {
                let removed = pool.len() / 2;
                pool.drain(0..removed);
                self.allocated -= removed * max_size;
            }
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn allocated(&self) -> usize {
        self.allocated
    }
    
    #[wasm_bindgen(getter)]
    pub fn pool_count(&self) -> usize {
        self.pools.len()
    }
}

// 多线程工作任务
#[wasm_bindgen]
pub struct WorkerTask {
    id: u32,
    data: Vec<f32>,
    result: Option<Vec<f32>>,
}

#[wasm_bindgen]
impl WorkerTask {
    #[wasm_bindgen(constructor)]
    pub fn new(id: u32, data: Vec<f32>) -> WorkerTask {
        WorkerTask {
            id,
            data,
            result: None,
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> u32 { self.id }
    
    #[wasm_bindgen(getter)]
    pub fn data(&self) -> Vec<f32> { self.data.clone() }
    
    pub fn process_data(&mut self, operation: &str) {
        match operation {
            "square" => {
                self.result = Some(self.data.iter().map(|x| x * x).collect());
            },
            "sqrt" => {
                self.result = Some(self.data.iter().map(|x| x.sqrt()).collect());
            },
            "normalize" => {
                let max_val = self.data.iter().fold(0.0f32, |a, &b| a.max(b));
                if max_val > 0.0 {
                    self.result = Some(self.data.iter().map(|x| x / max_val).collect());
                } else {
                    self.result = Some(self.data.clone());
                }
            },
            _ => {
                self.result = Some(self.data.clone());
            }
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn result(&self) -> Option<Vec<f32>> {
        self.result.clone()
    }
    
    pub fn is_complete(&self) -> bool {
        self.result.is_some()
    }
}
```

**构建优化配置：**

```toml
# Cargo.toml 优化配置
[package]
name = "optimized-wasm-app"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = "0.3"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
  "Performance",
  "Window",
]

# 发布版本优化
[profile.release]
lto = true                    # 链接时优化
codegen-units = 1            # 单个代码生成单元
opt-level = "s"              # 优化大小
panic = "abort"              # 禁用展开
overflow-checks = false      # 禁用溢出检查

# WASM 特定优化
[package.metadata.wasm-pack.profile.release]
wasm-opt = ["-Oz", "--enable-simd"]  # 使用 wasm-opt 进一步优化
```

**JavaScript 性能优化代码：**

```javascript
// performance-optimization.js
class WASMPerformanceOptimizer {
    constructor() {
        this.wasmModule = null;
        this.workerPool = [];
        this.taskQueue = [];
        this.isInitialized = false;
    }
    
    async initialize() {
        // 预加载和编译 WASM 模块
        const wasmResponse = await fetch('./pkg/optimized_wasm_app.wasm');
        const wasmBytes = await wasmResponse.arrayBuffer();
        
        // 使用 WebAssembly.compile 预编译
        this.compiledModule = await WebAssembly.compile(wasmBytes);
        
        // 实例化主模块
        const { optimized_wasm_app } = await import('./pkg/optimized_wasm_app.js');
        this.wasmModule = optimized_wasm_app;
        
        // 初始化 Worker 池
        await this.initializeWorkerPool();
        
        this.isInitialized = true;
        console.log('🚀 WASM 性能优化器初始化完成');
    }
    
    async initializeWorkerPool() {
        const workerCount = navigator.hardwareConcurrency || 4;
        
        for (let i = 0; i < workerCount; i++) {
            const worker = new Worker('./wasm-worker.js');
            
            // 在 Worker 中预实例化 WASM 模块
            worker.postMessage({
                type: 'INIT',
                compiledModule: this.compiledModule
            });
            
            worker.onmessage = (event) => {
                this.handleWorkerMessage(event, i);
            };
            
            this.workerPool.push({
                worker,
                busy: false,
                id: i
            });
        }
        
        console.log(`🔧 初始化了 ${workerCount} 个 Worker`);
    }
    
    // 使用 Worker 池进行并行处理
    async processInParallel(data, operation) {
        return new Promise((resolve, reject) => {
            const chunkSize = Math.ceil(data.length / this.workerPool.length);
            const chunks = [];
            
            // 将数据分块
            for (let i = 0; i < data.length; i += chunkSize) {
                chunks.push(data.slice(i, i + chunkSize));
            }
            
            let completedTasks = 0;
            const results = new Array(chunks.length);
            
            chunks.forEach((chunk, index) => {
                const availableWorker = this.workerPool.find(w => !w.busy);
                
                if (availableWorker) {
                    availableWorker.busy = true;
                    availableWorker.worker.postMessage({
                        type: 'PROCESS',
                        taskId: index,
                        data: chunk,
                        operation
                    });
                    
                    const originalOnMessage = availableWorker.worker.onmessage;
                    availableWorker.worker.onmessage = (event) => {
                        if (event.data.type === 'RESULT' && event.data.taskId === index) {
                            results[index] = event.data.result;
                            completedTasks++;
                            availableWorker.busy = false;
                            
                            if (completedTasks === chunks.length) {
                                resolve(results.flat());
                            }
                            
                            // 恢复原始消息处理器
                            availableWorker.worker.onmessage = originalOnMessage;
                        }
                    };
                } else {
                    // 如果没有可用的 Worker，加入队列
                    this.taskQueue.push({ chunk, index, operation, resolve, reject });
                }
            });
        });
    }
    
    // 内存优化的批处理
    processLargeDataset(data, batchSize = 10000) {
        const monitor = new this.wasmModule.PerformanceMonitor();
        const memoryPool = new this.wasmModule.MemoryPool(1024 * 1024 * 100); // 100MB
        
        monitor.start_timer('large_dataset_processing');
        
        const results = [];
        
        for (let i = 0; i < data.length; i += batchSize) {
            const batch = data.slice(i, i + batchSize);
            
            // 从内存池分配缓冲区
            const buffer = memoryPool.allocate(batch.length * 4); // 4 bytes per float
            
            // 处理批次
            const batchResult = this.wasmModule.process_batch(batch);
            results.push(...batchResult);
            
            // 释放缓冲区回内存池
            memoryPool.deallocate(buffer);
            
            // 定期强制垃圾回收
            if (i % (batchSize * 10) === 0) {
                if (window.gc) {
                    window.gc();
                }
            }
        }
        
        const duration = monitor.end_timer('large_dataset_processing');
        const memoryUsage = monitor.memory_usage();
        
        console.log(`📊 处理 ${data.length} 个元素耗时: ${duration.toFixed(2)}ms`);
        console.log(`💾 内存使用: ${(memoryUsage / 1024 / 1024).toFixed(2)}MB`);
        
        return results;
    }
    
    // SIMD 优化的向量运算
    optimizedVectorOperations(vectorA, vectorB, operation) {
        const simdProcessor = new this.wasmModule.SIMDProcessor();
        const monitor = new this.wasmModule.PerformanceMonitor();
        
        monitor.start_timer(`simd_${operation}`);
        
        let result;
        switch (operation) {
            case 'add':
                result = simdProcessor.vector_add_simd(vectorA, vectorB);
                break;
            case 'multiply_matrix':
                // 假设 vectorA 和 vectorB 是矩阵数据
                const rows = Math.sqrt(vectorA.length);
                const cols = Math.sqrt(vectorB.length);
                result = simdProcessor.matrix_multiply_simd(
                    vectorA, vectorB, rows, rows, cols
                );
                break;
            default:
                throw new Error(`不支持的操作: ${operation}`);
        }
        
        const duration = monitor.end_timer(`simd_${operation}`);
        console.log(`⚡ SIMD ${operation} 操作完成，耗时: ${duration.toFixed(2)}ms`);
        
        return result;
    }
    
    // 性能基准测试
    async runBenchmarks() {
        console.log('🏃‍♂️ 开始性能基准测试...');
        
        const testSizes = [1000, 10000, 100000];
        const results = {};
        
        for (const size of testSizes) {
            console.log(`\n📏 测试数据大小: ${size}`);
            
            // 生成测试数据
            const testDataA = new Float32Array(size);
            const testDataB = new Float32Array(size);
            
            for (let i = 0; i < size; i++) {
                testDataA[i] = Math.random();
                testDataB[i] = Math.random();
            }
            
            // JavaScript 原生实现
            const jsStart = performance.now();
            const jsResult = new Float32Array(size);
            for (let i = 0; i < size; i++) {
                jsResult[i] = testDataA[i] + testDataB[i];
            }
            const jsTime = performance.now() - jsStart;
            
            // WASM 标准实现
            const wasmStart = performance.now();
            const wasmResult = this.wasmModule.vector_add_standard(testDataA, testDataB);
            const wasmTime = performance.now() - wasmStart;
            
            // WASM SIMD 实现
            const simdStart = performance.now();
            const simdResult = this.optimizedVectorOperations(testDataA, testDataB, 'add');
            const simdTime = performance.now() - simdStart;
            
            results[size] = {
                javascript: jsTime,
                wasm: wasmTime,
                wasm_simd: simdTime,
                speedup_wasm: jsTime / wasmTime,
                speedup_simd: jsTime / simdTime
            };
            
            console.log(`  JS: ${jsTime.toFixed(2)}ms`);
            console.log(`  WASM: ${wasmTime.toFixed(2)}ms (${(jsTime/wasmTime).toFixed(1)}x)`);
            console.log(`  WASM+SIMD: ${simdTime.toFixed(2)}ms (${(jsTime/simdTime).toFixed(1)}x)`);
        }
        
        return results;
    }
    
    // 内存使用监控
    startMemoryMonitoring() {
        setInterval(() => {
            if (performance.memory) {
                const memInfo = {
                    used: performance.memory.usedJSHeapSize,
                    total: performance.memory.totalJSHeapSize,
                    limit: performance.memory.jsHeapSizeLimit
                };
                
                console.log(`💾 内存使用: ${(memInfo.used/1024/1024).toFixed(1)}MB / ${(memInfo.total/1024/1024).toFixed(1)}MB`);
                
                // 内存使用超过阈值时警告
                if (memInfo.used / memInfo.limit > 0.8) {
                    console.warn('⚠️ 内存使用率过高，建议进行垃圾回收');
                }
            }
        }, 5000);
    }
}

// Worker 脚本 (wasm-worker.js)
const workerScript = `
let wasmModule = null;

self.onmessage = async function(event) {
    const { type, compiledModule, taskId, data, operation } = event.data;
    
    if (type === 'INIT') {
        try {
            // 在 Worker 中实例化预编译的 WASM 模块
            const wasmInstance = await WebAssembly.instantiate(compiledModule);
            const { optimized_wasm_app } = await import('./pkg/optimized_wasm_app.js');
            wasmModule = optimized_wasm_app;
            
            self.postMessage({ type: 'READY' });
        } catch (error) {
            self.postMessage({ type: 'ERROR', error: error.message });
        }
    } else if (type === 'PROCESS' && wasmModule) {
        try {
            const task = new wasmModule.WorkerTask(taskId, data);
            task.process_data(operation);
            const result = task.result();
            
            self.postMessage({
                type: 'RESULT',
                taskId,
                result
            });
        } catch (error) {
            self.postMessage({
                type: 'ERROR',
                taskId,
                error: error.message
            });
        }
    }
};
`;

// 创建 Worker 脚本的 Blob URL
const workerBlob = new Blob([workerScript], { type: 'application/javascript' });
const workerURL = URL.createObjectURL(workerBlob);

// 使用示例
async function runOptimizationDemo() {
    const optimizer = new WASMPerformanceOptimizer();
    await optimizer.initialize();
    
    // 启动内存监控
    optimizer.startMemoryMonitoring();
    
    // 运行基准测试
    const benchmarkResults = await optimizer.runBenchmarks();
    console.table(benchmarkResults);
    
    // 测试并行处理
    const largeData = new Float32Array(1000000);
    for (let i = 0; i < largeData.length; i++) {
        largeData[i] = Math.random();
    }
    
    const parallelResult = await optimizer.processInParallel(largeData, 'square');
    console.log(`🔄 并行处理 ${largeData.length} 个元素完成`);
}

// 启动演示
runOptimizationDemo();
```

**部署优化配置：**

```yaml
# .github/workflows/optimize-build.yml
name: 优化构建和部署

on:
  push:
    branches: [ main ]

jobs:
  optimize-build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: 安装 Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
        target: wasm32-unknown-unknown
    
    - name: 安装 wasm-pack
      run: curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
    
    - name: 安装 wasm-opt
      run: |
        wget https://github.com/WebAssembly/binaryen/releases/download/version_108/binaryen-version_108-x86_64-linux.tar.gz
        tar -xzf binaryen-version_108-x86_64-linux.tar.gz
        sudo cp binaryen-version_108/bin/* /usr/local/bin/
    
    - name: 构建 WASM (发布版本)
      run: |
        wasm-pack build --target web --out-dir pkg --release
        
    - name: 进一步优化 WASM
      run: |
        wasm-opt -Oz --enable-simd -o pkg/optimized_wasm_app_bg.wasm pkg/optimized_wasm_app_bg.wasm
        wasm-strip pkg/optimized_wasm_app_bg.wasm
    
    - name: 压缩资源
      run: |
        gzip -k pkg/*.wasm
        gzip -k pkg/*.js
    
    - name: 生成性能报告
      run: |
        ls -lh pkg/
        echo "WASM 文件大小:" >> performance-report.txt
        ls -lh pkg/*.wasm >> performance-report.txt
    
    - name: 部署到 GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./
```

**性能优化检查清单**：

- ✅ **编译优化**: LTO、代码生成单元、优化级别
- ✅ **SIMD 指令**: 向量化运算、并行处理
- ✅ **内存管理**: 对象池、缓冲区重用、垃圾回收优化
- ✅ **多线程**: Worker 池、任务分发、并行计算
- ✅ **构建优化**: wasm-opt、strip、压缩
- ✅ **性能监控**: 实时监控、基准测试、内存跟踪
- ✅ **部署优化**: CDN、缓存策略、资源压缩
</details>

## 评分标准

| 题目类型 | 分值分布 | 评分要点 |
|---------|---------|----------|
| **游戏引擎开发** | 30分 | 架构设计、性能表现、功能完整性 |
| **图像处理应用** | 25分 | 算法正确性、SIMD优化、用户体验 |
| **科学计算平台** | 20分 | 数值精度、算法效率、功能覆盖 |
| **性能优化综合** | 25分 | 优化效果、工具使用、最佳实践 |

**总分：100分**
**及格线：60分**

---

**🎯 核心要点**：
- 掌握大型 WebAssembly 项目的架构设计
- 熟练使用性能优化技术和工具
- 理解实际生产环境的部署要求
- 能够进行综合性能分析和调优
