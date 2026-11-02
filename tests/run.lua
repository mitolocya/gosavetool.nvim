-- nvim --headless -u NONE -l tests/run.lua   (from the plugin folder; Neovim 0.9 or newer)
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/gosavetool.lua')

local sub = require('gosavetool.subtitles')
local txt = require('gosavetool.text')
local gst = require('gosavetool')
local failures = 0

local function eq(actual, expected, what)
  if not vim.deep_equal(actual, expected) then
    failures = failures + 1
    print('FAIL ' .. what .. '\n  expected: ' .. vim.inspect(expected) .. '\n  actual:   ' .. vim.inspect(actual))
  end
end

-- Subtitles: the checks of @gosavetool/subtitles
local SRT = '1\r\n00:00:01,000 --> 00:00:03,500\r\nHello\r\nworld\r\n\r\n2\r\n00:00:03,000 --> 00:00:02,000\r\nSecond\r\n\r\n3\r\n00:00:00,500 --> 00:00:00,900\r\nFirst\r\n'
local cues = sub.parse(SRT)
eq(#cues, 3, 'parse count')
eq(cues[1].text, 'Hello\nworld', 'multi-line text')
eq(sub.to_vtt(cues):sub(1, 51), 'WEBVTT\n\n00:00:01.000 --> 00:00:03.500\nHello\nworld\n\n', 'to_vtt')
eq(sub.convert('WEBVTT\n\nNOTE hi\n\n01:02.5 --> 01:04.000 align:start\nA\n', 'srt'), '1\n00:01:02,500 --> 00:01:04,000\nA\n', 'vtt to srt')
eq(sub.convert('WEBVTT\n\n01:02.5 --> 01:04.000 align:start\nA\n', 'vtt'), 'WEBVTT\n\n00:01:02.500 --> 00:01:04.000 align:start\nA\n', 'settings kept')
eq(pcall(sub.convert, SRT, 'ass'), false, 'bad target')
local shifted = {}
for i, c in ipairs(sub.shift(cues, -1000)) do shifted[i] = { c.start, c['end'] } end
eq(shifted, { { 0, 2500 }, { 2000, 1000 } }, 'shift')
local fixed, n = sub.repair(cues)
eq(vim.tbl_map(function(c) return c.text end, fixed), { 'First', 'Hello\nworld', 'Second' }, 'repair order')
eq(n, 3, 'repair count')
eq(cues[2]['end'], 2000, 'repair leaves the input alone')
eq(sub.from_ms(3723004, ','), '01:02:03,004', 'from_ms')
eq(sub.to_ms('1:02:03.4'), 3723400, 'to_ms')
eq(sub.to_ms('nope'), nil, 'to_ms invalid')
eq(sub.is_vtt('\239\187\191WEBVTT\n'), true, 'is_vtt with BOM')

-- Text: the checks of @gosavetool/text
eq(txt.stats('Hello world. It’s 2026!'), { words = 4, chars = 23, charsNoSpaces = 20, lines = 1, sentences = 2, readSeconds = 1 }, 'stats')
local st = txt.stats('Hello world. It’s 2026!\nSecond line.')
eq({ st.words, st.lines, st.sentences }, { 6, 2, 3 }, 'stats lines')
eq(txt.stats('').lines, 0, 'empty')
eq(txt.stats('Ölçü birimi çeviri').words, 3, 'Turkish words')
eq(txt.limits(string.rep('x', 300), { 'x-post' })['x-post'], { limit = 280, used = 300, left = -20, fits = false }, 'limits')
eq(txt.title('the lord of the rings: return of the king'), 'The Lord of the Rings: Return of the King', 'title')
eq(txt.title('it’s a dog’s life'), 'It’s a Dog’s Life', 'title apostrophe')
eq(txt.sentence('HELLO WORLD. how ARE you?'), 'Hello world. How are you?', 'sentence')
eq(txt.slug('Ölçü Birimi & Çeviri!'), 'olcu-birimi-ceviri', 'slug Turkish')
eq(txt.slug('Straße café'), 'strasse-cafe', 'slug accents')
eq(txt.camel('best posting time'), 'bestPostingTime', 'camel')
eq(txt.snake('bestPostingTime'), 'best_posting_time', 'snake')
eq(txt.kebab('Best Posting_Time'), 'best-posting-time', 'kebab')
eq(txt.upper('çğü'), 'ÇĞÜ', 'upper non-ASCII')
eq(txt.clean('a   b  \n\n\n\nc\t'), 'a b\n\nc', 'clean')
eq(txt.clean('a  \r\n\r\n\r\n\r\nb'), 'a\r\n\r\nb', 'clean CRLF')

-- Commands on a buffer
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'the lord of the rings', 'second line' })
vim.cmd('1GoSaveTool case title')
eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { 'The Lord of the Rings', 'second line' }, ':GoSaveTool case on a line')
-- Characterwise visual selection of "second"
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd('normal! vee\27')
vim.cmd("'<,'>GoSaveTool case upper")
eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { 'The Lord of the Rings', 'SECOND LINE' }, 'visual selection')
eq(gst.statusline(), '7 words', 'statusline')
eq(gst.complete('ti', 'GoSaveTool case ti'), { 'title' }, 'completion')

vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split('1\n00:00:02,000 --> 00:00:01,000\nB\n\n2\n00:00:00,500 --> 00:00:01,500\nA', '\n'))
vim.cmd('GoSaveTool repair')
eq(vim.api.nvim_buf_get_lines(buf, 0, 3, false), { '1', '00:00:00,500 --> 00:00:01,500', 'A' }, ':GoSaveTool repair')
vim.cmd('GoSaveTool shift 1,5')
eq(vim.api.nvim_buf_get_lines(buf, 1, 2, false), { '00:00:02,000 --> 00:00:03,000' }, ':GoSaveTool shift')
vim.cmd('GoSaveTool to_vtt')
eq(vim.api.nvim_buf_get_lines(0, 0, 1, false), { 'WEBVTT' }, ':GoSaveTool to_vtt opens a new buffer')
eq(vim.bo.filetype, 'webvtt', 'filetype')
eq(#gst.report('hi'), 12, 'report lines')

if failures > 0 then
  print(failures .. ' checks failed')
  vim.cmd('cquit 1')
end
print('all checks passed')
