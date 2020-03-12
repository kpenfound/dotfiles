call plug#begin('~/.vim/plugged')

Plug 'junegunn/vim-easy-align'
" Plug 'fatih/vim-go'
Plug 'scrooloose/nerdtree'

call plug#end()

set nocompatible
filetype off

set number
set ruler

syntax on

set noswapfile

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

