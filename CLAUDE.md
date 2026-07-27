# Hello-Termux 开发约束

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- `i18n::printf` 签名：第一个参数为中文 fmt，第二个为英文 fmt，后续为 `printf` 的 `%s` 等占位参数
- 纯数据文本不包含 ANSI 序列

## ANSI 样式

- 组标题和菜单项标题由调用方包裹 ANSI，遵循模式：`${_green}...${_faint}（附属信息）${_off}`
- 括号内的附属信息使用 `_faint`，继承前方颜色（如 `_green..._faint（已安装）_off`）

## 函数命名空间

- `pure::` — 无副作用函数。不输出到 stdout/stderr、不等待用户交互、不写文件。只返回纯文本或状态码（0=成功/已安装/true 等）。所有输出（i18n、ANSI）由调用方负责
- `menu::` — 菜单系统的三种角色，命名即约定：
  - `menu::groupname` — 组标题，输出该组的 i18n 文本（可含 ANSI）
  - `menu::parent::key` — 叶子动作，执行操作；`menu::parent::key::title` — 输出该选项的 i18n 标题（可含 ANSI）
  - `menu::groupname::member` — 分组内子项的动作；`menu::groupname::member::title` — 子项标题
- `app::` — 应用初始化与核心流程。存放生命周期函数（`set_*`）和递归渲染入口
- `sys::` — 有副作用操作，与 `pure::` 相反：可写文件、调外部命令。Termux 特定操作命名带 `termux_` 前缀，通用操作不加
- `i18n::` — 国际化基础函数，核心为 `i18n::printf`，签名见上文 §i18n
- `i18n_msg::` — 可复用的 i18n 消息模板，封装完整 `i18n::printf` 调用

## 菜单系统

- `menu_tree` 变量以 S-表达式 `"(root key1 key2 (groupname key3 key4))"` 定义菜单树，括号内为分组
- `app::submenu` 递归渲染：`while true` 循环 → 清屏 → 渲染标题和选项 → `read` 输入 → 分发到 `menu::` 函数
- `MENU_QUICK=1` 使操作完成后直接返回菜单不暂停

## 提交信息

- 参考历史提交信息、简明扼要
- 多行、中文、描述业务变更而非实现细节
