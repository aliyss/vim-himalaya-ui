
let s:stdout = []
let s:stderr = []

function! himalaya_ui#job#neovim#start(cmd) abort
  let s:stdout = []
  let s:stderr = []

  let cmd = split(a:cmd, ' -- ')
  let job = jobstart(cmd[0], {
  \ 'on_stdout': {_, lines -> s:on_stdout(lines)},
  \ 'on_stderr': {_, lines -> s:on_stderr(lines)},
  \})

  if len(cmd) > 1
    call chansend(job, join(cmd[1:], ' -- '))
    call chanclose(job, 'stdin')
  endif

  " Wait for the job to finish
  call jobwait([job])

  " Handle any stderr output
  if !empty(s:stderr)
    for line in s:stderr
      call himalaya#log#err(line)
    endfor
    redraw
    throw 'CLI error, see :messages for more information'
  endif

  " Return the stdout data
  return s:stdout
endfunction

function! s:on_stdout(lines) abort
  let s:stdout += s:compact_lines(a:lines)
endfunction

function! s:on_stderr(lines) abort
  let s:stderr += s:compact_lines(a:lines)
endfunction

function! s:compact_lines(lines) abort
  let lines = copy(a:lines)

  " removes empty strings at the begining
  while len(lines) > 0 && empty(lines[0])
    let lines = lines[1:]
  endwhile
  
  " removes empty strings at the end
  while len(lines) > 0 && empty(lines[len(lines) - 1])
    let lines = lines[:len(lines) - 2]
  endwhile

  " concat lines if there is at least one string
  if reduce(lines, {acc, val -> acc + len(val)}, 0) > 0
    return lines
  endif

  return []
endfunction
