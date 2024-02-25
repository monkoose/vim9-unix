vim9script

export def Ffn(fn: string, path: string): func
  const io_dict = 'io_' .. matchstr(path, '^\a\a\+\ze:')
  return get(g:, io_dict, {})->get(fn, function(fn))
enddef

export def Fcall(fn: string, path: string, ...variadic: list<any>): any
  return call(Ffn(fn, path), [path] + variadic)
enddef

export def ErrMessage(msg: string)
  echohl ErrorMsg
  echom 'vim9-unix: ' .. msg
  echohl None
enddef

export def MkdirCallable(name: string): list<any>
  const ns = matchstr(name, '^\a\a\+\ze:')
  if !Fcall('isdirectory', name) && Fcall('filewritable', name) != 2
    const mkdir_func = $'g:io_{ns}.mkdir'
    if exists(mkdir_func)
      return [function(mkdir_func), [name, 'p']]
    elseif empty(ns)
      return ['mkdir', [name, 'p']]
    endif
  endif
  return [(..._) => -1, []]
enddef

