if exists('g:loaded_checkpatch_vim')
    finish
endif
let g:loaded_checkpatch_vim = 1

" optional user-specified fallback checkpatch
if !exists('g:user_checkpatch_path')
    let g:user_checkpatch_path = ''
endif

" extra user flags
if !exists('g:user_checkpatch_flags')
    let g:user_checkpatch_flags = ''
endif

command! -nargs=* CheckpatchFiles call checkpatch#run_checkpatch_files(<f-args>)
command! CheckpatchChanges call checkpatch#run_checkpatch_changes()
command! -nargs=? CheckpatchCommits call checkpatch#run_checkpatch_commits(<f-args>)
