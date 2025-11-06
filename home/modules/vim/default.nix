{
  config,
  pkgs,
  ...
}: {
  programs.vim = {
    enable = true;
    defaultEditor = true;
    plugins = with pkgs.vimPlugins; [
      ale
      delimitMate
      editorconfig-vim
      fzf-vim
      jq-vim
      papercolor-theme
      vim-airline
      vim-airline-themes
      vim-commentary
      vim-easy-align
      vim-fugitive
      vim-gitgutter
      vim-indent-guides
      vim-lastplace
      vim-repeat
      vim-rhubarb # required by vim-fugitive
      vim-surround
      vim-unimpaired
    ];

    settings = {
      ignorecase = true;
      smartcase = true;
      tabstop = 4;
      shiftwidth = 4;
      expandtab = true;

      hidden = true;
      number = true;
      mouse = "a";
      mousemodel = "popup";
      modeline = true;

      background = "dark";
    };

    extraConfig = ''
      " disable blinking cursor
      set gcr=a:blinkon0
      let mapleader=','
      set hlsearch
      set fileformats=unix,dos,mac

      set signcolumn=yes

      colorscheme PaperColor

      let g:indent_guides_enable_on_vim_startup = 1
      let g:indent_guides_guide_size = 1

      autocmd FileType markdown setlocal spell
      autocmd FileType gitcommit setlocal spell

      xmap ga <Plug>(EasyAlign)
      nmap ga <Plug>(EasyAlign)

      nnoremap n nzzzv
      nnoremap N Nzzzv

      if exists("*fugitive#statusline")
        set statusline+=%{fugitive#statusline()}
      endif

      nnoremap <silent> <leader>sh :terminal<CR>

      "" Abbreviations
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

      " Mappings

      " Split
      noremap <Leader>h :<C-u>split<CR>
      noremap <Leader>v :<C-u>vsplit<CR>

      " Git
      noremap <Leader>ga :Gwrite<CR>
      noremap <Leader>gc :Git commit --verbose<CR>
      noremap <Leader>gs :Git<CR>
      noremap <Leader>gb :Git blame<CR>
      noremap <Leader>gr :GRemove<CR>

      " fzf
      set wildmode=list:longest,list:full
      nnoremap <silent> <leader>e :FZF -m<CR>
      command! FilesTab call fzf#run({'source': fzf#vim#with_preview()['source'], 'sink': 'tabedit'})
      nnoremap <leader>te :FilesTab<CR>

      nnoremap <Tab> gt
      nnoremap <S-Tab> gT
      nnoremap <silent> <S-t> :tabnew<CR>

      noremap YY "+y<CR>
      noremap <Leader>p "+gP<CR>
      noremap XX "+x<CR>

      " clean search (highlight)
      nnoremap <silent> <Leader><space> :noh<CR>

      " switching windows
      noremap <C-j> <C-w>j
      noremap <C-k> <C-w>k
      noremap <C-l> <C-w>l
      noremap <C-h> <C-w>h
    '';
  };
}
