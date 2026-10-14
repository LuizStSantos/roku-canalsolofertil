' Uma linha da grade: cabeçalho de dia, programa ou programa selecionado (expandido)
sub init()
  m.bg = m.top.findNode("bg")
  m.bar = m.top.findNode("bar")
  m.hdr = m.top.findNode("hdr")
  m.time = m.top.findNode("time")
  m.nowBg = m.top.findNode("nowBg")
  m.title = m.top.findNode("title")
  m.thumb = m.top.findNode("thumb")
  m.desc = m.top.findNode("desc")
  m.meta = m.top.findNode("meta")
  m.hdr.font = "font:SmallestBoldSystemFont"
  m.top.findNode("nowLbl").font = "font:SmallestBoldSystemFont"
  m.desc.font = "font:SmallestSystemFont"
  m.meta.font = "font:SmallestSystemFont"
end sub

sub layout()
  d = m.top.rowData
  if d = invalid then return

  if d.kind = "hdr"
    m.hdr.text = d.label
    m.hdr.visible = true
    m.bg.visible = false
    m.bar.visible = false
    m.time.visible = false
    m.title.visible = false
    m.nowBg.visible = false
    m.thumb.visible = false
    m.desc.visible = false
    m.meta.visible = false
    return
  end if

  f = m.top.focused
  m.hdr.visible = false
  m.time.visible = true
  m.title.visible = true
  m.bg.visible = f
  m.bar.visible = f

  m.time.text = d.time
  m.title.text = d.title
  if f
    m.time.font = "font:SmallestBoldSystemFont"
    m.time.color = "0xFFC300FF"
    m.title.font = "font:SmallestBoldSystemFont"
  else
    m.time.font = "font:SmallestSystemFont"
    m.time.color = "0xFFFFFFA6"
    m.title.font = "font:SmallestSystemFont"
  end if

  tx = 102
  m.nowBg.visible = d.isNow
  if d.isNow then tx = 186
  m.title.translation = [tx, 7]
  m.title.width = 552 - tx

  m.thumb.visible = f
  m.desc.visible = f
  m.meta.visible = f
  if f
    m.thumb.uri = d.icon
    m.desc.text = d.desc
    m.meta.text = d.meta
  end if
end sub
