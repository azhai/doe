# Doe 语言 1.0 规范

## 第二部分：变量、常量与控制流

### 2.1 变量与常量声明

```doe
# 可变变量
var x = 10
var name str = "hello"

# 不可变绑定
let y = 20
let port twine = 8080

# 常量（建议全大写 SNAKE_CASE）
let MAX_SIZE = 1024
let DEFAULT_TIMEOUT = 30

# 合并定义（Go 风格）
let (
    x = 10
    y = 20
    z = 30
)

var (
    count = 0
    total = 0.0
)

use (
    "std/io"
    "net/http" as net
    "utils/helper.cy"
)
```

### 2.2 块语法

| 形式 | 说明 |
|------|------|
| 标准块 | 冒号 `:` + 换行缩进 |
| 单行块 | 冒号 `:` + 同一行，分号 `;` 分隔多语句 |

```doe
# 标准块
func add(a int, b int) int:
    return a + b

# 单行块
func add(a int, b int) int: return a + b

# 多语句单行
if ready: init(); start(); run()

for arr as item: print(item)

defer: cleanup()
```

### 2.3 条件语句

#### if

```doe
if x > 0:
    print("positive")

if x > 0:
    print("positive")
else:
    print("non-positive")

if x > 0:
    print("positive")
else if x < 0:
    print("negative")
else:
    print("zero")
```

#### if let（解构 Option/Result）

```doe
# 风格一：直接解构，简单场景
if let Ok(user) = fetchUser(42):
    print(user.name)
else:
    print("failed")

# 风格二：先 let 再解构，失败时需原始值
let result = fetchUser(42)
if let Ok(user) = result:
    print(user.name)
else:
    log(result)
```

**规则**：
- `else` 后**不接表达式**，简单处理失败分支
- 需错误变量或复杂分支 → 用 `match`

#### match（多分支匹配）

```doe
match result:
    Ok(user) -> print(user.name)
    Err(NotFound) -> print("missing")
    Err(Timeout) -> print("slow")
    Err(e) -> log("error: " + e)
    else -> default()
```

### 2.4 循环语句

**仅 `for` 关键字**，统摄所有循环场景。

#### 条件循环（替代 while）

```doe
for i < 10:
    i += 1

# 无限循环
for:
    break
```

#### 迭代循环

```doe
# 单变量
for arr as item:
    print(item)

# 带索引
for arr as index, item:
    print(index, item)

# 字典
for dict as key, value:
    print(key, value)

# 字符串（迭代 rune）
for str as ch:
    print(ch)
```

#### 区间迭代

```doe
for 0..10 as i:       # 0 到 9，左闭右开
    print(i)

for 0..=10 as i:      # 0 到 10，双闭
    print(i)
```

### 2.5 defer

```doe
func process():
    let file = open("data.txt")
    defer: file.close()

    let data = file.read()
    process(data)
    # 函数返回时自动执行 file.close()
```

---

*Doe 语言 1.0 规范 | 第二部分*
