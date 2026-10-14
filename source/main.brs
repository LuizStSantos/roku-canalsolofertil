sub Main(args as dynamic)
  screen = CreateObject("roSGScreen")
  port = CreateObject("roMessagePort")
  screen.setMessagePort(port)
  scene = screen.CreateScene("MainScene")
  screen.show()

  ' Direct to Play / link direto no lançamento (contentId + mediaType)
  if type(args) = "roAssociativeArray"
    if args.mediaType <> invalid and args.contentId <> invalid
      print "[Solo Fertil] lancado com deep link: "; args.mediaType; " / "; args.contentId
    end if
    scene.launchArgs = args
  end if

  ' Eventos roInput com o app já aberto (exigido pela certificação, req. 5.2)
  input = CreateObject("roInput")
  input.setMessagePort(port)

  ' Monitoramento de memória: importante para um canal que fica ligado 24/7
  memMon = CreateObject("roAppMemoryMonitor")
  memMon.setMessagePort(port)
  memMon.enableMemoryWarningEvent(true)
  devInfo = CreateObject("roDeviceInfo")
  devInfo.setMessagePort(port)
  devInfo.enableLowGeneralMemoryEvent(true)
  print "[Solo Fertil] memoria do canal: limite="; memMon.getChannelMemoryLimit(); " disponivel="; memMon.getChannelAvailableMemory(); " uso%="; memMon.getMemoryLimitPercent()

  while true
    msg = wait(0, port)
    msgType = type(msg)

    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return

    else if msgType = "roInputEvent"
      if msg.isInput()
        info = msg.getInfo()
        if info.DoesExist("mediatype") and info.DoesExist("contentid")
          print "[Solo Fertil] roInput com deep link: "; info.mediatype; " / "; info.contentid
        end if
        scene.inputArgs = info
      end if

    else if msgType = "roAppMemoryMonitorEvent"
      print "[Solo Fertil] aviso de pouca memoria do canal"
      scene.memoryWarning = true

    else if msgType = "roDeviceInfoEvent"
      info = msg.getInfo()
      level = invalid
      if info <> invalid then level = info["generalMemoryLevel"]
      print "[Solo Fertil] memoria geral do aparelho: "; level
      if level = "low" or level = "critical" then scene.memoryWarning = true
    end if
  end while
end sub
