# Neovim eklentisini yayınlama (GitHub + lazy.nvim, dotfyle, awesome-neovim)

Neovim'in merkezi bir mağazası yoktur: eklenti bir **GitHub deposudur** ve kullanıcılar lazy.nvim / packer / vim-plug ile depo adından kurar. Görünürlük üç yerden gelir: GitHub (DA çok yüksek), **dotfyle.com** (Neovim eklenti dizini, GitHub'dan otomatik toplar) ve **awesome-neovim** listesi (PR ile).

## Durum (2 Kasım 2026)

- **Yayınlandı:** https://github.com/mitolocya/gosavetool.nvim — `main` dalı + `v1.0.0` etiketi gönderildi, depo Public.
- **Test edildi:** Neovim 0.12.6 taşınabilir zip (`.tools/nvim`), `nvim --headless -u NONE -l tests/run.lua` → **all checks passed** (39 kontrol). Testteki `sub(1, 50)` beklentisi `sub(1, 51)` olarak düzeltildi.
- **Kalan:** GitHub'da About açıklaması ve **topics** boş (`"description": null`, `"topics": []`). `neovim-plugin` topic'i olmadan dotfyle listelemez — https://github.com/mitolocya/gosavetool.nvim sayfasında "About" yanındaki ⚙ ile ekle (API token olmadan komut satırından yapılamıyor).
- **Release yok:** yalnızca git etiketi var; GitHub'da sürüm notlu bir Release istersen Releases → "Draft a new release" → `v1.0.0` → Publish.

Depo adresi: `https://github.com/mitolocya/gosavetool.nvim.git` (yerel `.git` bu klasörde, `origin` bağlı).

## GitHub About ve topics (tek eksik adım)

About açıklaması:

```
Convert SRT and WebVTT, shift and repair subtitles, count words with social media limits and change text case. Pure Lua.
```

Website: `https://www.gosavetool.com/`

Topics (tek tek eklenir):

```
neovim nvim neovim-plugin lua subtitles srt webvtt word-count case-converter
```

## Kurulum testi

Kendi Neovim'inde `%LOCALAPPDATA%\nvim\init.lua` içine lazy.nvim spec'i ekle:

```lua
{ 'mitolocya/gosavetool.nvim', cmd = 'GoSaveTool', opts = { keymaps = true } }
```

`:Lazy sync`, sonra bir .srt dosyasında `:GoSaveTool to_vtt`.

## Sonraki sürümler

```
git add -A
git commit -m "1.0.1: ..."
git tag v1.0.1 && git push && git push origin v1.0.1
```

lazy.nvim kullanıcıları `:Lazy update` ile alır.

## Görünürlük

- **dotfyle.com**: https://dotfyle.com/neovim/plugins → `neovim-plugin` topic'i eklendikten sonra birkaç gün içinde kendiliğinden listelenir; listelenmezse sayfadaki "Submit plugin" bağlantısını kullan. (2 Kasım: https://dotfyle.com/neovim/plugins/mitolocya/gosavetool.nvim → 404, henüz indekslenmedi.)
- **awesome-neovim**: https://github.com/rockerBOO/awesome-neovim → Fork → `README.md` içinde "Utility" bölümüne alfabetik sırayla şu satırı ekle, PR aç:

  `- [mitolocya/gosavetool.nvim](https://github.com/mitolocya/gosavetool.nvim) - Convert SRT and WebVTT, shift and repair subtitles, count words with social media limits and change text case.`

- Reddit r/neovim "Plugin" etiketiyle kısa bir tanıtım gönderisi.
