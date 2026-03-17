# Logica do Stream Link e Reproducao (Bible FM)

Este documento descreve a logica completa do stream: montagem do link, inicializacao, reproducao automatica, retry, fallback e diagnostico.

## 1) Fonte do stream link

Arquivo: `lib/core/constants/stream_config.dart`

- URL base usada no app:
  - `kRadioStreamUrl = https://servidor13.brlogic.com:7156/live`

## 2) Como o stream link final e montado

Arquivo: `lib/features/radio/services/radio_player_controller.dart`  
Metodo: `_configureSource()`

Passos:

1. Faz `Uri.parse(kRadioStreamUrl)`.
2. Adiciona query param `t=<timestamp>`:
   - objetivo: forcar refresh e aproximar do "live edge".
3. Cria `AudioSource.uri(liveUri, ...)`.
4. Define `preload: false` para comportamento melhor em stream ao vivo.

## 3) Background vs fallback de reproducao

Arquivos:

- `lib/main.dart`
- `lib/core/audio/audio_runtime_config.dart`
- `lib/features/radio/services/radio_player_controller.dart`

Fluxo:

1. `main.dart` tenta `JustAudioBackground.init(...)`.
2. Se sucesso: `AudioRuntimeConfig.backgroundEnabled = true`.
3. Se falha: `backgroundEnabled = false`, app continua em fallback.
4. Em `_configureSource()`, o controller aplica `MediaItem` com metadados e `isLive: true` (inclusive no fallback, com `extras` indicando fallback).

## 4) Fluxo de reproducao ao abrir o app (autoplay)

No construtor de `RadioPlayerController`:

- cria `AudioPlayer`
- assina streams de estado/posicao/erros
- chama `_bootstrapAutoPlay()` (sem bloquear UI)

`_bootstrapAutoPlay()`:

1. `_configureSource(forceRefresh: true)`
2. `_playWithRetry()`
3. em falha, registra log e define mensagem amigavel para UI.

## 5) Estados de reproducao (lifecycle)

O app usa enum `RadioPlaybackLifecycle`:

- `idle`
- `preparing`
- `buffering`
- `playing`
- `paused`
- `reconnecting`
- `error`

`RadioPlayerState` expoe:

- `lifecycle`
- `elapsed`
- `errorMessage`
- `isLiveMode`

E getters de compatibilidade para UI:

- `isPlaying`
- `isBuffering`

## 6) Comandos de controle

### `togglePlayPause()`

- Se estiver tocando:
  - pausa (`_player.pause()`)
  - seta `paused` e `isLiveMode = false`
- Se estiver parado:
  - garante source configurada
  - executa `_playWithRetry()`
  - em erro, marca `error`

### `goLive()`

- Marca estado `reconnecting`
- Faz `stop()`
- Reconfigura source com `forceRefresh: true`
- Tenta tocar com retry
- Em falha, marca `error` e desativa `isLiveMode`

## 7) Retry e robustez de reconexao

Metodo: `_playWithRetry(maxAttempts: 3)`

- Ate 3 tentativas de `play()`
- Backoff exponencial + jitter:
  - base: `300ms * 2^(tentativa-1)`
  - jitter aleatorio adicional (ate ~240ms)
- Na falha final:
  - `lifecycle = error`
  - mensagem amigavel para usuario

## 8) Tratamento de erros de runtime

Erro de setup/source:

- capturado em `_configureSource()`
- marca source como nao configurada
- loga stack no `debugPrint`

Erro de playback:

- capturado em `playbackEventStream` (`onError`)
- atualiza estado para `error`
- publica mensagem para UI

Protecoes extras:

- `_sourceLock`: evita corrida entre configuracoes simultaneas
- `_isSwitchingSource`: impede falso-positivo de erro durante troca de source
- `_sourceConfigured`: evita reconfiguracoes desnecessarias

## 9) Como diagnosticar quando nao toca

Procure no terminal por:

- `JustAudioBackground.init falhou: ...`
- `Falha ao configurar source: ...`
- `Tentativa X de play falhou: ...`
- `Erro no playbackEventStream: ...`
- `Falha ao iniciar reproducao automatica: ...`

Checklist rapido:

1. `flutter clean`
2. `flutter pub get`
3. `flutter run`
4. Testar play e LIVE
5. Se falhar, capturar as primeiras linhas da excecao (nao so o fim da stack)

