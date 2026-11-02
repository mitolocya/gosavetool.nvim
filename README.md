# gosavetool.nvim

Subtitle and text tools for Neovim: convert **SRT ↔ WebVTT**, **shift** and **repair** subtitle timings, **count words** with **social media and SEO character limits**, and change **text case** of a selection. Pure Lua, no dependencies, works offline.

Made by [GoSaveTool](https://www.gosavetool.com/), free online tools for creators.

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'mitolocya/gosavetool.nvim', cmd = 'GoSaveTool', opts = { keymaps = true } }
```

[packer.nvim](https://github.com/wbthomason/packer.nvim): `use 'mitolocya/gosavetool.nvim'`. vim-plug: `Plug 'mitolocya/gosavetool.nvim'`. Requires Neovim 0.9 or newer.

## Commands

| Command | What it does |
| --- | --- |
| `:GoSaveTool count` | Words, characters, sentences, lines, reading time and the characters left for X, Instagram, TikTok, YouTube, LinkedIn, Pinterest, SEO title and meta description. Works on a visual selection or a range too. |
| `:GoSaveTool case {op}` | `title`, `sentence`, `upper`, `lower`, `slug`, `camel`, `snake`, `kebab` or `clean` on the visual selection (characterwise too), a range or the current line |
| `:GoSaveTool to_vtt` / `to_srt` | Opens the converted subtitles in a split, in a new buffer named `file.vtt` / `file.srt` |
| `:GoSaveTool shift 1.5` | Moves every cue 1.5 s later (`-2` = earlier) |
| `:GoSaveTool repair` | Sorts cues, fixes overlaps and end times before the start, drops empty cues, renumbers |
| `:GoSaveTool info` | Format, number of cues, end time |

Tab completion works for the subcommands and the case names. Full help: `:help gosavetool`.

With `setup({ keymaps = true })`: `<leader>gc` count, `<leader>gt` Title Case, `<leader>gs` Sentence case, `<leader>gu` UPPERCASE, `<leader>gl` lowercase.

Statusline (for example lualine): `require('gosavetool').statusline()` returns `"123 words"`.

## Lua API

```lua
local sub = require('gosavetool.subtitles')
local cues = sub.parse(text)                 -- { { start = 1000, ['end'] = 3500, text = 'Hello' }, ... }
sub.convert(text, 'vtt')
local fixed, n = sub.repair(cues)

local txt = require('gosavetool.text')
txt.stats('Hello world.')                    -- { words = 2, chars = 12, readSeconds = 1, ... }
txt.title('the lord of the rings')           -- 'The Lord of the Rings'
txt.slug('Ölçü Birimi & Çeviri!')            -- 'olcu-birimi-ceviri'
```

The rules are the same as the [`@gosavetool/subtitles`](https://www.npmjs.com/package/@gosavetool/subtitles) and [`@gosavetool/text`](https://www.npmjs.com/package/@gosavetool/text) packages.

## Tests

```bash
nvim --headless -u NONE -l tests/run.lua
```

## Online tools

[VTT Subtitle Generator](https://www.gosavetool.com/vtt-subtitle-generator), [Auto Captions Generator](https://www.gosavetool.com/auto-captions-generator), [Character Counter](https://www.gosavetool.com/character-counter)

## License

MIT
