vim9script

import '../../import/vim9_unix/utils.vim'

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

  if file !~# '^\a\+:\|^/'
    file = getcwd() .. '/' .. file
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

export def Edit(qargs: string, bang: bool)
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

export def Write(bang: bool)
  SudoSetup(expand('%:p'), bang)
  setlocal noreadonly
  write!
enddef

