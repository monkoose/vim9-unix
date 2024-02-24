vim9script

var find_path: string
export def FindPath(): string
  if find_path == null
    find_path = 'find'
    if has('win32')
      for p in split($PATH, ';')
        const prg_path = p ..'/find'
        if p !~? '\<System32\>' && executable(prg_path)
          path = prg_path
          break
        endif
      endfor
    endif
  endif
  return find_path
enddef

# TODO: fix grep
export def Grep(qargs: string, prg: string, bang: bool, type: string = '')
  const shellpipe = &shellpipe
  defer execute($'setlocal grepprg={&l:grepprg} gfm={&l:grepformat}')
  defer execute($'set shellpipe={shellpipe}')

  &l:grepprg = prg
  &l:grepformat = '%f'
  if shellpipe ==# '2>&1| tee' || shellpipe ==# '|& tee'
    &shellpipe = '| tee'
  endif

  execute($'{type}grep! {qargs}')

  if !bang && !empty(getqflist())
    cfirst
  endif
enddef
