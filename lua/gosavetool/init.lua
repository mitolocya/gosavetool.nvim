-- GoSaveTool for Neovim: SRT and WebVTT tools, word counter with social media limits, case changes.
-- https://www.gosavetool.com/

local sub = require('gosavetool.subtitles')
local txt = require('gosavetool.text')

local M = {}

M.CASES = { 'title', 'sentence', 'upper', 'lower', 'slug', 'camel', 'snake', 'kebab', 'clean' }
local NAMES = {
  ['x-post'] = 'X post', ['instagram-caption'] = 'Instagram caption', ['tiktok-caption'] = 'TikTok caption',
  ['youtube-title'] = 'YouTube title', ['youtube-description'] = 'YouTube description', ['linkedin-post'] = 'LinkedIn post',
  ['pinterest-description'] = 'Pinterest description', ['seo-title'] = 'SEO title', ['meta-description'] = 'Meta description',
}

local function notify(msg, level)
  vim.notify('GoSaveTool: ' .. msg, level or vim.log.levels.INFO)
end

local function buffer_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

local function set_buffer_text(buf, text)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split((text:gsub('\n$', '')), '\n', { plain = true }))
end

--- The last visual selection as 0-based { start_row, start_col, end_row, end_col } with an exclusive end column,
--- for nvim_buf_get_text. Linewise and blockwise selections cover whole lines.
local function visual_range(buf)
  local s, e = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  local sr, sc, er, ec = s[2] - 1, s[3] - 1, e[2] - 1, e[3]
  if vim.fn.visualmode() ~= 'v' then
    local last = vim.api.nvim_buf_get_lines(buf, er, er + 1, false)[1] or ''
    return { sr, 0, er, #last }
  end
  local line = vim.api.nvim_buf_get_lines(buf, er, er + 1, false)[1] or ''
  -- '> points at the first byte of the last character, which may be several bytes long (or past the end after v$)
  if ec >= #line then return { sr, sc, er, #line } end
  local tail = line:sub(ec):match('^[%z\1-\127\194-\244][\128-\191]*') or ''
  return { sr, sc, er, ec - 1 + math.max(#tail, 1) }
end

local function range_text(buf, r)
  return table.concat(vim.api.nvim_buf_get_text(buf, r[1], r[2], r[3], r[4], {}), '\n')
end

--- Changes the case of the visual selection, or of the given lines (a :range), or of the current line
function M.change_case(op, opts)
  if not vim.tbl_contains(M.CASES, op) then
    return notify('unknown operation ' .. tostring(op) .. '. Use one of: ' .. table.concat(M.CASES, ', '), vim.log.levels.ERROR)
  end
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local r
  if opts.visual then
    r = visual_range(buf)
  else
    local l1, l2 = opts.line1 or vim.fn.line('.'), opts.line2 or vim.fn.line('.')
    local last = vim.api.nvim_buf_get_lines(buf, l2 - 1, l2, false)[1] or ''
    r = { l1 - 1, 0, l2 - 1, #last }
  end
  local before = range_text(buf, r)
  local after = txt[op](before)
  if after ~= before then
    vim.api.nvim_buf_set_text(buf, r[1], r[2], r[3], r[4], vim.split(after, '\n', { plain = true }))
  end
end

--- Counts and limits of a text, as lines for a message
function M.report(text)
  local st = txt.stats(text)
  local lines = {
    string.format('Words: %d   Characters: %d   Without spaces: %d', st.words, st.chars, st.charsNoSpaces),
    string.format('Sentences: %d   Lines: %d   Reading time: %d min %d s', st.sentences, st.lines, math.floor(st.readSeconds / 60), st.readSeconds % 60),
    '',
  }
  local lim = txt.limits(text)
  for _, k in ipairs(txt.LIMITS_ORDER) do
    local l = lim[k]
    lines[#lines + 1] = string.format('%-22s %5d  %s', NAMES[k], l.limit, l.fits and (l.left .. ' left') or ((-l.left) .. ' over'))
  end
  return lines
end

function M.count(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local text
  if opts.visual then
    text = range_text(buf, visual_range(buf))
  elseif opts.range and opts.range > 0 then
    text = table.concat(vim.api.nvim_buf_get_lines(buf, opts.line1 - 1, opts.line2, false), '\n')
  else
    text = buffer_text(buf)
  end
  vim.api.nvim_echo(vim.tbl_map(function(l) return { l .. '\n' } end, M.report(text)), false, {})
end

local function cues_of(buf)
  local src = buffer_text(buf)
  local cues = sub.parse(src)
  if #cues == 0 then
    notify('no SRT or WebVTT cues in this buffer', vim.log.levels.WARN)
    return nil
  end
  return src, cues
end

--- Opens the buffer converted to "srt" or "vtt" in a split, in a new buffer named after the file
function M.convert(to)
  local buf = vim.api.nvim_get_current_buf()
  local src, cues = cues_of(buf)
  if not src then return end
  local name = vim.api.nvim_buf_get_name(buf)
  local base = name ~= '' and vim.fn.fnamemodify(name, ':r') or 'subtitles'
  vim.cmd('new')
  local out = vim.api.nvim_get_current_buf()
  set_buffer_text(out, sub.convert(src, to))
  pcall(vim.api.nvim_buf_set_name, out, base .. '.' .. to)
  vim.bo[out].filetype = to == 'vtt' and 'webvtt' or 'srt'
  notify(#cues .. ' cues converted. Save with :w')
end

function M.shift(seconds)
  local sec = tonumber((tostring(seconds or ''):gsub(',', '.')))
  if not sec then return notify('give the seconds, like :GoSaveTool shift 1.5 or -2', vim.log.levels.ERROR) end
  local buf = vim.api.nvim_get_current_buf()
  local src, cues = cues_of(buf)
  if not src then return end
  local moved = sub.shift(cues, math.floor(sec * 1000 + 0.5))
  set_buffer_text(buf, sub.is_vtt(src) and sub.to_vtt(moved) or sub.to_srt(moved))
  notify('moved ' .. sec .. ' s')
end

function M.repair()
  local buf = vim.api.nvim_get_current_buf()
  local src, cues = cues_of(buf)
  if not src then return end
  local fixed, n = sub.repair(cues)
  set_buffer_text(buf, sub.is_vtt(src) and sub.to_vtt(fixed) or sub.to_srt(fixed))
  notify(n > 0 and (n .. ' problems fixed') or 'no problems found')
end

function M.info()
  local buf = vim.api.nvim_get_current_buf()
  local src, cues = cues_of(buf)
  if not src then return end
  local last = 0
  for _, c in ipairs(cues) do last = math.max(last, c['end']) end
  local vtt = sub.is_vtt(src)
  notify((vtt and 'WebVTT' or 'SRT') .. ', ' .. #cues .. ' cues, ends at ' .. sub.from_ms(last, vtt and '.' or ','))
end

--- For a statusline: "123 words"
function M.statusline()
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_line_count(buf) > 20000 then return '' end
  return txt.stats(buffer_text(buf)).words .. ' words'
end

local SUBCOMMANDS = { 'count', 'case', 'to_vtt', 'to_srt', 'shift', 'repair', 'info' }

--- :GoSaveTool {subcommand} [args]
function M.command(opts)
  local args = opts.fargs
  local name = args[1]
  -- A command run from visual mode gets the '<,'> range
  local visual = opts.range == 2 and vim.fn.line("'<") == opts.line1 and vim.fn.line("'>") == opts.line2
  if name == 'count' then
    M.count({ visual = visual, range = opts.range, line1 = opts.line1, line2 = opts.line2 })
  elseif name == 'case' then
    M.change_case(args[2], { visual = visual, line1 = opts.line1, line2 = opts.line2 })
  elseif name == 'to_vtt' then
    M.convert('vtt')
  elseif name == 'to_srt' then
    M.convert('srt')
  elseif name == 'shift' then
    M.shift(args[2])
  elseif name == 'repair' then
    M.repair()
  elseif name == 'info' then
    M.info()
  else
    notify('use one of: ' .. table.concat(SUBCOMMANDS, ', ') .. '. See :help gosavetool', vim.log.levels.ERROR)
  end
end

function M.complete(arg_lead, cmdline)
  local words = vim.split(cmdline, '%s+', { trimempty = true })
  local n = #words + (cmdline:match('%s$') and 1 or 0)
  local list = n <= 2 and SUBCOMMANDS or (words[2] == 'case' and n == 3 and M.CASES or {})
  return vim.tbl_filter(function(c) return c:sub(1, #arg_lead) == arg_lead end, list)
end

--- Optional: require('gosavetool').setup({ keymaps = true }) adds <leader>g mappings
function M.setup(opts)
  opts = opts or {}
  if opts.keymaps then
    local map = function(lhs, rhs, desc) vim.keymap.set({ 'n', 'x' }, lhs, rhs, { desc = desc }) end
    map('<leader>gc', ':GoSaveTool count<CR>', 'GoSaveTool: word count')
    map('<leader>gt', ':GoSaveTool case title<CR>', 'GoSaveTool: Title Case')
    map('<leader>gs', ':GoSaveTool case sentence<CR>', 'GoSaveTool: Sentence case')
    map('<leader>gu', ':GoSaveTool case upper<CR>', 'GoSaveTool: UPPERCASE')
    map('<leader>gl', ':GoSaveTool case lower<CR>', 'GoSaveTool: lowercase')
  end
end

return M
