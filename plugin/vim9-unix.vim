vim9script noclear

if exists(':SudoWrite') == 2 || has('win32')
  finish
endif
g:loaded_vim9_unix = 1

import autoload '../autoload/vim9_unix/dir.vim'
import autoload '../autoload/vim9_unix/file.vim'
import autoload '../autoload/vim9_unix/find.vim'
import autoload '../autoload/vim9_unix/sudo.vim'

# Dir
command! -bar -bang -nargs=? -complete=dir Mkdir dir.Create(<q-args>)

# File
command! -bar -bang Remove file.Unlink(<bang>0)
command! -bar -bang Delete file.Delete(<q-bang>)
command! -bar -nargs=1 -bang -complete=file Move file.Move(<q-args>, <bang>0)
command! -bar -nargs=1 -bang -complete=file Copy file.Copy(<q-args>, <q-mods>, <q-bang>)
command! -bar -nargs=1 -bang -complete=customlist,file.Complete Rename file.Move(escape(file.RenameArg(<q-args>), '"|'), <bang>0)
command! -bar -nargs=1 -bang -complete=customlist,file.Complete Duplicate file.Copy(escape(file.RenameArg(<q-args>), '"|'), <q-mods>, <q-bang>)

# Find
command! -bang -complete=file -nargs=+ Cfind   find.Grep(<q-args>, 'find', <bang>0)
command! -bang -complete=file -nargs=+ Lfind   find.Grep(<q-args>, 'find', <bang>0, 'l')
command! -bang -complete=file -nargs=+ Clocate find.Grep(<q-args>, 'locate', <bang>0)
command! -bang -complete=file -nargs=+ Llocate find.Grep(<q-args>, 'locate', <bang>0, 'l')

# Sudo
command! -bar -bang SudoWrite sudo.Write(<bang>0)
command! -bar -bang -complete=file -nargs=? SudoEdit sudo.Edit(<q-args>, <bang>0)

# vim:set sw=2 sts=2:
