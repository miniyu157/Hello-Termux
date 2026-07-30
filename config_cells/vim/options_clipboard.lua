if vim.env.TERMUX_VERSION then
  vim.g.clipboard = {
    name = 'termux',
    copy = {
      ['+'] = 'termux-clipboard-set', -- 复制到系统剪贴板
      ['*'] = 'termux-clipboard-set', -- ' * ' 寄存器也使用系统剪贴板
    },
    paste = {
      ['+'] = 'termux-clipboard-get', -- 从系统剪贴板粘贴
      ['*'] = 'termux-clipboard-get',
    },
    cache_enabled = 1, -- 开启缓存以提高速度
  }
  -- 强制nvim使用系统的 '+ ' 寄存器
  vim.opt.clipboard = 'unnamedplus'
end
