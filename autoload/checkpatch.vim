" ---------------------------
" Show lines in quickfix
" ---------------------------
function! s:merge_checkpatch_output(lines) abort
    let l:merged = []
    let l:insert = 0

    for l:line in a:lines
        if empty(trim(l:line))
            let l:insert = 0
        elseif l:line =~# '^\(\S\+\)\?:\d\+: \(ERROR\|WARNING\|CHECK\):'
            call add(l:merged, l:line)
            let l:insert = 1
        elseif l:insert == 1
            call add(l:merged, l:line)
        endif
    endfor

    return l:merged
endfunction

function! s:show_in_quickfix(lines) abort
    let l:merged = s:merge_checkpatch_output(a:lines)
    if empty(l:merged)
        echo "checkpatch: no messages"
        return
    endif

    call setqflist([], 'r', {'lines': l:merged})
    let l:qfh = float2nr(winheight(0) * 0.25)
    execute 'copen' l:qfh
endfunction

" ---------------------------
" Run checkpatch
" ---------------------------
function! s:run_checkpatch(cp, type, input) abort
    if empty(a:input)
        echoerr "checkpatch: no input specified"
        return []
    endif

    let l:flags = ['--showfile']

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
        let l:full_cmd = [a:cp] + l:flags
        let l:out = systemlist(join(l:full_cmd, ' '), a:input)
    else
        let l:full_cmd = [a:cp] + l:flags + [a:input]
        let l:out = systemlist(join(l:full_cmd, ' '))
    endif

    if empty(l:out)
        echo "checkpatch: no messages"
    endif

    return l:out
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
    return ''

endfunction

" ---------------------------
" Run checkpatch on one or multiple files/patches
" ---------------------------
function! checkpatch#run_checkpatch_files(...) abort
    let l:cp = s:resolve_checkpatch_path()
    if empty(l:cp)
        return
    endif

    if a:0 == 0
        let l:files = [expand('%:p')]
    else
        let l:files = a:000
    endif

    let l:all_out = []

    for l:f in l:files
        if l:f =~# '\v\.(patch|diff)$'
            let l:type = 'patch'
        else
            let l:type = 'file'
        endif

        let l:out = s:run_checkpatch(l:cp, l:type, l:f)
        call extend(l:all_out, l:out)
    endfor

    call s:show_in_quickfix(l:all_out)
endfunction

" ---------------------------
" Run checkpatch on modified/staged changes
" ---------------------------
function! checkpatch#run_checkpatch_changes() abort
    let l:cp = s:resolve_checkpatch_path()
    if empty(l:cp)
        return
    endif

    call system('git add -N .')
    let l:staged   = system('git diff --cached')
    let l:unstaged = system('git diff')

    let l:diff_patch = l:staged . "\n" . l:unstaged

    if empty(l:diff_patch)
        echo "checkpatch: no changes to check"
        return
    endif

    let l:out = s:run_checkpatch(l:cp, 'stdin', l:diff_patch)
    call s:show_in_quickfix(l:out)
endfunction

" ---------------------------
" Run checkpatch on commits
" ---------------------------
function! checkpatch#run_checkpatch_commits(...) abort
    let l:cp = s:resolve_checkpatch_path()
    if empty(l:cp)
        return
    endif

    let l:range = (a:0 > 0 && !empty(a:1)) ? a:1 : 'HEAD'

    let l:out = s:run_checkpatch(l:cp, 'git', l:range)
    call s:show_in_quickfix(l:out)
endfunction
