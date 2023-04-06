" don't load hikeeper more than once
if exists('g:hikeeper_loaded')
  finish
endif

let g:hikeeper_loaded = 1

let g:nvim_hl_methods_available = has('nvim') && has('nvim-0.5.1')

let s:cache = {}

function! s:get_inherited_attrs(group) abort
  if has_key(s:cache, a:group)
    return s:cache[a:group]
  endif

  let attrs = []
  redir => output
  silent! execute 'highlight ' . a:group
  redir END
  for line in split(output, "\n")
    if line =~ '\<\S\+=\S\+\>'
      call add(attrs, substitute(line, '^.*xxx ', '', 'g'))
    endif

    if line =~ '^.*link.*$'
      let link_group = substitute(line, '^.*links to ', '', '')
      call add(attrs, s:get_inherited_attrs(link_group))
    endif
  endfor

  let s:cache[a:group] = trim(join(attrs))
  return s:cache[a:group]
endfunction

function! s:vim_set_highlight()
  let groups = get(g:, "hikeeper_vim_groups", {})
  for group in keys(groups)
    let attrs = ''
    if has_key(s:cache, group)
      let attrs = s:cache[group]
    else
      let attrs = s:get_inherited_attrs(group)
    endif

    let properties = []
    for prop in keys(groups[group])
      call add(properties, prop.'='.groups[group][prop])
    endfor

    let newAttrs = join(properties, ' ')
    execute "highlight" group attrs newAttrs
  endfor

endfunction

function! s:nvim_set_highlight()
  let groups = get(g:, "hikeeper_nvim_groups", {})
  for group in keys(groups)
    let attrs = {}
    if !has_key(s:cache, group)
      let attrs = nvim_get_hl_by_name(group, 1)
    endif

    call extend(attrs,groups[group])
    let s:cache[group] = attrs
    call nvim_set_hl(0,group, attrs )
  endfor
endfunction

function! s:apply_hikeeper() abort
  if g:nvim_hl_methods_available
    call s:nvim_set_highlight()
  else
    call s:vim_set_highlight()
  endif

  let s:cache = {}
endfunction

" apply hikeeper at startup unless g:hikeeper_apply_at_startup is 0
let apply_at_startup = get(g:, "hikeeper_apply_at_startup", 1)
if apply_at_startup 
  function! s:hikeeper_augroup() abort
    augroup hikeeper
      autocmd!
      autocmd colorscheme * :call <SID>apply_hikeeper()
    augroup END
  endfunction
  call s:hikeeper_augroup()
endif

" define :hikeeperApply to apply hikeeper manually
command! -bar HikeeperApply :call <SID>apply_hikeeper()
