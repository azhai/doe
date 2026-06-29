[![Latest Build](https://github.com/azhai/doe/actions/workflows/latest-build.yml/badge.svg)](https://github.com/azhai/doe/actions/workflows/latest-build.yml) 

[English](README.md)

![Doe Logo](./docs/doe-logo.svg)

Doe 是一个有趣且实用的语言，基于 [Zig](https://ziglang.org/) 和 [Cyber](https://github.com/fubark/cyber)。你可以将它嵌入到桌面应用、游戏或引擎中，也可以在 Web 端使用。Doe 还提供了 CLI 工具，方便在电脑上进行脚本编程。

- [文档](https://azhai.github.io/doe)
- [下载](https://github.com/azhai/doe/releases)
- [构建](https://github.com/azhai/doe/blob/master/docs/build.md)
- [贡献](https://github.com/azhai/doe/blob/master/docs/contributing.md)

### 支持平台
- Linux x64 (Ubuntu, Fedora, Arch)
- macOS x64
- macOS arm64
- Windows x64
- WASM Web
- WASM WASI

### 安装
- 使用命令行安装（Linux, macOS）
```sh
# 安装最新发布版本。
curl -fsSL https://raw.githubusercontent.com/azhai/doe/master/install.sh | bash

# 安装最新开发版本。
curl -fsSL https://raw.githubusercontent.com/azhai/doe/master/install.sh | bash -s latest
```
- 从[下载页面](https://github.com/azhai/doe/releases)安装。

### 使用
- `doer` — VM 运行器，支持 REPL 和脚本执行
- `doec` — JIT 编译器，即时编译为 WebAssembly 模块或桌面平台的可执行文件