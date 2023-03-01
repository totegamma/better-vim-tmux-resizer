" Maps <M-h/j/k/l> to resize vim splits in the given direction.
" If the movement operation has no effect in Vim, it forwards the operation to
" Tmux.

if exists("g:loaded_tmux_resizer") || &cp || v:version < 700
    finish
endif
let g:loaded_tmux_resizer = 1

if !exists("g:tmux_resizer_resize_count")
    let g:tmux_resizer_resize_count = 5
endif

if !exists("g:tmux_resizer_vertical_resize_count")
    let g:tmux_resizer_vertical_resize_count = 10
endif

if !exists("g:tmux_resizer_no_mappings")
    nnoremap <silent> <M-h> :TmuxResizeLeft<CR>
    nnoremap <silent> <M-j> :TmuxResizeDown<CR>
    nnoremap <silent> <M-k> :TmuxResizeUp<CR>
    nnoremap <silent> <M-l> :TmuxResizeRight<CR>
endif

function! s:VimResize(direction, opposite)
    " Resize Vim window toward given direction, like tmux
    let l:current_window_is_last_window = xor((winnr() == winnr('$')), a:opposite)
    if (a:direction == 'h' || a:direction == 'k')
        let l:modifier = l:current_window_is_last_window ? '+' : '-'
    else
        let l:modifier = l:current_window_is_last_window ? '-' : '+'
    endif

    if (a:direction == 'h' || a:direction == 'l')
        let l:command = 'vertical resize'
        let l:window_resize_count = g:tmux_resizer_vertical_resize_count
    else
        let l:command = 'resize'
        let l:window_resize_count = g:tmux_resizer_resize_count
    endif

    execute l:command . ' ' . l:modifier . l:window_resize_count . '<CR>'
endfunction

if empty($TMUX)
    command! TmuxResizeLeft call s:VimResize('h')
    command! TmuxResizeDown call s:VimResize('j')
    command! TmuxResizeUp call s:VimResize('k')
    command! TmuxResizeRight call s:VimResize('l')
    finish
endif

command! TmuxResizeLeft call s:TmuxAwareResize('h')
command! TmuxResizeDown call s:TmuxAwareResize('j')
command! TmuxResizeUp call s:TmuxAwareResize('k')
command! TmuxResizeRight call s:TmuxAwareResize('l')

function! s:TmuxOrTmateExecutable()
    return (match($TMUX, 'tmate') != -1 ? 'tmate' : 'tmux')
endfunction

function! s:TmuxSocket()
    " The socket path is the first value in the comma-separated list of $TMUX.
    return split($TMUX, ',')[0]
endfunction

function! s:TmuxCommand(args)
    let cmd = s:TmuxOrTmateExecutable() . ' -S ' . s:TmuxSocket() . ' ' . a:args
    return system(cmd)
endfunction

function! s:NeedsVitalityRedraw()
    return exists('g:loaded_vitality') && v:version < 704 && !has("patch481")
endfunction

function! s:TmuxAwareResize(direction)
    let info = getwininfo(win_getid())
    let leftmost = info[0].wincol
    let topmost = info[0].winrow
    let width  = info[0].width
    let height = info[0].height
    let winbar = info[0].winbar

    let screenwidth = &columns
    let screenheight = &lines

    let left = leftmost
    let top = topmost-1
    let right = leftmost+width-1
    let bot = topmost+height+winbar+1

    let isLeftMost = (left == 1)
    let isBottomMost = (bot == screenheight)
    let isTopMost = (top == 1)
    let isRightMost = (right == screenwidth)

    let isMotionX = (a:direction == 'h' || a:direction == 'l')
    let isMotionY = (a:direction == 'j' || a:direction == 'k')

    if (
       \ (
         \ isMotionX
         \ && ((isLeftMost && isRightMost)
         \ || (isRightMost && (system("tmux display-message -p '#{pane_at_right}'") == 0)))
       \ )
       \ ||
       \ (
         \ isMotionY
         \ && ((isTopMost && isBottomMost)
         \ || (isBottomMost && (system("tmux display-message -p '#{pane_at_bottom}'") == 0)))
       \ )
    \  ) " tmux側をリサイズする条件

        let l:resize_count = isMotionX ? g:tmux_resizer_vertical_resize_count : g:tmux_resizer_resize_count
        let args = 'resize-pane -' . tr(a:direction, 'hjkl', 'LDUR') . ' ' . l:resize_count

        silent call s:TmuxCommand(args)

        if s:NeedsVitalityRedraw()
            redraw!
        endif
    else
        call s:VimResize(a:direction, (isMotionX && !isLeftMost && !isBottomMost) || (isMotionY && !isRightMost && !isTopMost))
    endif
endfunction

