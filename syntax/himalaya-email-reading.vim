if exists('b:current_syntax')
  finish
endif

runtime! syntax/mail.vim
syntax match himalayaEmailReadingHeader /<#part>/ nextgroup=himalayaEmailReadingHeader
syntax match himalayaEmailReadingHeaderNext /<#\/part>/ nextgroup=himalayaEmailReadingHeaderNext

highlight default link himalayaEmailReadingHeader Special
highlight default link himalayaEmailReadingHeaderNext Special


let b:current_syntax = 'himalaya-email-reading'
