# Doe 语言 1.0 规范

## 第五部分：可见性与模块系统

### 5.1 标识符可见性

| 前缀 | 可见性 | 说明 |
|------|--------|------|
| `name` | 公有 | 全局可访问 |
| `_name` | 私有 | 本类/本模块内可访问 |

```doe
class Counter:
    var _value int              # 私有属性
    var name str                # 公有属性

    func _reset():              # 私有方法
        self._value = 0

    func increment():           # 公有方法
        self._value += 1

    func (&self) get() int:     # 公有方法
        return self._value
```

### 5.2 子类型可见性

子类型**从不**加下划线，可见性由**顶层类型**控制。

```doe
# 公有枚举，公有子类型
enum Status:
    Pending                     # 公有，外部可直接用 Pending
    Running
    Done

# 私有枚举（顶层加下划线）
enum _InternalStatus:
    Pending                     # 子类型无下划线
    Failed

# 公有联合
union Result[T, E]:
    Ok of T                     # 公有
    Err of E

# 私有联合
union _InternalResult[T, E]:
    Ok of T
    Err of E
```

**外部引用**：

```doe
let s = Pending                 # ✅ Status 公有，Pending 可直接用
let s2 = Status.Pending         # ✅ 也可加前缀，更明确

let i = _InternalStatus.Pending # ✅ 本模块可见
let i2 = Pending                # ❌ _InternalStatus 私有，Pending 不在命名空间
```

### 5.3 文件与目录可见性

| 前缀 | 可见性 | 说明 |
|------|--------|------|
| `name.cy` / `dir/` | 全局 | 第三方可用 |
| `_name.cy` | 本目录 | 仅同目录内可见 |
| `_dir/` | 本项目 | 项目内任意处可见，第三方不可用 |

**目录结构示例**：

```
myproject/
  main.cy
  utils/
    _helper.cy          # 仅 utils/ 内可见
    public.cy
    _internal/          # 本项目内可见
      secret.cy
  _internal/            # 本项目内可见
    core.cy
  lib/
    parser.cy
```

**引用**：

```doe
# main.cy
use "utils/public"            # ✅ 全局可见
use "utils/_helper"         # ❌ 仅 utils/ 内可见
use "utils/_internal/secret" # ✅ _internal/ 目录本项目可见
use "_internal/core"          # ✅ 本项目可见
use "lib/parser"              # ✅ 全局可见

# utils/public.cy
use "_helper"                # ✅ 同目录可见
use "../_internal/core"      # ✅ _internal/ 本项目可见

# 第三方项目
use "myproject/utils/public"       # ✅ 公有
use "myproject/utils/_helper"      # ❌ 不可见（_helper.cy 仅本目录）
use "myproject/_internal/core"     # ❌ 不可见（_internal/ 仅本项目）
use "myproject/utils/_internal/secret" # ❌ 不可见
```

### 5.4 use 语句

```doe
# 别名后置
use "path/to/pkg" as mypkg

# 无别名：默认取路径最后一段（不含扩展名）
use "std/io"                  # 别名 io
use "net/http" as net         # 别名 net
use "utils/helper.cy"         # 别名 helper
use "lib/parser.cy" as p      # 别名 p

# 合并定义（Go 风格）
use (
    "std/io"
    "net/http" as net
    "utils/helper.cy"
)
```

**路径规则**：

| 路径类型 | 别名来源 |
|---------|---------|
| 包路径 `a/b/c` | 最后一段 `c` |
| 文件路径 `a/b.cy` | 文件名 `b`（不含 `.cy`） |

---

*Doe 语言 1.0 规范 | 第五部分*
