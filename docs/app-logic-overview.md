# Visao Geral da Logica do App

Este documento explica, de forma funcional, o que o app faz e qual o papel de cada parte.

## Objetivo do app

O app e um player de radio ao vivo (Bible FM).  
A experiencia principal e:

- abrir o app,
- iniciar a reproducao automaticamente,
- permitir pausar/retomar,
- voltar para o modo ao vivo (`LIVE`),
- mostrar estado da transmissao (tocando, conectando, pausado, erro).

## Fluxo principal (do boot ate tocar audio)

1. `main.dart` inicia o Flutter.
2. O app tenta inicializar suporte de audio em background (`just_audio_background`).
3. O app sobe com `ProviderScope` (Riverpod).
4. A tela principal (`RadioPlayerPage`) observa o `radioPlayerProvider`.
5. O `RadioPlayerController`:
   - prepara a URL do stream,
   - tenta autoplay,
   - atualiza estados para a UI.

## Estrutura logica por camada

## 1) Inicializacao

### `lib/main.dart`

Responsabilidades:

- inicializar runtime global;
- habilitar (ou nao) notificacao/background audio;
- subir o app com Riverpod.

Se o background falhar, o app continua funcionando em fallback.

### `lib/core/audio/audio_runtime_config.dart`

Responsabilidade:

- guardar a flag global `backgroundEnabled`.

Essa flag decide se o player deve usar metadados de background (`MediaItem`) ou fallback simples.

## 2) Configuracao

### `lib/core/constants/stream_config.dart`

Responsabilidade:

- centralizar a URL base do stream (`kRadioStreamUrl`).

## 3) Regra de negocio do player

### `lib/features/radio/services/radio_player_controller.dart`

Responsabilidade:

- ser o "cerebro" do player.

Principais funcoes:

- gerenciar estado global de audio (`RadioPlayerState`);
- controlar ciclo de vida de playback (`RadioPlaybackLifecycle`);
- configurar source do stream;
- executar autoplay no inicio;
- pausar/retomar;
- voltar para ao-vivo (`goLive`);
- aplicar retry com backoff + jitter;
- capturar e publicar erros para a UI.

### Estado publicado para a UI

`RadioPlayerState` expoe:

- `lifecycle`: estado atual do player;
- `elapsed`: tempo exibido no contador;
- `errorMessage`: erro amigavel para o usuario;
- `isLiveMode`: flag visual/logica do modo live.

Getters de compatibilidade:

- `isPlaying`;
- `isBuffering`.

## 4) Interface principal

### `lib/features/radio/screens/radio_player_page.dart`

Responsabilidade:

- montar o layout;
- refletir estado vindo do controller;
- disparar acoes de controle.

Acoes de UI:

- botao play/pause -> `togglePlayPause()`;
- botao LIVE -> `goLive()`.

Feedbacks visuais:

- chip de status (`Ao vivo`, `Conectando`, `Pausado`);
- tempo da sessao/transmissao;
- mensagem de erro quando necessario.

## 5) Componente de botao principal

### `lib/features/radio/widgets/play_button.dart`

Responsabilidade:

- representar visualmente o botao principal;
- exibir loading quando buffering;
- alternar icone play/pause com base no estado recebido.

## Comportamentos importantes do app

- **Autoplay no inicio:** o controller tenta tocar assim que a tela abre.
- **Fallback sem quebrar:** se background falhar, o app continua tentando tocar sem notificacao.
- **Retry inteligente:** falhas de play tentam reconectar antes de mostrar erro final.
- **Modo LIVE:** refresca a URL para aproximar do "live edge".
- **Estado unico global:** qualquer tela pode observar o mesmo estado do player via Riverpod.

## Resumo funcional

O app e um player de radio ao vivo com estado centralizado, UI reativa e tratamento de falhas para manter a reproducao estavel.  
Cada arquivo tem papel claro: inicializacao, configuracao, regra de audio e interface.

