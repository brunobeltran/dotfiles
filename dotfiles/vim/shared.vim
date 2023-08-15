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
" => VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Turn on the WiLd menu
set wildmenu

" Ignore compiled files
set wildignore=*.o,*~,*.pyc
if has("win16") || has("win32")
    set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store
else
    set wildignore+=.git\*,.hg\*,.svn\*
endif

" have the wildmenu emulate terminal tab completion
set wildmode=list:longest

"Always show current position
set ruler

" Height of the command bar
set cmdheight=2

" A buffer becomes hidden when it is abandoned
set hidden

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch


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

" Toggle paste mode on and off
map <leader>P :setlocal paste!<cr>

" so tired of accidentally ending up in record mode
nnoremap q: :q
" and of accidentally putting capital letters for commands...
command! Q q



