"==================================================
" File:         echofunc.vim
" Brief:        Echo the function declaration in
"               the command line for C/C++.
" Author:       Mingbai <mbbill AT gmail DOT com>
" Last Change:  2007-10-16 23:19:10
" Version:      1.9
"
" Install:      1. Put echofunc.vim to /plugin directory.
"               2. Use the command below to create tags
"                  file including signature field.
"                  ctags --fields=+S .
"
" Usage:        When you type '(' after a function name
"               in insert mode, the function declaration
"               will be displayed in the command line
"               automatically. Then use alt+-, alt+= to
"               cycle between function declarations (if exists).
" Options:      g:EchoFuncTagsLanguages
"               File types to enable echofunc. Example:
"               let g:EchoFuncTagsLanguages = ["java","cpp"]
"
" Thanks:       edyfox
"               Wu YongWei
"
"==================================================

" Vim version 7.x is needed.
if v:version < 700
     echohl ErrorMsg | echomsg "Echofunc.vim needs vim version >= 7.0!" | echohl None
     finish
endif

let s:res=[]
let s:count=1

function! s:EchoFuncDisplay()
    if len(s:res) == 0
        return
    endif
    set noshowmode
    let content=substitute(s:res[s:count-1],'^\s*','','')
    let wincols=&columns
    let allowedheight=&lines/5
    let statusline=(&laststatus==1 && winnr('$')>1) || (&laststatus==2)
    let reqspaces_lastline=(statusline || !&ruler) ? 12 : 29
    let width=len(content)
    let height=width/wincols+1
    let cols_lastline=width%wincols
    if cols_lastline > wincols-reqspaces_lastline
        let height=height+1
    endif
    if height > allowedheight
        let height=allowedheight
    endif
    let &cmdheight=height
    echohl Type | echo content | echohl None
endfunction

function! s:GetFunctions(fun, fn_only)
    let s:res=[]
    let ftags=taglist('^'.escape(a:fun,'[\*~^').'$')
    if (type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[]))
"        \ && a:fn_only
        return
    endif
    let fil_tag=[]
    for i in ftags
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            if (i.kind=='p' || i.kind=='f' || a:fn_only == 0) && i.name==a:fun " p is declare, f is defination
                let fil_tag+=[i]
            endif
        else
            if a:fn_only == 0 && i.name == a:fun
                let fil_tag+=[i]
            endif
        endif
    endfor
    if fil_tag==[]
        return
    endif
    let s:count=1
    for i in fil_tag
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            let tmppat=escape(i.name,'[\*~^')
            let tmppat=substitute(tmppat,'\<operator ','operator\\s*','')
            let tmppat=substitute(tmppat,'^\(.*::\)','\\(\1,\\)\\?','')
            let tmppat=tmppat.'.*'
            let name=substitute(i.cmd[2:],tmppat,'','').i.name.i.signature
        else
            let name=i.name
        endif
        let s:res+=[name.' ('.(index(fil_tag,i)+1).'/'.len(fil_tag).') '.i.filename]
    endfor
endfunction

function! s:GetFuncName(text)
    let name=substitute(a:text,'.\{-}\(\(\k\+::\)*\(\~\?\k*\|'.
                \'operator\s\+new\(\[]\)\?\|'.
                \'operator\s\+delete\(\[]\)\?\|'.
                \'operator\s*[[\]()+\-*/%<>=!~\^&|]\+'.
                \'\)\)\s*$','\1','')
    if name =~ '\<operator\>'  " tags have exactly one space after 'operator'
        let name=substitute(name,'\<operator\s*','operator ','')
    endif
    return name
endfunction

function! EchoFunc()
    let name=s:GetFuncName(getline('.')[:(col('.')-3)])
    if name==''
        return ''
    endif
    call s:GetFunctions(name, 1)
    call s:EchoFuncDisplay()
    return ''
endfunction

function! EchoFuncN()
    if s:res==[]
        return ''
    endif
    if s:count==len(s:res)
        let s:count=1
    else
        let s:count+=1
    endif
    call s:EchoFuncDisplay()
    return ''
endfunction

function! EchoFuncP()
    if s:res==[]
        return ''
    endif
    if s:count==1
        let s:count=len(s:res)
    else
        let s:count-=1
    endif
    call s:EchoFuncDisplay()
    return ''
endfunction

function! EchoFuncStart()
    if exists('b:EchoFuncStarted')
        return
    endif
    let b:EchoFuncStarted=1
    let s:ShowMode=&showmode
    let s:CmdHeight=&cmdheight
    inoremap    <silent>    <buffer>    (       (<c-r>=EchoFunc()<cr>
    inoremap    <silent>    <buffer>    )       )<c-o>:echo<cr>
    inoremap    <silent>    <buffer>    <m-=>   <c-r>=EchoFuncN()<cr>
    inoremap    <silent>    <buffer>    <m-->   <c-r>=EchoFuncP()<cr>
endfunction

function! EchoFuncStop()
    if !exists('b:EchoFuncStarted')
        return
    endif
    iunmap      <buffer>    (
    iunmap      <buffer>    )
    iunmap      <buffer>    <m-=>
    iunmap      <buffer>    <m-->
    unlet b:EchoFuncStarted
endfunction

function! s:RestoreSettings()
    if !exists('b:EchoFuncStarted')
        return
    endif
    if s:ShowMode
        set showmode
    endif
    exec "set cmdheight=".s:CmdHeight
    echo
endfunction

function! BalloonDeclaration()
    let line=getline(v:beval_lnum)
    let pos=v:beval_col - 1
    let endpos=match(line, '\W', pos)
    if endpos != -1
        if v:beval_text == 'operator'
            if line[endpos :] =~ '^\s*\(new\(\[]\)\?\|delete\(\[]\)\?\|[[\]+\-*/%<>=!~\^&|]\+\|()\)'
                let endpos=matchend(line, '^\s*\(new\(\[]\)\?\|delete\(\[]\)\?\|[[\]+\-*/%<>=!~\^&|]\+\|()\)',endpos)
            endif
        elseif v:beval_text == 'new' || v:beval_text == 'delete'
            if line[:endpos+1] =~ 'operator\s\+\(new\|delete\)\[]$'
                let endpos=endpos+2
            endif
        endif
    endif
    if (endpos != -1)
        let endpos=endpos - 1
    endif
    let name=s:GetFuncName(line[0:endpos])
    if name==''
        return ''
    endif
    call s:GetFunctions(name, 0)
    let result = ""
    for item in s:res
        let result = result . item . "\n"
    endfor
    return strpart(result, 0, len(result) - 1)
endfunction

function! BalloonDeclarationStart()
    set ballooneval
    set balloonexpr=BalloonDeclaration()
endfunction

function! BalloonDeclarationStop()
    set balloonexpr=
    set noballooneval
endfunction

if !exists("g:EchoFuncTagsLanguages")
    let g:EchoFuncTagsLanguages=[
                \ "asm",
                \ "aspvbs",
                \ "awk",
                \ "c",
                \ "cpp",
                \ "cs",
                \ "cobol",
                \ "eiffel",
                \ "erlang",
                \ "fortran",
                \ "html",
                \ "java",
                \ "javascript",
                \ "lisp",
                \ "lua",
                \ "make",
                \ "pascal",
                \ "perl",
                \ "php",
                \ "plsql",
                \ "python",
                \ "rexx",
                \ "ruby",
                \ "scheme",
                \ "sh",
                \ "zsh",
                \ "slang",
                \ "sml",
                \ "tcl",
                \ "vera",
                \ "verilog",
                \ "vim",
                \ "yacc"]
endif

function! s:CheckTagsLanguage(filetype)
    return count(g:EchoFuncTagsLanguages, a:filetype)
endfunction

function! CheckedEchoFuncStart()
    if s:CheckTagsLanguage(&filetype)
        call EchoFuncStart()
    endif
endfunction

function! CheckedBalloonDeclarationStart()
    if s:CheckTagsLanguage(&filetype)
        call BalloonDeclarationStart()
    endif
endfunction

function! s:EchoFuncInitialize()
    augroup EchoFunc
        autocmd!
        autocmd InsertLeave * call s:RestoreSettings()
        autocmd BufRead,BufNewFile * call CheckedEchoFuncStart()
        if has('gui_running')
            menu    &Tools.Echo\ F&unction.Echo\ F&unction\ Start   :call EchoFuncStart()<CR>
            menu    &Tools.Echo\ F&unction.Echo\ Function\ Sto&p    :call EchoFuncStop()<CR>
        endif

        if has("balloon_eval")
            autocmd BufRead,BufNewFile * call CheckedBalloonDeclarationStart()
            if has('gui_running')
                menu    &Tools.Echo\ Function.&Balloon\ Declaration\ Start  :call BalloonDeclarationStart()<CR>
                menu    &Tools.Echo\ Function.Balloon\ Declaration\ &Stop   :call BalloonDeclarationStop()<CR>
            endif
        endif
    augroup END

    call CheckedEchoFuncStart()
    if has("balloon_eval")
        call CheckedBalloonDeclarationStart()
    endif
endfunction

augroup EchoFunc
    autocmd BufRead,BufNewFile * call s:EchoFuncInitialize()
augroup END

" vim: set et sts=4 sw=4:
