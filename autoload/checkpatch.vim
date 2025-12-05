function! s:checkpatch_quickfix_fmt(info) abort
    let l:qflist = getqflist({'id' : a:info.id, 'items' : 1}).items
    let l:result = []

    for l:i in l:qflist
        let l:line = ''
        if l:i.valid == 0
            let l:line = printf('|| %s', l:i.text)
        else
            let l:i.filename = bufname(l:i.bufnr)
            let l:line = printf('%s %s|%d| %s', l:i.type, l:i.filename, l:i.lnum, l:i.text)
        endif
        call add(l:result, l:line)
    endfor

    return l:result
endfunction

function! s:parse_checkpatch_output(lines, info) abort
    let l:pattern = '\v^(.+):(\d+):\s*(ERROR|WARNING|CHECK):\s*(.*)$'
    let l:out = []

    for l:line in a:lines
        if empty(trim(l:line))
            continue
        endif

        if l:line =~# l:pattern
            let l:match = matchlist(l:line, l:pattern)
            let l:type = ''
            if l:match[3] ==# 'ERROR'
                let l:type = 'E'
                let a:info.e_cnt += 1
            elseif l:match[3] ==# 'WARNING'
                let l:type = 'W'
                let a:info.w_cnt += 1
            elseif l:match[3] ==# 'CHECK'
                let l:type = 'C'
                let a:info.c_cnt += 1
            endif
            call add(l:out, {
                        \ 'filename': l:match[1],
                        \ 'lnum': l:match[2],
                        \ 'type': l:type,
                        \ 'text': l:match[4],
                        \ 'valid': 1
                        \ })

        else
            call add(l:out, {
                        \ 'text': l:line,
                        \ 'valid': 0
                        \ })
        endif

        call add(l:out, l:line)
    endfor

    return l:out
endfunction

" ---------------------------
" Run checkpatch
" ---------------------------
function! s:run_checkpatch(info, type, input) abort
    if empty(a:input)
        echoerr "checkpatch: no input specified"
        return []
    endif

    let l:flags = ['--showfile', '--quiet', '--no-summary']

    " Add user flags if any
    if !empty(g:user_checkpatch_flags)
        let l:flags += split(g:user_checkpatch_flags)
    endif

    " basic flags
    if a:type ==# 'file'
        call add(l:flags, '--file')
    elseif a:type ==# 'git'
        call add(l:flags, '--git')
    else
        call add(l:flags, '--patch')
    endif

    if a:type ==# 'stdin'
        let l:full_cmd = [a:info.cp] + l:flags
        let l:out = systemlist(join(l:full_cmd, ' '), a:input)
    else
        let l:full_cmd = [a:info.cp] + l:flags + [a:input]
        let l:out = systemlist(join(l:full_cmd, ' '))
    endif

    let l:out = s:parse_checkpatch_output(l:out, a:info)
    call setqflist([], 'a', {'id': a:info.qfid, 'items': l:out})

    return
endfunction

" ---------------------------
" Get the path to checkpatch.pl
" ---------------------------
function! s:resolve_checkpatch_path() abort
    " use project's checkpatch.pl by default
    let l:cp = trim(system('git ls-files *checkpatch.pl'))
    if !empty(l:cp)
        return fnamemodify(expand(l:cp), ':p')
    endif

    if !empty(g:user_checkpatch_path) && filereadable(g:user_checkpatch_path)
        return fnamemodify(expand(g:user_checkpatch_path), ':p')
    endif

    echoerr "checkpatch.vim: cannot find checkpatch.pl, please set g:user_checkpatch_path"
    return
endfunction

function! s:checkpatch_prepare() abort
    let l:info = {}

    call setqflist([], ' ', {'quickfixtextfunc': 's:checkpatch_quickfix_fmt'})
    let l:info.qfid = getqflist({'id': 0}).id
    let l:info.cp = s:resolve_checkpatch_path()
    let l:info.e_cnt = 0
    let l:info.w_cnt = 0
    let l:info.c_cnt = 0

    return l:info
endfunction

function! s:checkpatch_show(info) abort
    let l:cnt = "checkpatch.vim: " .
                \ a:info.e_cnt . " errors, " .
                \ a:info.w_cnt . " warnings, " .
                \ a:info.c_cnt . " checks"

    echo l:cnt
    if len(getqflist({'id': a:info.qfid, 'items': 1}).items) == 0
        return
    endif

    call setqflist([], 'a', {'id': a:info.qfid, 'title': l:cnt})
    execute 'cclose'
    let l:qfh = float2nr(winheight(0) * 0.25)
    if l:qfh < 10
        let l:qfh = 10
    endif
    execute 'botright copen' l:qfh

    highlight CheckPatchError ctermfg=red ctermbg=none cterm=bold
    highlight CheckPatchWarn ctermfg=yellow ctermbg=none cterm=bold
    highlight CheckPatchCheck ctermfg=green ctermbg=none cterm=bold

    call matchadd('CheckPatchError', '^E\s')
    call matchadd('CheckPatchWarn', '^W\s')
    call matchadd('CheckPatchCheck', '^C\s')
endfunction

" ---------------------------
" Run checkpatch on one or multiple files/patches
" ---------------------------
function! checkpatch#run_checkpatch_files(...) abort
    let l:info = s:checkpatch_prepare()

    if a:0 == 0
        let l:files = [expand('%:p')]
    else
        let l:files = a:000
    endif

    for l:f in l:files
        if l:f =~# '\v\.(patch|diff)$'
            let l:type = 'patch'
        else
            let l:type = 'file'
        endif

        call s:run_checkpatch(l:info, l:type, l:f)
    endfor

    call s:checkpatch_show(l:info)
endfunction

" ---------------------------
" Run checkpatch on modified/staged changes
" ---------------------------
function! checkpatch#run_checkpatch_changes() abort
    let l:info = s:checkpatch_prepare()

    call system('git add -N .')
    let l:staged   = system('git diff --cached')
    let l:unstaged = system('git diff')

    let l:diff_patch = l:staged . l:unstaged

    if empty(l:diff_patch)
        echo "checkpatch: no changes to check"
        return
    endif

    call s:run_checkpatch(l:info, 'stdin', l:diff_patch)
    call s:checkpatch_show(l:info)
endfunction

" ---------------------------
" Run checkpatch on commits
" ---------------------------
function! checkpatch#run_checkpatch_commits(...) abort
    let l:info = s:checkpatch_prepare()

    let l:range = (a:0 > 0 && !empty(a:1)) ? a:1 : 'HEAD'

    call s:run_checkpatch(l:info, 'git', l:range)
    call s:checkpatch_show(l:info)
endfunction
