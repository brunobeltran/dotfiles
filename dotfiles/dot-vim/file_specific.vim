augroup filespecificconfig

"{{{ => Terraform-specific
au BufNewFile,BufRead *.tf set tabstop=2
au BufNewFile,BufRead *.tf set softtabstop=2
au BufNewFile,BufRead *.tf set shiftwidth=2
"}}}

"{{{ => TeX specific

" this makeprg should execute pdflatex,bibtex,pdflatex,pdflatex on the current
" file, unless bibtex fails, in which case it will simply execute two pdflatex's
" in a row
au FileType tex set makeprg=pdflatex\ %:r\ &&\ bibtex\ %:r\ &&\ pdflatex\ %:r\ &&\ pdflatex\ %:r\ &&\ pdflatex\ %:r\ \\\|\\\|\ pdflatex\ %:r
"}}}

"{{{ => Python specific

" " get virtualenv support
" if has('python')
" py << EOF
" import os.path
" import sys
" if 'VIRTUAL_ENV' in os.environ:
"     project_base_dir = os.environ['VIRTUAL_ENV']
"     sys.path.insert(0, project_base_dir)
"     execfile('/home/bbeltr1/.vim/venv_activate.py', dict(venv_directory=project_base_dir))
" EOF
" endif

" Good default fold positions
"autocmd BufWinEnter *.py setlocal foldexpr=SimpylFold(v:lnum) foldmethod=expr
"autocmd BufWinLeave *.py setlocal foldexpr< foldmethod<

"}}}

"{{{ => C++ specific
augroup cpp_settings
    autocmd!
    autocmd FileType cpp setlocal shiftwidth=2 tabstop=2 expandtab softtabstop=2 smarttab
    autocmd FileType cpp setlocal cinoptions=:0,l1,t0 textwidth=100 colorcolumn=+1
    autocmd FileType cpp setlocal formatoptions=croql comments=://,s1:/*,mb:*,ex:*/
augroup END
"}}}

"{{{ => Web specific
"
au BufNewFile,BufRead *.js,*.html,*.css,*.vue set tabstop=2
au BufNewFile,BufRead *.js,*.html,*.css,*.vue set softtabstop=2
au BufNewFile,BufRead *.js,*.html,*.css,*.vue set shiftwidth=2
au BufNewFile,BufReadPost *.md set filetype=markdown
let g:markdown_fenced_languages = ['html', 'python', 'bash=sh']

"}}}

"{{{ => org-mode specific
au BufNewFile,BufRead *.org set textwidth=0
" automatically commit and rsync up/down on read/write of shared org files
au BufReadPost /home/bbeltr1/developer/org-mode-notes/*.org OrgSafelyPullRemoteChanges
au BufWritePost /home/bbeltr1/developer/org-mode-notes/*.org OrgUnSafelyPushChangesToRemote
"}}}

"{{{ => vimrc specific
au FileType vim set foldmethod=marker
"}}}
"

augroup END

" Highlight fortran source in modern style
let fortran_free_source=1
let fortran_have_tabs=1
let fortran_more_precise=1
let fortran_do_enddo=1
