# Neovim eklentisini yayınlama (GitHub + lazy.nvim, dotfyle, awesome-neovim)

Neovim'in merkezi bir mağazası yoktur: eklenti bir **GitHub deposudur** ve kullanıcılar lazy.nvim / packer / vim-plug ile depo adından kurar. Görünürlük üç yerden gelir: GitHub (DA çok yüksek), **dotfyle.com** (Neovim eklenti dizini, GitHub'dan otomatik toplar) ve **awesome-neovim** listesi (PR ile).

Durum (2 Kasım 2026): **Test edildi.** Neovim 0.12.6 taşınabilir zip'ten `.tools/nvim` içine kuruldu; `nvim --headless -u NONE -l tests/run.lua` → **all checks passed**. Testteki bir beklenti hatalıydı (`sub(1, 50)` → `sub(1, 51)`), düzeltildi. Yükleme yapılmadı; `mitolocya/gosavetool.nvim` deposu henüz yok.

Komut:

```
/c/Users/BWT/Downloads/Work/new/.tools/nvim/nvim-win64/bin/nvim.exe --headless -u NONE -l tests/run.lua
```

PowerShell: `& "C:\Users\BWT\Downloads\Work\new\.tools\nvim\nvim-win64\bin\nvim.exe" --headless -u NONE -l tests/run.lua`

## 1. Hesap

GitHub hesabı yeterli (mevcut `mitolocya`).

## 2. GitHub deposu

1. https://github.com/new → ad **`gosavetool.nvim`** (Neovim eklentilerinde `.nvim` soneki gelenek), Public, README ekleme.
2. Bu klasörün içeriğini kök dizine yükle: `lua/`, `plugin/`, `doc/`, `tests/`, `README.md`, `LICENSE`.
3. About: `Convert SRT and WebVTT, shift and repair subtitles, count words with social media limits and change text case. Pure Lua.` — website `https://www.gosavetool.com/`.
4. Topics: `neovim`, `nvim`, `neovim-plugin`, `lua`, `subtitles`, `srt`, `webvtt`, `word-count`, `case-converter`.
5. **Releases → Draft a new release** → tag `v1.0.0` → Publish.

Depo açıldıktan sonra bu klasörden:

```
git init
git add .
git commit -m "gosavetool.nvim 1.0.0"
git branch -M main
git remote add origin https://github.com/mitolocya/gosavetool.nvim.git
git push -u origin main
git tag v1.0.0 && git push origin v1.0.0
```

## 3. Kurulum testi

Kendi Neovim'inde `%LOCALAPPDATA%\nvim\init.lua` içine lazy.nvim spec'i ekle:

```lua
{ 'mitolocya/gosavetool.nvim', cmd = 'GoSaveTool', opts = { keymaps = true } }
```

`:Lazy sync`, sonra bir .srt dosyasında `:GoSaveTool to_vtt`.

## 4. Görünürlük

- **dotfyle.com**: https://dotfyle.com/neovim/plugins → depo GitHub'da `neovim-plugin` topic'i ile birkaç gün içinde kendiliğinden listelenir; listelenmezse sayfadaki "Submit plugin" bağlantısını kullan.
- **awesome-neovim**: https://github.com/rockerBOO/awesome-neovim → Fork → `README.md` içinde uygun bölüme (ör. "Utility") alfabetik sırayla şu satırı ekle, PR aç:

  `- [mitolocya/gosavetool.nvim](https://github.com/mitolocya/gosavetool.nvim) - Convert SRT and WebVTT, shift and repair subtitles, count words with social media limits and change text case.`

- Reddit r/neovim "Plugin" etiketiyle kısa bir tanıtım gönderisi.

## Listeleme metinleri

- **Ad:** gosavetool.nvim
- **Kısa açıklama:** Convert SRT and WebVTT, shift and repair subtitles, count words with social media limits and change text case. Pure Lua.
- **Etiketler (topics):** neovim, nvim, neovim-plugin, lua, subtitles, srt, webvtt, word-count, case-converter
- **Uzun açıklama:** README.md

## Sonraki sürümler

Değişiklikleri yükle, yeni bir release etiketi aç (`v1.0.1`). lazy.nvim kullanıcıları `:Lazy update` ile alır.
