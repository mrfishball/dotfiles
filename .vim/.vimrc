call plug#begin('~/.vim/plugged')
if has('nvim')
	Plug 'w0rp/ale'
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
Plug 'altercation/vim-colors-solarized'
Plug 'janko/vim-test'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app & yarn install'  }
Plug '/usr/local/opt/fzf'
Plug 'junegunn/vim-easy-align'
Plug 'morhetz/gruvbox'
Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'ludovicchabant/vim-gutentags'
Plug 'peitalin/vim-jsx-typescript'
Plug 'scrooloose/nerdcommenter'
Plug 'slashmili/alchemist.vim'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'

call plug#end()

" Basic Settings {{{
if !has('nvim')
  set nocompatible
  set encoding=utf-8
endif

syntax enable

if exists('&termguicolors')
  set termguicolors
endif

let g:gruvbox_contrast_light = 'hard'
let g:gruvbox_contrast_dark = 'hard'

set background=light
colorscheme gruvbox
" colorscheme solarized
highlight search cterm=underline ctermfg=214 gui=underline guifg=#fabd2f

" Neovim Terminal
if has('nvim')
  tnoremap <c-\> <c-\><c-n>

  augroup myterminal
    au TermOpen * setlocal nonumber norelativenumber
  augroup END
endif


set cc=80
set ls=2  " always show status line
set showcmd
if exists('&belloff')
  set belloff=all
endif

" tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4

set smarttab
set expandtab

set nowrap

" searching
set hlsearch
set ignorecase
set smartcase

" line numbers
set number
if exists('&relativenumber')
  set relativenumber
endif

set listchars=eol:↲,tab:▶▹,nbsp:␣,extends:…,trail:•
set exrc

set completeopt-=preview

if exists('&inccommand')
	set inccommand=split
endif

" File Type Settings {{{
augroup filetypesettings
  autocmd!
  au filetype typescript.tsx setlocal ts=2 softtabstop=2 sw=2
  au filetype javascript setlocal ts=2 softtabstop=2 sw=2
  au filetype htmldjango setlocal ts=4 softtabstop=4 sw=4
  au filetype vim setlocal ts=2 softtabstop=2 sw=2
  au filetype elixir setlocal foldmethod=syntax foldlevel=20
  au filetype elixir nnoremap <leader>tr :silent exec '!tmux send-keys -r -t 1 "mix test" enter' <Bar> redraw!<CR>
  au filetype ruby setlocal ts=2 sw=2 softtabstop=2
  au filetype markdown setlocal spell
  au filetype clojure setlocal lispwords+=describe,context,it,around,should-invoke
  au cmdwinenter * setlocal cc=0 nonumber norelativenumber
  autocmd filetype yaml setlocal ts=2 sts=2 sw=2 expandtab
augroup end
"}}}

" Whitespace {{{
function! MatchTrailingWhitespace()
  call matchadd('Error', '\v\s+$')
endfunction

augroup whitespace_detect
  autocmd!
  au BufEnter * :call MatchTrailingWhitespace()
augroup END
"}}}

" formatting {{{
augroup fmt
  autocmd!
  " autocmd BufWritePre * undojoin | Neoformat
augroup END
" }}}

execute pathogen#infect()

:imap jk <Esc>
:nnoremap <leader>ff :GFiles<cr>
:nnoremap <leader>fg :Files<cr>
:nnoremap <leader>pi :PlugInstall<cr>
:nnoremap <leader>pu :PlugUpdate<cr>
:nnoremap <leader>pg :PlugUpgrade<cr>
:nnoremap <leader>pc :PlugClean!<cr>
:nnoremap <leader>gs :Gstatus<cr>
:nnoremap <leader>at :ALEToggle<cr>
:nnoremap <leader>mp :MarkdownPreview<cr>
:nnoremap <leader>mx :MarkdownPreviewStop<cr>

:nmap <silent> <leader>tn :TestNearest<CR>
:nmap <silent> <leader>tf :TestFile<CR>
:nmap <silent> <leader>ta :TestSuite<CR>
:nmap <silent> <leader>tl :TestLast<CR>
:nmap <silent> <leader>tv :TestVisit<CR>

" JSON Tidy
noremap <leader>jt <Esc>:%!json_xs -f json -t json-pretty<CR>

command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

command! -bang -nargs=* Ag
  \ call fzf#vim#ag(<q-args>,
  \                 <bang>0 ? fzf#vim#with_preview('up:60%')
  \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
  \                 <bang>0)

let g:deoplete#enable_at_startup = 1

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Use compact syntax for prettified multi-line comments
let g:NERDCompactSexyComs = 1

" Align line-wise comment delimiters flush left instead of following code indentation
let g:NERDDefaultAlign = 'left'

" Set a language to use its alternate delimiters by default
let g:NERDAltDelims_java = 1

" Add your own custom formats or override the defaults
let g:NERDCustomDelimiters = { 'c': { 'left': '/**','right': '*/' } }

" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1

" Enable NERDCommenterToggle to check all selected lines is commented or not
let g:NERDToggleCheckAllLines = 1

let g:ale_fix_on_save = 1
let g:ale_linter_aliases = {'typescriptreact': 'typescript'}
let g:ale_linters = {'ruby': ['rubocop'], 'javascript': ['eslint'], 'typescript': ['tsserver', 'eslint'], 'vue': ['eslint']}
let g:ale_fixers = {'ruby': ['rubocop'], '*': ['remove_trailing_lines', 'trim_whitespace'], 'javascript': ['eslint'], 'typescript': ['eslint'], 'vue': ['eslint']}
let g:ale_sign_error = '>>'
let g:ale_sign_warning = '--'

let g:ycm_show_diagnostics_ui = 0
let g:ycm_enable_diagnostic_signs = 0
let g:ycm_enable_diagnostic_highlighting = 0
let g:test#preserve_screen = 0

" Load all plugins now.
" Plugins need to be added to runtimepath before helptags can be generated.
packloadall
" Load all of the helptags now, after plugins have been loaded.
" All messages and errors will be ignored.
silent! helptags ALL

hi link ALEError Error
hi Warning term=underline cterm=underline ctermfg=Yellow gui=undercurl guisp=Gold
hi link ALEWarning Warning
hi link ALEInfo SpellCap
