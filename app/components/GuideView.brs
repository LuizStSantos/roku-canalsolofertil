' Painel lateral da programação: dias agrupados, programa selecionado expandido
sub init()
  m.AREA_H = 540
  m.H_HDR = 34
  m.H_ROW = 42
  m.H_SEL = 160

  m.top.findNode("gTitle").font = "font:LargeBoldSystemFont"
  m.top.findNode("gSub").font = "font:SmallestSystemFont"
  m.top.findNode("f1").font = "font:SmallestSystemFont"
  m.top.findNode("f2").font = "font:SmallestSystemFont"

  m.rows = []
  m.focus = -1
  m.first = 0
  m.pool = []
  list = m.top.findNode("list")
  for i = 0 to 13
    r = CreateObject("roSGNode", "GuideRow")
    r.visible = false
    list.appendChild(r)
    m.pool.Push(r)
  end for
end sub

sub onSub()
  m.top.findNode("gSub").text = m.top.subtitle
end sub

sub onRows()
  m.rows = m.top.rows
  m.focus = -1
  m.first = 0
  for i = 0 to m.rows.Count() - 1
    if m.rows[i].kind = "prog"
      m.focus = i
      exit for
    end if
  end for
  render()
end sub

function rowHeight(i as integer) as integer
  if m.rows[i].kind = "hdr" then return m.H_HDR
  if i = m.focus then return m.H_SEL
  return m.H_ROW
end function

sub ensureVisible()
  if m.focus < 0 then return
  if m.focus < m.first
    m.first = m.focus
    if m.first > 0
      if m.rows[m.first - 1].kind = "hdr" then m.first = m.first - 1
    end if
  end if
  while m.first < m.focus
    total = 0
    for i = m.first to m.focus
      total = total + rowHeight(i)
    end for
    if total <= m.AREA_H then exit while
    m.first = m.first + 1
  end while
end sub

sub render()
  ensureVisible()
  y = 0
  n = m.rows.Count()
  for s = 0 to m.pool.Count() - 1
    r = m.pool[s]
    idx = m.first + s
    if idx < n
      h = rowHeight(idx)
      if y + h <= m.AREA_H
        r.translation = [0, y]
        r.rowData = m.rows[idx]
        r.focused = (idx = m.focus)
        r.visible = true
        y = y + h
      else
        r.visible = false
      end if
    else
      r.visible = false
    end if
  end for
end sub

sub moveFocus(dir as integer)
  j = m.focus + dir
  while j >= 0 and j < m.rows.Count()
    if m.rows[j].kind = "prog" then exit while
    j = j + dir
  end while
  if j >= 0 and j < m.rows.Count()
    m.focus = j
    render()
  end if
end sub

function handleKey(key as string) as boolean
  if key = "up"
    moveFocus(-1)
    return true
  else if key = "down"
    moveFocus(1)
    return true
  else if key = "fastforward"
    for i = 1 to 5
      moveFocus(1)
    end for
    return true
  else if key = "rewind"
    for i = 1 to 5
      moveFocus(-1)
    end for
    return true
  else if key = "OK" or key = "back" or key = "left" or key = "right"
    m.top.closeRequested = true
    return true
  else if key = "play"
    m.top.togglePause = true
    return true
  end if
  return false
end function
