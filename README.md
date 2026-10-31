# MDV

轻量的 macOS 原生 Markdown 查看器。只读，没有编辑功能。

A lightweight native macOS Markdown viewer built with AppKit. Read-only, with a heading outline and automatic Solarized light/dark themes. No WebView or third-party dependencies.

## 功能

- 原生 AppKit 窗口和文本排版，不使用 WebView、Electron 或第三方依赖。
- 文章标题目录，点击跳转，阅读时自动高亮当前章节。
- 标题、粗体、斜体、删除线、代码块、嵌套列表、引用、表格和链接。
- 本地图片按需解码成缩略图；远程图片显示替代文字，不自动联网下载。
- 文件拖放、文本选择与复制、⌘F 查找、文字缩放、系统深浅色。
- [Solarized](https://ethanschoonover.com/solarized/) 配色随系统自动切换浅色、深色，切换时无需重新打开文档。
- 声明 Markdown 文件关联，可从 Finder「打开方式」中选择 MDV。
- 单窗口阅读，只保留当前文档，不缓存已读文档。

## 构建与运行

运行需要 macOS 13+。构建需要 Swift 6+（Xcode 16+ 或对应版本的 Command Line Tools），当前构建默认针对本机架构。

```sh
git clone https://github.com/coderhwz/mdv.git
cd mdv
./scripts/build.sh
open dist/MDV.app
```

拖动 `dist/MDV.app` 到「应用程序」即可安装。

## 关联 .md 文件

Finder 中选中一个 `.md` 文件 → ⌘I「显示简介」→「打开方式」选择 MDV →「全部更改」。
应用只声明可打开的类型，默认程序由你在 Finder 中选择。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开文件 | ⌘O |
| 查找 / 下一个 | ⌘F / ⌘G |
| 显示、隐藏目录 | ⌃⌘S |
| 放大 / 缩小文字 | ⌘+ / ⌘- |
| 恢复字号 | ⌘0 |
| 重新载入 | ⌘R |

## 阅读示例

这是 **粗体**、*斜体*、~~删除线~~ 和 `inline code`。

> 简单的工具，让注意力留在内容上。

1. 打开文章
2. 点击侧栏标题
3. 开始阅读

### 代码

```swift
import Foundation
print("Hello, Markdown!")
```

### 链接

[跳回功能](#功能) · [Apple](https://www.apple.com)

## 验证

```sh
swift test
```

使用系统 Markdown 解析器，适用于常见 Markdown 文档。HTML、数学公式、Mermaid 不执行或渲染；任务列表以只读文本呈现。当前读取 UTF-8 文件；文档按全文解析和排版，超大文件的内存随内容增长，不属于虚拟分页阅读器。修改源文件后按 ⌘R 刷新。

## 许可证

本项目使用 [MIT License](LICENSE)。Solarized 配色来自 [Ethan Schoonover](https://ethanschoonover.com/solarized/)。
