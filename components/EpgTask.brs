' ============================================================
'  Baixa e interpreta o guia de programação (XMLTV)
'  1) devolve na hora a cópia guardada (abre mais rápido)
'  2) baixa a versão nova, guarda a cópia e devolve de novo
' ============================================================
sub init()
  m.top.functionName = "fetchEpg"
end sub

sub fetchEpg()
  cachePath = "cachefs:/epg_cache.xml"

  ' 1) cópia guardada
  cached = ReadAsciiFile(cachePath)
  if cached <> ""
    items = parseXmltv(cached)
    if items.Count() > 0 then m.top.result = { ok: true, cached: true, items: items }
  end if

  ' 2) versão nova (parâmetro t evita resposta antiga de cache)
  req = CreateObject("roUrlTransfer")
  req.SetUrl(m.top.url + "?t=" + CreateObject("roDateTime").AsSeconds().ToStr())
  req.SetCertificatesFile("common:/certs/ca-bundle.crt")
  req.AddHeader("X-Roku-Reserved-Dev-Id", "")
  req.EnableEncodings(true)

  text = req.GetToString()
  out = { ok: false, cached: false, items: [] }
  if text <> ""
    out.items = parseXmltv(text)
    out.ok = (out.items.Count() > 0)
    if out.ok then WriteAsciiFile(cachePath, text)
  end if

  m.top.result = out
end sub

' Lê o XMLTV: título, descrição, categoria, classificação e imagem.
' Guarda de 6 h atrás até 4 dias à frente, em ordem de horário.
function parseXmltv(text as string) as object
  items = []

  ' remove a linha <!DOCTYPE ...> para o parser não tropeçar
  re = CreateObject("roRegex", "<!DOCTYPE[^>]*>", "i")
  text = re.ReplaceAll(text, "")

  xml = CreateObject("roXMLElement")
  if not xml.Parse(text) then return items

  nowSec = CreateObject("roDateTime").AsSeconds()
  minStop = nowSec - 6 * 3600
  maxStart = nowSec + 4 * 86400

  progs = xml.GetNamedElements("programme")
  for each p in progs
    attrs = p.GetAttributes()
    startStr = attrs["start"]
    stopStr = attrs["stop"]

    if startStr <> invalid
      if stopStr <> invalid
        startSec = xmltvToEpoch(startStr)
        stopSec = xmltvToEpoch(stopStr)

        if stopSec > startSec and stopSec > minStop and startSec < maxStart
          item = { startSec: startSec, stopSec: stopSec, title: "", desc: "", icon: "", category: "", rating: "" }

          kids = p.GetChildElements()
          if kids <> invalid
            for each k in kids
              n = k.GetName()
              if n = "title"
                if item.title = "" then item.title = k.GetText()
              else if n = "desc"
                if item.desc = "" then item.desc = k.GetText()
              else if n = "category"
                if item.category = "" then item.category = k.GetText()
              else if n = "rating"
                if item.rating = ""
                  vals = k.GetNamedElements("value")
                  if vals <> invalid
                    if vals.Count() > 0 then item.rating = vals[0].GetText()
                  end if
                end if
              else if n = "icon"
                if item.icon = ""
                  ia = k.GetAttributes()
                  if ia <> invalid
                    if ia["src"] <> invalid then item.icon = ia["src"]
                  end if
                end if
              end if
            end for
          end if

          items.Push(item)
        end if
      end if
    end if
  end for

  items.SortBy("startSec")

  ' se um programa invade o próximo, encerra ele no começo do seguinte
  last = items.Count() - 1
  for i = 0 to last - 1
    nextStart = items[i + 1].startSec
    if items[i].stopSec > nextStart and nextStart > items[i].startSec then items[i].stopSec = nextStart
  end for

  return items
end function

function xmltvToEpoch(s as string) as integer
  if Len(s) < 14 then return 0

  y = Val(Mid(s, 1, 4), 10)
  mo = Val(Mid(s, 5, 2), 10)
  d = Val(Mid(s, 7, 2), 10)
  hh = Val(Mid(s, 9, 2), 10)
  mi = Val(Mid(s, 11, 2), 10)
  ss = Val(Mid(s, 13, 2), 10)

  ' dias desde 1970-01-01 (algoritmo "days from civil")
  if mo <= 2 then y = y - 1
  era = Int(y / 400)
  yoe = y - era * 400
  if mo > 2
    mp = mo - 3
  else
    mp = mo + 9
  end if
  doy = Int((153 * mp + 2) / 5) + d - 1
  doe = yoe * 365 + Int(yoe / 4) - Int(yoe / 100) + doy
  days = era * 146097 + doe - 719468

  epoch = days * 86400 + hh * 3600 + mi * 60 + ss

  ' fuso horário, ex.: " -0300"
  if Len(s) >= 20
    sign = Mid(s, 16, 1)
    oh = Val(Mid(s, 17, 2), 10)
    om = Val(Mid(s, 19, 2), 10)
    offset = oh * 3600 + om * 60
    if sign = "-" then offset = -offset
    epoch = epoch - offset
  end if

  return epoch
end function
