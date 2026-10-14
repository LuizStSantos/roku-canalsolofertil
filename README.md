# Canal Solo Fértil — app para Roku

App Roku (BrightScript / SceneGraph) que abre direto na transmissão ao vivo 24/7 do **Canal Solo Fértil**, com a programação lida de um arquivo XMLTV.

Versão atual: **1.4** · Firmware mínimo: **15.1** · Resolução da interface: HD (1280x720)

## Telas

| Abertura | Barra de informações | Programação |
|---|---|---|
| ![Abertura](docs/screenshots/01-abertura.jpg) | ![Barra de informações](docs/screenshots/02-barra-info.jpg) | ![Programação](docs/screenshots/03-programacao.jpg) |

> O Roku não captura a camada de vídeo nos screenshots, por isso o fundo das duas últimas telas aparece preto. No aparelho, a interface fica sobre a transmissão ao vivo.

## O que o app faz

- Toca a stream HLS ao vivo em tela cheia.
- Tela de abertura com a arte do canal e "Conectando...".
- Barra de informações: logo, selo **AO VIVO**, programa no ar, horário, barra de progresso, **A SEGUIR** e relógio. Aparece ao iniciar, quando um programa novo começa e ao apertar OK; some depois de 6 segundos.
- Grade de **Programação** agrupada por dia (HOJE, AMANHÃ...), com o programa selecionado expandido (imagem, descrição, categoria, classificação e horários).
- Atualiza o guia a cada 30 minutos e guarda uma cópia em cache para abrir mais rápido.
- Reconecta sozinho se a stream cair (3, 5, 10, 20 e 30 s), com contagem na tela. OK tenta na hora.
- Pausa e volta ao ao vivo: pausado por mais de 30 s, retoma no ponto ao vivo.
- Aviso de "Sem conexão com a internet"; a transmissão volta sozinha quando a rede volta.
- Direct to Play (deep link com `contentId` e `mediaType`) e beacon `AppLaunchComplete`.
- Reinicia o player ao receber aviso de pouca memória (canal 24/7).

## Controle remoto

| Tecla | Tela principal | Programação |
|---|---|---|
| OK | Mostra/esconde a barra (na tela de erro: tenta de novo) | Fecha a programação |
| Direita ou `*` | Abre a programação | Fecha a programação |
| Esquerda, Cima, Baixo | Mostra a barra | Esquerda fecha; Cima/Baixo navegam |
| Avançar / Voltar (⏩ ⏪) | — | Pulam 5 programas |
| Play/Pausa | Pausa ou continua | Pausa ou continua |
| Voltar | Fecha o canal (padrão da Roku) | Fecha a programação |

## Configuração

Os endereços ficam no início de `components/MainScene.brs`:

```brightscript
function getStreamUrl() as string
  return "https://stream.canalsolofertil.com.br/live/canalsolofertil/index.m3u8?cookieCheck=1"
end function

function getEpgUrl() as string
  return "https://stream.canalsolofertil.com.br/epg.xml"
end function
```

O `?cookieCheck=1` evita o redirecionamento do MediaMTX, já que o Roku não guarda cookies. No servidor, mantenha `hlsTrustedProxies` vazio se não houver proxy reverso na frente do MediaMTX.

### Guia (XMLTV)

O app lê `title`, `desc`, `category`, `icon` e `rating/value` de cada `<programme>`, com horários no formato `20261013110000 -0300`. Mantenha o arquivo cobrindo hoje e os próximos dias. Sem programa para o horário atual, a barra mostra só o nome do canal e a grade mostra "Programação indisponível no momento".

## Rodando no Roku (modo desenvolvedor)

1. Ative o modo desenvolvedor no Roku (Home ×3, Cima ×2, Direita, Esquerda, Direita, Esquerda, Direita) e anote o IP.
2. Gere o pacote: `./build.sh` (cria `out/canalsolofertil.zip`; o `manifest` precisa estar na raiz do zip).
3. Abra `http://IP-DO-ROKU`, envie o zip em **Upload** e clique em **Install** ("Replace with zip" para atualizar).
4. Console de depuração: `telnet IP-DO-ROKU 8085` (uma conexão por vez).

## Publicação

- Gere o `.pkg` com a chave de desenvolvedor (Packager do instalador) e envie no Developer Dashboard, em **App package**, com firmware mínimo **15.1**.
- Aumente `minor_version`/`build_version` no `manifest` a cada nova versão enviada.
- Screenshots da loja: 1280x720, tiradas em **Utilities → Screenshot** na página do instalador.
- **Nunca** versione a chave de desenvolvedor, a senha do genkey ou os arquivos `.pkg`.
- O app reproduz vídeo continuamente; se a certificação apontar o item de protetor de tela (4.5), peça isenção à Roku em developer.roku.com/contact.

## Estrutura

```
manifest              configuração do canal (versão, ícones, firmware)
source/main.brs       entrada: roInput, memória, eventos
components/
  MainScene.*         tela principal, vídeo, barra, reconexão, rede
  GuideView.* GuideRow.*  painel lateral da programação
  EpgTask.*           baixa e interpreta o XMLTV (com cache)
  InputTask.*         recebe deep links (roInput)
images/               ícone (290x218), abertura (1280x720), logo, gradientes
docs/screenshots/     capturas usadas neste README
build.sh              gera out/canalsolofertil.zip
```

## Versão Samsung

Existe uma versão equivalente para Smart TVs Samsung (Tizen). Os dois apps compartilham a mesma stream e o mesmo guia.
