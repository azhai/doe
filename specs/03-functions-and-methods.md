# Doe 语言 1.0 规范

## 第三部分：函数与方法

### 3.1 函数定义

```doe
func add(a int, b int) int:
    return a + b

# 单行
func add(a int, b int) int: return a + b

# 无返回值
func greet(name str):
    print("hello " + name)

# 多返回值（继承 Cyber）
func divide(a int, b int) (int, str!):
    if b == 0:
        return 0, Err(DivideByZero)
    return a / b, Ok(none)
```

### 3.2 方法接收者

**设计原则**：定义方决定传递方式，调用方不操心。

| 语法 | 名称 | 传递方式 | 使用场景 |
|------|------|---------|---------|
| `func (self)` | 值接收者 | 拷贝 | 纯读、小对象、消费/转换 |
| `func (&self)` | 引用接收者 | 别名 | 大对象、修改状态、避免拷贝 |

```doe
class Point:
    var x float
    var y float

    # 值接收者 — 纯读
    func (self) distance(other Point) float:
        return hypot(self.x - other.x, self.y - other.y)

    # 值接收者 — 返回新对象
    func (self) withX(x float) Point:
        self.x = x
        return self

    # 引用接收者 — 修改状态
    func (&self) move(dx float, dy float):
        self.x += dx
        self.y += dy

    # 引用接收者 — 大对象纯读
    func (&self) describe() str:
        return "Point(" + self.x + ", " + self.y + ")"
```

**大对象默认值类型**：`list[T]`, `dict[K,V]`, `class` 等引用类型默认使用引用接收者。

**需要副本**：调用方主动 `clone()`。

```doe
let buf2 = buf.clone()
let arr2 = arr.clone()
```

### 3.3 构造函数

```doe
class Animal:
    var name str
    var age int

    # 构造函数
    func Animal.new(name str, age int) Self:
        return Self{name: name, age: age}

    # 或使用默认构造 + 初始化方法
    func (&self) init(name str, age int):
        self.name = name
        self.age = age

# 使用
let dog = Animal.new("Buddy", 3)
# 或
let cat = Animal{}
cat.init("Kitty", 2)
```

### 3.4 错误处理

| 语法 | 含义 | 触发条件 |
|------|------|---------|
| `expr-?` | 强制解包 | `T?` 遇到 `none` → **panic** |
| `expr-!` | 错误传播 | `T!` 遇到 `error` → **提前返回该 error** |

**`-!` 不处理 `none`**：`none` 不是错误，属于正常语义。

```doe
func find(id int) User?:
    if notFound:
        return None
    return Some(user)

func fetch(id int) User!:
    if netFail:
        return Err(NetError)
    return Ok(user)

# 使用
let u1 = find(42)-?           # none → panic
let u2 = fetch(42)-!          # error → 提前返回

# none 不是错误，-! 不管
let u3 = find(42)             # User?，不能对 -!
```

### 3.5 默认值（else）

```doe
let port = config.get("port") else 8080
let name = user.name else "anonymous"
```

---

*Doe 语言 1.0 规范 | 第三部分*
