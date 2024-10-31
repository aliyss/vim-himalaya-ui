# vim-himalaya-ui

Simple UI for [himalaya](https://github.com/pimalaya/himalaya).
It allows simple navigation through mail accounts and allows for reading and writing email.

Tested on Linux and Neovim.

Features:
* Navigate through multiple accounts and it's folders and emails

## Disclaimer
The idea is to have a similar interface to [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), but for email.
Which is why I decided to fork it and modify it to the needs of himalaya.
This is a work in progress and it's not ready for use. Pull requests are extremely welcome.

This is my first vim plugin, so I'm learning as I go.

## Installation

No clue. I'm still working on this.

After configuring your mail account, run `:HIMALAYAUI`, which should open up a drawer with all mail accounts provided.
When you finish writing an email, just write the file (`:w`) and it will automatically prompt to send or save as draft.

## Actions

### Drawer
- [ ] Create a new email
- [x] List folders in an account
- [x] List emails in a folder

### List
- [x] Navigate Next & Previous Pages (Enter, n, p)
- [x] Read an email in the list view (Enter)
- [x] Refresh list of emails (r)
- [x] Reply to an email in the list view (R)
- [x] Forward an email in the list view (F)
- [x] Delete an email in the list view (dd)
- [ ] Delete multiple emails in the list view

### Mail
- [x] Reply to the email in the mail view (R)
- [x] Forward the email in the mail view (F)
- [x] Delete the email in the mail view (D)
- [ ] Add attachment to the email in the mail view


## Future

Fix multiple issues and implement more features.

### Roadmap

#### Mail List View (aka $ list mails)
Uses the current window where in dadbod you write the query, but instead lists all the emails.

_Actions (based on keybindings and hovered_over):_
- Reply (Mail Create View)
- Reply all (Mail Create View)
- Forward (Mail Create View)
- Download Attachments
- Open externally...
- Delete
- Move to... (Telescope integration?)
- Enter: shows Mail in the dadbod result window (Mail Display View)

#### Mail Display View
Displays Mail as text. Toggable to HTML view which shows raw html.

_Actions:_
- same as in List View
- View as HTML/Text
- (when hovered_on Thread expand...)

#### Mail Create View (aka $ create mail)
Pre-filled based on context. Should actually already work easily as himalaya provides most of this.

_Actions_
- Send
- Save as draft
- Add Attachment
- Discard

--- 

Afaik that should be all of the main stuff.

---

_Hard stuff not provided by Himalaya:_
- Enhanced Mail View in the future with lynx browser integration possibly.
- Images maybe with sixel. No clue. I actually don't mind reading Email in text only.
- Querying using something like notmuch

