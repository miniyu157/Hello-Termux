# Hello-Termux 开发约束

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- 纯数据文本不包含 ANSI 序列
- `i18n::printf` 签名：

  ```
  i18n::printf [-v varname] "中文 fmt" "英文 fmt" [args...]
  ```

  - 不带 `-v`：输出到 stdout（向后兼容，用于动作函数中直接打印到终端）
  - 带 `-v varname`：写入指定变量，零 fork（用于 `::title` / 组标题等被调用方捕获输出的场景）

## 零 fork 调用约定

菜单渲染路径禁止使用 `$()` 捕获函数输出，所有标题函数统一采用变量传递：

- **`::title` 函数**（叶子标题）：接受 `$1` 为输出变量名，内部用 `i18n::printf -v "$1" "..." "..."`

  ```bash
  # 定义
  menu::root::m::title() { i18n::printf -v "$1" "安装" "Install"; }
  # 调用
  menu::root::m::title _t; printf '%s\n' "$_t"
  ```

- **组标题函数**（`menu::groupname`）：同上

  ```bash
  menu::sh() { i18n::printf -v "$1" "Shell 套件" "Shell utilities"; }
  ```

- **调用方**：先声明 `local _varname=''`，传入变量名，直接读取变量

  ```bash
  local _ht=''
  "menu::${parent}" _ht 2>/dev/null || true
  header_text="$_ht"
  ```

- 动作函数（`menu::parent::key`）不受此约束：它们输出到终端，仍然用 `i18n::printf` 无 `-v` 形式

- `pure::` 函数如被渲染路径调用，应支持可选的输出变量参数以消除 fork：

  ```bash
  pure::strip_parens() {
      local s="${1#(}" _v="${2:-}"
      if [[ -n $_v ]]; then
          printf -v "$_v" '%s' "${s%)}"
      else
          printf '%s\n' "${s%)}"
      fi
  }
  ```

## ANSI 样式

- 组标题和菜单项标题由调用方包裹 ANSI，遵循模式：`${_green}...${_faint}（附属信息）${_off}`
- 括号内的附属信息使用 `_faint`，继承前方颜色（如 `_green..._faint（已安装）_off`）

## 函数命名空间

- `pure::` — 内部工具函数，与 UI 无关（文本处理、解析、状态判断等）。不等待用户交互、不写文件。被渲染路径调用的函数需支持可选输出变量以消除 fork（见 §零 fork 调用约定）
- `menu::` — 菜单系统的三种角色，命名即约定：
  - `menu::groupname` — 组标题，接受 `$1` 为输出变量名，写入 i18n 文本（可含 ANSI）
  - `menu::parent::key` — 叶子动作，执行操作（输出到 stdout）；`menu::parent::key::title` — 接受 `$1` 为输出变量名，写入 i18n 标题（可含 ANSI）
  - `menu::groupname::member` — 分组内子项的动作；`menu::groupname::member::title` — 同上接受输出变量
- `app::` — 应用初始化与核心流程。存放生命周期函数（`set_*`）和递归渲染入口。渲染路径使用变量传递，禁止 `$()`
- `sys::` — 有副作用操作，与 `pure::` 相反：可写文件、调外部命令。Termux 特定操作命名带 `termux_` 前缀，通用操作不加
- `i18n::` — 国际化基础函数，核心为 `i18n::printf`，签名见上文 §i18n
- `i18n_msg::` — 可复用的 i18n 消息模板，封装完整 `i18n::printf` 调用

## 菜单系统

- 菜单树以 S-表达式 `"(root key1 key2 (groupname key3 key4))"` 定义，括号内为分组，直接传入 `app::loop_menu`
- `app::loop_menu` 递归渲染：`while true` 循环 → 清屏 → 调用 `menu::<parent>` 获取标题 → 调用 `pure::parse_children` 解析子节点 → 遍历子节点调用 `::title` 函数获取显示文本 → `read` 输入 → 分发到 `menu::` 动作函数
- 所有标题获取均通过变量传递，渲染路径零 fork：`pure::parse_children` 通过 nameref 数组输出，`app::loop_menu` 在 `while true` 循环前解析一次，循环内用 `for child in "${arr[@]}"` 迭代渲染与输入匹配
- `MENU_QUICK=1` 使操作完成后直接返回菜单不暂停

## 提交信息

- 参考历史提交信息、简明扼要
- 多行、中文、描述业务变更而非实现细节
