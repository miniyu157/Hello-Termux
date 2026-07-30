# 贡献指南与架构约束

Hello-Termux 是一个运行于 Termux 的交互式环境配置工具，提供主题/字体/Shell 等一站式菜单安装。

> 非 Termux 环境也可以使用部分功能，后续可能会做兼容，甚至升级项目定位。

本文档既是项目的开发规范，也是希望贡献代码时的必读指南。
请确保所有提交遵循以下约束。

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- 纯数据文本不包含 ANSI 序列
- `i18n::printf` 签名：

  ```text
  i18n::printf [-v varname] "中文 fmt" "英文 fmt" [args...]
  ```

  - 不带 `-v`：输出到 stdout（向后兼容，用于动作函数中直接打印到终端）
  - 带 `-v varname`：写入指定变量，用于 `::title` / 组标题等被调用方捕获输出的场景

## 菜单渲染路径零 fork 调用约定

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

- `::title` 内动态数据尽量零 fork，以保证菜单渲染性能
- 渲染循环（`app::loop_menu`）内的输出用 buf 拼装 + 单次 `printf`，不使用逐行 `printf`，减少闪烁
- `io::` 函数被渲染路径调用时，数据必须通过 `local -n` 引用或 stdout 捕获在内存中传递，不落临时文件

## ANSI 样式

- 组标题和菜单项标题由调用方包裹 ANSI，遵循模式：`${_green}...${_faint}（附属信息）${_off}`
- 括号内的附属信息使用 `_faint`，继承前方颜色（如 `_green..._faint（已安装）_off`）

## 函数命名空间

- `pure::` — 纯计算，无副作用。不写文件、不调外部命令、不等待用户交互。
  被渲染路径调用时需支持可选输出变量以消除 fork（见 §零 fork 调用约定）
- `do::` — 流程编排单元。被 `&&` 链调用，不向调用者传递数据（可输出消息到终端），只返回 0/1。
  不被渲染路径调用。与 `io::` / `sys::` 互斥
- `io::` — 与文件读写相关的操作（网络获取、文件缓存、目录列表、原子交换等）。可能被渲染路径调用
- `sys::` — 与文件系统无关的操作（调外部命令、状态查询等）。可能被渲染路径调用
- `menu::` — 菜单系统的三种角色，命名即约定：
  - `menu::groupname` — 组标题，接受 `$1` 为输出变量名，写入 i18n 文本（可含 ANSI）
  - `menu::parent::key` — 叶子动作，执行操作（输出到 stdout）；`menu::parent::key::title`
    — 接受 `$1` 为输出变量名，写入 i18n 标题（可含 ANSI）
  - `menu::groupname::member` — 分组内子项的动作；`menu::groupname::member::title` — 同上接受输出变量
  - `menu::_::key` / `menu::_::key::title` — 通用回退。当 `menu::parent::key` 不存在时自动查找此命名空间，适合跨父菜单共享的动作或标题
- `app::` — 应用初始化与核心流程。渲染路径使用变量传递，禁止 `$()`
- `i18n::` — 国际化基础函数，核心为 `i18n::printf`，签名见上文 §i18n
- `i18n_msg::` — 可复用的 i18n 消息模板

### 命名空间决策

| 问题 | 是 | 否 |
| ------ | :--: | :--: |
| 涉及文件系统读写？ | `io::` | `sys::` |
| 被 `&&` 编排为流程环节？ | `do::` | — |
| 无副作用（纯计算）？ | `pure::` | — |
| 属于应用初始化或核心流程？ | `app::` | — |

> `io::` / `sys::` 的前提是不被 `&&` 编排。若函数是流程环节则归属 `do::`。

## 机制与策略分离

函数提供**机制**（做什么），调用方决定**策略**（何时做、如何响应）。

- `do::` 函数只提供通用动作，不内嵌业务分类（如不写 `case fonts/themes/keymaps`）
- 调用方通过参数注入差异化（URL 前缀、目标路径、grep 模式等）
- 成功提示是否内置取决于调用方数量与个性化需求（见 §编排链尾消息）

## 调用编排习惯

不向调用者传递数据的函数（`do::`、外部命令）用 `&&` 串联，而非分散 `|| return 1`：

```bash
do::step_one arg && do::step_two arg && external_cmd arg
```

## 编排链尾消息

`do::` 编排链的最后一步（成功提示）是否内置，由调用方数量和差异化需求决定：

| 条件 | 消息位置 |
| ------ | --------- |
| 调用方 ≥2，且无差异化需求 | 内置在 `do::` 函数中 |
| 调用方 =1，或需个性化 | 留给调用方 `&& i18n` |

## 菜单系统

- 菜单树以 S-表达式 `"(root key1 key2 (groupname key3 key4))"` 定义，括号内为分组，直接传入 `app::loop_menu`，排版随意，舒服即可。
  解析器忽略换行与缩进，空格分隔 Token，括号仅用于嵌套分组，支持任意深度。
  支持 `;` 行内注释：`;` 及之后到行尾的内容在解析时被剥离，可用于标注各节点用途。
- 动作分发有回退链：先查 `menu::parent::key`，不存在则回退到 `menu::_::key`。
  标题无独立回退 —— 标题跟随动作归属的命名空间（动作在 parent 则标题取 `menu::parent::key::title`，动作走 `_::` 则标题取 `menu::_::key::title`）。
- `app::loop_menu` 递归渲染：`while true` 循环 → 清屏 → 调用 `menu::<parent>` 获取标题
  → 调用 `pure::parse_children` 解析子节点 → 遍历子节点调用 `::title` 函数获取显示文本
  → `read` 输入 → 分发到 `menu::` 动作函数
- `menu::<group>` 标题支持多行：内嵌换行使首行自动加粗（`_b` + `✦` 包裹），后续行缩进 4 格作为副标题。
  仅进入该组时显示完整多行；在父菜单的组标签列表中只渲染首行，列表内不自动加粗。
- `MENU_QUICK=1` 使操作完成后直接返回菜单不暂停

## 如何写业务函数

1. 定义叶子标题：

   ```bash
   menu::root::hello::title() { i18n::printf -v "$1" "打招呼" "Say hi"; }
   ```

2. 定义叶子动作：

   ```bash
   menu::root::hello() { i18n::printf "你好，世界" "Hello World"; }
   ```

3. 挂到菜单树：

   ```bash
   app::loop_menu '(root hello)'
   ```

4. 若同名 key 在多个父菜单下行为相同，定义一次 `menu::_::key` 即可，无需为每个 parent 重复定义：

   ```bash
   menu::_::hello::title() { i18n::printf -v "$1" "打招呼" "Say hi"; }
   menu::_::hello()        { i18n::printf "你好，世界" "Hello World"; }
   ```

以上即 hi.sh 的实际编写模式：在文件中任意位置定义函数，将 key 加入文件底部的 S-表达式即可。`app::loop_menu` 自动处理清屏、输入捕获、递归导航，无需额外 main 函数。

## 测试

- `test/test_loopmenu.sh` — 交互式测试入口，提供渲染测试（`render`）和参数透传测试（`args`），启动方式：`bash test/test_loopmenu.sh`
- 生产菜单（`hi.sh`）不包含测试入口，开发和调试请使用 `test/test_loopmenu.sh`

## 提交信息

- 参考历史的多行提交信息（不要使用 --oneline）保持一致、简明扼要、多行、中文。
- 多描述业务变更而非实现细节、若无业务变更则只描述具体更改。
