# Doe 语言 1.0 规范

Doe（豆语言）是一门静态类型、编译型语言，支持即时编译（JIT）和脚本执行两种后端。

## 文档结构

| 文件 | 内容 |
|------|------|
| [01-overview-and-types.md](01-overview-and-types.md) | 概述与类型系统 |
| [02-variables-and-control-flow.md](02-variables-and-control-flow.md) | 变量、常量与控制流 |
| [03-functions-and-methods.md](03-functions-and-methods.md) | 函数与方法 |
| [04-custom-types.md](04-custom-types.md) | 自定义类型 |
| [05-visibility-and-modules.md](05-visibility-and-modules.md) | 可见性与模块系统 |
| [06-examples-and-inheritance.md](06-examples-and-inheritance.md) | 完整示例与 Doe 继承说明 |

## 核心特性

- 简洁：仅 `for` 循环、`match` 分支
- 显式：定义方决定值/引用传递
- 安全：`T?` 可选、`T!` 结果、`-?`/`-!` 解包
- 清晰：`_` 前缀私有、CamelCase/snake_case 强制区分

## 设计来源

基于 [Cyber 语言](https://github.com/fubark/cyber)，移除 `cgen`/`LLVM IR` 后端，调整类型命名和语法风格。
