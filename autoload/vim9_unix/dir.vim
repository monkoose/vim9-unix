vim9script

import '../../import/vim9_unix/utils.vim'

export def Create(qargs: string)
  const dst = empty(qargs) ? expand('%:h') : qargs
  if call('call', utils.MkdirCallable(dst)) == -1
    utils.ErrMessage('Directory already exists: ' .. dst)
  elseif empty(qargs)
    silent keepalt execute 'file' fnameescape(@%)
  endif
enddef
