# Doe 语言 1.0 规范

## 第四部分：自定义类型

### 4.1 class（聚类）

引用类型，自定义数据结构。

```doe
class Counter:
    var _value int              # 私有属性
    var name str                # 公有属性

    # 构造函数
    func Counter.new() Self:
        return Self{_value: 0, name: ""}

    # 私有方法
    func _reset():
        self._value = 0

    # 公有方法 — 值接收者
    func (self) clone() Counter:
        return Counter{_value: self._value, name: self.name}

    # 公有方法 — 引用接收者
    func (&self) increment():
        self._value += 1

    func (&self) get() int:
        return self._value
```

### 4.2 enum（枚举）

底层为无符号整数，默认 `byte`，可选 `twine`。

#### 基本枚举

```doe
enum Status:
    Pending
    Running
    Done

# 底层：byte，Pending=0, Running=1, Done=2
```

#### 指定底层类型

```doe
enum Status twine:
    Pending
    Running
    Done

# 底层：twine，Pending=0, Running=1, Done=2
```

#### 自定义值

```doe
enum Status:
    Pending = 10
    Running = auto + 5      # 15
    Done                    # 复用表达式：16
```

#### auto 递增（Go 风格 iota）

```doe
enum Size:
    _   = auto              # 0，占位
    KB  = 1 << (10 * auto)  # 1 << 10 = 1024
    MB                      # 1 << 20 = 1048576
    GB                      # 1 << 30
    TB                      # 1 << 40
```

#### atom — 位标志

```doe
enum Permission atom:
    Read        # 1 << 0 = 1
    Write       # 1 << 1 = 2
    Execute     # 1 << 2 = 4

# 使用
let p = Permission.Read | Permission.Write   # 3
```

**规则**：
- `auto` = 当前行索引（从 0 开始），可嵌入表达式
- `atom` = 独立位，每个值占独立位，用于位运算
- 显式写了表达式后，后续行**自动复用该表达式**，只需替换 `auto`

### 4.3 union（联合）

命名变体，可带数据。每行一个成员：`Name of Type`。

```doe
union Result[T, E]:
    Ok of T
    Err of E

union Option[T]:
    Some of T
    None

union Color:
    Red
    Green
    Blue
    RGB of (byte, byte, byte)
```

**使用**：

```doe
let r Result[int, str] = Ok(42)

match r:
    Ok(n) -> print(n)
    Err(e) -> print("error: " + e)

let c = RGB(255, 0, 0)
match c:
    Red -> print("red")
    RGB(r, g, b) -> print("rgb(" + r + ")")
```

**与 enum 的区别**：
- `enum` = 底层整数，用于状态/标志
- `union` = 命名变体，可带数据，用于结果/选项

### 4.4 trait（接口）

接口契约，可带默认实现。

```doe
trait Drawable:
    func (self) draw()
    func (self) area() float

    # 默认实现
    func (self) describe() str:
        return "drawable"

trait Comparable:
    func (self) compare(other Self) Order
    func (self) hash() int

trait Clonable:
    func (self) clone() Self
```

**实现**：

```doe
class Circle:
    var radius float

    # 隐式实现 Drawable
    func (self) draw():
        print("draw circle")

    func (self) area() float:
        return 3.14159 * self.radius * self.radius

    # 使用默认 describe()
```

### 4.5 Order 枚举

```doe
enum Order:
    Less
    Equal
    Greater
```

用于 `Comparable` 接口的返回值。

---

*Doe 语言 1.0 规范 | 第四部分*
