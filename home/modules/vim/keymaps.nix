# Vim keymaps and plugin configuration
{...}: {
  programs.vim.extraConfig = ''
    " General settings
    set gcr=a:blinkon0
    let mapleader=','
    set hlsearch
    set fileformats=unix,dos,mac
    set signcolumn=yes

    " Theme
    colorscheme PaperColor

    " Indent guides
    let g:indent_guides_enable_on_vim_startup = 1
    let g:indent_guides_guide_size = 1

    " Spelling for prose
    autocmd FileType markdown setlocal spell
    autocmd FileType gitcommit setlocal spell

    " EasyAlign
    xmap ga <Plug>(EasyAlign)
    nmap ga <Plug>(EasyAlign)

    " Center search results
    nnoremap n nzzzv
    nnoremap N Nzzzv

    " Terminal
    nnoremap <silent> <leader>sh :terminal<CR>

    " Command abbreviations (typo fixes)
    cnoreabbrev W! w!
    cnoreabbrev Q! q!
    cnoreabbrev Qall! qall!
    cnoreabbrev Wq wq
    cnoreabbrev Wa wa
    cnoreabbrev wQ wq
    cnoreabbrev WQ wq
    cnoreabbrev W w
    cnoreabbrev Q q
    cnoreabbrev Qall qall

    " Splits
    noremap <Leader>h :<C-u>split<CR>
    noremap <Leader>v :<C-u>vsplit<CR>

    " FZF
    set wildmode=list:longest,list:full
    nnoremap <silent> <leader>e :FZF -m<CR>
    command! FilesTab call fzf#run({'source': fzf#vim#with_preview()['source'], 'sink': 'tabedit'})
    nnoremap <leader>te :FilesTab<CR>

    " Tabs
    nnoremap <Tab> gt
    nnoremap <S-Tab> gT
    nnoremap <silent> <S-t> :tabnew<CR>

    " Clipboard
    noremap YY "+y<CR>
    noremap <Leader>p "+gP<CR>
    noremap XX "+x<CR>

    " Clear search highlight
    nnoremap <silent> <Leader><space> :noh<CR>

    " Window navigation
    noremap <C-j> <C-w>j
    noremap <C-k> <C-w>k
    noremap <C-l> <C-w>l
    noremap <C-h> <C-w>h

    " Nix formatting
    noremap <silent> <Leader>af :%!alejandra -qq<CR>

    " NERDTree
    let g:NERDTreeChDirMode=2
    let g:NERDTreeIgnore=['\~$']
    let g:NERDTreeSortOrder=[]
    let g:NERDTreeShowBookmarks=1
    let g:NERDTreeWinSize=50
    set wildignore+=*/tmp/*,*.swp
    nnoremap <silent> <F2> :NERDTreeFind<CR>
    nnoremap <silent> <F3> :NERDTreeToggle<CR>
  '';
}
