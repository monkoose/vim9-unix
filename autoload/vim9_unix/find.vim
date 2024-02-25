vim9script

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
