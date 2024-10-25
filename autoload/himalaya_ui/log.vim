function! himalaya_ui#log#info(msg) abort
  echohl None
  echomsg a:msg
endfunction

function! himalaya_ui#log#warn(msg) abort
  echohl WarningMsg
  echomsg a:msg
  echohl None
endfunction

function! himalaya_ui#log#err(msg) abort
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction
