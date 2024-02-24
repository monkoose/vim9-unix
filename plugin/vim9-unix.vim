vim9script noclear

if exists('g:loaded_vim9_unix')
  finish
endif
g:loaded_vim9_unix = 1

# configure separator for windows
var slash_pat: string
var Separator: func(): string
if exists('+shellslash')
  slash_pat = '[\/]'
  Separator = () => &shellslash ? '/' : '\'
else
  slash_pat = '/'
  Separator = () => '/'
endif

def Ffn(fn: string, path: string): func
  const io_dict = 'io_' .. matchstr(path, '^\a\a\+\ze:')
  return get(g:, io_dict, {})->get(fn, function(fn))
enddef

def Fcall(fn: string, path: string, ...variadic: list<any>): any
  return call(Ffn(fn, path), [path] + variadic)
enddef

def ErrMessage(msg: string)
  echohl ErrorMsg
  echom 'vim9-unix: ' .. msg
  echohl None
enddef

def AbortOnError(cmd: string): string
  try
    exe cmd
  catch '^Vim(\w\+):E\d'
    return 'return ' .. string('echoerr ' .. string(matchstr(v:exception, ':\zsE\d.*')))
  endtry
  return ''
enddef

def MkdirCallable(name: string): list<any>
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

def Mkdir(qargs: string)
  const dst = empty(qargs) ? expand('%:h') : qargs
  if call('call', MkdirCallable(dst)) == -1
    echohl WarningMsg
    echo "Directory already exists: " .. dst
    echohl NONE
  elseif empty(qargs)
    silent keepalt execute 'file' fnameescape(@%)
  endif
enddef

command! -bar -bang -nargs=? -complete=dir Mkdir Mkdir(<q-args>)

def DeletePath(path: string): any
  if isdirectory(path)
    return delete(path, 'd')
  else
    return Fcall('delete', path)
  endif
enddef

def DeleteError(file: string): string
  if empty(Fcall('getftype', file))
    return $'Could not find "{file}" on disk'
  else
    return $'Failed to delete "{file}"'
  endif
enddef

def Unlink(bang: bool)
  if !bang && &undoreload >= 0 && line('$') >= &undoreload
    echoerr "Buffer too big for 'undoreload' (add ! to override)"
  elseif DeletePath(@%)
    echoerr DeleteError(@%)
  else
    edit!
    execute('doautocmd <nomodeline> User FileUnlinkPost')
  endif
enddef

command! -bar -bang Unlink Unlink(<bang>0)
command! -bar -bang Remove Unlink(<bang>0)

def Delete(bang: string)
  if !bang && !(line('$') == 1 && empty(getline(1)) || Fcall('getftype', @%) !=# 'file')
    ErrMessage('File not empty (add ! to override)')
  else
    const file = expand('%:p')
    execute 'bdelete' .. bang
    if !bufloaded(file) && DeletePath(file)
      ErrMessage(DeleteError(file))
    endif
  endif
enddef

command! -bar -bang Delete Delete(<q-bang>)

def Rename(src: string, dst: string): number
  if src !~# '^\a\a\+:' && dst !~# '^\a\a\+:'
    return rename(src, dst)
  endif

  try
    const Fn = Ffn('writefile', dst)
    const copy = call(Fn, [Fcall('readfile', src, 'b'), dst])
    if copy == 0
      const delete = Fcall('delete', src)
      if delete == 0
        return 0
      else
        call Fcall('delete', dst)
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
  if file =~# slash_pat .. '$'
    file ..=  expand('%:t')
  elseif Fcall('isdirectory', file)
    file ..= Separator() .. expand('%:t')
  endif
  return substitute(file, '^\.' .. slash_pat, '', '')
enddef

def Copy(qargs: string, mods: string, bang: string)
  var dst = FileDest(qargs)
  call call('call', MkdirCallable(fnamemodify(dst, ':h')))
  dst = Fcall('simplify', dst)
  execute($'{expand(mods)} saveas{bang} {fnameescape(dst)}')
  filetype detect
enddef

command! -bar -nargs=1 -bang -complete=file Copy Copy(<q-args>, <q-mods>, <q-bang>)

def Move(qargs: string, bang: bool)
  var dst = FileDest(qargs)
  exe AbortOnError($'call call("call", MkdirCallable({string(fnamemodify(dst, ':h'))}))')
  dst = Fcall('simplify', dst)

  if !bang && Fcall('filereadable', dst)
    ErrMessage('File already exists (add ! to override)')
    return
    # const confirm = &confirm
    # try
    #   if confirm | set noconfirm | endif
    #   exe AbortOnError('keepalt saveas ' .. fnameescape(dst))
    # finally
    #   if confirm | set confirm | endif
    # endtry
  endif

  # TODO: fix when dst already exists
  const src = expand('%')
  if Fcall('filereadable', src) && Rename(src, dst)
    ErrMessage($'Failed to rename "{src}" to "{dst}"')
  else
    const last_bufnr = bufnr('$')
    exe AbortOnError('silent keepalt file ' .. fnameescape(dst))

    if bufnr('$') != last_bufnr
      exe $':{bufnr("$")} bwipe'
    endif

    setlocal modified
    write!
    filetype detect
  endif
enddef

command! -bar -nargs=1 -bang -complete=file Move Move(<q-args>, <bang>0)

# ~/f, $VAR/f, /f, C:/f, url://f, ./f, ../f
const absolute_pat = '^[~$]\|^' .. slash_pat .. '\|^\a\+:\|^\.\.\=\%(' .. slash_pat .. '\|$\)'

def RenameComplete(leading: string, _, _): list<string>
  const sep = Separator()
  const prefix = leading =~# absolute_pat ? '' : expand('%:h') .. sep
  var files = glob(prefix .. leading .. '*')
                ->split("\n")
                ->map((_, v) => fnameescape(strpart(v, len(prefix)) .. (isdirectory(v) ? sep : '')))
  return files
enddef

def RenameArg(arg: string): string
  if arg =~# absolute_pat
    return arg
  else
    return expand('%:h') .. '/' .. arg
  endif
enddef

command! -bar -nargs=1 -bang -complete=customlist,s:RenameComplete Duplicate Copy(escape(RenameArg(<q-args>), '"|'), <q-mods>, <q-bang>)
command! -bar -nargs=1 -bang -complete=customlist,s:RenameComplete Rename Move(escape(RenameArg(<q-args>), '"|'), <bang>0)

var find_path: string
def FindPath(): string
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
def Grep(qargs: string, prg: string, bang: bool, type: string = '')
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

command! -bang -complete=file -nargs=+ Cfind   Grep(<q-args>, FindPath(), <bang>0)
command! -bang -complete=file -nargs=+ Clocate Grep(<q-args>, 'locate', <bang>0)
command! -bang -complete=file -nargs=+ Lfind   Grep(<q-args>, FindPath(), <bang>0, 'l')
command! -bang -complete=file -nargs=+ Llocate Grep(<q-args>, 'locate', <bang>0, 'l')

# Sudo
def SilentSudoCmd(editor: string): list<string>
  const cmd = $'env SUDO_EDITOR={editor} VISUAL={editor} sudo -e'
  if !has('gui_running') || &guioptions =~# '!'
    redraw
    echo
    return ['silent', cmd]
  elseif !empty($SUDO_ASKPASS) ||
      filereadable('/etc/sudo.conf') &&
      !empty(readfile('/etc/sudo.conf', '', 50)->filter('v:val =~# "^Path askpass "'))
    return ['silent', $'{cmd} -A']
  else
    return ['', cmd]
  endif
enddef

augroup unix_sudo
augroup END

def SudoSetup(f: string, resolve_symlink: bool)
  var file = f
  if resolve_symlink && getftype(file) ==# 'link'
    file = resolve(file)
    if file !=# f
      silent keepalt exe 'file' fnameescape(file)
    endif
  endif

  file = substitute(file, slash_pat, '/', 'g')
  if file !~# '^\a\+:\|^/'
    file = substitute(getcwd(), slash_pat, '/', 'g') .. '/' .. file
  endif
  const escaped_file = fnameescape(file)
  if !filereadable(file) && !exists('#unix_sudo#BufReadCmd#' .. escaped_file)
    execute 'autocmd unix_sudo BufReadCmd ' escaped_file 'exe SudoReadCmd()'
  endif
  if !filewritable(file) && !exists('#unix_sudo#BufWriteCmd#' .. escaped_file)
    execute 'autocmd unix_sudo BufReadPost' escaped_file 'set noreadonly'
    execute 'autocmd unix_sudo BufWriteCmd' escaped_file 'exe SudoWriteCmd()'
  endif
enddef

const error_file = tempname()

def SudoError(): string
  const error = readfile(error_file)->join(" | ")
  if error =~# '^sudo' || !!v:shell_error
    return !empty(error) ? error : 'Error invoking sudo'
  else
    return error
  endif
enddef

def SudoReadCmd(): string
  if &shellpipe =~ '|&'
    return 'echoerr ' .. string('vim9-unix: no sudo read support for csh')
  endif

  deletebufline('%', 1, '$')
  silent doautocmd <nomodeline> BufReadPre
  const [silent, cmd] = SilentSudoCmd('cat')
  execute $'{silent} read !{cmd} "%" 2> {error_file}'

  const exit_status = v:shell_error
  deletebufline('%', 1)
  setlocal nomodified
  if exit_status
    return 'echoerr ' .. string(SudoError())
  else
    return 'silent doautocmd BufReadPost'
  endif
enddef

def SudoWriteCmd(): string
  silent doautocmd <nomodeline> BufWritePre
  const [silent, cmd] = SilentSudoCmd(shellescape('sh -c cat>"$0"'))
  execute $'{silent} write !{cmd} "%" 2> {error_file}'
  const error = SudoError()
  if !empty(error)
    return 'echoerr ' .. string(error)
  else
    setlocal nomodified
    return 'silent doautocmd <nomodeline> BufWritePost'
  endif
enddef

def SudoEdit(qargs: string, bang: bool)
  const arg = resolve(qargs)
  SudoSetup(fnamemodify(empty(arg) ? @% : arg, ':p'), empty(arg) && bang)
  if !&modified || !empty(arg) || bang
    const bang_str = bang ? '!' : ''
    exe $'edit{bang_str} {fnameescape(arg)}'
  endif
  if empty(qargs) || expand('%:p') ==# fnamemodify(arg, ':p')
    set noreadonly
  endif
enddef

def SudoWrite(bang: bool)
  SudoSetup(expand('%:p'), bang)
  setlocal noreadonly
  write!
enddef

command! -bar -bang -complete=file -nargs=? SudoEdit SudoEdit(<q-args>, <bang>0)
command! -bar -bang SudoWrite SudoWrite(<bang>0)

# vim:set sw=2 sts=2:
