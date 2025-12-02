# checkpatch.vim

A Vim plugin to run Linux checkpatch.pl (or compatible scripts) directly from Vim and display results in the Quickfix window.

## Configuration
``` vim
" Optional: specify custom checkpatch.pl if the project does not provide one
let g:user_checkpatch_path = '/path/to/other/project/scripts/checkpatch.pl'

" Optional: extra flags for checkpatch.pl
let g:checkpatch_user_flags = '--strict'
```
## Usage
### Run on current file or multiple files
``` vim
:CheckpatchFiles          " Run on current file
:CheckpatchFiles file1.c file2.c
```
### Run on staged & unstaged changes
``` vim
:CheckpatchChanges
```
### Run on git commits
``` vim
:CheckpatchCommits        " Run on HEAD
:CheckpatchCommits HEAD^
```
### Quickfix Navigation
- Quickfix will show merged messages in `filename|line number| type: message` format.
- Supports jump to the specific line by pressing Enter on a quickfix entry.
