function! NeovimStrategy(cmd) abort
  let opts = {'suffix': ' # vim-test'}
  function! opts.close_terminal()
    if bufnr(self.suffix) != -1
      execute 'bdelete!' bufnr(self.suffix)
    end
  endfunction
  call opts.close_terminal()
  vertical botright new

  call termopen(a:cmd . opts.suffix, opts)
  au BufDelete <buffer> wincmd p
  startinsert
endfunction

let test#filename_modifier = ":p"
let g:test#custom_strategies = {'vertical-neovim': function('NeovimStrategy')}
let g:test#strategy = 'vertical-neovim'
