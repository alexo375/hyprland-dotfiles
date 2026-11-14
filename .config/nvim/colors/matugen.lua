-- Material You (Matugen) Colorscheme for Neovim
local colors_ok, matugen = pcall(require, "colors.matugen")

local c = colors_ok and matugen.colors or {
  primary = "#a7c8ff",
  on_primary = "#003060",
  primary_container = "#244777",
  secondary = "#b9c7df",
  tertiary = "#dabce2",
  background = "#111418",
  surface = "#111418",
  surface_container = "#1d2024",
  surface_container_high = "#282a2f",
  on_surface = "#e1e2e8",
  on_surface_variant = "#c3c7cf",
  outline = "#8d9199",
  outline_variant = "#43474e",
  error = "#ffb4ab",
  red = "#ffb4ab",
  green = "#9fd49c",
  yellow = "#fedc6c",
  blue = "#a7c8ff",
  magenta = "#e0b6ff",
  cyan = "#98ccf9",
}

local hl = vim.api.nvim_set_hl

local function setup()
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  vim.g.colors_name = "matugen"
  vim.o.termguicolors = true

  -- Editor basics (transparent background)
  hl(0, "Normal", { fg = c.on_surface, bg = "none" })
  hl(0, "NormalNC", { fg = c.on_surface_variant, bg = "none" })
  hl(0, "NormalFloat", { fg = c.on_surface, bg = "none" })
  hl(0, "FloatBorder", { fg = c.outline_variant, bg = "none" })
  hl(0, "FloatTitle", { fg = c.primary, bold = true })
  hl(0, "CursorLine", { bg = c.surface_container })
  hl(0, "CursorLineNr", { fg = c.primary, bold = true })
  hl(0, "LineNr", { fg = c.outline })
  hl(0, "SignColumn", { bg = "none" })
  hl(0, "FoldColumn", { fg = c.outline, bg = "none" })
  hl(0, "Folded", { fg = c.on_surface_variant, bg = "none" })
  hl(0, "Search", { fg = c.on_primary, bg = c.primary })
  hl(0, "IncSearch", { fg = c.surface, bg = c.tertiary, bold = true })
  hl(0, "Visual", { bg = c.primary_container })
  hl(0, "ColorColumn", { bg = c.surface_container })
  hl(0, "VertSplit", { fg = c.outline_variant })
  hl(0, "WinSeparator", { fg = c.outline_variant })
  hl(0, "StatusLine", { fg = c.on_surface, bg = "none" })
  hl(0, "StatusLineNC", { fg = c.outline, bg = "none" })

  -- Syntax (clear, high contrast Material You)
  hl(0, "Comment", { fg = c.outline, italic = true })
  hl(0, "Constant", { fg = c.cyan or c.tertiary })
  hl(0, "String", { fg = c.green })
  hl(0, "Character", { fg = c.green })
  hl(0, "Number", { fg = c.yellow or c.tertiary })
  hl(0, "Boolean", { fg = c.yellow or c.tertiary, bold = true })
  hl(0, "Float", { fg = c.yellow or c.tertiary })
  hl(0, "Identifier", { fg = c.on_surface })
  hl(0, "Function", { fg = c.blue or c.primary, bold = true })
  hl(0, "Statement", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "Conditional", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "Repeat", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "Label", { fg = c.primary })
  hl(0, "Operator", { fg = c.primary })
  hl(0, "Keyword", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "Exception", { fg = c.error, bold = true })
  hl(0, "PreProc", { fg = c.tertiary })
  hl(0, "Include", { fg = c.tertiary })
  hl(0, "Define", { fg = c.tertiary })
  hl(0, "Macro", { fg = c.tertiary })
  hl(0, "Type", { fg = c.cyan or c.primary })
  hl(0, "StorageClass", { fg = c.secondary })
  hl(0, "Structure", { fg = c.cyan or c.primary })
  hl(0, "Typedef", { fg = c.cyan or c.primary })
  hl(0, "Special", { fg = c.primary })
  hl(0, "Underlined", { underline = true })
  hl(0, "Error", { fg = c.error, bold = true })
  hl(0, "Todo", { fg = c.surface, bg = c.yellow or c.primary, bold = true })

  -- Treesitter
  hl(0, "@variable", { fg = c.on_surface })
  hl(0, "@variable.builtin", { fg = c.primary, bold = true })
  hl(0, "@variable.parameter", { fg = c.on_surface_variant })
  hl(0, "@variable.member", { fg = c.on_surface })
  hl(0, "@property", { fg = c.on_surface_variant })
  hl(0, "@function", { fg = c.blue or c.primary, bold = true })
  hl(0, "@function.builtin", { fg = c.blue or c.primary })
  hl(0, "@function.call", { fg = c.blue or c.primary })
  hl(0, "@function.method", { fg = c.blue or c.primary })
  hl(0, "@constructor", { fg = c.cyan or c.primary })
  hl(0, "@keyword", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "@keyword.function", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "@keyword.return", { fg = c.magenta or c.secondary, bold = true })
  hl(0, "@string", { fg = c.green })
  hl(0, "@number", { fg = c.yellow or c.tertiary })
  hl(0, "@boolean", { fg = c.yellow or c.tertiary, bold = true })
  hl(0, "@type", { fg = c.cyan or c.primary })
  hl(0, "@type.builtin", { fg = c.cyan or c.primary, italic = true })
  hl(0, "@comment", { fg = c.outline, italic = true })
  hl(0, "@punctuation.bracket", { fg = c.on_surface_variant })
  hl(0, "@punctuation.delimiter", { fg = c.outline })

  -- Diagnostics
  hl(0, "DiagnosticError", { fg = c.error })
  hl(0, "DiagnosticWarn", { fg = c.yellow or c.tertiary })
  hl(0, "DiagnosticInfo", { fg = c.blue or c.primary })
  hl(0, "DiagnosticHint", { fg = c.cyan or c.secondary })

  -- GitSigns
  hl(0, "GitSignsAdd", { fg = c.green })
  hl(0, "GitSignsChange", { fg = c.yellow or c.primary })
  hl(0, "GitSignsDelete", { fg = c.error })

  -- Neo-tree
  hl(0, "NeoTreeNormal", { fg = c.on_surface, bg = "none" })
  hl(0, "NeoTreeNormalNC", { fg = c.on_surface_variant, bg = "none" })
  hl(0, "NeoTreeDirectoryIcon", { fg = c.primary })
  hl(0, "NeoTreeDirectoryName", { fg = c.primary })
  hl(0, "NeoTreeFileName", { fg = c.on_surface })
  hl(0, "NeoTreeRootName", { fg = c.primary, bold = true })
  hl(0, "NeoTreeGitModified", { fg = c.yellow or c.tertiary })
  hl(0, "NeoTreeGitUntracked", { fg = c.green })
  hl(0, "NeoTreeIndentMarker", { fg = c.outline_variant })

  -- Telescope / Snacks
  hl(0, "TelescopeBorder", { fg = c.outline_variant, bg = "none" })
  hl(0, "TelescopePromptBorder", { fg = c.primary, bg = "none" })
  hl(0, "TelescopePromptTitle", { fg = c.on_primary, bg = c.primary, bold = true })
  hl(0, "TelescopeSelection", { bg = c.surface_container })

  -- Bufferline
  hl(0, "BufferLineFill", { bg = "none" })
  hl(0, "BufferLineBackground", { fg = c.outline, bg = "none" })
  hl(0, "BufferLineBufferSelected", { fg = c.primary, bold = true, italic = true })
end

setup()
