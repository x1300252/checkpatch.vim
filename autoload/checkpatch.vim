function! s:merge_checkpatch_output(lines) abort
    let l:merged = []

    for l:line in a:lines
        if empty(trim(l:line))
            continue
        endif

        call add(l:merged, l:line)
    endfor

    return l:merged
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

    let l:merged = s:merge_checkpatch_output(l:out)
    call setqflist([], 'a', {'id': a:info.qfid, 'lines': l:merged})

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

    call setqflist([], ' ')
    let l:info.qfid = getqflist({'id': 0}).id
    let l:info.cp = s:resolve_checkpatch_path()

    return l:info
endfunction

function! s:checkpatch_show() abort
    execute 'cclose'
    let l:qfh = float2nr(winheight(0) * 0.25)
    execute 'botright copen' l:qfh
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

    call s:checkpatch_show()
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
    call s:checkpatch_show()
endfunction

" ---------------------------
" Run checkpatch on commits
" ---------------------------
function! checkpatch#run_checkpatch_commits(...) abort
    let l:info = s:checkpatch_prepare()

    let l:range = (a:0 > 0 && !empty(a:1)) ? a:1 : 'HEAD'

    call s:run_checkpatch(l:info, 'git', l:range)
    call s:checkpatch_show()
endfunction
