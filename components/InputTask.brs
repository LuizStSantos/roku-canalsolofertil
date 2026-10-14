' ============================================================
'  Escuta eventos roInput (link direto / Direct to Play) e repassa
'  para a cena. Exigido pela certificação (requisito 5.2).
' ============================================================
sub init()
  m.top.functionName = "listenForInput"
end sub

sub listenForInput()
  port = CreateObject("roMessagePort")
  input = CreateObject("roInput")
  input.setMessagePort(port)

  while true
    msg = wait(0, port)
    if type(msg) = "roInputEvent"
      if msg.isInput()
        info = msg.getInfo()
        if info.DoesExist("mediatype") and info.DoesExist("contentid")
          m.top.inputData = info
        end if
      end if
    end if
  end while
end sub
