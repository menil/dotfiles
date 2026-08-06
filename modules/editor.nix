{ config, pkgs, lib, ... }: {
  # Neovim configuration as the default system editor
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
    initLua = ''
      -- Core Settings
      vim.opt.number = true           -- Enable line numbers
      vim.opt.relativenumber = true   -- Enable relative line numbers
      vim.opt.ruler = true            -- Show ruler
      vim.opt.cursorline = true       -- Highlight the current line

      -- Tab / Indentation
      vim.opt.expandtab = true        -- Use spaces instead of tabs
      vim.opt.shiftwidth = 2          -- Number of spaces for auto-indent
      vim.opt.tabstop = 2             -- Number of spaces that a tab counts for
      vim.opt.smartindent = true      -- Make indenting smart

      -- Search
      vim.opt.ignorecase = true       -- Ignore case when searching
      vim.opt.smartcase = true        -- Don't ignore case when search has capitals

      -- Graphics/UI
      vim.opt.termguicolors = true    -- Enable 24-bit RGB colors
      vim.opt.mouse = 'a'             -- Enable mouse support in all modes

      -- Security
      vim.opt.modeline = false        -- Disable modeline to prevent file-content exploits
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
