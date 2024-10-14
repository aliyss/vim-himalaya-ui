let s:editor = has('nvim') ? 'neovim' : 'vim8'

function! himalaya_ui#job#start(cmd) abort
  let result = call('himalaya_ui#job#' . s:editor . '#start', [a:cmd])
  return result
endfunction
