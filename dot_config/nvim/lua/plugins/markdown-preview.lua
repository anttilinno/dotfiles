return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  build = function()
    vim.fn["mkdp#util#install"]()
  end,
  config = function()
    vim.cmd([[
      function OpenMarkdownPreview (url)
        execute "silent ! floorp --new-window " . a:url
      endfunction
    ]])

    vim.g.mkdp_browserfunc = "OpenMarkdownPreview"

    vim.g.mkdp_filetypes = { "markdown" }
    vim.g.mkdp_browser = "/usr/bin/floorp"
  end,
  ft = { "markdown" },
  keys = {
    { "<f5>", "<Cmd>MarkdownPreviewToggle<CR>", desc = "Toggle MarkdownPreview" },
  },
}
