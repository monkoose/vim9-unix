vim9script

import '../../import/vim9_unix/utils.vim'

def AbortOnError(cmd: string): string
  try
    exe cmd
  catch '^Vim(\w\+):E\d'
    return 'return ' .. string('echoerr ' .. string(matchstr(v:exception, ':\zsE\d.*')))
  endtry
  return ''
enddef

def DeletePath(path: string): any
  if isdirectory(path)
    return delete(path, 'd')
  else
    return utils.Fcall('delete', path)
  endif
enddef

def DeleteError(file: string): string
  if empty(utils.Fcall('getftype', file))
    return $'Could not find "{file}" on disk'
  else
    return $'Failed to delete "{file}"'
  endif
enddef

export def Unlink(bang: bool)
  if !bang && &undoreload >= 0 && line('$') >= &undoreload
    echoerr "Buffer too big for 'undoreload' (add ! to override)"
  elseif DeletePath(@%)
    echoerr DeleteError(@%)
  else
    edit!
    execute('doautocmd <nomodeline> User FileUnlinkPost')
  endif
enddef

export def Delete(bang: string)
  if !bang && !(line('$') == 1 && empty(getline(1)) || utils.Fcall('getftype', @%) !=# 'file')
    utils.ErrMessage('File not empty (add ! to override)')
  else
    const file = expand('%:p')
    execute 'bdelete' .. bang
    if !bufloaded(file) && DeletePath(file)
      utils.ErrMessage(DeleteError(file))
    endif
  endif
enddef

# ~/f, $VAR/f, /f, C:/f, url://f, ./f, ../f
const absolute_pat = '^[~$]\|^' .. utils.slash_pat .. '\|^\a\+:\|^\.\.\=\%(' .. utils.slash_pat .. '\|$\)'

export def Complete(leading: string, _, _): list<string>
  const sep = utils.Separator()
  const prefix = leading =~# absolute_pat ? '' : expand('%:h') .. sep
  var files = glob(prefix .. leading .. '*')
                ->split("\n")
                ->map((_, v) => fnameescape(strpart(v, len(prefix)) .. (isdirectory(v) ? sep : '')))
  return files
enddef

export def RenameArg(arg: string): string
  if arg =~# absolute_pat
    return arg
  else
    return expand('%:h') .. '/' .. arg
  endif
enddef

def Rename(src: string, dst: string): number
  if src !~# '^\a\a\+:' && dst !~# '^\a\a\+:'
    return rename(src, dst)
  endif

  try
    const Fn = utils.Ffn('writefile', dst)
    const copy = call(Fn, [utils.Fcall('readfile', src, 'b'), dst])
    if copy == 0
      const delete = utils.Fcall('delete', src)
      if delete == 0
        return 0
      else
        utils.Fcall('delete', dst)
        return -1
      endif
    endif
  catch
    return -1
  endtry
  return 0
enddef

def FileDest(qargs: string): string
  var file = qargs
  if file =~# utils.slash_pat .. '$'
    file ..=  expand('%:t')
  elseif utils.Fcall('isdirectory', file)
    file ..= utils.Separator() .. expand('%:t')
  endif
  return substitute(file, '^\.' .. utils.slash_pat, '', '')
enddef

export def Copy(qargs: string, mods: string, bang: string)
  var dst = FileDest(qargs)
  call call('call', utils.MkdirCallable(fnamemodify(dst, ':h')))
  dst = utils.Fcall('simplify', dst)
  try
    execute($'{expand(mods)} saveas{bang} {fnameescape(dst)}')
  catch '^Vim(\w\+):E\%(13\|139\):'
    utils.ErrMessage('File already exists (add ! to override)')
  endtry
  filetype detect
enddef

export def Move(qargs: string, bang: bool)
  var dst = FileDest(qargs)
  exe AbortOnError($'call call("call", utils.MkdirCallable({string(fnamemodify(dst, ':h'))}))')
  dst = utils.Fcall('simplify', dst)

  if !bang && utils.Fcall('filereadable', dst)
    utils.ErrMessage('File already exists (add ! to override)')
    return
    # const confirm = &confirm
    # try
    #   if confirm | set noconfirm | endif
    #   exe AbortOnError('keepalt saveas ' .. fnameescape(dst))
    # finally
    #   if confirm | set confirm | endif
    # endtry
  endif

  const src = expand('%')
  if utils.Fcall('filereadable', src) && Rename(src, dst)
    utils.ErrMessage($'Failed to rename "{src}" to "{dst}"')
  else
    const last_bufnr = bufnr('$')
    exe AbortOnError('silent keepalt file ' .. fnameescape(dst))

    const lb = bufnr('$')
    if lb != last_bufnr
      exe $':{lb}bwipe'
    endif

    setlocal modified
    write!
    filetype detect
  endif
enddef
