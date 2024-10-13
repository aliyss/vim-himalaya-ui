let s:himalayaui_instance = {}
let s:himalayaui = {}

function! himalaya_ui#open(mods) abort
  call s:init()
  return s:himalayaui_instance.drawer.open(a:mods)
endfunction

function! himalaya_ui#toggle() abort
  call s:init()
  return s:himalayaui_instance.drawer.toggle()
endfunction

function! himalaya_ui#close() abort
  call s:init()
  return s:himalayaui_instance.drawer.quit()
endfunction

function! himalaya_ui#save_himalayaout(file) abort
  call s:init()
  return s:himalayaui_instance.save_himalayaout(a:file)
endfunction

function! himalaya_ui#connections_list() abort
  call s:init()
  return map(copy(s:himalayaui_instance.himalayas_list), {_,v-> {
        \ 'name': v.name,
        \ 'url': v.url,
        \ 'is_connected': !empty(s:himalayaui_instance.himalayas[v.key_name].conn),
        \ 'source': v.source,
        \ }})
endfunction

function! himalaya_ui#find_buffer() abort
  call s:init()
  if !len(s:himalayaui_instance.himalayas_list)
    return himalaya_ui#notifications#error('No database entries found in HIMALAYAUI.')
  endif

  if !exists('b:himalayaui_himalaya_key_name')
    let saved_query_himalaya = s:himalayaui_instance.drawer.get_query().get_saved_query_himalaya_name()
    let himalaya = s:get_himalaya(saved_query_himalaya)
    if empty(himalaya)
      return himalaya_ui#notifications#error('No database entries selected or found.')
    endif
    call s:himalayaui_instance.connect(himalaya)
    call himalaya_ui#notifications#info('Assigned buffer to himalaya '.himalaya.name, {'delay': 10000 })
    let b:himalayaui_himalaya_key_name = himalaya.key_name
    let b:himalaya = himalaya.conn
  endif

  if !exists('b:himalayaui_himalaya_key_name')
    return himalaya_ui#notifications#error('Unable to find in HIMALAYAUI. Not a valid himalayaui query buffer.')
  endif

  let himalaya = b:himalayaui_himalaya_key_name
  let bufname = bufname('%')

  call s:himalayaui_instance.drawer.get_query().setup_buffer(s:himalayaui_instance.himalayas[himalaya], { 'existing_buffer': 1 }, bufname, 0)
  if exists('*vim_dahimalayaod_completion#fetch')
    call vim_dahimalayaod_completion#fetch(bufnr(''))
  endif
  let s:himalayaui_instance.himalayas[himalaya].expanded = 1
  let s:himalayaui_instance.himalayas[himalaya].buffers.expanded = 1
  call s:himalayaui_instance.drawer.open()
  let row = 1
  for line in s:himalayaui_instance.drawer.content
    if line.himalayaui_himalaya_key_name ==? himalaya && line.type ==? 'buffer' && line.file_path ==? bufname
      break
    endif
    let row += 1
  endfor
  call cursor(row, 0)
  call s:himalayaui_instance.drawer.render({ 'himalaya_key_name': himalaya, 'queries': 1 })
  wincmd p
endfunction

function! himalaya_ui#rename_buffer() abort
  call s:init()
  return s:himalayaui_instance.drawer.rename_buffer(bufname('%'), get(b:, 'himalayaui_himalaya_key_name'), 0)
endfunction

function! himalaya_ui#get_conn_info(himalaya_key_name) abort
  if empty(s:himalayaui_instance)
    return {}
  endif
  if !has_key(s:himalayaui_instance.himalayas, a:himalaya_key_name)
    return {}
  endif
  let himalaya = s:himalayaui_instance.himalayas[a:himalaya_key_name]
  call s:himalayaui_instance.connect(himalaya)
  return {
        \ 'url': himalaya.url,
        \ 'conn': himalaya.conn,
        \ 'tables': himalaya.tables.list,
        \ 'schemas': himalaya.schemas.list,
        \ 'scheme': himalaya.scheme,
        \ 'connected': !empty(himalaya.conn),
        \ }
endfunction

function! himalaya_ui#query(query) abort
  if empty(b:himalaya)
    throw 'Cannot find valid connection for a buffer.'
  endif

  let parsed = himalaya#url#parse(b:himalaya)
  let scheme = himalaya_ui#schemas#get(parsed.scheme)
  if empty(scheme)
    throw 'Unsupported scheme '.parsed.scheme
  endif

  let result = himalaya_ui#schemas#query(b:himalaya, scheme, a:query)

  return scheme.parse_results(result, 0)
endfunction

function! himalaya_ui#print_last_query_info() abort
  call s:init()
  let info = s:himalayaui_instance.drawer.get_query().get_last_query_info()
  if empty(info.last_query)
    return himalaya_ui#notifications#info('No queries ran.')
  endif

  let content = ['Last query:'] + info.last_query
  let content += ['' + 'Time: '.info.last_query_time.' sec.']

  return himalaya_ui#notifications#info(content, {'echo': 1})
endfunction

function! himalaya_ui#statusline(...)
  let himalaya_key_name = get(b:, 'himalayaui_himalaya_key_name', '')
  let himalayaout = get(b:, 'himalaya', '')
  if empty(s:himalayaui_instance) || (&filetype !=? 'himalayaout' && empty(himalaya_key_name))
    return ''
  end
  if &filetype ==? 'himalayaout'
    let last_query_info = s:himalayaui_instance.drawer.get_query().get_last_query_info()
    let last_query_time = last_query_info.last_query_time
    if !empty(last_query_time)
      return 'Last query time: '.last_query_time.' sec.'
    endif
    return ''
  endif
  let opts = get(a:, 1, {})
  let prefix = get(opts, 'prefix', 'HIMALAYAUI: ')
  let separator = get(opts, 'separator', ' -> ')
  let show = get(opts, 'show', ['himalaya_name', 'schema', 'table'])
  let himalaya_table = get(b:, 'himalayaui_table_name', '')
  let himalaya_schema = get(b:, 'himalayaui_schema_name', '')
  let himalaya = s:himalayaui_instance.himalayas[himalaya_key_name]
  let data = { 'himalaya_name': himalaya.name, 'schema': himalaya_schema, 'table': himalaya_table }
  let content = []
  for item in show
    let entry = get(data, item, '')
    if !empty(entry)
      call add(content, entry)
    endif
  endfor
  return prefix.join(content, separator)
endfunction

function! s:himalayaui.new() abort
  let instance = copy(self)
  let instance.himalayas = {}
  let instance.himalayas_list = []
  let instance.save_path = ''
  let instance.connections_path = ''
  let instance.tmp_location = ''
  let instance.drawer = {}
  let instance.old_buffers = []
  let instance.himalayaout_list = {}

  if !empty(g:himalaya_ui_save_location)
    let instance.save_path = substitute(fnamemodify(g:himalaya_ui_save_location, ':p'), '\/$', '', '')
    let instance.connections_path = printf('%s/%s', instance.save_path, 'connections.json')
  endif

  if !empty(g:himalaya_ui_tmp_query_location)
    let tmp_loc = substitute(fnamemodify(g:himalaya_ui_tmp_query_location, ':p'), '\/$', '', '')
    if !isdirectory(tmp_loc)
      call mkdir(tmp_loc, 'p')
    endif
    let instance.tmp_location = tmp_loc
    let instance.old_buffers = glob(tmp_loc.'/*', 1, 1)
  endif

  call instance.populate_himalayas()
  let instance.drawer = himalaya_ui#drawer#new(instance)
  return instance
endfunction

function! s:himalayaui.save_himalayaout(file) abort
  let himalaya_input = ''
  let content = ''
  if has_key(self.himalayaout_list, a:file) && !empty(self.himalayaout_list[a:file])
    return
  endif
  let himalaya_input = get(getbufvar(a:file, 'himalaya', {}), 'input')
  if !empty(himalaya_input) && filereadable(himalaya_input)
    let content = get(readfile(himalaya_input, 1), 0)
    if len(content) > 30
      let content = printf('%s...', content[0:30])
    endif
  endif
  let self.himalayaout_list[a:file] = content
  call self.drawer.render()
endfunction

function! s:himalayaui.populate_himalayas() abort
  let self.himalayas_list = []
  call self.populate_from_dotenv()
  call self.populate_from_env()
  call self.populate_from_global_variable()
  call self.populate_from_himalaya()

  for himalaya in self.himalayas_list
    let key_name = printf('%s_%s', himalaya.name, himalaya.backend)
    if !has_key(self.himalayas, key_name) || himalaya.backend !=? self.himalayas[key_name].backend
      let new_entry = self.generate_new_himalaya_entry(himalaya)
      if !empty(new_entry)
        let self.himalayas[key_name] = new_entry
      endif
    else
      let self.himalayas[key_name] = self.drawer.populate(self.himalayas[key_name])
    endif
  endfor
endfunction

function! s:himalayaui.generate_new_himalaya_entry(himalaya) abort
  let himalaya = {
        \ 'backend': a:himalaya.backend,
        \ 'conn': '',
        \ 'conn_error': '',
        \ 'conn_tried': 0,
        \ 'source': a:himalaya.backend,
        \ 'scheme': '',
        \ 'table_helpers': {},
        \ 'expanded': 0,
        \ 'tables': {'expanded': 0 , 'items': {}, 'list': [] },
        \ 'schemas': {'expanded': 0, 'items': {}, 'list': [] },
        \ 'saved_queries': { 'expanded': 0, 'list': [] },
        \ 'buffers': { 'expanded': 0, 'list': [], 'tmp': [] },
        \ 'save_path': "",
        \ 'himalaya_name': a:himalaya.name,
        \ 'name': a:himalaya.name,
        \ 'key_name': printf('%s_%s', a:himalaya.name, a:himalaya.backend),
        \ 'schema_support': 0,
        \ 'quote': 0,
        \ 'default_scheme': '',
        \ 'filetype': ''
        \ }

  " call self.populate_schema_info(himalaya)
  return himalaya
endfunction

function! s:himalayaui.resolve_url_global_variable(Value) abort
  if type(a:Value) ==? type('')
    return a:Value
  endif

  if type(a:Value) ==? type(function('tr'))
    return call(a:Value, [])
  endif

  " if type(a:Value) ==? type(v:t_func)
  " endif
  "
  " echom string(type(a:Value))
  " echom string(a:Value)
  "
  throw 'Invalid type global variable database url:'..type(a:Value)
endfunction

function! s:himalayaui.populate_from_global_variable() abort
  if exists('g:himalaya') && !empty(g:himalaya)
    let url = self.resolve_url_global_variable(g:himalaya)
    let ghimalaya_name = split(url, '/')[-1]
    call self.add_if_not_exists(ghimalaya_name, url, 'g:himalayas')
  endif

  if !exists('g:himalayas') || empty(g:himalayas)
    return self
  endif

  if type(g:himalayas) ==? type({})
    for [himalaya_name, Db_url] in items(g:himalayas)
      call self.add_if_not_exists(himalaya_name, self.resolve_url_global_variable(Db_url), 'g:himalayas')
    endfor
    return self
  endif

  for himalaya in g:himalayas
    call self.add_if_not_exists(himalaya.name, self.resolve_url_global_variable(himalaya.url), 'g:himalayas')
  endfor

  return self
endfunction

function! s:himalayaui.populate_from_dotenv() abort
  let prefix = g:himalaya_ui_dotenv_variable_prefix
  let all_envs = {}
  if exists('*environ')
    let all_envs = environ()
  else
    for item in systemlist('env')
      let env = split(item, '=')
      if len(env) > 1
        let all_envs[env[0]] = join(env[1:], '')
      endif
    endfor
  endif
  let all_envs = extend(all_envs, exists('*DotenvGet') ? DotenvGet() : {})
  for [name, url] in items(all_envs)
    if stridx(name, prefix) != -1
      let himalaya_name = tolower(join(split(name, prefix)))
      call self.add_if_not_exists(himalaya_name, url, 'dotenv')
    endif
  endfor
endfunction

function! s:himalayaui.env(var) abort
  return exists('*DotenvGet') ? DotenvGet(a:var) : eval('$'.a:var)
endfunction

function! s:himalayaui.populate_from_env() abort
  let env_url = self.env(g:himalaya_ui_env_variable_url)
  if empty(env_url)
    return self
  endif
  let env_name = self.env(g:himalaya_ui_env_variable_name)
  if empty(env_name)
    let env_name = get(split(env_url, '/'), -1, '')
  endif

  if empty(env_name)
    return himalaya_ui#notifications#error(
          \ printf('Found %s variable for himalaya url, but unable to parse the name. Please provide name via %s', g:himalaya_ui_env_variable_url, g:himalaya_ui_env_variable_name))
  endif

  call self.add_if_not_exists(env_name, env_url, 'env')
  return self
endfunction

function! s:himalayaui.parse_url(url) abort
  try
    return himalaya#url#parse(a:url)
  catch /.*/
    call himalaya_ui#notifications#error(v:exception)
    return {}
  endtry
endfunction

function! s:himalayaui.populate_from_himalaya() abort

  let accounts = himalaya_ui#utils#request_json_sync({
  \ 'cmd': 'account list',
  \ 'args': [],
  \ 'msg': 'Listing accounts...',
  \})

  for account in accounts
    call self.add_if_not_exists(account.name, account.backend, account.default)
  endfor

  echom self
  return self
endfunction

function! s:himalayaui.add_if_not_exists(name, backend, default) abort
  let existing = get(filter(copy(self.himalayas_list), 'v:val.name ==? a:name && v:val.backend ==? a:backend'), 0, {})
  if !empty(existing)
    return himalaya_ui#notifications#warning(printf('Warning: Duplicate connection name "%s" in "%s" backend. First one added has precedence.', a:name, a:backend))
  endif
  return add(self.himalayas_list, {
        \ 'name': a:name, 'backend': a:backend, 'default': a:default, 'key_name': printf('%s_%s', a:name, a:backend)
        \ })
endfunction

function! s:himalayaui.is_tmp_location_buffer(himalaya, buf) abort
  if index(a:himalaya.buffers.tmp, a:buf) > -1
    return 1
  endif
  return !empty(self.tmp_location) && a:buf =~? '^'.self.tmp_location
endfunction

function! s:himalayaui.connect(himalaya) abort
  if !empty(a:himalaya.conn)
    return a:himalaya
  endif

  try
    let query_time = reltime()
    call himalaya_ui#notifications#info('Connecting to himalaya '.a:himalaya.name.'...')
    let a:himalaya.conn = himalaya#connect(a:himalaya.url)
    let a:himalaya.conn_error = ''
    call self.populate_schema_info(a:himalaya)
    call himalaya_ui#notifications#info('Connected to himalaya '.a:himalaya.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  catch /.*/
    let a:himalaya.conn_error = v:exception
    let a:himalaya.conn = ''
    call himalaya_ui#notifications#error('Error connecting to himalaya '.a:himalaya.name.': '.v:exception, {'width': 80 })
  endtry

  redraw!
  let a:himalaya.conn_tried = 1
  return a:himalaya
endfunction

function! s:himalayaui.populate_schema_info(himalaya) abort
  let url = !empty(a:himalaya.conn) ? a:himalaya.conn : a:himalaya.url
  let parsed_url = self.parse_url(url)
  let scheme = get(parsed_url, 'scheme', '')
  let scheme_info = himalaya_ui#schemas#get(scheme)
  let a:himalaya.scheme = scheme
  let a:himalaya.table_helpers = himalaya_ui#table_helpers#get(scheme)
  let a:himalaya.schema_support = himalaya_ui#schemas#supports_schemes(scheme_info, parsed_url)
  let a:himalaya.quote = get(scheme_info, 'quote', 0)
  let a:himalaya.default_scheme = get(scheme_info, 'default_scheme', '')
  let a:himalaya.filetype = get(scheme_info, 'filetype', himalaya#adapter#call(url, 'input_extension', [], 'sql'))
  " Properly map mongohimalaya js to javascript
  if a:himalaya.filetype ==? 'js'
    let a:himalaya.filetype = 'javascript'
  endif
endfunction

" Resolve only urls for HIMALAYAs that are files
function himalaya_ui#resolve(url) abort
  let parsed_url = himalaya#url#parse(a:url)
  let resolve_schemes = ['sqlite', 'jq', 'duckhimalaya', 'osquery']

  if index(resolve_schemes, get(parsed_url, 'scheme', '')) > -1
    return himalaya#resolve(a:url)
  endif

  return a:url
endfunction

function! himalaya_ui#reset_state() abort
  let s:himalayaui_instance = {}
endfunction

function! s:init() abort
  if empty(s:himalayaui_instance)
    let s:himalayaui_instance = s:himalayaui.new()
  endif

  return s:himalayaui_instance
endfunction

function! s:get_himalaya(saved_query_himalaya) abort
  if !len(s:himalayaui_instance.himalayas_list)
    return {}
  endif

  if !empty(a:saved_query_himalaya)
    let saved_himalaya = get(filter(copy(s:himalayaui_instance.himalayas_list), 'v:val.name ==? a:saved_query_himalaya'), 0, {})
    if empty(saved_himalaya)
      return {}
    endif
    return s:himalayaui_instance.himalayas[saved_himalaya.key_name]
  endif

  if len(s:himalayaui_instance.himalayas_list) ==? 1
    return values(s:himalayaui_instance.himalayas)[0]
  endif

  let options = map(copy(s:himalayaui_instance.himalayas_list), '(v:key + 1).") ".v:val.name')
  let selection = himalaya_ui#utils#inputlist(['Select himalaya to assign this buffer to:'] + options)
  if selection < 1 || selection > len(options)
    call himalaya_ui#notifications#error('Wrong selection.')
    return {}
  endif
  let selected_himalaya = s:himalayaui_instance.himalayas_list[selection - 1]
  let selected_himalaya = s:himalayaui_instance.himalayas[selected_himalaya.key_name]
  return selected_himalaya
endfunction
