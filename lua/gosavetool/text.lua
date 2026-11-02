-- Word, character and reading-time counts, case changes, URL slugs and whitespace cleanup.
-- The Lua version of @gosavetool/text: https://www.gosavetool.com/character-counter
-- Works on UTF-8 strings. Case changes of non-ASCII letters use Neovim's toupper()/tolower().

local M = {}

M.LIMITS_ORDER = {
  'x-post', 'instagram-caption', 'tiktok-caption', 'youtube-title', 'youtube-description',
  'linkedin-post', 'pinterest-description', 'seo-title', 'meta-description',
}
-- Character limits of common fields; SEO values are the length search results show before cutting
M.LIMITS = {
  ['x-post'] = 280,
  ['instagram-caption'] = 2200,
  ['tiktok-caption'] = 4000,
  ['youtube-title'] = 100,
  ['youtube-description'] = 5000,
  ['linkedin-post'] = 3000,
  ['pinterest-description'] = 500,
  ['seo-title'] = 60,
  ['meta-description'] = 160,
}

local SMALL = {}
for _, w in ipairs({ 'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of', 'on', 'or', 'so', 'the', 'to', 'up', 'yet', 'via', 'vs' }) do
  SMALL[w] = true
end

--- Code points of a UTF-8 string: a list of { char = "ç", cp = 231 }
local function chars(s)
  local out = {}
  for ch in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    local b1, n = ch:byte(1), #ch
    local cp
    if n == 1 then
      cp = b1
    elseif n == 2 then
      cp = (b1 % 32) * 64 + ch:byte(2) % 64
    elseif n == 3 then
      cp = ((b1 % 16) * 64 + ch:byte(2) % 64) * 64 + ch:byte(3) % 64
    else
      cp = (((b1 % 8) * 64 + ch:byte(2) % 64) * 64 + ch:byte(3) % 64) * 64 + ch:byte(4) % 64
    end
    out[#out + 1] = { char = ch, cp = cp }
  end
  return out
end
M._chars = chars

local function is_space(cp)
  return cp == 32 or (cp >= 9 and cp <= 13) or cp == 0xA0 or cp == 0x1680 or (cp >= 0x2000 and cp <= 0x200A)
    or cp == 0x2028 or cp == 0x2029 or cp == 0x202F or cp == 0x205F or cp == 0x3000 or cp == 0xFEFF
end

local function is_digit(cp)
  return cp >= 48 and cp <= 57
end

--- A letter or digit. Outside ASCII, everything but spaces, punctuation blocks and combining marks counts as a letter.
local function is_alnum(cp)
  if cp < 128 then
    return (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
  end
  if is_space(cp) then return false end
  if cp >= 0xA1 and cp <= 0xBF and cp ~= 0xAA and cp ~= 0xB2 and cp ~= 0xB3 and cp ~= 0xB5 and cp ~= 0xB9 and cp ~= 0xBA then return false end
  if cp == 0xD7 or cp == 0xF7 then return false end
  if cp >= 0x0300 and cp <= 0x036F then return false end -- combining marks
  if cp >= 0x2000 and cp <= 0x2BFF then return false end -- punctuation, symbols, arrows, dingbats
  if cp >= 0x3000 and cp <= 0x303F then return false end -- CJK punctuation
  if (cp >= 0xFE30 and cp <= 0xFE4F) or (cp >= 0xFF01 and cp <= 0xFF0F) or (cp >= 0xFF1A and cp <= 0xFF20) then return false end
  if cp >= 0x1F000 then return false end -- emoji and pictographs
  return true
end
M._is_alnum = is_alnum

local function upper_char(c)
  if vim and vim.fn then return vim.fn.toupper(c) end
  return c:upper()
end

local function lower_char(c)
  if vim and vim.fn then return vim.fn.tolower(c) end
  return c:lower()
end

function M.upper(s)
  return upper_char(s)
end

function M.lower(s)
  return lower_char(s)
end

local function is_upper(c) return lower_char(c) ~= c end
local function is_lower(c) return upper_char(c) ~= c end

local APOS = { [39] = true, [0x2019] = true }
local TERM = { [46] = true, [33] = true, [63] = true, [0x2026] = true } -- . ! ? …

--- Words, characters, lines, sentences and reading time (238 words a minute) of a text
function M.stats(s)
  local cs = chars(s)
  local words, no_spaces, sentences, lines = 0, 0, 0, 0
  local in_word, prev_body = false, false
  for i, c in ipairs(cs) do
    local cp = c.cp
    -- A word starts with a letter or digit and goes on over letters, digits, apostrophes, _ and -
    if in_word then
      in_word = is_alnum(cp) or APOS[cp] or cp == 95 or cp == 45
    elseif is_alnum(cp) then
      in_word = true
      words = words + 1
    end
    if not is_space(cp) then no_spaces = no_spaces + 1 end
    -- A sentence is text followed by . ! ? or …
    if TERM[cp] then
      if prev_body then sentences = sentences + 1 end
      prev_body = false
    else
      prev_body = true
    end
    if cp == 10 and not (i > 1 and cs[i - 1].cp == 13) then lines = lines + 1 end
    if cp == 13 then lines = lines + 1 end
  end
  return {
    words = words,
    chars = #cs,
    charsNoSpaces = no_spaces,
    lines = s == '' and 0 or lines + 1,
    sentences = sentences,
    readSeconds = math.floor(words / 238 * 60 + 0.5),
  }
end

--- How each limit is met: { ['x-post'] = { limit = 280, used = 120, left = 160, fits = true }, ... }
function M.limits(s, only)
  local used = #chars(s)
  local out = {}
  for _, k in ipairs(M.LIMITS_ORDER) do
    if not only or vim.tbl_contains(only, k) then
      local n = M.LIMITS[k]
      out[k] = { limit = n, used = used, left = n - used, fits = used <= n }
    end
  end
  return out
end

--- 'bestPostingTime 2' -> { 'best', 'Posting', 'Time', '2' }
function M.words(s)
  local out, cur = {}, {}
  local prev
  local function flush()
    if #cur > 0 then out[#out + 1] = table.concat(cur) end
    cur = {}
  end
  for _, c in ipairs(chars(s)) do
    if is_alnum(c.cp) then
      if prev and is_upper(c.char) and (is_digit(prev.cp) or is_lower(prev.char)) then flush() end
      cur[#cur + 1] = c.char
      prev = c
    else
      flush()
      prev = nil
    end
  end
  flush()
  return out
end

local function capitalize(w)
  local first = w:match('^[%z\1-\127\194-\244][\128-\191]*')
  return upper_char(first) .. w:sub(#first + 1)
end

--- 'the lord of the rings: return of the king' -> 'The Lord of the Rings: Return of the King'
function M.title(s)
  local low = lower_char(s)
  local out, word, first, after_colon = {}, {}, true, false
  local pending_space = false
  local function flush()
    if #word == 0 then return end
    local w = table.concat(word)
    if first or after_colon or not SMALL[w] then w = capitalize(w) end
    out[#out + 1] = w
    word, first, after_colon = {}, false, false
  end
  for _, c in ipairs(chars(low)) do
    if is_alnum(c.cp) or (#word > 0 and APOS[c.cp]) then
      word[#word + 1] = c.char
    else
      flush()
      out[#out + 1] = c.char
      -- The next word starts a new phrase after : . ! ? and any spaces
      if c.cp == 58 or TERM[c.cp] and c.cp ~= 0x2026 then
        after_colon = true
      elseif not is_space(c.cp) then
        after_colon = false
      end
    end
  end
  flush()
  return table.concat(out)
end

--- 'HELLO WORLD. how ARE you?' -> 'Hello world. How are you?'
function M.sentence(s)
  local out = {}
  local start = true -- at the start, or after . ! ? … and at least one space
  local after_term = false
  for _, c in ipairs(chars(lower_char(s))) do
    local cp = c.cp
    if start and is_alnum(cp) and not is_digit(cp) then
      out[#out + 1] = upper_char(c.char)
      start, after_term = false, false
    else
      out[#out + 1] = c.char
      if TERM[cp] then
        after_term, start = true, false
      elseif is_space(cp) then
        if after_term then start = true end
      else
        start, after_term = false, false
      end
    end
  end
  return table.concat(out)
end

local FOLD = {}
for base, list in pairs({
  a = 'àáâãäåāăąǎ', c = 'çćĉċč', d = 'ďđð', e = 'èéêëēĕėęě', g = 'ĝğġģ', h = 'ĥħ', i = 'ìíîïĩīĭįı', j = 'ĵ', k = 'ķ',
  l = 'ĺļľŀł', n = 'ñńņňŉ', o = 'òóôõöøōŏőǒ', r = 'ŕŗř', s = 'śŝşšș', t = 'ţťŧț', u = 'ùúûüũūŭůűųǔ', w = 'ŵ', y = 'ýÿŷ', z = 'źżž',
  A = 'ÀÁÂÃÄÅĀĂĄǍ', C = 'ÇĆĈĊČ', D = 'ĎĐÐ', E = 'ÈÉÊËĒĔĖĘĚ', G = 'ĜĞĠĢ', H = 'ĤĦ', I = 'ÌÍÎÏĨĪĬĮİ', J = 'Ĵ', K = 'Ķ',
  L = 'ĹĻĽĿŁ', N = 'ÑŃŅŇ', O = 'ÒÓÔÕÖØŌŎŐǑ', R = 'ŔŖŘ', S = 'ŚŜŞŠȘ', T = 'ŢŤŦȚ', U = 'ÙÚÛÜŨŪŬŮŰŲǓ', W = 'Ŵ', Y = 'ÝŸŶ', Z = 'ŹŻŽ',
}) do
  for _, c in ipairs(chars(list)) do FOLD[c.char] = base end
end
FOLD['ß'], FOLD['æ'], FOLD['Æ'], FOLD['œ'], FOLD['Œ'], FOLD['þ'], FOLD['Þ'] = 'ss', 'ae', 'ae', 'oe', 'oe', 'th', 'th'

--- 'Ölçü Birimi & Çeviri!' -> 'olcu-birimi-ceviri'
function M.slug(s)
  local out = {}
  for _, c in ipairs(chars(s)) do out[#out + 1] = FOLD[c.char] or c.char end
  local ascii = table.concat(out):lower():gsub('[^a-z0-9]+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
  return ascii
end

function M.camel(s)
  local out = {}
  for i, w in ipairs(M.words(s)) do
    out[i] = i == 1 and lower_char(w) or capitalize(lower_char(w))
  end
  return table.concat(out)
end

local function join_lower(s, sep)
  local out = {}
  for i, w in ipairs(M.words(s)) do out[i] = lower_char(w) end
  return table.concat(out, sep)
end

function M.snake(s) return join_lower(s, '_') end
function M.kebab(s) return join_lower(s, '-') end

--- Trailing spaces, runs of spaces and more than one blank line in a row
function M.clean(s)
  local nl = s:find('\r\n', 1, true) and '\r\n' or '\n'
  local lines = {}
  for line in (s .. '\n'):gmatch('(.-)\r?\n') do
    line = line:gsub('[ \t]+$', ''):gsub('(%S)[ \t][ \t]+', '%1 ')
    lines[#lines + 1] = line
  end
  local out = table.concat(lines, nl)
  local three = nl:rep(3)
  while out:find(three, 1, true) do
    out = out:gsub(vim.pesc(three), nl .. nl)
  end
  return out
end

return M
