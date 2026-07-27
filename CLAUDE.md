# Hello-Termux 开发约束

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- `i18n::printf` 签名：第一个参数为中文 fmt，第二个为英文 fmt，后续为 `printf` 的 `%s` 等占位参数
- 纯数据文本不包含 ANSI 序列

## ANSI 样式

- 组标题和菜单项标题由调用方包裹 ANSI，遵循模式：`${_green}...${_faint}（附属信息）${_off}`
- 括号内的附属信息使用 `_faint`，继承前方颜色（如 `_green..._faint（已安装）_off`）

## 函数命名空间

- `pure::` — 纯函数/工具函数，不输出 ANSI，返回纯文本或状态码
- `menu::` — 菜单动作（`menu::key`）和标题（`menu::key::title`）；`menu::groupname` 为组标题，`menu::groupname::member` 为成员动作
- `app::` / `termux::` / `i18n::` — 应用级、Termux 特定、国际化函数

## 菜单系统

- `menu_keys` 数组中 `"name(a b c)"` 表示分组，在主菜单显示组标题，进入后列出成员
- `MENU_QUICK=1` 使操作完成后直接返回菜单不暂停

## 提交信息

- 参考历史提交信息、简明扼要
- 多行、中文、描述业务变更而非实现细节
