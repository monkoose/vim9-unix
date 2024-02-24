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

export def Grep(qargs: string, prg: string, bang: bool, type: string = '')
  setqflist([], 'r')
  job_start(['/bin/sh', '-c', $'{prg} {qargs}'], {
    out_cb: (_, m) => {
      setqflist([{filename: m}], 'a')
    },
    close_cb: (_) => {
      if !bang && !empty(getqflist())
        cfirst
      endif
    },
  })
enddef
