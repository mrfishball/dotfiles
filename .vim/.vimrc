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
Plug 'iamcco/markdown-preview.nvim', { 'do': ':call mkdp#util#install()', 'for': 'markdown', 'on': 'MarkdownPreview' }

if isdirectory("/usr/local/opt/fzf") " Homebrew is installed in /opt/homebrew/ on Apple Silicone
  Plug '/usr/local/opt/fzf'
else
  Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
endif

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
Plug 'elixir-editors/vim-elixir'
Plug 'OmniSharp/omnisharp-vim'
Plug 'mileszs/ack.vim'
Plug 'tfnico/vim-gradle'
Plug 'github/copilot.vim'

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
" let g:gruvbox_contrast_dark = 'hard'

" set background=light
set background=dark
colorscheme gruvbox
" colorscheme solarized
" highlight search cterm=underline ctermfg=214 gui=underline guifg=#fabd2f

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
set tabstop=2
set shiftwidth=2
set softtabstop=2

set smarttab
set expandtab

set nowrap

" searching
set hlsearch
set ignorecase
set smartcase

" line numbers
set number
" if exists('&relativenumber')
"   set relativenumber
" endif

set cursorline
" hi CursorLine term=bold cterm=bold guibg=Grey25

" TypeScript Syntax Highlight Settings {{{
" dark red
hi tsxTagName guifg=#E06C75
hi tsxComponentName guifg=#E06C75
hi tsxCloseComponentName guifg=#E06C75

" orange
hi tsxCloseString guifg=#F99575
hi tsxCloseTag guifg=#F99575
hi tsxCloseTagName guifg=#F99575
hi tsxAttributeBraces guifg=#F99575
hi tsxEqual guifg=#F99575

" yellow
hi tsxAttrib guifg=#F8BD7F cterm=italic

" light-grey
hi tsxTypeBraces guifg=#999999
" dark-grey
hi tsxTypes guifg=#666666

hi ReactState guifg=#C176A7
hi ReactProps guifg=#D19A66
hi ApolloGraphQL guifg=#CB886B
hi Events ctermfg=204 guifg=#56B6C2
hi ReduxKeywords ctermfg=204 guifg=#C678DD
hi ReduxHooksKeywords ctermfg=204 guifg=#C176A7
hi WebBrowser ctermfg=204 guifg=#56B6C2
hi ReactLifeCycleMethods ctermfg=204 guifg=#D19A66
"}}}

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
  au filetype typescript.ts setlocal ts=2 softtabstop=2 sw=2
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
:nnoremap <leader>gs :Git<cr>
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

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang Rg call RipgrepFzf(<q-args>, <bang>0)

let g:fzf_layout = { 'window': { 'width': 1, 'height': 0.7 } }
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
let g:ale_linters = {'ruby': ['rubocop'], 'javascript': ['eslint'], 'typescript': ['tsserver', 'eslint'], 'vue': ['eslint'], 'cs': ['OmniSharp'], 'python': ['mypy']}
let g:ale_fixers = {'elixir': ['mix_format'], 'ruby': ['rubocop'], '*': ['remove_trailing_lines', 'trim_whitespace'], 'javascript': ['eslint'], 'typescript': ['eslint'], 'vue': ['eslint'], 'python': ['black']}

let g:ale_python_mypy_use_global = 0
let g:ale_python_mypy_auto_pipenv = 1
let g:ale_python_mypy_auto_poetry = 1

let g:ale_python_black_auto_poetry = 1

let g:ale_sign_error = '>>'
let g:ale_sign_warning = '--'

" let test#java#runner = 'gradletest'
let test#python#runner = 'pytest'

let vim_markdown_preview_github=1

let g:ycm_show_diagnostics_ui = 0
let g:ycm_enable_diagnostic_signs = 0
let g:ycm_enable_diagnostic_highlighting = 0
let g:test#preserve_screen = 0

let g:gutentags_add_default_project_roots = 0
let g:gutentags_project_root = ['package.json', '.git']

let g:gutentags_generate_on_new = 1
let g:gutentags_generate_on_missing = 1
let g:gutentags_generate_on_write = 1
let g:gutentags_generate_on_empty_buffer = 0

let g:gutentags_ctags_exclude = [
      \ '*.git', '*.svg', '*.hg',
      \ '*/tests/*',
      \ 'build',
      \ 'build-cache',
      \ 'es',
      \ 'dist',
      \ '*sites/*/files/*',
      \ 'bin',
      \ 'node_modules',
      \ 'bower_components',
      \ 'cache',
      \ 'compiled',
      \ 'docs',
      \ 'example',
      \ 'bundle',
      \ 'vendor',
      \ '*.md',
      \ '*-lock.json',
      \ '*.lock',
      \ '*bundle*.js',
      \ '*build*.js',
      \ '.*rc*',
      \ '*.json',
      \ '*.min.*',
      \ '*.map',
      \ '*.bak',
      \ '*.zip',
      \ '*.pyc',
      \ '*.class',
      \ '*.sln',
      \ '*.Master',
      \ '*.csproj',
      \ '*.tmp',
      \ '*.csproj.user',
      \ '*.cache',
      \ '*.pdb',
      \ 'tags*',
      \ 'cscope.*',
      \ '*.css',
      \ '*.less',
      \ '*.scss',
      \ '*.exe', '*.dll',
      \ '*.mp3', '*.ogg', '*.flac',
      \ '*.swp', '*.swo',
      \ '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
      \ '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
      \ '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
      \ ]

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
