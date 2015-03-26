" Vim plugin file
" Purpose:	Create a template for new bb files
" Author:	Ricardo Salveti <rsalveti@gmail.com>
" Copyright:	Copyright (C) 2008 Ricardo Salveti <rsalveti@gmail.com>
"
" This file is licensed under the MIT license, see COPYING.MIT in
" this source distribution for the terms.
"
" Based on the gentoo-syntax package
"
" Will try to use git to find the user name and email

if &compatible || v:version < 600
    finish
endif

fun! <SID>GetUserName()
    let l:user_name = system("git config --get user.name")
    if v:shell_error
        return "Unknow User"
    else
        return substitute(l:user_name, "\n", "", "")
endfun

fun! <SID>GetUserEmail()
    let l:user_email = system("git config --get user.email")
    if v:shell_error
        return "unknow@user.org"
    else
        return substitute(l:user_email, "\n", "", "")
endfun

fun! BBHeader()
    let l:current_year = strftime("%Y")
    let l:user_name = <SID>GetUserName()
    let l:user_email = <SID>GetUserEmail()
    0 put ='# Copyright (C) ' . l:current_year .
                \ ' ' . l:user_name . ' <' . l:user_email . '>'
    put ='# Released under the MIT license (see COPYING.MIT for the terms)'
    $
endfun

fun! NewBBTemplate()
    let l:paste = &paste
    set nopaste
    
    " Get the header
    call BBHeader()

    " New the bb template
    put ='DESCRIPTION = \"\"'
    put ='HOMEPAGE = \"\"'
    put ='LICENSE = \"\"' 
    put ='SECTION = \"\"'
    put ='DEPENDS = \"\"'
    put =''
    put ='SRC_URI = \"\"'

    " Go to the first place to edit
    0
    /^DESCRIPTION =/
    exec "normal 2f\""

    if paste == 1
        set paste
    endif
endfun

if !exists("g:bb_create_on_empty")
    let g:bb_create_on_empty = 1
endif

" disable in case of vimdiff
if v:progname =~ "vimdiff"
    let g:bb_create_on_empty = 0
endif

augroup NewBB
    au BufNewFile *.bb
                \ if g:bb_create_on_empty |
                \    call NewBBTemplate() |
                \ endif
augroup END

" s:Complete, s:runtime_globpath, and s:find are from tpope/scriptease and
" modified for use with $BBLAYERS
function! s:Complete(A,L,P)
  let sep = !exists("+shellslash") || &shellslash ? '/' : '\'
  let pattern = substitute(a:A,'/\|\'.sep,'*'.sep,'g').'*'
  let found = {}
  for glob in split($BBLAYERS, ' ')
    for path in map(split(glob(glob.sep.'recipes*'), "\n"), 'fnamemodify(v:val, ":p")')
      let matches = split(glob(path.sep.pattern),"\n")
      call map(matches,'isdirectory(v:val) ? v:val.sep : v:val')
      call map(matches,'fnamemodify(v:val, ":p")[strlen(path)+1:-1]')
      for match in matches
        let found[match] = 1
      endfor
    endfor
  endfor
  return sort(keys(found))
endfunction

function! s:runtime_globpath(file)
  let sep = !exists("+shellslash") || &shellslash ? '/' : '\'
  let sep .= 'recipes*'
  return split(globpath(join(split($BBLAYERS, ' '), sep.',').sep, a:file), "\n")
endfunction

function! s:find(count,cmd,file,lcd)
  let found = s:runtime_globpath(a:file)
  echo found
  let file = get(found, a:count - 1, '')
  if file ==# ''
    return "echoerr 'E345: Can''t find file \"".a:file."\" in $BBLAYERS'"
  elseif a:cmd ==# 'read'
    return a:cmd.' '.s:fnameescape(file)
  elseif a:lcd
    let path = file[0:-strlen(a:file)-2]
    return a:cmd.' '.s:fnameescape(file) . '|lcd '.s:fnameescape(path)
  else
    let window = 0
    let precmd = ''
    let postcmd = ''
    if a:cmd =~# '^pedit'
      try
        exe 'silent ' . a:cmd
      catch /^Vim\%((\a\+)\)\=:E32/
      endtry
      let window = s:previewwindow()
      let precmd = printf('%d wincmd w|', window)
      let postcmd = '|wincmd w'
    elseif a:cmd !~# '^edit'
      exe a:cmd
    endif
    call setloclist(window, map(found,
          \ '{"filename": v:val, "text": v:val[0 : -len(a:file)-2]}'))
    return precmd . 'll'.matchstr(a:cmd, '!$').' '.a:count . postcmd
  endif
endfunction

command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBe
      \ :execute s:find(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBedit
      \ :execute s:find(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBopen
      \ :execute s:find(<count>,'edit<bang>',<q-args>,1)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBsplit
      \ :execute s:find(<count>,'split',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBvsplit
      \ :execute s:find(<count>,'vsplit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBtabedit
      \ :execute s:find(<count>,'tabedit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBpedit
      \ :execute s:find(<count>,'pedit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete BBread
      \ :execute s:find(<count>,'read',<q-args>,<bang>0)
