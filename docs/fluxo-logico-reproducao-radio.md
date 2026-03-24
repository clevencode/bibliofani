# Fluxo lógico da reprodução de rádio

Este documento descreve o fluxo do app desde a inicialização até começar a tocar áudio, com foco no objetivo principal: tocar uma rádio via stream link.

## Objetivo de produto

- O app abre e prepara a interface do player.
- A reprodução começa automaticamente.
- O estado inicial de escuta deve ser **ao vivo** ("en direct"/live).
- O usuário pode pausar, retomar em diferido ou voltar ao live.

## Arquitetura atual (resumo)

- `main.dart` inicializa o Flutter e sobe o app com `ProviderScope`.
- `lib/app/app.dart` monta o `MaterialApp` e define `home: RadioPlayerPage()`.
- `RadioPlayerPage` observa o estado do player via Riverpod.
- `radio_player_ui_provider.dart` contém as regras de estado/transição de playback.

## Sequência do app ao iniciar

1. **Bootstrap**
   - `main()` chama `WidgetsFlutterBinding.ensureInitialized()`.
   - `runApp()` sobe `RadioApp` dentro de `ProviderScope`.

2. **Composição da app**
   - `RadioApp` constrói tema, localizações e `home`.
   - A tela inicial é `RadioPlayerPage`.

3. **Primeiro frame da tela**
   - Em `RadioPlayerPage.initState()`, após o primeiro frame:
   - chama `ref.read(radioPlayerUiProvider.notifier).autoStartLivePlayback()`.

4. **Arranque automático de reprodução**
   - `autoStartLivePlayback()` valida se está em `idle`.
   - Executa `await centralTap()` para simular o fluxo de start.
   - Em seguida executa `liveTap()` para ativar modo live.

5. **Transições de estado no start**
   - `centralTap()` em `idle` faz:
     - `idle -> preparing` (zera contador e prepara ciclo)
     - atraso mock (400ms)
     - `preparing -> buffering`
     - atraso mock (400ms)
     - `buffering -> playing`
   - `liveTap()` ajusta:
     - `isLiveMode = true`
     - `lifecycle = playing`
     - `liveSyncEligible = false`
   - Resultado funcional esperado: player em reprodução **ao vivo**.

6. **Efeito visual/UX**
   - A barra superior de loading aparece durante `preparing/buffering`.
   - O chip de status passa para "En direct" quando `isPlaying && isLiveMode`.
   - O contador (`elapsed`) começa a avançar por `Timer.periodic` quando está tocando.

## Máquina de estados (UI atual)

Estados (`UiPlaybackLifecycle`):

- `idle`
- `preparing`
- `buffering`
- `playing`
- `paused`

Eventos principais:

- `centralTap()`
  - `idle` -> start (preparing/buffering/playing)
  - `playing` -> `paused`
  - `paused` -> `playing` (retoma em diferido: `isLiveMode = false`)
  - `preparing|buffering` -> `idle` (cancelamento)
- `liveTap()`
  - Força `playing` + `isLiveMode = true`
  - Aplicável quando `canTapLive` for true
- `autoStartLivePlayback()`
  - Sequência automática de startup: start + live

## Onde entra o stream link real

Hoje o fluxo usa atrasos mock para simular preparação e buffering. Para áudio real:

1. Criar uma camada de player (ex.: `RadioStreamPlayerService`).
2. No start (`centralTap`/`autoStartLivePlayback`):
   - carregar URL do stream
   - `setUrl(streamLink)` / `play()`
3. Traduzir estados do player real para estados de UI:
   - loading -> `preparing|buffering`
   - ready/playing -> `playing`
   - paused -> `paused`
   - erro -> `errorMessage` preenchido
4. Em `liveTap()`:
   - reposicionar para o live edge (quando o backend suportar)
   - manter `isLiveMode = true` e estado coerente

## Contrato sugerido para integração de stream

Exemplo de operações necessárias no serviço de áudio:

- `Future<void> init(String streamUrl)`
- `Future<void> play()`
- `Future<void> pause()`
- `Future<void> seekToLiveEdge()` (quando suportado)
- `Stream<PlaybackStatus> watchStatus()`
- `Stream<Duration> watchPosition()`
- `Future<void> dispose()`

Com esse contrato, o notifier continua sendo a orquestração de UX/estado, enquanto o serviço encapsula o player nativo.

## Fluxo alvo (produção)

Ao abrir o app:

- inicializa player com stream link
- entra em loading/buffering
- começa a tocar automaticamente
- entra em live mode automaticamente
- usuário percebe app "ligado" já no direto

## Observações

- O estado atual é de UI mock, mas o desenho de transições já está pronto para plugar um backend de áudio.
- A ação de "auto-start live" foi centralizada no notifier para manter consistência entre startup e botões da tela.
