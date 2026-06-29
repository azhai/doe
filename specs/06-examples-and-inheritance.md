# Doe 语言 1.0 规范

## 第六部分：完整示例与 Cyber 继承说明

### 6.1 完整示例

```doe
# main.cy

use (
    "std/io"
    "net/http" as net
    "_internal/config" as cfg
)

class Server:
    var _port twine
    var _handler func(req str) str!

    func Server.new(port twine) Self:
        return Self{_port: port, _handler: none}

    func (&self) setHandler(h func(req str) str!):
        self._handler = h

    func (&self) start():
        io.println("Server on port " + self._port)
        net.listen(self._port, self._handler)

    func (&self) stop():
        io.println("Server stopped")

enum HttpStatus:
    Ok = 200
    NotFound = 404
    Error = 500

union ApiResult[T]:
    Success of T
    Failure of str

func handleRequest(req str) str!:
    if req == "/health":
        return Ok("ok")
    if req == "/data":
        let data = fetchData()-!
        return Ok(data)
    return Err(NotFound)

func fetchData() str!:
    let config = cfg.load()
    let source = config.get("source")-?
    let data = net.get(source)-!
    return Ok(data)

func main():
    let config = cfg.load()
    let port = config.get("port")-?   # 强制解包，无配置则 panic

    let server = Server.new(port)
    server.setHandler(handleRequest)
    server.start()

    # defer 清理
    defer: server.stop()

    # 主循环
    for:
        let cmd = io.readLine()
        if cmd == "quit": break
        io.println("cmd: " + cmd)
```

### 6.2 继承 Cyber 的部分

以下特性**完全继承 Cyber 语言**，Doe 不做修改：

| 类别 | 具体内容 |
|------|---------|
| **表达式语法** | 算术、逻辑、位运算、比较运算符 |
| **运算符优先级** | 与 Cyber 一致 |
| **字面量** | 整数、浮点、字符串、布尔、转义序列 |
| **注释** | 单行 `#`、多行（如有） |
| **块作用域** | 变量作用域规则 |
| **变量提升/声明** | 声明规则 |
| **内存管理** | GC 或引用计数模型 |
| **并发原语** | 协程、通道等机制 |
| **错误类型内部结构** | error 的具体实现 |
| **标准库组织** | 包结构、内置函数 |
| **编译单元** | 文件组织、编译模型 |
| **元编程/反射** | 如有 |
| **运算符重载** | 如有 |
| **模板/泛型机制** | 具体实现细节 |

### 6.3 后端

| 后端 | 说明 |
|------|------|
| JIT | 即时编译，继承自 Cyber |
| 脚本 | 解释执行，继承自 Cyber |

**移除**：
- `cgen`（C 代码生成后端）
- `LLVM IR` 后端

### 6.4 快速参考卡

```doe
# 变量
var x = 10                    # 可变
let y = 20                    # 不可变

# 类型
byte twine rune int float bool str
list[T] dict[K,V] class enum union trait

# 修饰符
T?    # 可选
T!    # 结果

# 解包
val-?   # 强制解包，panic
val-!   # 错误传播
val else default  # 默认值

# 控制流
if cond: ...
if let Pat = val: ... else: ...
match val: Pat -> ... else -> ...
for cond: ...
for: ...
for arr as item: ...
for 0..10 as i: ...

# 方法
func (self) method()       # 值接收者
func (&self) method()      # 引用接收者
func Class.new() Self      # 构造函数
func Class.method(&self)   # 普通方法

# 可见性
name      # 公有
_name     # 私有

# 模块
use "path"                  # 默认别名
use "path" as alias         # 显式别名
```

---

*Doe 语言 1.0 规范 | 第六部分*

**Doe 语言 1.0 — 冻结**
