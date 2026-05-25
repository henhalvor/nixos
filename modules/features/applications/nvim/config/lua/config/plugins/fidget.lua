require("fidget").setup({
  progress = {
    poll_rate = 100,
    suppress_on_insert = true,
    ignore_done_already = false,
    ignore_empty_message = false,
    notification_group = function(msg)
      return msg.lsp_client.name
    end,
    display = {
      render_limit = 16,
      done_ttl = 3,
      done_icon = "✓",
      done_style = "Constant",
      progress_ttl = 99999,
      progress_icon = { pattern = "dots", period = 1 },
      progress_style = "WarningMsg",
      group_style = "Title",
      icon_style = "Question",
      priority = 30,
      skip_history = true,
      format_message = function(msg)
        local title = msg.title or ""
        local message = msg.message or ""
        local percentage = msg.percentage and string.format(" (%s%%)", msg.percentage) or ""
        return string.format("%s%s%s", title, message and (#message > 0 and ": " .. message or "") or "", percentage)
      end,
    },
  },
  notification = {
    window = {
      normal_hl = "Comment",
      winblend = 100,
      border = "none",
      zindex = 45,
      max_width = 0,
      max_height = 0,
      x_padding = 1,
      y_padding = 0,
      align = "bottom",
      relative = "editor",
    },
  },
})
