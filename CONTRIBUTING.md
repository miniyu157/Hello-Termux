# 贡献指南

Hello-Termux 是一个运行于 Termux 的交互式环境配置工具。本文档面向贡献者——如何添加功能、遵守哪些规则。
架构设计决策和渲染约定见 [ARCHITECTURE.md](./ARCHITECTURE.md)。

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

以上即 hi.sh 的实际编写模式：在文件中任意位置定义函数，将 key 加入文件底部的
S-表达式即可。`app::loop_menu` 自动处理清屏、输入捕获、递归导航，无需额外 main 函数。

> 在编写 action 函数前，建议先浏览 hi.sh 中已有的 `do::` 和 `out::` 函数——
> 很多通用操作（依赖安装、资源缓存、安全写入、fzf 选取）已有现成实现。

## 菜单系统

### S-表达式语法

菜单树以 S-表达式定义。括号 `()` 创建分组（无限嵌套），空格分隔 key，`;` 到行尾为注释，排版随意，舒服即可：

```text
app::loop_menu '(root
      setup  config  ; Basic operations.
      (tools         ; Tools group — 分组开始
        pick  list  browse)
      quit           ; Exit
)'
```

分组内 key 可以换行、缩进随意——解析器只关心括号嵌套和空格分隔。

### 创建分组

每个分组需要一个**组标题函数**，接受 `$1` 为输出变量名，写入 i18n 文本（含 ANSI）。
组标题不使用 `::title` 后缀——函数名就是 `menu::<groupname>` 本身：

```bash
menu::tools() { i18n::printf -v "$1" \
    "${_green}${_memu_hl} 浏览与管理工具${_off}" \
    "${_green}${_memu_hl} Browse and manage tools${_off}"; }
```

组标题支持多行：内嵌 `\n` 使首行自动加粗（`_b` + `✦` 包裹），后续行缩进 4 格作为副标题：

```bash
menu::tools() { i18n::printf -v "$1" \
    "${_green}${_memu_hl} 工具管理${_off}
${_faint}选择工具后可配置与安装${_off}" \
    "${_green}${_memu_hl} Tool Manager${_off}
${_faint}Select a tool to configure or install${_off}"; }
```

### 参数透传

用户在菜单中输入 `key arg1 arg2` 后，key 用于分发，剩余参数通过 `$@` 传入动作函数：

```bash
menu::root::hello() { i18n::printf "你好，%s" "Hello, %s" "${1:-World}"; }
# 输入: hello Claude  →  输出: 你好，Claude
```

### 跳过暂停提示

默认情况下，动作执行完毕后会暂停等待回车。在动作函数中设 `MENU_QUICK=1` 可跳过暂停，直接返回菜单：

```bash
menu::root::hello() {
    i18n::printf "你好，世界\n" "Hello World\n"
    MENU_QUICK=1
}
```

### 深入

菜单渲染内部机制（零 fork 调用约定、回退链 `_::`、递归导航）见 [ARCHITECTURE.md](./ARCHITECTURE.md#循环菜单框架)。

## i18n

- 所有面向用户的文本必须使用 `i18n::printf "中文格式" "English format" [args...]`，中英文双语文案同步
- 纯数据文本不包含 ANSI 序列
- `i18n::printf` 签名：

  ```text
  i18n::printf [-v varname] "中文 fmt" "英文 fmt" [args...]
  ```

  - 不带 `-v`：输出到 stdout（用于动作函数中直接打印到终端）
  - 带 `-v varname`：写入指定变量，用于 `::title` / 组标题等被调用方捕获输出的场景

> `i18n::printf` 始终接受中英文两个格式字符串，运行时根据当前语言选择。
> 这避免了外部翻译文件，使每条文本的翻译上下文在一行内可见。

## ANSI 样式

- 标题函数自行包裹 ANSI 颜色，调用方直接渲染结果，不再二次包裹。
  不同功能域使用不同主色调：`_cat1`（红=镜像）、`_cat2`（蓝=字体）、
  `_cat3`（粉=主题）、`_cat4`（黄=按键）、`_green`（确认/成功）、
  `_purple`（Shell 扩展）、`_vimcolor`（Neovim 专属绿）
- 附属信息使用 `_faint`，继承前方颜色（如 `${_green}...${_faint}（已安装）${_off}`）

> 渲染方仅负责排版装饰（序号斜体、组名缩进、首行加粗 `✦`），不干涉标题的语义颜色。

## 调用编排习惯

不向调用者传递数据的函数（`do::`、外部命令）用 `&&` 串联，而非分散 `|| return 1`：

```bash
do::step_one arg && do::step_two arg && external_cmd arg
```

## 测试

- `test/test_loopmenu.sh` — 交互式测试入口，提供渲染测试（`render`）和参数透传测试（`args`），启动方式：`bash test/test_loopmenu.sh`
- 生产菜单（`hi.sh`）不包含测试入口，开发和调试请使用 `test/test_loopmenu.sh`

## 提交信息

- 参考历史的多行提交信息（不要使用 --oneline）保持一致、简明扼要、多行、中文。
- 多描述业务变更而非实现细节、若无业务变更则只描述具体更改。
