# 第9章 从 Rust 编译

Rust 是编译到 WebAssembly 的最佳语言之一，具有零成本抽象、内存安全、高性能等特点。本章将深入介绍如何使用 Rust 编译到 WebAssembly，包括工具链配置、最佳实践和性能优化。

## 9.1 Rust WebAssembly 工具链

### 9.1.1 环境搭建

**安装 Rust 工具链**：
```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 安装 WebAssembly 目标
rustup target add wasm32-unknown-unknown

# 安装 wasm-pack（推荐）
curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# 或者通过 cargo 安装
cargo install wasm-pack

# 安装其他有用工具
cargo install wasm-bindgen-cli
cargo install wasm-opt
```

**验证安装**：
```bash
# 检查 Rust 版本
rustc --version
cargo --version

# 检查 WebAssembly 目标
rustup target list | grep wasm32

# 检查 wasm-pack
wasm-pack --version
```

### 9.1.2 项目创建和配置

**创建新项目**：
```bash
# 使用 wasm-pack 模板
cargo generate --git https://github.com/rustwasm/wasm-pack-template

# 或手动创建
cargo new --lib my-wasm-project
cd my-wasm-project
```

**Cargo.toml 配置**：
```toml
[package]
name = "my-wasm-project"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]  # 生成动态库

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"          # JavaScript API 绑定
web-sys = "0.3"         # Web API 绑定

# 可选的实用库
serde = { version = "1.0", features = ["derive"] }
serde-wasm-bindgen = "0.4"
console_error_panic_hook = "0.1"

[dependencies.web-sys]
version = "0.3"
features = [
  "console",
  "Document",
  "Element",
  "HtmlElement",
  "Window",
]

# 优化配置
[profile.release]
opt-level = "s"          # 优化体积
lto = true              # 链接时优化
debug = false           # 移除调试信息
panic = "abort"         # panic 时直接终止

# 开发配置
[profile.dev]
opt-level = 0
debug = true
```

### 9.1.3 基本项目结构

```
my-wasm-project/
├── Cargo.toml
├── src/
│   ├── lib.rs          # 主库文件
│   ├── utils.rs        # 工具函数
│   └── math.rs         # 数学计算模块
├── tests/
│   └── web.rs          # 集成测试
├── pkg/                # 生成的 wasm 包（自动生成）
└── www/                # 前端示例（可选）
    ├── index.html
    ├── index.js
    └── package.json
```

## 9.2 基础示例

### 9.2.1 Hello World

**src/lib.rs**：
```rust
use wasm_bindgen::prelude::*;

// 导入 JavaScript 的 alert 函数
#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

// 定义一个宏来简化 console.log
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

// 导出到 JavaScript 的函数
#[wasm_bindgen]
pub fn greet(name: &str) {
    alert(&format!("Hello, {}!", name));
}

#[wasm_bindgen]
pub fn say_hello() {
    console_log!("Hello from Rust and WebAssembly!");
}

// 启动函数，在模块加载时自动执行
#[wasm_bindgen(start)]
pub fn main() {
    console_log!("Rust WebAssembly module loaded!");
    
    // 设置 panic hook 以便在浏览器中调试
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();
}
```

**编译和使用**：
```bash
# 使用 wasm-pack 编译
wasm-pack build --target web

# 生成的文件在 pkg/ 目录下
ls pkg/
# my_wasm_project.js
# my_wasm_project_bg.wasm
# my_wasm_project.d.ts
# package.json
```

**HTML 使用示例**：
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Rust WebAssembly Demo</title>
</head>
<body>
    <script type="module">
        import init, { greet, say_hello } from './pkg/my_wasm_project.js';
        
        async function run() {
            // 初始化 wasm 模块
            await init();
            
            // 调用 Rust 函数
            say_hello();
            greet('WebAssembly');
        }
        
        run();
    </script>
</body>
</html>
```

### 9.2.2 数学计算库

**src/math.rs**：
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct Calculator {
    value: f64,
}

#[wasm_bindgen]
impl Calculator {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Calculator {
        Calculator { value: 0.0 }
    }
    
    #[wasm_bindgen(getter)]
    pub fn value(&self) -> f64 {
        self.value
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_value(&mut self, value: f64) {
        self.value = value;
    }
    
    pub fn add(&mut self, other: f64) -> &mut Self {
        self.value += other;
        self
    }
    
    pub fn subtract(&mut self, other: f64) -> &mut Self {
        self.value -= other;
        self
    }
    
    pub fn multiply(&mut self, other: f64) -> &mut Self {
        self.value *= other;
        self
    }
    
    pub fn divide(&mut self, other: f64) -> Result<&mut Self, String> {
        if other == 0.0 {
            Err("Division by zero".to_string())
        } else {
            self.value /= other;
            Ok(self)
        }
    }
    
    pub fn power(&mut self, exp: f64) -> &mut Self {
        self.value = self.value.powf(exp);
        self
    }
    
    pub fn sqrt(&mut self) -> Result<&mut Self, String> {
        if self.value < 0.0 {
            Err("Square root of negative number".to_string())
        } else {
            self.value = self.value.sqrt();
            Ok(self)
        }
    }
    
    pub fn reset(&mut self) -> &mut Self {
        self.value = 0.0;
        self
    }
}

// 静态函数
#[wasm_bindgen]
pub fn factorial(n: u32) -> u64 {
    if n <= 1 {
        1
    } else {
        (2..=n as u64).product()
    }
}

#[wasm_bindgen]
pub fn fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0u64;
            let mut b = 1u64;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}

#[wasm_bindgen]
pub fn gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 {
        let temp = b;
        b = a % b;
        a = temp;
    }
    a
}

#[wasm_bindgen]
pub fn lcm(a: u32, b: u32) -> u32 {
    if a == 0 || b == 0 {
        0
    } else {
        (a * b) / gcd(a, b)
    }
}

#[wasm_bindgen]
pub fn prime_check(n: u32) -> bool {
    if n < 2 {
        return false;
    }
    if n == 2 {
        return true;
    }
    if n % 2 == 0 {
        return false;
    }
    
    let sqrt_n = (n as f64).sqrt() as u32;
    for i in (3..=sqrt_n).step_by(2) {
        if n % i == 0 {
            return false;
        }
    }
    true
}
```

**lib.rs 中导出模块**：
```rust
mod math;
pub use math::*;

mod utils;
pub use utils::*;
```

### 9.2.3 向量和矩阵运算

**src/linear_algebra.rs**：
```rust
use wasm_bindgen::prelude::*;
use std::fmt;

#[wasm_bindgen]
pub struct Vector3 {
    x: f64,
    y: f64,
    z: f64,
}

#[wasm_bindgen]
impl Vector3 {
    #[wasm_bindgen(constructor)]
    pub fn new(x: f64, y: f64, z: f64) -> Vector3 {
        Vector3 { x, y, z }
    }
    
    #[wasm_bindgen(getter)]
    pub fn x(&self) -> f64 { self.x }
    
    #[wasm_bindgen(getter)]
    pub fn y(&self) -> f64 { self.y }
    
    #[wasm_bindgen(getter)]
    pub fn z(&self) -> f64 { self.z }
    
    #[wasm_bindgen(setter)]
    pub fn set_x(&mut self, x: f64) { self.x = x; }
    
    #[wasm_bindgen(setter)]
    pub fn set_y(&mut self, y: f64) { self.y = y; }
    
    #[wasm_bindgen(setter)]
    pub fn set_z(&mut self, z: f64) { self.z = z; }
    
    pub fn length(&self) -> f64 {
        (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
    }
    
    pub fn normalize(&mut self) -> &mut Self {
        let len = self.length();
        if len > 0.0 {
            self.x /= len;
            self.y /= len;
            self.z /= len;
        }
        self
    }
    
    pub fn dot(&self, other: &Vector3) -> f64 {
        self.x * other.x + self.y * other.y + self.z * other.z
    }
    
    pub fn cross(&self, other: &Vector3) -> Vector3 {
        Vector3 {
            x: self.y * other.z - self.z * other.y,
            y: self.z * other.x - self.x * other.z,
            z: self.x * other.y - self.y * other.x,
        }
    }
    
    pub fn add(&self, other: &Vector3) -> Vector3 {
        Vector3 {
            x: self.x + other.x,
            y: self.y + other.y,
            z: self.z + other.z,
        }
    }
    
    pub fn subtract(&self, other: &Vector3) -> Vector3 {
        Vector3 {
            x: self.x - other.x,
            y: self.y - other.y,
            z: self.z - other.z,
        }
    }
    
    pub fn scale(&self, scalar: f64) -> Vector3 {
        Vector3 {
            x: self.x * scalar,
            y: self.y * scalar,
            z: self.z * scalar,
        }
    }
    
    pub fn distance_to(&self, other: &Vector3) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        let dz = self.z - other.z;
        (dx * dx + dy * dy + dz * dz).sqrt()
    }
    
    #[wasm_bindgen(js_name = toString)]
    pub fn to_string(&self) -> String {
        format!("Vector3({:.3}, {:.3}, {:.3})", self.x, self.y, self.z)
    }
}

#[wasm_bindgen]
pub struct Matrix4x4 {
    elements: [f64; 16], // 列主序存储
}

#[wasm_bindgen]
impl Matrix4x4 {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Matrix4x4 {
        Matrix4x4 {
            elements: [
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            ]
        }
    }
    
    pub fn identity() -> Matrix4x4 {
        Matrix4x4::new()
    }
    
    pub fn set(&mut self, row: usize, col: usize, value: f64) -> Result<(), String> {
        if row >= 4 || col >= 4 {
            return Err("Matrix index out of bounds".to_string());
        }
        self.elements[col * 4 + row] = value;
        Ok(())
    }
    
    pub fn get(&self, row: usize, col: usize) -> Result<f64, String> {
        if row >= 4 || col >= 4 {
            return Err("Matrix index out of bounds".to_string());
        }
        Ok(self.elements[col * 4 + row])
    }
    
    pub fn multiply(&self, other: &Matrix4x4) -> Matrix4x4 {
        let mut result = Matrix4x4::new();
        
        for i in 0..4 {
            for j in 0..4 {
                let mut sum = 0.0;
                for k in 0..4 {
                    sum += self.elements[k * 4 + i] * other.elements[j * 4 + k];
                }
                result.elements[j * 4 + i] = sum;
            }
        }
        
        result
    }
    
    pub fn transform_vector(&self, vector: &Vector3) -> Vector3 {
        let x = self.elements[0] * vector.x + self.elements[4] * vector.y + self.elements[8] * vector.z + self.elements[12];
        let y = self.elements[1] * vector.x + self.elements[5] * vector.y + self.elements[9] * vector.z + self.elements[13];
        let z = self.elements[2] * vector.x + self.elements[6] * vector.y + self.elements[10] * vector.z + self.elements[14];
        
        Vector3::new(x, y, z)
    }
    
    pub fn translate(x: f64, y: f64, z: f64) -> Matrix4x4 {
        let mut matrix = Matrix4x4::identity();
        matrix.elements[12] = x;
        matrix.elements[13] = y;
        matrix.elements[14] = z;
        matrix
    }
    
    pub fn scale(x: f64, y: f64, z: f64) -> Matrix4x4 {
        let mut matrix = Matrix4x4::new();
        matrix.elements[0] = x;
        matrix.elements[5] = y;
        matrix.elements[10] = z;
        matrix
    }
    
    pub fn rotate_x(angle_rad: f64) -> Matrix4x4 {
        let cos_a = angle_rad.cos();
        let sin_a = angle_rad.sin();
        
        let mut matrix = Matrix4x4::identity();
        matrix.elements[5] = cos_a;
        matrix.elements[6] = sin_a;
        matrix.elements[9] = -sin_a;
        matrix.elements[10] = cos_a;
        matrix
    }
    
    pub fn rotate_y(angle_rad: f64) -> Matrix4x4 {
        let cos_a = angle_rad.cos();
        let sin_a = angle_rad.sin();
        
        let mut matrix = Matrix4x4::identity();
        matrix.elements[0] = cos_a;
        matrix.elements[2] = -sin_a;
        matrix.elements[8] = sin_a;
        matrix.elements[10] = cos_a;
        matrix
    }
    
    pub fn rotate_z(angle_rad: f64) -> Matrix4x4 {
        let cos_a = angle_rad.cos();
        let sin_a = angle_rad.sin();
        
        let mut matrix = Matrix4x4::identity();
        matrix.elements[0] = cos_a;
        matrix.elements[1] = sin_a;
        matrix.elements[4] = -sin_a;
        matrix.elements[5] = cos_a;
        matrix
    }
    
    pub fn determinant(&self) -> f64 {
        let e = &self.elements;
        
        // 4x4 矩阵行列式计算（使用第一行展开）
        e[0] * (
            e[5] * (e[10] * e[15] - e[11] * e[14]) -
            e[6] * (e[9] * e[15] - e[11] * e[13]) +
            e[7] * (e[9] * e[14] - e[10] * e[13])
        ) - e[4] * (
            e[1] * (e[10] * e[15] - e[11] * e[14]) -
            e[2] * (e[9] * e[15] - e[11] * e[13]) +
            e[3] * (e[9] * e[14] - e[10] * e[13])
        ) + e[8] * (
            e[1] * (e[6] * e[15] - e[7] * e[14]) -
            e[2] * (e[5] * e[15] - e[7] * e[13]) +
            e[3] * (e[5] * e[14] - e[6] * e[13])
        ) - e[12] * (
            e[1] * (e[6] * e[11] - e[7] * e[10]) -
            e[2] * (e[5] * e[11] - e[7] * e[9]) +
            e[3] * (e[5] * e[10] - e[6] * e[9])
        )
    }
    
    pub fn get_elements(&self) -> Vec<f64> {
        self.elements.to_vec()
    }
    
    #[wasm_bindgen(js_name = toString)]
    pub fn to_string(&self) -> String {
        let mut result = String::from("Matrix4x4[\n");
        for row in 0..4 {
            result.push_str("  [");
            for col in 0..4 {
                result.push_str(&format!("{:8.3}", self.elements[col * 4 + row]));
                if col < 3 { result.push_str(", "); }
            }
            result.push_str("]\n");
        }
        result.push(']');
        result
    }
}
```

## 9.3 JavaScript 互操作

### 9.3.1 数据类型绑定

**复杂数据结构绑定**：
```rust
use wasm_bindgen::prelude::*;
use serde::{Deserialize, Serialize};

// 使用 serde 进行序列化
#[derive(Serialize, Deserialize)]
#[wasm_bindgen]
pub struct Person {
    name: String,
    age: u32,
    email: String,
}

#[wasm_bindgen]
impl Person {
    #[wasm_bindgen(constructor)]
    pub fn new(name: String, age: u32, email: String) -> Person {
        Person { name, age, email }
    }
    
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }
    
    #[wasm_bindgen(getter)]
    pub fn age(&self) -> u32 {
        self.age
    }
    
    #[wasm_bindgen(getter)]
    pub fn email(&self) -> String {
        self.email.clone()
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_age(&mut self, age: u32) {
        self.age = age;
    }
    
    pub fn greet(&self) -> String {
        format!("Hello, I'm {} and I'm {} years old!", self.name, self.age)
    }
}

// 处理 JavaScript 对象
#[wasm_bindgen]
pub fn process_person_data(value: &JsValue) -> Result<String, JsValue> {
    let person: Person = serde_wasm_bindgen::from_value(value.clone())?;
    Ok(format!("Processed: {}", person.greet()))
}

// 返回复杂数据给 JavaScript
#[wasm_bindgen]
pub fn create_person_list() -> Result<JsValue, JsValue> {
    let people = vec![
        Person::new("Alice".to_string(), 30, "alice@example.com".to_string()),
        Person::new("Bob".to_string(), 25, "bob@example.com".to_string()),
        Person::new("Charlie".to_string(), 35, "charlie@example.com".to_string()),
    ];
    
    serde_wasm_bindgen::to_value(&people).map_err(|err| err.into())
}

// 处理数组
#[wasm_bindgen]
pub fn sum_array(numbers: &[f64]) -> f64 {
    numbers.iter().sum()
}

#[wasm_bindgen]
pub fn sort_array(numbers: &mut [f64]) {
    numbers.sort_by(|a, b| a.partial_cmp(b).unwrap());
}

#[wasm_bindgen]
pub fn filter_positive(numbers: Vec<f64>) -> Vec<f64> {
    numbers.into_iter().filter(|&x| x > 0.0).collect()
}
```

### 9.3.2 异步操作和 Promise

**异步函数绑定**：
```rust
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
pub async fn fetch_data(url: String) -> Result<JsValue, JsValue> {
    let mut opts = RequestInit::new();
    opts.method("GET");
    opts.mode(RequestMode::Cors);

    let request = Request::new_with_str_and_init(&url, &opts)?;

    let window = web_sys::window().unwrap();
    let resp_value = JsFuture::from(window.fetch_with_request(&request)).await?;
    let resp: Response = resp_value.dyn_into().unwrap();

    let text = JsFuture::from(resp.text()?).await?;
    Ok(text)
}

#[wasm_bindgen]
pub async fn delay(ms: u32) -> Result<(), JsValue> {
    let promise = js_sys::Promise::new(&mut |resolve, _| {
        let closure = Closure::once_into_js(move || {
            resolve.call0(&JsValue::NULL).unwrap();
        });
        
        web_sys::window()
            .unwrap()
            .set_timeout_with_callback_and_timeout_and_arguments_0(
                closure.as_ref().unchecked_ref(),
                ms as i32,
            )
            .unwrap();
    });
    
    JsFuture::from(promise).await?;
    Ok(())
}

// 计算密集型异步任务
#[wasm_bindgen]
pub async fn heavy_computation(n: u32) -> Result<u64, JsValue> {
    let mut result = 0u64;
    
    for i in 0..n {
        // 每1000次迭代让出控制权
        if i % 1000 == 0 {
            delay(0).await?;
        }
        
        result = result.wrapping_add(fibonacci(i % 30) as u64);
    }
    
    Ok(result)
}
```

### 9.3.3 Web API 集成

**DOM 操作**：
```rust
use wasm_bindgen::prelude::*;
use web_sys::{console, Document, Element, HtmlElement, Window};

#[wasm_bindgen]
pub struct DomHelper {
    document: Document,
    window: Window,
}

#[wasm_bindgen]
impl DomHelper {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Result<DomHelper, JsValue> {
        let window = web_sys::window().ok_or("No global window exists")?;
        let document = window.document().ok_or("Should have a document on window")?;
        
        Ok(DomHelper { document, window })
    }
    
    pub fn create_element(&self, tag_name: &str) -> Result<Element, JsValue> {
        self.document.create_element(tag_name)
    }
    
    pub fn get_element_by_id(&self, id: &str) -> Option<Element> {
        self.document.get_element_by_id(id)
    }
    
    pub fn set_inner_html(&self, element_id: &str, html: &str) -> Result<(), JsValue> {
        if let Some(element) = self.get_element_by_id(element_id) {
            element.set_inner_html(html);
            Ok(())
        } else {
            Err(JsValue::from_str(&format!("Element with id '{}' not found", element_id)))
        }
    }
    
    pub fn append_child(&self, parent_id: &str, child: &Element) -> Result<(), JsValue> {
        if let Some(parent) = self.get_element_by_id(parent_id) {
            parent.append_child(child)?;
            Ok(())
        } else {
            Err(JsValue::from_str(&format!("Parent element with id '{}' not found", parent_id)))
        }
    }
    
    pub fn add_event_listener(&self, element_id: &str, event_type: &str, callback: &Closure<dyn FnMut()>) -> Result<(), JsValue> {
        if let Some(element) = self.get_element_by_id(element_id) {
            let html_element: HtmlElement = element.dyn_into()?;
            html_element.add_event_listener_with_callback(event_type, callback.as_ref().unchecked_ref())?;
            Ok(())
        } else {
            Err(JsValue::from_str(&format!("Element with id '{}' not found", element_id)))
        }
    }
    
    pub fn log(&self, message: &str) {
        console::log_1(&JsValue::from_str(message));
    }
    
    pub fn alert(&self, message: &str) {
        self.window.alert_with_message(message).unwrap();
    }
}

// 实用的 DOM 操作函数
#[wasm_bindgen]
pub fn create_button_with_callback(
    container_id: &str, 
    button_text: &str,
    callback: &js_sys::Function
) -> Result<(), JsValue> {
    let dom = DomHelper::new()?;
    
    // 创建按钮
    let button = dom.create_element("button")?;
    button.set_text_content(Some(button_text));
    
    // 添加事件监听器
    let closure = Closure::wrap(Box::new(move || {
        callback.call0(&JsValue::NULL).unwrap();
    }) as Box<dyn FnMut()>);
    
    let html_button: HtmlElement = button.dyn_into()?;
    html_button.add_event_listener_with_callback("click", closure.as_ref().unchecked_ref())?;
    
    // 将按钮添加到容器
    dom.append_child(container_id, &button)?;
    
    // 防止闭包被释放
    closure.forget();
    
    Ok(())
}
```

## 9.4 性能优化

### 9.4.1 编译器优化

**Cargo.toml 优化配置**：
```toml
[profile.release]
# 体积优化
opt-level = "s"     # 或 "z" 极致体积优化
lto = true          # 链接时优化
codegen-units = 1   # 更好的优化，但编译慢
panic = "abort"     # 减少 panic 处理代码
strip = true        # 移除符号表

# 性能优化配置
[profile.performance]
inherits = "release"
opt-level = 3       # 最高性能优化
lto = "fat"         # 全链接时优化

# 特定依赖的优化
[profile.dev.package."*"]
opt-level = 2       # 依赖库使用较高优化级别
```

**wasm-pack 构建选项**：
```bash
# 体积优化构建
wasm-pack build --target web --release -- --features "optimize-size"

# 性能优化构建
wasm-pack build --target web --release -- --features "optimize-speed"

# 使用 wasm-opt 进一步优化
wasm-pack build --target web --release
wasm-opt -Oz -o pkg/optimized.wasm pkg/my_project_bg.wasm
```

### 9.4.2 内存管理优化

**自定义分配器**：
```rust
use wasm_bindgen::prelude::*;

// 使用 wee_alloc 作为全局分配器（体积更小）
#[cfg(feature = "wee_alloc")]
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// 内存池示例
#[wasm_bindgen]
pub struct MemoryPool<T> {
    pool: Vec<T>,
    available: Vec<usize>,
    capacity: usize,
}

#[wasm_bindgen]
impl MemoryPool<f64> {
    #[wasm_bindgen(constructor)]
    pub fn new(capacity: usize) -> MemoryPool<f64> {
        let pool = Vec::with_capacity(capacity);
        let available = (0..capacity).collect();
        
        MemoryPool {
            pool,
            available,
            capacity,
        }
    }
    
    pub fn allocate(&mut self, value: f64) -> Option<usize> {
        if let Some(index) = self.available.pop() {
            if index < self.pool.len() {
                self.pool[index] = value;
            } else {
                self.pool.push(value);
            }
            Some(index)
        } else {
            None
        }
    }
    
    pub fn deallocate(&mut self, index: usize) -> Result<(), String> {
        if index >= self.capacity {
            return Err("Index out of bounds".to_string());
        }
        
        self.available.push(index);
        Ok(())
    }
    
    pub fn get(&self, index: usize) -> Result<f64, String> {
        if index >= self.pool.len() {
            return Err("Index out of bounds".to_string());
        }
        Ok(self.pool[index])
    }
    
    pub fn set(&mut self, index: usize, value: f64) -> Result<(), String> {
        if index >= self.pool.len() {
            return Err("Index out of bounds".to_string());
        }
        self.pool[index] = value;
        Ok(())
    }
}

// 零拷贝字符串处理
#[wasm_bindgen]
pub fn process_large_string(input: &str) -> String {
    // 避免不必要的字符串分配
    input.lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| line.trim())
        .collect::<Vec<_>>()
        .join("\n")
}

// 使用 Vec<u8> 而不是 String 进行字节操作
#[wasm_bindgen]
pub fn process_bytes(mut data: Vec<u8>) -> Vec<u8> {
    // 就地修改，避免额外分配
    for byte in &mut data {
        *byte = byte.wrapping_add(1);
    }
    data
}
```

### 9.4.3 算法优化

**SIMD 并行化**：
```rust
use std::arch::wasm32::*;

#[wasm_bindgen]
pub fn simd_add_arrays(a: &[f32], b: &[f32]) -> Vec<f32> {
    let mut result = Vec::with_capacity(a.len());
    let chunks = a.len() / 4;
    
    // SIMD 处理（每次处理4个元素）
    for i in 0..chunks {
        let offset = i * 4;
        
        unsafe {
            let va = v128_load(a.as_ptr().add(offset) as *const v128);
            let vb = v128_load(b.as_ptr().add(offset) as *const v128);
            let vr = f32x4_add(va, vb);
            
            let temp = [0f32; 4];
            v128_store(temp.as_ptr() as *mut v128, vr);
            result.extend_from_slice(&temp);
        }
    }
    
    // 处理剩余元素
    for i in (chunks * 4)..a.len() {
        result.push(a[i] + b[i]);
    }
    
    result
}

#[wasm_bindgen]
pub fn simd_dot_product(a: &[f32], b: &[f32]) -> f32 {
    let mut sum = unsafe { f32x4_splat(0.0) };
    let chunks = a.len() / 4;
    
    for i in 0..chunks {
        let offset = i * 4;
        
        unsafe {
            let va = v128_load(a.as_ptr().add(offset) as *const v128);
            let vb = v128_load(b.as_ptr().add(offset) as *const v128);
            let prod = f32x4_mul(va, vb);
            sum = f32x4_add(sum, prod);
        }
    }
    
    // 提取并累加 SIMD 结果
    let mut result = unsafe {
        f32x4_extract_lane::<0>(sum) +
        f32x4_extract_lane::<1>(sum) +
        f32x4_extract_lane::<2>(sum) +
        f32x4_extract_lane::<3>(sum)
    };
    
    // 处理剩余元素
    for i in (chunks * 4)..a.len() {
        result += a[i] * b[i];
    }
    
    result
}
```

**缓存友好的算法**：
```rust
#[wasm_bindgen]
pub fn cache_friendly_matrix_multiply(
    a: &[f64], 
    b: &[f64], 
    c: &mut [f64], 
    n: usize,
    block_size: usize
) {
    // 分块矩阵乘法，提高缓存命中率
    for ii in (0..n).step_by(block_size) {
        for jj in (0..n).step_by(block_size) {
            for kk in (0..n).step_by(block_size) {
                
                let i_end = (ii + block_size).min(n);
                let j_end = (jj + block_size).min(n);
                let k_end = (kk + block_size).min(n);
                
                for i in ii..i_end {
                    for j in jj..j_end {
                        let mut sum = 0.0;
                        for k in kk..k_end {
                            sum += a[i * n + k] * b[k * n + j];
                        }
                        c[i * n + j] += sum;
                    }
                }
            }
        }
    }
}

// 预计算和查找表优化
#[wasm_bindgen]
pub struct SinCosTable {
    sin_table: Vec<f32>,
    cos_table: Vec<f32>,
    table_size: usize,
}

#[wasm_bindgen]
impl SinCosTable {
    #[wasm_bindgen(constructor)]
    pub fn new(table_size: usize) -> SinCosTable {
        let mut sin_table = Vec::with_capacity(table_size);
        let mut cos_table = Vec::with_capacity(table_size);
        
        for i in 0..table_size {
            let angle = 2.0 * std::f32::consts::PI * (i as f32) / (table_size as f32);
            sin_table.push(angle.sin());
            cos_table.push(angle.cos());
        }
        
        SinCosTable {
            sin_table,
            cos_table,
            table_size,
        }
    }
    
    pub fn sin(&self, angle: f32) -> f32 {
        let normalized = angle / (2.0 * std::f32::consts::PI);
        let index = ((normalized.fract() * self.table_size as f32) as usize) % self.table_size;
        self.sin_table[index]
    }
    
    pub fn cos(&self, angle: f32) -> f32 {
        let normalized = angle / (2.0 * std::f32::consts::PI);
        let index = ((normalized.fract() * self.table_size as f32) as usize) % self.table_size;
        self.cos_table[index]
    }
}
```

## 9.5 测试和调试

### 9.5.1 单元测试

**tests/web.rs**：
```rust
//! 浏览器环境下的测试

#![cfg(target_arch = "wasm32")]

extern crate wasm_bindgen_test;
use wasm_bindgen_test::*;

use my_wasm_project::*;

wasm_bindgen_test_configure!(run_in_browser);

#[wasm_bindgen_test]
fn test_calculator_basic_operations() {
    let mut calc = Calculator::new();
    
    calc.add(10.0);
    assert_eq!(calc.value(), 10.0);
    
    calc.multiply(2.0);
    assert_eq!(calc.value(), 20.0);
    
    calc.subtract(5.0);
    assert_eq!(calc.value(), 15.0);
    
    calc.divide(3.0).unwrap();
    assert!((calc.value() - 5.0).abs() < f64::EPSILON);
}

#[wasm_bindgen_test]
fn test_division_by_zero() {
    let mut calc = Calculator::new();
    calc.set_value(10.0);
    
    let result = calc.divide(0.0);
    assert!(result.is_err());
    assert_eq!(calc.value(), 10.0); // 值不应该改变
}

#[wasm_bindgen_test]
fn test_vector_operations() {
    let v1 = Vector3::new(1.0, 2.0, 3.0);
    let v2 = Vector3::new(4.0, 5.0, 6.0);
    
    let dot = v1.dot(&v2);
    assert_eq!(dot, 32.0); // 1*4 + 2*5 + 3*6 = 32
    
    let cross = v1.cross(&v2);
    assert_eq!(cross.x(), -3.0);
    assert_eq!(cross.y(), 6.0);
    assert_eq!(cross.z(), -3.0);
    
    let distance = v1.distance_to(&v2);
    assert!((distance - (27.0f64).sqrt()).abs() < f64::EPSILON);
}

#[wasm_bindgen_test]
fn test_matrix_multiplication() {
    let m1 = Matrix4x4::identity();
    let m2 = Matrix4x4::translate(1.0, 2.0, 3.0);
    
    let result = m1.multiply(&m2);
    
    // 单位矩阵乘以平移矩阵应该得到平移矩阵
    assert_eq!(result.get(0, 3).unwrap(), 1.0);
    assert_eq!(result.get(1, 3).unwrap(), 2.0);
    assert_eq!(result.get(2, 3).unwrap(), 3.0);
}

#[wasm_bindgen_test]
async fn test_async_computation() {
    let result = heavy_computation(1000).await.unwrap();
    assert!(result > 0);
}

#[wasm_bindgen_test]
fn test_prime_check() {
    assert!(!prime_check(1));
    assert!(prime_check(2));
    assert!(prime_check(3));
    assert!(!prime_check(4));
    assert!(prime_check(5));
    assert!(!prime_check(9));
    assert!(prime_check(17));
    assert!(!prime_check(25));
}

#[wasm_bindgen_test]
fn test_fibonacci() {
    assert_eq!(fibonacci(0), 0);
    assert_eq!(fibonacci(1), 1);
    assert_eq!(fibonacci(2), 1);
    assert_eq!(fibonacci(3), 2);
    assert_eq!(fibonacci(4), 3);
    assert_eq!(fibonacci(5), 5);
    assert_eq!(fibonacci(10), 55);
}
```

**运行测试**：
```bash
# 安装测试运行器
cargo install wasm-pack

# 运行浏览器测试
wasm-pack test --headless --chrome
wasm-pack test --headless --firefox

# 运行 Node.js 测试
wasm-pack test --node
```

### 9.5.2 性能基准测试

**benches/benchmark.rs**：
```rust
#![cfg(target_arch = "wasm32")]

extern crate wasm_bindgen_test;
use wasm_bindgen_test::*;
use web_sys::console;

use my_wasm_project::*;

wasm_bindgen_test_configure!(run_in_browser);

fn measure_time<F, R>(name: &str, f: F) -> R
where
    F: FnOnce() -> R,
{
    let start = js_sys::Date::now();
    let result = f();
    let end = js_sys::Date::now();
    
    console::log_1(&format!("{}: {:.2}ms", name, end - start).into());
    result
}

#[wasm_bindgen_test]
fn benchmark_fibonacci() {
    measure_time("Fibonacci(30)", || {
        fibonacci(30)
    });
    
    measure_time("Fibonacci(35)", || {
        fibonacci(35)
    });
}

#[wasm_bindgen_test]
fn benchmark_vector_operations() {
    let v1 = Vector3::new(1.0, 2.0, 3.0);
    let v2 = Vector3::new(4.0, 5.0, 6.0);
    
    measure_time("Vector dot product (10000x)", || {
        for _ in 0..10000 {
            v1.dot(&v2);
        }
    });
    
    measure_time("Vector cross product (10000x)", || {
        for _ in 0..10000 {
            v1.cross(&v2);
        }
    });
}

#[wasm_bindgen_test]
fn benchmark_matrix_operations() {
    let m1 = Matrix4x4::identity();
    let m2 = Matrix4x4::translate(1.0, 2.0, 3.0);
    
    measure_time("Matrix multiplication (1000x)", || {
        for _ in 0..1000 {
            m1.multiply(&m2);
        }
    });
}

#[wasm_bindgen_test]
fn benchmark_simd_vs_scalar() {
    let a: Vec<f32> = (0..10000).map(|i| i as f32).collect();
    let b: Vec<f32> = (0..10000).map(|i| (i * 2) as f32).collect();
    
    measure_time("Scalar dot product", || {
        let mut sum = 0.0f32;
        for i in 0..a.len() {
            sum += a[i] * b[i];
        }
        sum
    });
    
    measure_time("SIMD dot product", || {
        simd_dot_product(&a, &b)
    });
}
```

### 9.5.3 调试技巧

**调试配置**：
```rust
use wasm_bindgen::prelude::*;

// 调试宏
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
    
    #[wasm_bindgen(js_namespace = console)]
    fn error(s: &str);
    
    #[wasm_bindgen(js_namespace = console, js_name = log)]
    fn log_u32(a: u32);
    
    #[wasm_bindgen(js_namespace = console, js_name = log)]
    fn log_f64(a: f64);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

macro_rules! console_error {
    ($($t:tt)*) => (error(&format_args!($($t)*).to_string()))
}

// 条件编译的调试代码
#[wasm_bindgen]
pub fn debug_function(value: f64) -> f64 {
    #[cfg(debug_assertions)]
    {
        console_log!("Debug: input value = {}", value);
    }
    
    let result = value * 2.0;
    
    #[cfg(debug_assertions)]
    {
        console_log!("Debug: result = {}", result);
    }
    
    result
}

// 错误处理和日志记录
#[wasm_bindgen]
pub fn safe_divide(a: f64, b: f64) -> Result<f64, String> {
    if b == 0.0 {
        let error_msg = "Division by zero attempted";
        console_error!("{}", error_msg);
        Err(error_msg.to_string())
    } else {
        let result = a / b;
        console_log!("Division result: {} / {} = {}", a, b, result);
        Ok(result)
    }
}

// 性能监控
#[wasm_bindgen]
pub struct PerformanceMonitor {
    start_time: f64,
    samples: Vec<f64>,
}

#[wasm_bindgen]
impl PerformanceMonitor {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PerformanceMonitor {
        PerformanceMonitor {
            start_time: js_sys::Date::now(),
            samples: Vec::new(),
        }
    }
    
    pub fn start_measurement(&mut self) {
        self.start_time = js_sys::Date::now();
    }
    
    pub fn end_measurement(&mut self) -> f64 {
        let elapsed = js_sys::Date::now() - self.start_time;
        self.samples.push(elapsed);
        console_log!("Measurement: {:.2}ms", elapsed);
        elapsed
    }
    
    pub fn get_average(&self) -> f64 {
        if self.samples.is_empty() {
            0.0
        } else {
            self.samples.iter().sum::<f64>() / self.samples.len() as f64
        }
    }
    
    pub fn get_stats(&self) -> String {
        if self.samples.is_empty() {
            return "No measurements".to_string();
        }
        
        let avg = self.get_average();
        let min = self.samples.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = self.samples.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        
        format!("Samples: {}, Avg: {:.2}ms, Min: {:.2}ms, Max: {:.2}ms", 
                self.samples.len(), avg, min, max)
    }
}
```

## 9.6 实际应用案例

### 9.6.1 游戏引擎核心

**src/game_engine.rs**：
```rust
use wasm_bindgen::prelude::*;
use std::collections::HashMap;

#[wasm_bindgen]
pub struct GameEngine {
    entities: HashMap<u32, Entity>,
    next_entity_id: u32,
    delta_time: f64,
    last_frame_time: f64,
}

#[wasm_bindgen]
pub struct Entity {
    id: u32,
    position: Vector3,
    velocity: Vector3,
    rotation: Vector3,
    scale: Vector3,
    active: bool,
}

#[wasm_bindgen]
impl Entity {
    #[wasm_bindgen(constructor)]
    pub fn new(id: u32) -> Entity {
        Entity {
            id,
            position: Vector3::new(0.0, 0.0, 0.0),
            velocity: Vector3::new(0.0, 0.0, 0.0),
            rotation: Vector3::new(0.0, 0.0, 0.0),
            scale: Vector3::new(1.0, 1.0, 1.0),
            active: true,
        }
    }
    
    #[wasm_bindgen(getter)]
    pub fn position(&self) -> Vector3 {
        Vector3::new(self.position.x(), self.position.y(), self.position.z())
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_position(&mut self, pos: Vector3) {
        self.position = pos;
    }
    
    pub fn translate(&mut self, delta: &Vector3) {
        self.position = self.position.add(delta);
    }
    
    pub fn update(&mut self, delta_time: f64) {
        if !self.active {
            return;
        }
        
        // 更新位置基于速度
        let scaled_velocity = self.velocity.scale(delta_time);
        self.position = self.position.add(&scaled_velocity);
    }
}

#[wasm_bindgen]
impl GameEngine {
    #[wasm_bindgen(constructor)]
    pub fn new() -> GameEngine {
        GameEngine {
            entities: HashMap::new(),
            next_entity_id: 1,
            delta_time: 0.0,
            last_frame_time: js_sys::Date::now(),
        }
    }
    
    pub fn create_entity(&mut self) -> u32 {
        let id = self.next_entity_id;
        self.next_entity_id += 1;
        
        let entity = Entity::new(id);
        self.entities.insert(id, entity);
        
        id
    }
    
    pub fn remove_entity(&mut self, id: u32) -> bool {
        self.entities.remove(&id).is_some()
    }
    
    pub fn get_entity(&self, id: u32) -> Option<Entity> {
        self.entities.get(&id).cloned()
    }
    
    pub fn update(&mut self) {
        let current_time = js_sys::Date::now();
        self.delta_time = (current_time - self.last_frame_time) / 1000.0;
        self.last_frame_time = current_time;
        
        // 更新所有实体
        for entity in self.entities.values_mut() {
            entity.update(self.delta_time);
        }
    }
    
    pub fn get_delta_time(&self) -> f64 {
        self.delta_time
    }
    
    pub fn get_entity_count(&self) -> u32 {
        self.entities.len() as u32
    }
}

// 物理系统
#[wasm_bindgen]
pub struct PhysicsWorld {
    gravity: Vector3,
    entities: Vec<u32>,
    engine: GameEngine,
}

#[wasm_bindgen]
impl PhysicsWorld {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PhysicsWorld {
        PhysicsWorld {
            gravity: Vector3::new(0.0, -9.81, 0.0),
            entities: Vec::new(),
            engine: GameEngine::new(),
        }
    }
    
    pub fn set_gravity(&mut self, gravity: Vector3) {
        self.gravity = gravity;
    }
    
    pub fn add_entity(&mut self, entity_id: u32) {
        self.entities.push(entity_id);
    }
    
    pub fn simulate_step(&mut self, delta_time: f64) {
        for &entity_id in &self.entities {
            if let Some(mut entity) = self.engine.get_entity(entity_id) {
                // 应用重力
                let gravity_force = self.gravity.scale(delta_time);
                entity.velocity = entity.velocity.add(&gravity_force);
                
                // 更新实体
                entity.update(delta_time);
            }
        }
    }
}
```

### 9.6.2 图像处理库

**src/image_processing.rs**：
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct ImageProcessor {
    width: u32,
    height: u32,
    data: Vec<u8>, // RGBA 格式
}

#[wasm_bindgen]
impl ImageProcessor {
    #[wasm_bindgen(constructor)]
    pub fn new(width: u32, height: u32) -> ImageProcessor {
        let size = (width * height * 4) as usize;
        ImageProcessor {
            width,
            height,
            data: vec![0; size],
        }
    }
    
    pub fn load_from_array(&mut self, data: Vec<u8>) -> Result<(), String> {
        let expected_size = (self.width * self.height * 4) as usize;
        if data.len() != expected_size {
            return Err(format!("Data size mismatch: expected {}, got {}", 
                             expected_size, data.len()));
        }
        self.data = data;
        Ok(())
    }
    
    pub fn get_data(&self) -> Vec<u8> {
        self.data.clone()
    }
    
    pub fn get_pixel(&self, x: u32, y: u32) -> Result<Vec<u8>, String> {
        if x >= self.width || y >= self.height {
            return Err("Pixel coordinates out of bounds".to_string());
        }
        
        let index = ((y * self.width + x) * 4) as usize;
        Ok(vec![
            self.data[index],     // R
            self.data[index + 1], // G
            self.data[index + 2], // B
            self.data[index + 3], // A
        ])
    }
    
    pub fn set_pixel(&mut self, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) -> Result<(), String> {
        if x >= self.width || y >= self.height {
            return Err("Pixel coordinates out of bounds".to_string());
        }
        
        let index = ((y * self.width + x) * 4) as usize;
        self.data[index] = r;
        self.data[index + 1] = g;
        self.data[index + 2] = b;
        self.data[index + 3] = a;
        
        Ok(())
    }
    
    pub fn apply_grayscale(&mut self) {
        for i in (0..self.data.len()).step_by(4) {
            let r = self.data[i] as f32;
            let g = self.data[i + 1] as f32;
            let b = self.data[i + 2] as f32;
            
            // 使用亮度公式
            let gray = (0.299 * r + 0.587 * g + 0.114 * b) as u8;
            
            self.data[i] = gray;
            self.data[i + 1] = gray;
            self.data[i + 2] = gray;
            // Alpha 保持不变
        }
    }
    
    pub fn adjust_brightness(&mut self, factor: f32) {
        for i in (0..self.data.len()).step_by(4) {
            self.data[i] = ((self.data[i] as f32 * factor).min(255.0).max(0.0)) as u8;
            self.data[i + 1] = ((self.data[i + 1] as f32 * factor).min(255.0).max(0.0)) as u8;
            self.data[i + 2] = ((self.data[i + 2] as f32 * factor).min(255.0).max(0.0)) as u8;
            // Alpha 保持不变
        }
    }
    
    pub fn apply_blur(&mut self, radius: u32) {
        let mut new_data = self.data.clone();
        let radius = radius as i32;
        
        for y in 0..self.height as i32 {
            for x in 0..self.width as i32 {
                let mut r_sum = 0u32;
                let mut g_sum = 0u32;
                let mut b_sum = 0u32;
                let mut count = 0u32;
                
                // 在半径范围内采样
                for dy in -radius..=radius {
                    for dx in -radius..=radius {
                        let nx = x + dx;
                        let ny = y + dy;
                        
                        if nx >= 0 && nx < self.width as i32 && 
                           ny >= 0 && ny < self.height as i32 {
                            let index = ((ny * self.width as i32 + nx) * 4) as usize;
                            r_sum += self.data[index] as u32;
                            g_sum += self.data[index + 1] as u32;
                            b_sum += self.data[index + 2] as u32;
                            count += 1;
                        }
                    }
                }
                
                if count > 0 {
                    let index = ((y * self.width as i32 + x) * 4) as usize;
                    new_data[index] = (r_sum / count) as u8;
                    new_data[index + 1] = (g_sum / count) as u8;
                    new_data[index + 2] = (b_sum / count) as u8;
                    // Alpha 保持不变
                }
            }
        }
        
        self.data = new_data;
    }
    
    pub fn apply_edge_detection(&mut self) {
        let mut new_data = vec![0u8; self.data.len()];
        
        // Sobel 算子
        let sobel_x = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
        let sobel_y = [-1, -2, -1, 0, 0, 0, 1, 2, 1];
        
        for y in 1..(self.height - 1) {
            for x in 1..(self.width - 1) {
                let mut gx = 0.0f32;
                let mut gy = 0.0f32;
                
                for i in 0..9 {
                    let dx = (i % 3) as i32 - 1;
                    let dy = (i / 3) as i32 - 1;
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    
                    let index = ((ny * self.width as i32 + nx) * 4) as usize;
                    let gray = (self.data[index] as f32 * 0.299 + 
                               self.data[index + 1] as f32 * 0.587 + 
                               self.data[index + 2] as f32 * 0.114);
                    
                    gx += gray * sobel_x[i] as f32;
                    gy += gray * sobel_y[i] as f32;
                }
                
                let magnitude = (gx * gx + gy * gy).sqrt().min(255.0) as u8;
                let index = ((y * self.width + x) * 4) as usize;
                
                new_data[index] = magnitude;
                new_data[index + 1] = magnitude;
                new_data[index + 2] = magnitude;
                new_data[index + 3] = self.data[index + 3]; // 保持 Alpha
            }
        }
        
        self.data = new_data;
    }
    
    #[wasm_bindgen(getter)]
    pub fn width(&self) -> u32 { self.width }
    
    #[wasm_bindgen(getter)]
    pub fn height(&self) -> u32 { self.height }
}

// 滤镜效果
#[wasm_bindgen]
pub fn apply_sepia_filter(data: &mut [u8]) {
    for i in (0..data.len()).step_by(4) {
        let r = data[i] as f32;
        let g = data[i + 1] as f32;
        let b = data[i + 2] as f32;
        
        let tr = (0.393 * r + 0.769 * g + 0.189 * b).min(255.0);
        let tg = (0.349 * r + 0.686 * g + 0.168 * b).min(255.0);
        let tb = (0.272 * r + 0.534 * g + 0.131 * b).min(255.0);
        
        data[i] = tr as u8;
        data[i + 1] = tg as u8;
        data[i + 2] = tb as u8;
    }
}

#[wasm_bindgen]
pub fn apply_invert_filter(data: &mut [u8]) {
    for i in (0..data.len()).step_by(4) {
        data[i] = 255 - data[i];       // R
        data[i + 1] = 255 - data[i + 1]; // G
        data[i + 2] = 255 - data[i + 2]; // B
        // Alpha 保持不变
    }
}
```

## 本章小结

通过本章学习，你已经掌握了：

1. **Rust WebAssembly 工具链**：环境搭建、项目配置和构建流程
2. **基础编程**：函数导出、数据类型绑定和错误处理
3. **JavaScript 互操作**：复杂数据交换、异步操作和 Web API 集成
4. **性能优化**：编译器优化、内存管理和算法优化
5. **测试调试**：单元测试、性能基准和调试技巧
6. **实际应用**：游戏引擎和图像处理等复杂应用

**🎯 重点技能**：
- ✅ 熟练使用 Rust 编译到 WebAssembly
- ✅ 掌握 wasm-bindgen 和相关工具链
- ✅ 理解 Rust 的内存安全优势
- ✅ 能够构建高性能的 WebAssembly 应用
- ✅ 掌握与 JavaScript 的无缝集成

---

**📚 下一步**：[第9章 练习题](./chapter9-exercises.md)
