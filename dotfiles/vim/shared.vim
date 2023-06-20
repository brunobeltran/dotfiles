"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use spaces instead of tabs
set expandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4
set softtabstop=4
set shiftround
set autoindent

set linebreak
set textwidth=80

set si " Smart indent
set wrap " Wrap lines


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Netrw settings (Vim's built-in file manager)
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_list_hide= '.*\.swp$,.*\.pyc$,^\./$,^\.\./$'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Close the current buffer
map <leader>bx :Bclose<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Treat long lines as break lines (useful when moving around in them)
map j gj
map k gk

" readline-style motion in command/insert modes
cnoremap <C-A> <Home>
cnoremap <C-E> <End>
cnoremap <C-K> <C-U>
cnoremap <C-N> <Down>
cnoremap <C-P> <Up>
cnoremap <C-D> <Right><Backspace>
cnoremap <C-F> <Right>
cnoremap <C-B> <Left>
inoremap <C-D> <Right><Backspace>
inoremap <C-F> <Right>
inoremap <C-B> <Left>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Delete trailing white space on save, useful for Python and CoffeeScript ;)
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc

" catchall cleanup
nnoremap <leader><cr> <C-c>:noh<cr>:redraw!<cr>:call DeleteTrailingWS()<cr>:w<cr>:edit<cr>
nnoremap <leader><leader><cr> <C-c>:noh<cr>:redraw!<cr>:%s/\t/    /g<cr>:w<cr>:edit<cr>
