' ============================================================
'  Canal Solo Fértil - transmissão ao vivo 24/7 com guia (XMLTV)
'  Para trocar os endereços, edite apenas as duas funções abaixo.
' ============================================================
function getStreamUrl() as string
  ' O MediaMTX redireciona index.m3u8 para ?cookieCheck=1. Já usamos essa
  ' URL direto para o Roku (que não guarda cookies) não depender do redirecionamento.
  return "https://stream.canalsolofertil.com.br/live/canalsolofertil/index.m3u8?cookieCheck=1"
end function

function getEpgUrl() as string
  return "https://stream.canalsolofertil.com.br/epg.xml"
end function

function getChannelName() as string
  return "Canal Solo Fértil"
end function

sub init()
  m.video = m.top.findNode("video")
  m.info = m.top.findNode("info")
  m.guide = m.top.findNode("guide")
  m.splash = m.top.findNode("splash")
  m.errorGroup = m.top.findNode("errorGroup")
  m.pausedGroup = m.top.findNode("pausedGroup")
  m.netGroup = m.top.findNode("netGroup")

  m.countTimer = m.top.findNode("countTimer")
  m.hideTimer = m.top.findNode("hideTimer")
  m.tickTimer = m.top.findNode("tickTimer")
  m.epgTimer = m.top.findNode("epgTimer")
  m.netTimer = m.top.findNode("netTimer")
  m.launchTimer = m.top.findNode("launchTimer")

  m.progTitle = m.top.findNode("progTitle")
  m.progTime = m.top.findNode("progTime")
  m.progBar = m.top.findNode("progBar")
  m.progNext = m.top.findNode("progNext")
  m.epgRow = m.top.findNode("epgRow")
  m.clock = m.top.findNode("clock")

  ' fontes
  m.top.findNode("liveLabel").font = "font:SmallestBoldSystemFont"
  m.top.findNode("chLabel").font = "font:SmallestBoldSystemFont"
  m.progTitle.font = "font:LargeBoldSystemFont"
  m.progTime.font = "font:SmallestSystemFont"
  m.progNext.font = "font:SmallestSystemFont"
  m.top.findNode("nextTag").font = "font:SmallestBoldSystemFont"
  m.clock.font = "font:MediumBoldSystemFont"
  for each id in ["h1", "h2", "h3", "h4"]
    m.top.findNode(id).font = "font:SmallestSystemFont"
  end for
  m.top.findNode("pausedText").font = "font:MediumSystemFont"
  m.top.findNode("errTitle").font = "font:MediumBoldSystemFont"
  m.top.findNode("errReason").font = "font:SmallestSystemFont"
  m.top.findNode("errRetry").font = "font:MediumSystemFont"
  m.top.findNode("errHint").font = "font:SmallestSystemFont"
  m.top.findNode("splashText").font = "font:SmallestSystemFont"
  m.top.findNode("netTitle").font = "font:MediumBoldSystemFont"
  m.top.findNode("netText").font = "font:SmallestSystemFont"

  m.programmes = []
  m.guideKey = -2
  m.guideAvailable = false
  m.launchSignaled = false
  m.infoShownOnce = false
  m.everPlayed = false
  m.paused = false
  m.offline = false
  m.retryIdx = 0
  m.retryLeft = 0
  m.retryDelays = [3, 5, 10, 20, 30]
  m.pauseSpan = CreateObject("roTimespan")

  ' transmissão ao vivo: sem barra de avançar/pausar do player
  m.video.enableUI = false
  m.video.enableTrickPlay = false
  m.video.observeField("state", "onVideoState")

  m.countTimer.observeField("fire", "onCountTick")
  m.hideTimer.observeField("fire", "hideInfo")
  m.tickTimer.observeField("fire", "onTick")
  m.epgTimer.observeField("fire", "loadEpg")
  m.netTimer.observeField("fire", "checkNetwork")
  m.guide.observeField("closeRequested", "onGuideClose")
  m.guide.observeField("togglePause", "onGuidePause")

  ' Beacon de abertura exigido pela Roku: se o vídeo demorar, avisa em 10 s
  m.launchTimer.observeField("fire", "signalLaunchComplete")
  m.launchTimer.control = "start"

  m.top.observeField("launchArgs", "onLaunchArgs")
  m.top.observeField("inputArgs", "onInputArgs")
  m.top.observeField("memoryWarning", "onMemoryWarning")

  ' escuta eventos roInput (link direto) em uma Task, como a Roku espera
  m.inputTask = CreateObject("roSGNode", "InputTask")
  m.inputTask.observeField("inputData", "onInputData")
  m.inputTask.control = "RUN"

  m.top.findNode("spinAnim").control = "start"

  ' o foco fica na cena para receber os botões do controle
  m.top.setFocus(true)

  updateClock()
  startStream()
  loadEpg()
  m.tickTimer.control = "start"
  m.epgTimer.control = "start"
  m.netTimer.control = "start"
end sub

' ------------------------------------------------------------
'  Vídeo
' ------------------------------------------------------------
sub startStream()
  if m.offline then return
  m.video.control = "stop"
  m.paused = false
  m.pausedGroup.visible = false
  m.countTimer.control = "stop"

  if not m.everPlayed
    m.splash.visible = true
    m.top.findNode("splashText").text = "Conectando..."
  end if

  content = CreateObject("roSGNode", "ContentNode")
  content.url = getStreamUrl()
  content.streamFormat = "hls"
  content.title = getChannelName()
  content.live = true

  m.video.content = content
  m.video.control = "play"
end sub

sub onVideoState()
  state = m.video.state
  print "[Solo Fertil] estado do player: "; state

  if state = "playing"
    m.everPlayed = true
    m.retryIdx = 0
    m.countTimer.control = "stop"
    m.splash.visible = false
    m.errorGroup.visible = false
    signalLaunchComplete()
    if m.infoShownOnce <> true
      m.infoShownOnce = true
      showInfo()
    end if
  else if state = "error" or state = "finished"
    reason = "Falha ao conectar no servidor da transmissão."
    if state = "finished" then reason = "A transmissão foi encerrada."
    if state = "error"
      reason = reason + " (erro " + m.video.errorCode.ToStr() + ")"
      print "[Solo Fertil] erro codigo: "; m.video.errorCode
      print "[Solo Fertil] erro msg: "; m.video.errorMsg
      print "[Solo Fertil] erro str: "; m.video.errorStr
    end if
    scheduleRetry(reason)
  end if
end sub

' Reconecta sozinho: 3 s, 5 s, 10 s, 20 s, 30 s... com contagem na tela
sub scheduleRetry(reason as string)
  if m.offline then return
  idx = m.retryIdx
  if idx > m.retryDelays.Count() - 1 then idx = m.retryDelays.Count() - 1
  m.retryLeft = m.retryDelays[idx]
  m.retryIdx = m.retryIdx + 1

  m.top.findNode("errReason").text = reason
  updateRetryText()
  m.splash.visible = false
  m.errorGroup.visible = true
  hideInfo()
  closeGuide()
  m.countTimer.control = "stop"
  m.countTimer.control = "start"
end sub

sub onCountTick()
  m.retryLeft = m.retryLeft - 1
  if m.retryLeft <= 0
    m.countTimer.control = "stop"
    m.top.findNode("errRetry").text = "Reconectando..."
    startStream()
  else
    updateRetryText()
  end if
end sub

sub updateRetryText()
  m.top.findNode("errRetry").text = "Tentando de novo em " + m.retryLeft.ToStr() + "s..."
end sub

' Avisa a Roku que o app terminou de abrir (beacon AppLaunchComplete)
sub signalLaunchComplete()
  if m.launchSignaled = true then return
  m.launchSignaled = true
  m.launchTimer.control = "stop"
  m.top.signalBeacon("AppLaunchComplete")
  print "[Solo Fertil] beacon AppLaunchComplete enviado"
end sub

' Pausa / continua. Pausado por mais de 30 s, volta para o ponto "ao vivo".
sub togglePause()
  if m.paused
    m.paused = false
    m.pausedGroup.visible = false
    if m.pauseSpan.TotalMilliseconds() > 30000
      startStream()
    else
      m.video.control = "resume"
    end if
  else
    if m.video.state <> "playing" then return
    m.paused = true
    m.pauseSpan.Mark()
    m.video.control = "pause"
    m.pausedGroup.visible = true
    hideInfo()
  end if
end sub

' Sem internet: avisa na tela e volta sozinho quando a rede retornar
sub checkNetwork()
  dev = CreateObject("roDeviceInfo")
  online = dev.GetLinkStatus()
  if online = false and not m.offline
    print "[Solo Fertil] sem conexao com a internet"
    m.offline = true
    m.countTimer.control = "stop"
    m.errorGroup.visible = false
    m.netGroup.visible = true
    closeGuide()
  else if online = true and m.offline
    print "[Solo Fertil] conexao restabelecida"
    m.offline = false
    m.netGroup.visible = false
    m.retryIdx = 0
    startStream()
    loadEpg()
  end if
end sub

' roInput (link direto / voz): o canal tem um único stream, então só garante que está tocando
sub onLaunchArgs()
  handleDeepLink(m.top.launchArgs)
end sub

sub onInputArgs()
  handleDeepLink(m.top.inputArgs)
end sub

sub onInputData(event as object)
  handleDeepLink(event.getData())
end sub

' Lê contentId e mediaType sem diferenciar maiúsculas de minúsculas
function parseDeepLink(info as dynamic) as object
  result = { contentId: "", mediaType: "" }
  if type(info) <> "roAssociativeArray" then return result

  for each key in info
    val = info[key]
    if type(val) = "String" or type(val) = "roString"
      k = LCase(key)
      if k = "contentid" then result.contentId = val
      if k = "mediatype" then result.mediaType = LCase(val)
    end if
  end for

  return result
end function

' Direct to Play: este canal tem um único conteúdo, o stream ao vivo (livefeed).
' Qualquer link válido (contentId + mediaType) toca o ao vivo, sem tela de retomar.
' Sem os dois campos, o app abre normal, que já é tocando o ao vivo.
sub handleDeepLink(info as dynamic)
  link = parseDeepLink(info)
  if link.contentId = "" or link.mediaType = "" then return

  print "[Solo Fertil] deep link: mediaType="; link.mediaType; " contentId="; link.contentId
  if m.video.state <> "playing" and m.video.state <> "buffering" then startStream()
end sub

' Pouca memória: reinicia o player para liberar recursos (importante em canal 24/7)
sub onMemoryWarning()
  print "[Solo Fertil] aviso de memoria, reiniciando o player"
  startStream()
end sub


' ------------------------------------------------------------
'  Guia de programação
' ------------------------------------------------------------
sub loadEpg()
  m.epgTask = CreateObject("roSGNode", "EpgTask")
  m.epgTask.observeField("result", "onEpgResult")
  m.epgTask.url = getEpgUrl()
  m.epgTask.control = "RUN"
end sub

sub onEpgResult(event as object)
  data = event.getData()
  if data <> invalid
    if data.ok = true
      m.programmes = data.items
      print "[Solo Fertil] EPG carregado: "; m.programmes.Count(); " programas (cache="; data.cached; ")"
      refreshGuide()
      if m.guide.visible then buildGuide()
      return
    end if
  end if
  print "[Solo Fertil] nao foi possivel carregar o EPG"
end sub

sub onTick()
  updateClock()
  refreshGuide()
end sub

sub updateClock()
  dt = CreateObject("roDateTime")
  dt.ToLocalTime()
  m.clock.text = pad2(dt.GetHours()) + ":" + pad2(dt.GetMinutes())
end sub

' Programa no ar e o próximo. Pequenos intervalos (até 10 min) entre programas
' contam como o programa anterior ainda no ar.
sub findNowNext(nowSec as integer, res as object)
  res.current = invalid
  res.upcoming = invalid
  prev = invalid

  for each p in m.programmes
    if p.startSec <= nowSec and nowSec < p.stopSec
      res.current = p
    else if p.startSec > nowSec
      if res.upcoming = invalid
        res.upcoming = p
      else if p.startSec < res.upcoming.startSec
        res.upcoming = p
      end if
    else if p.stopSec <= nowSec
      if prev = invalid
        prev = p
      else if p.stopSec > prev.stopSec
        prev = p
      end if
    end if
  end for

  if res.current = invalid and prev <> invalid
    if nowSec - prev.stopSec <= 600 and res.upcoming <> invalid then res.current = prev
  end if
end sub

sub refreshGuide()
  nowSec = CreateObject("roDateTime").AsSeconds()
  res = {}
  findNowNext(nowSec, res)
  current = res.current
  upcoming = res.upcoming

  if current = invalid
    ' sem programa para este horário: mostra só o nome do canal
    m.guideAvailable = false
    m.guideKey = -2
    m.progTitle.text = getChannelName()
    m.epgRow.visible = false
    return
  end if

  m.guideAvailable = true
  changed = (current.startSec <> m.guideKey)
  m.guideKey = current.startSec

  m.progTitle.text = current.title
  m.progTime.text = formatHM(current.startSec) + " - " + formatHM(current.stopSec)

  total = current.stopSec - current.startSec
  frac = 0.0
  if total > 0 then frac = (nowSec - current.startSec) / total
  if frac < 0 then frac = 0
  if frac > 1 then frac = 1
  m.progBar.width = Int(150 * frac)

  if upcoming <> invalid
    m.progNext.text = formatHM(upcoming.startSec) + " · " + upcoming.title
  else
    m.progNext.text = ""
  end if
  m.epgRow.visible = true

  ' quando começa um novo programa, a barra aparece sozinha por alguns segundos
  if changed and m.everPlayed and not m.guide.visible and not m.paused and not m.errorGroup.visible then showInfo()
end sub

sub showInfo()
  m.info.visible = true
  m.hideTimer.control = "stop"
  m.hideTimer.control = "start"
end sub

sub hideInfo()
  m.info.visible = false
  m.hideTimer.control = "stop"
end sub

' ------------------------------------------------------------
'  Grade de programação (tecla direita)
' ------------------------------------------------------------
sub openGuide()
  if m.errorGroup.visible or m.offline then return
  buildGuide()
  hideInfo()
  m.guide.visible = true
  m.top.setFocus(true)
end sub

sub closeGuide()
  if not m.guide.visible then return
  m.guide.visible = false
  m.top.setFocus(true)
end sub

sub onGuideClose()
  closeGuide()
end sub

sub onGuidePause()
  closeGuide()
  togglePause()
end sub

sub buildGuide()
  nowSec = CreateObject("roDateTime").AsSeconds()
  res = {}
  findNowNext(nowSec, res)

  rows = []
  lastDay = ""
  count = 0
  fallbackThumb = "pkg:/images/splash_hd.jpg"

  for each p in m.programmes
    if p.stopSec > nowSec
      day = dayLabel(p.startSec, nowSec)
      if day <> lastDay
        rows.Push({ kind: "hdr", label: day })
        lastDay = day
      end if

      meta = ""
      if p.category <> "" then meta = p.category
      if p.rating <> ""
        if meta <> "" then meta = meta + " · "
        meta = meta + "Classificação: " + p.rating
      end if
      if meta <> "" then meta = meta + " · "
      meta = meta + formatHM(p.startSec) + "–" + formatHM(p.stopSec)

      desc = cleanDesc(p.desc, 90)
      if desc = "" then desc = "Programação oficial do Canal Solo Fértil"
      icon = p.icon
      if icon = "" then icon = fallbackThumb

      isNow = false
      if res.current <> invalid
        if p.startSec = res.current.startSec then isNow = true
      end if

      rows.Push({ kind: "prog", time: formatHM(p.startSec), title: cleanDesc(p.title, 60), desc: desc, meta: meta, icon: icon, isNow: isNow })
      count = count + 1
    end if
  end for

  dt = CreateObject("roDateTime")
  dt.ToLocalTime()
  if count = 0
    m.guide.subtitle = "Programação indisponível no momento"
  else
    m.guide.subtitle = getChannelName() + " · Hoje, " + pad2(dt.GetHours()) + ":" + pad2(dt.GetMinutes())
  end if
  m.guide.rows = rows
end sub

' HOJE / AMANHÃ / SEG 14/10
function dayLabel(epoch as integer, nowSec as integer) as string
  d = CreateObject("roDateTime")
  d.FromSeconds(epoch)
  d.ToLocalTime()
  n = CreateObject("roDateTime")
  n.FromSeconds(nowSec)
  n.ToLocalTime()
  t = CreateObject("roDateTime")
  t.FromSeconds(nowSec + 86400)
  t.ToLocalTime()

  if d.GetYear() = n.GetYear() and d.GetMonth() = n.GetMonth() and d.GetDayOfMonth() = n.GetDayOfMonth() then return "HOJE"
  if d.GetYear() = t.GetYear() and d.GetMonth() = t.GetMonth() and d.GetDayOfMonth() = t.GetDayOfMonth() then return "AMANHÃ"

  names = { Sunday: "DOM", Monday: "SEG", Tuesday: "TER", Wednesday: "QUA", Thursday: "QUI", Friday: "SEX", Saturday: "SÁB" }
  wd = names[d.GetWeekday()]
  if wd = invalid then wd = ""
  return wd + " " + pad2(d.GetDayOfMonth()) + "/" + pad2(d.GetMonth())
end function

' ------------------------------------------------------------
'  Controle remoto
' ------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  ' grade aberta: o próprio painel trata as teclas
  if m.guide.visible
    if m.guide.callFunc("handleKey", key) then return true
    if key = "back"
      closeGuide()
      return true
    end if
    return false
  end if

  ' sem internet: deixa o Voltar/Início funcionarem normalmente
  if m.offline then return false

  ' erro: OK tenta de novo agora
  if m.errorGroup.visible
    if key = "OK"
      m.retryLeft = 0
      m.countTimer.control = "stop"
      m.top.findNode("errRetry").text = "Reconectando..."
      startStream()
      return true
    end if
    return false
  end if

  ' pausado: OK ou Play continuam
  if m.paused
    if key = "OK" or key = "play"
      togglePause()
      return true
    end if
    return false
  end if

  if key = "play"
    togglePause()
    return true
  else if key = "right" or key = "options"
    openGuide()
    return true
  else if key = "OK"
    if m.info.visible then hideInfo() else showInfo()
    return true
  else if key = "left" or key = "up" or key = "down"
    showInfo()
    return true
  end if

  ' "back" fica livre: a Roku fecha o canal
  return false
end function

' ------------------------------------------------------------
'  Utilitários
' ------------------------------------------------------------
function formatHM(epoch as integer) as string
  dt = CreateObject("roDateTime")
  dt.FromSeconds(epoch)
  dt.ToLocalTime()
  return pad2(dt.GetHours()) + ":" + pad2(dt.GetMinutes())
end function

' Limpa quebras de linha e corta descrições longas (no máximo ~2 linhas)
function cleanDesc(s as string, maxLen as integer) as string
  re = CreateObject("roRegex", "\s+", "")
  s = re.ReplaceAll(s, " ").Trim()
  if Len(s) > maxLen
    s = Left(s, maxLen)
    ' tenta cortar numa palavra inteira
    cutAt = Len(s)
    while cutAt > 1 and Mid(s, cutAt, 1) <> " "
      cutAt = cutAt - 1
    end while
    if cutAt > maxLen * 0.6 then s = Left(s, cutAt - 1)
    s = s + "..."
  end if
  return s
end function

function pad2(n as integer) as string
  s = n.ToStr()
  if Len(s) < 2 then s = "0" + s
  return s
end function
