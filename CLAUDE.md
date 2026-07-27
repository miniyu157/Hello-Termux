# Hello-Termux 开发约束

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- `i18n::printf` 签名：第一个参数为中文 fmt，第二个为英文 fmt，后续为 `printf` 的 `%s` 等占位参数
- 纯数据文本不包含 ANSI 序列

## ANSI 样式

- 组标题和菜单项标题由调用方包裹 ANSI，遵循模式：`${_green}...${_faint}（附属信息）${_off}`
- 括号内的附属信息使用 `_faint`，继承前方颜色（如 `_green..._faint（已安装）_off`）

## 函数命名空间

- `pure::` — 纯函数/工具函数。不输出 ANSI、不等待用户交互，返回纯文本或状态码（0=成功/已安装/true 等）
  - `pure::fetch_cached` / `pure::cache_resource` — 带缓存的资源拉取
  - `pure::swap_file` — 原子交换两个文件
  - `pure::write_shell_config` — 带 diff 预览和用户确认的配置写入（会调 `gum confirm`，但所有输出由调用方控制）
  - `pure::warn_existing_config` — 扫描已有配置痕迹
  - `pure::fisher_plugin_installed` / `pure::fisher_plugin_status` — fisher 插件状态查询
  - `pure::command_status` — 命令是否可用的 i18n 状态文本
  - `pure::strip_parens` / `pure::parse_children` — S-表达式解析
- `menu::` — 菜单系统的三种角色：
  - **组标题**: `menu::groupname` — 输出该组的 i18n 标题文本（可含 ANSI）
  - **叶子动作**: `menu::parent::key` — 执行具体操作；`menu::parent::key::title` — 输出该动作的 i18n 标题（可含 ANSI）
  - **成员动作**: `menu::groupname::member` — 分组内子项的动作；`menu::groupname::member::title` — 子项标题
- `app::` — 应用级初始化与核心流程
  - `app::set_resource_service` / `app::set_paths` / `app::set_deps` / `app::set_lang` — 初始化
  - `app::submenu` — 递归菜单渲染器（核心循环）
- `termux::` — Termux 特定操作（应用主题/字体/按键布局、打开 URL）
- `i18n::` — 国际化基础函数：`i18n::printf "中文" "English" [args...]`
- `i18n_msg::` — 可复用的 i18n 消息模板（如 `i18n_msg::shell_changed`）

## 菜单系统

- `menu_tree` 变量以 S-表达式 `"(root key1 key2 (groupname key3 key4))"` 定义菜单树，括号内为分组
- `app::submenu` 递归渲染：`while true` 循环 → 清屏 → 渲染标题和选项 → `read` 输入 → 分发到 `menu::` 函数
- `MENU_QUICK=1` 使操作完成后直接返回菜单不暂停

## 提交信息

- 参考历史提交信息、简明扼要
- 多行、中文、描述业务变更而非实现细节
