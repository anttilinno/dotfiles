return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      event_handlers = {
        {
          event = "file_opened",
          handler = function(file_path)
            require("neo-tree.command").execute({ action = "close" })
          end,
        },
      },
    })
  end,
  keys = function()
    local find_buffer_by_type = function(type)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ft = vim.api.nvim_buf_get_option(buf, "filetype")
        if ft == type then
          return buf
        end
      end
      return -1
    end
    local toggle_neotree = function(toggle_command)
      if find_buffer_by_type("neo-tree") > 0 then
        require("neo-tree.command").execute({ action = "close" })
      else
        toggle_command()
      end
    end

    return {
      {
        "<A-n>",
        function()
          toggle_neotree(function()
            require("neo-tree.command").execute({ action = "focus", reveal = true, dir = vim.uv.cwd() })
          end)
        end,
        desc = "Toggle Explorer (cwd)",
      },
      {
        "<C-n>",
        function()
          toggle_neotree(function()
            require("neo-tree.command").execute({ action = "focus", reveal = true })
          end)
        end,
        desc = "Toggle Explorer (root)",
      },
    }
  end,
}
