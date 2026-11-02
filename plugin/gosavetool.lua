-- :GoSaveTool command. The module loads on first use.
if vim.g.loaded_gosavetool then return end
vim.g.loaded_gosavetool = true

vim.api.nvim_create_user_command('GoSaveTool', function(opts)
  require('gosavetool').command(opts)
end, {
  nargs = '+',
  range = true,
  desc = 'GoSaveTool: subtitles, word count and case changes',
  complete = function(arg_lead, cmdline)
    return require('gosavetool').complete(arg_lead, cmdline)
  end,
})
