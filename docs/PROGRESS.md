# ROGUE DOODLE — STATUS DO DESENVOLVIMENTO

> **Documento de retomada.** Se este projeto for enviado a uma nova conversa,
> este arquivo descreve exatamente onde o desenvolvimento parou, as decisões
> de arquitetura tomadas e o que vem a seguir. Última atualização: fim da
> **PRONTO PARA PUBLICAÇÃO** (13/08/2026). O jogo se chama
> oficialmente **Blank Canvas** agora (era "Rogue Doodle" durante o
> desenvolvimento). **As 19 etapas do roteiro
> original estão completas.** O jogo tem o loop inteiro jogável:
> menu → criar personagem → criar habilidade → arena → waves
> infinitas → progressão → game over → jogar de novo. Dali em diante,
> qualquer trabalho futuro é iteração livre (novos assets do usuário,
> ajustes de balanceamento por playtesting real, novas mecânicas).

---

## 1. ONDE ESTAMOS

| Etapa | Conteúdo | Status |
|---|---|---|
| 1 | Estrutura do projeto + Menu Principal | ✅ Concluída |
| 2 | Editor de personagem 36×36 (PixelEditor) | ✅ Concluída |
| 3 | Armazenamento do desenho (memória + disco) | ✅ Concluída |
| 4 | Editor da habilidade principal (limite de pixels) | ✅ Concluída |
| 5 | Arena branca (quadro, paredes, limites de câmera) | ✅ Concluída |
| 6 | Jogador + movimentação (estilo Vampire Survivors) | ✅ Concluída |
| 7 | Efeito de caminhada (WalkAnimator procedural) | ✅ Concluída |
| 8 | Inimigos (EnemyBase, 3 tipos, spawner, HP do player, HUD) | ✅ Concluída |
| 8.5 | Sprites animados dos inimigos integrados (slime/bola/quadrado) | ✅ Concluída |
| 9 | Rastros/pintura dos inimigos (PaintCanvas) | ✅ Concluída |
| 10 | Projéteis (Area2D com desenho da habilidade) | ✅ Concluída |
| 11 | Auto-aim + disparo automático (AbilityController) | ✅ Concluída |
| 12 | Projéteis pintando o cenário (cor extraída do desenho) | ✅ Concluída |
| 13 | Sistema de waves (WaveManager, HP escalado, HUD) | ✅ Concluída |
| 14 | Progressão a cada 5 waves (tela + pausa + upgrade básico) | ✅ Concluída |
| 15 | Criação de novas habilidades em partida (overlay pausado) | ✅ Concluída |
| 16 | Upgrades (AbilityData + 3 escolhas sorteadas) | ✅ Concluída |
| 17 | Múltiplas habilidades (cooldowns paralelos + HUD com miniaturas) | ✅ Concluída |
| 18 | Game Over (tela real, textos finais combinados com o usuário) | ✅ Concluída |
| 19 | Polimento (pausa, balanceamento, feedback visual, limpeza) | ✅ Concluída |

**🎉 Roteiro original (seção 3 do documento de design) 100% completo.**

**Fluxo jogável atual:** Menu → Criar Personagem (desenho 36×36) → Criar
Habilidade (máx. 100 px) → Arena (quadro branco 4096×4096, jogador com o
próprio desenho, movimento suave WASD/setas, animação de trote, colisão nas
bordas, câmera com smoothing). ESC volta ao menu (provisório).

---

## 2. DECISÕES DE ARQUITETURA (não mudar sem motivo)

- **Desenhos = `Image` (dados) + `ImageTexture` (exibição).** Cada célula do
  grid 36×36 é 1 pixel real. CPU-side, leitura/escrita instantânea, vira
  sprite com `ImageTexture.create_from_image()`. `SubViewport` foi descartado
  (round-trip de GPU lento para leitura).
- **`GameManager` (Autoload)** é o único singleton: caminhos de cenas,
  transições com verificação (`ResourceLoader.exists`), desenhos do
  personagem/habilidades em memória, persistência em `user://drawings/*.png`,
  `last_wave_reached`, `DISPLAY_NAME` (nome oficial: "Blank Canvas", trocável ali).
- **`PixelEditor`** (`class_name`, cena própria) é reutilizável; as telas de
  criação herdam de **`DrawingCreatorBase`** e implementam só 3 hooks:
  `_on_creator_ready()`, `_on_confirm_button_pressed()`,
  `_on_back_button_pressed()`. Habilidades futuras (Etapa 15) reutilizam tudo.
- **Arena**: quadro de `(0,0)` até `arena_size` (export, padrão 4096×4096);
  paredes e limites de câmera são **gerados por código** a partir desse valor.
  O quadro branco é `_draw()` — será coberto pelo PaintCanvas (Etapa 9).
- **Player**: `CharacterBody2D` com `motion_mode = Floating`;
  aceleração/fricção via `move_toward`; sprite isolado do corpo físico.
- **`WalkAnimator`** anexado ao Sprite2D (estende Sprite2D): bounce + rotação
  + squash/stretch lendo `get_parent().velocity`. **Reutilizável nos inimigos.**
- **Input**: ações `move_up/down/left/right` (WASD + setas, physical keycodes)
  já no `project.godot` — o Player as usa; inimigos não precisam de input.
- **Pintura acumulativa (planejada, Etapa 9)**: um único `Image` +
  `ImageTexture` do tamanho da arena; inimigos/projéteis chamam
  `paint_line()`/`paint_circle()`; `texture.update()` no máximo 1×/frame
  (dirty flag). Zero Nodes por pincelada.

## 3. CONVENÇÕES DO PROJETO

- Godot **4.x** (features "4.3"); GDScript tipado; comentários em PT-BR.
- Signals conectados **por código** no `_ready()` (não pelo editor).
- Placeholders sempre sinalizados com comentário `PLACEHOLDER`/`PROVISÓRIO`.
- Etapas incrementais: **nunca avançar sem confirmação do usuário**; ao fim de
  cada etapa, reportar arquivos criados/modificados, como testar, placeholders
  e assets futuros. Código sempre completo (sem "# resto do código").
- Antes de alterar arquivo existente: ler a versão atual e preservar
  comportamento (regra 7 do documento de design).

## 4. MAPA DOS ARQUIVOS (fim da Etapa 7)

```text
project.godot                     Main Scene = main_menu; Autoload GameManager;
                                  viewport 640×480 (janela 2x: 1280×960); filtro Nearest; [input] WASD+setas
icon.svg                          Ícone provisório
scenes/menu/main_menu.tscn        Menu (título via GameManager.DISPLAY_NAME)
scenes/character_creator/…tscn    Tela do personagem (herda DrawingCreatorBase)
scenes/ability_creator/…tscn      Tela da habilidade (+ PixelCountLabel, limite 100 px)
scenes/ui/pixel_editor.tscn       Componente de desenho (Canvas+Drawing+GridOverlay)
scenes/game/arena.tscn            Arena (Boundaries + instância do Player)
scenes/player/player.tscn         Player (Sprite2D c/ WalkAnimator, colisão r=26, câmera)
scripts/managers/game_manager.gd  Autoload (229 linhas)
scripts/drawing/pixel_editor.gd   Editor de pixels (319 linhas, class_name PixelEditor)
scripts/ui/drawing_creator_base.gd Base das telas de criação (paleta, pincel, undo)
scripts/ui/character_creator.gd   Fluxo do personagem (salva e vai p/ habilidade)
scripts/ui/ability_creator.gd     Fluxo da habilidade (limite px, vai p/ arena)
scripts/ui/main_menu.gd           Menu
scripts/game/arena.gd             Quadro, paredes procedurais, setup do player
scripts/player/player.gd          Movimento, sprite do desenho, câmera (class Player)
scripts/player/walk_animator.gd   Animação procedural (class WalkAnimator)
```

## 5. PLACEHOLDERS ATIVOS

- ESC na arena volta ao menu (vira menu de pausa na Etapa 19).
- Quadro branco via `_draw()` (Etapa 9 adiciona o PaintCanvas por cima;
  background definitivo virá do usuário depois).
- Fallback do Player: círculo cinza se não houver desenho (só em teste isolado).
- `icon.svg`, fontes e estilos de botões padrão da engine.
- Micro-limpeza opcional p/ Etapa 19: em `ability_creator.gd`, o fallback
  "A Arena será implementada na Etapa 5" nunca mais executa (inofensivo).

## 6. ASSETS QUE O USUÁRIO FORNECERÁ FUTURAMENTE

- Background definitivo da arena → `assets/backgrounds/`
- Logo/título, ícone definitivo → `assets/sprites/`
- Música/SFX → `assets/audio/`

### Resolução (13/08/2026, pedido do usuário)
- Projeto agora em 640×480 (janela abre em 2x = 1280×960, override
  removível). UI toda reprojetada: menu (título 32, botões 200×40),
  editores (grid 360px/célula 10, painel 232px, paleta 32px, fontes
  9-14), HUD compacto (fontes 12/8). PixelEditor: cell_pixels padrão 10.

### Assets JÁ RECEBIDOS e integrados (13/08/2026)
- `assets/fonts/press_start_2p.ttf` (Press Start 2P, licença OFL no
  arquivo ao lado) — fonte padrão de TODA a UI via project.godot
  ([gui] theme/custom_font). Fonte monoespaçada larga: se algum texto
  estourar, ajustar font_size na cena correspondente.
- `assets/sprites/enemies/slime.png` (2×3, 6 frames 256², COMMON, 8 fps)
- `assets/sprites/enemies/bola.png` (4×4, 14 frames, FAST, 14 fps)
- `assets/sprites/enemies/quadrado.png` (5×5, 23 frames, TANK, 16 fps)
- Fatiados em runtime (AtlasTexture → SpriteFrames com cache static em
  EnemyBase). trail_color extraída da cor real de cada sprite. Fallback
  procedural permanece caso uma folha suma. WalkAnimator não é mais
  usado nos inimigos (as animações já têm squash/rotação) — segue no player.

## 6.5 KNOCKBACK (13/08, pedido do usuário)
- Player: velocity = _input_velocity + _knockback (componentes
  separados; empurrão não suja controles nem o facing). Exports:
  knockback_strength=260, knockback_decay=900 (~0,3s de impulso).
- EnemyBase chama player.apply_knockback(global_position) junto do
  dano de contato — o jogador é lançado para longe do atacante,
  abrindo espaço para escapar de hordas.

## 7. ETAPA 19 — O QUE FOI FEITO (13/08/2026)

O usuário escolheu as 4 áreas via seleção múltipla; todas foram
implementadas na mesma sessão:

### 7.1 Menu de pausa real
- scenes/ui/pause_screen.tscn + script (mesmo padrão de
  ProgressionScreen: CanvasLayer process_mode=WHEN_PAUSED, layer=20).
  "PAUSADO" / CONTINUAR / MENU.
- arena.gd: _unhandled_input agora só faz pause_screen.open() — como
  a Arena tem process_mode padrão (PAUSABLE), ela já fica muda
  automaticamente durante QUALQUER pausa (progressão, criação de
  habilidade em partida, ou a própria PauseScreen), então nenhuma
  verificação extra de estado foi necessária.
- ARMADILHA EVITADA: MENU despausa (get_tree().paused = false) ANTES
  de trocar de cena — sem isso, o menu principal carregaria com a
  árvore pausada e os botões não responderiam a clique (paused não
  reseta sozinho entre cenas).

### 7.2 Balanceamento (wave_manager.gd)
- Ritmo de spawn agora ACELERA por wave (base_spawn_interval=0.6,
  spawn_interval_decrease_per_wave=0.02, piso min_spawn_interval=0.15)
  — sem isso, waves grandes (50+ inimigos lá pela wave 10) levavam
  30s+ só para terminar de nascer.
- Pesos de tipo de inimigo agora MUDAM por wave: base 50/30/20
  (comum/rápido/resistente, igual ao original) com deltas por wave
  (-0.015/+0.006/+0.009, soma zero) e piso min_type_weight=0.05 — a
  partida fica mais ameaçadora em VARIEDADE conforme avança, não só
  em número. Ex.: por volta da wave 40, a proporção vira ~4/47/49%.
- hp_scale_per_wave (10%/wave) e os danos base NÃO foram alterados —
  já validados em testes anteriores (ex.: "slime morre em 2 tiros,
  bola em 1, quadrado em 5" documentado na Etapa 10).

### 7.3 Feedback visual (2 correções em 13/08 após testes do usuário)
- Ajuste de tempo (1a tentativa, insuficiente sozinha):
  rise_duration 0.55->1.0s, opaque_fraction=0.6 (fica 100% visível
  por 0.6s antes de esmaecer), rise_distance 22->28.
- BUG REAL (2a correção, a que importava): DamageNumber animava a
  subida dentro do próprio _ready(), lendo `position.y` para
  calcular o alvo. Mas quem instancia o node faz add_child() ANTES
  de corrigir global_position — e add_child() chama _ready() de
  forma SÍNCRONA. Resultado: o tween calculava um alvo ABSOLUTO
  (0 - rise_distance) em vez de relativo à posição certa, e o
  número "saltava" da origem do mundo até o local do abate — um
  salto de milhares de pixels, não os ~28px pretendidos. Corrigido
  movendo o início da animação para dentro de setup(), que o
  spawner (EnemyBase._spawn_damage_number) já chamava DEPOIS de
  corrigir global_position — não precisou mudar nada em
  enemy_base.gd, só a ordem interna do DamageNumber.
### 7.3 Feedback visual
- scenes/ui/damage_number.tscn + script: número flutuante (sobe +
  esmaece, 0.55s) com CONTORNO preto no texto branco — legível sobre
  qualquer cor do quadro pintado. Nasce no grupo "effects_container"
  (novo node Effects na arena), com z_index=100 (sempre por cima).
- enemy_base.gd: take_damage() spawna o número; _die() agora tem uma
  pequena animação de encolher+esmaecer (0.15s, TRANS_BACK) antes do
  queue_free(), em vez de sumir seco.
- BUG EVITADO NA PRÓPRIA IMPLEMENTAÇÃO: como _die() virou assíncrono
  (await no tween), um piercing acertando o mesmo inimigo 2x no mesmo
  frame poderia chamar died.emit() duas vezes e o WaveManager contar
  a morte em dobro. Corrigido com guarda _is_dying em take_damage()
  (mesmo padrão que Player já usa com _is_dead) + collision_shape
  desabilitada (set_deferred) assim que a morte começa.

### 7.4 Limpeza final
- Duas mensagens de fallback desatualizadas corrigidas (referenciavam
  "Etapa 2" e "Etapa 5", que não fazem mais sentido pra quem olha o
  projeto hoje): main_menu.gd e ability_creator.gd. Ambas continuam
  sendo código defensivo válido (só executam se uma cena sumir do
  projeto) — só o TEXTO da mensagem foi atualizado.
- Varredura completa do projeto por "PLACEHOLDER"/"PROVISÓRIO"
  confirmou que tudo mais restante é fallback intencional e
  corretamente documentado (texturas placeholder para testes
  isolados com F6, visual procedural caso um sprite sheet suma) — não
  precisa de limpeza, é comportamento permanente do projeto.

## 7.5 BACKGROUND DO MENU/GAME OVER (13/08/2026, pós-roteiro)
- Claude não consegue rodar o Godot neste ambiente (sem engine/GPU),
  então uma captura real de partida não é possível por aqui. Em vez
  disso: assets/backgrounds/menu_blurred_scene.png foi COMPOSTO
  proceduralmente (Python/PIL) usando os sprites REAIS do usuário
  (slime/bola/quadrado) espalhados em grade jitterizada + trilhas de
  tinta nas cores EXATAS do jogo (mesmos hex de enemy_base.gd),
  desfocado (GaussianBlur r=13) e com contraste/saturação reduzidos.
- Aplicado nas DUAS telas (main_menu.tscn e game_over.tscn) como
  TextureRect (texture_filter=2 Linear -- override necessário, já
  que o projeto usa Nearest globalmente para a pixel art) +
  stretch_mode=6 (Keep Aspect Covered) + uma "Scrim" ColorRect
  semitransparente (mesma cor "papel" 0.96/0.96/0.94 a 60% de opacidade)
  por cima, garantindo legibilidade do texto (Labels de título não têm
  painel de fundo, diferente dos Buttons).
- Caminho pro usuário conseguir uma versão MAIS autêntica: jogar
  algumas waves de verdade, tirar um screenshot (ou gravar um clipe),
  e enviar -- Claude troca a textura ou ajusta a Scrim em cima do
  material real, sem precisar mexer em mais nada da cena.

## 7.6 FUNDO ANIMADO + FLUTUAÇÃO (13/08/2026, pós-roteiro)
- Pedido do usuário: "efeito de pêndulo" no fundo + "cores animadas"
  + título/subtítulo/botões "com efeito de flutuação".
- scripts/ui/animated_background.gd (class AnimatedBackground,
  extends TextureRect): balanço tipo pêndulo (rotação oscilante,
  ±1.8°, período 10s) + deriva de posição em vaivém (X e Y com
  períodos diferentes, 14s/9s, pra não parecer metrônomo). Fica
  DENTRO de um Control pai com clip_contents=true e é escalado
  120% (overscan_scale) maior que a tela — assim a rotação/deriva
  nunca revela bordas vazias, o clip corta a sobra.
- assets/shaders/hue_cycle.gdshader: ciclo de matiz (RGB->HSV,
  desloca H em vaivém via seno, HSV->RGB de volta) aplicado como
  ShaderMaterial no mesmo TextureRect — as cores do desenho deslizam
  devagar pelo espectro (±0.15 de matiz, ciclo de 20s), sem virar
  estroboscópio.
- scripts/ui/floating_element.gd (class FloatingElement, extends
  Control): reutilizável, anexado a TitleLabel + PlayButton +
  QuitButton (menu) e TitleLabel + WaveLabel + PlayAgainButton +
  MenuButton (game over). Soma um deslocamento vertical senoidal à
  posição que o VBoxContainer já calculou (capturada no 1o _process,
  nao em _ready -- o Container ainda nao terminou de posicionar
  nesse momento). Cada elemento tem phase_offset diferente (0.0 a
  1.9 rad) pra flutuarem fora de sincronia entre si.
- Reestruturação: Background deixou de ser o TextureRect direto e
  virou um Control "clipador" (clip_contents=true) com
  BackgroundTexture (o TextureRect animado) dentro. main_menu.gd/
  game_over.gd não referenciam Background diretamente, então a
  troca foi segura (confirmado antes de fechar).
- Claude não conseguiu pré-visualizar o resultado (é animação via
  shader + script, não uma imagem estática) -- a correção de sintaxe/
  referências foi verificada exaustivamente por script, mas o
  resultado visual final só é conferível rodando o projeto.

## 7.7 CANTOS PIXEL ART + TRANSICOES DE CENA (13/08/2026, pós-roteiro)
- Pedido do usuário: aproveitar o "sentimento retrô" do pêndulo —
  cantos circulares em pixel art (não curvas suaves) em botões/caixas
  + transições animadas entre cenas.

### Cantos pixel art (tema global)
- assets/ui/{panel_pixel,button_normal,button_hover,button_pressed}.png:
  tiles 32x32 gerados por PIL (staircase de 5 degraus, borda 4px,
  script fora do projeto -- não fica salvo aqui, só o resultado).
- assets/ui/theme.tres: Theme global com StyleBoxTexture (9-slice,
  texture_margin=8) para Button (normal/hover/pressed/hover_pressed/
  disabled) e PanelContainer (panel). Aplicado em project.godot
  [gui] theme/custom -- MUDA TODOS os botões/painéis do projeto de
  uma vez só (menu, game over, progressão, pausa, HUD, criadores).
  Coexiste com theme/custom_font (fonte) sem conflito -- o theme.tres
  não define nenhum item de fonte, só estilos de caixa.
- Removidos os StyleBoxFlat locais (cantos suave/corner_radius) de
  hud.tscn, progression_screen.tscn, pause_screen.tscn -- agora
  herdam do tema global.
- drawing_creator_base.gd: paleta de cores migrada de StyleBoxFlat
  (corner_radius=6) para StyleBoxTexture com textura gerada em
  RUNTIME (Image/ImageTexture, mesmo padrão já usado em
  enemy_base.gd/player.gd) -- staircase de 3 degraus, tile 16x16,
  proporcional ao design dos botões/painéis maiores. Border normal
  (sutil) vs selecionado (escuro) preservados, largura de borda fixa
  (a variação de espessura por estado foi trocada por variação de
  cor, já que a forma agora vem de uma textura, não de um StyleBox
  paramétrico).
- Texture_filter: nada precisou de override explícito -- o projeto
  já tem default_texture_filter=0 (Nearest) global, então os novos
  StyleBoxTexture herdam nearest automaticamente (crisp, sem blur).

### Transições de cena
- assets/shaders/pixel_dissolve.gdshader: dither ordenado (matriz de
  Bayer 4x4) -- cobre/revela a tela em BLOCOS pixelados (uniform
  pixel_size, padrão 6.0) em vez de um fade liso, no espírito 8-bit.
- scripts/managers/transition_manager.gd (NOVO AUTOLOAD, registrado
  em project.godot junto do GameManager): CanvasLayer persistente
  (layer=1000, process_mode=ALWAYS) com um ColorRect+ShaderMaterial.
  play_transition(callback): cobre (tween 0->1, 0.28s) -> executa o
  callback (a troca de cena de verdade) -> aguarda 1 frame -> revela
  (tween 1->0, 0.28s).
- GameManager.change_scene() agora chama
  TransitionManager.play_transition() envolvendo o
  get_tree().change_scene_to_file() real, em vez de trocar
  diretamente. Retorno de change_scene()/go_to_*() continua
  significando "a cena existe e a transição foi iniciada" (síncrono),
  não mais "a troca já aconteceu" (a troca em si é assíncrona,
  acontece no pico da cobertura) -- nenhum chamador existente
  dependia de troca síncrona, conferido antes de aplicar.
- Nenhuma tela precisou de mudança própria -- é tudo centralizado no
  GameManager, então toda troca de cena do jogo (menu->criador->
  criador->arena->game over->menu, e pausa->menu) ganhou a transição
  automaticamente.

### O que Claude não conseguiu verificar
- Cantos pixel art: só PRÉ-VISUALIZADOS como PNG estático (confirmado
  visualmente, ver corner_preview.png gerado durante a sessão -- não
  faz parte do projeto). O RESULTADO em botões/painéis reais (via
  StyleBoxTexture 9-slice) só é conferível rodando o Godot.
- Transições: shader + animação, não há como pré-visualizar sem rodar
  o projeto.

## 7.8 CORREÇÃO DE CONTRASTE + SALVAR CENÁRIO (13/08/2026, pós-roteiro)

### Correção: texto dos botões ilegível
- CAUSA: o tema global (Etapa anterior) trocou só o FUNDO dos botões
  (StyleBoxTexture claro), mas nunca definiu Button/colors/font_color
  -- o texto continuava herdando a cor clara do tema padrão embutido
  da Godot (pensado pra fundo escuro). Resultado: texto claro sobre
  fundo claro.
- CORREÇÃO: assets/ui/theme.tres ganhou font_color/font_hover_color/
  font_pressed_color/font_focus_color/font_disabled_color, todos
  escuros (~0.05-0.15), consistente com o resto da paleta "papel
  claro + tinta escura" do projeto.

### Salvar cenário (feature nova)
- DESAFIO CENTRAL: a Arena (com o PaintCanvas) é DESTRUÍDA na troca
  de cena pro Game Over -- não dava pra "voltar e salvar depois" sem
  preservar os dados antes disso acontecer.
- SOLUÇÃO: PaintCanvas.get_image_copy() (novo) + Arena conecta
  player.died (que dispara ~2s ANTES da troca de cena de verdade,
  dentro do delay de fade do Player._die()) a
  _on_player_died_capture_canvas(), que chama
  GameManager.set_last_canvas_snapshot(paint_canvas.get_image_copy()).
  Essa é a ÚNICA janela em que a Arena ainda existe para ser lida.
- GameManager ganhou: last_canvas_snapshot (Image), last_saved_
  scenario_path (String, caminho ABSOLUTO do SO via
  ProjectSettings.globalize_path, pra mostrar ao jogador onde achar o
  arquivo de verdade), has_last_canvas_snapshot(),
  get_last_canvas_texture(), save_last_canvas_to_disk() (salva em
  user://saved_scenarios/scenario_<unix_timestamp>.png -- nome
  sempre novo, nunca sobrescreve saves anteriores). reset_run_data()
  limpa o snapshot ao iniciar uma nova run.
- Botão SALVAR CENÁRIO no Game Over (entre JOGAR NOVAMENTE e MENU):
  salva em disco (síncrono) e navega para a nova cena
  scenes/ui/scenario_viewer.tscn -- "QUADRO FINAL", fundo escuro tipo
  galeria (proposital, contrasta com o pêndulo animado do menu: aqui
  o quadro pintado é o protagonista), o quadro emoldurado no estilo
  pixelado (herda o tema global de PanelContainer automaticamente),
  caminho do arquivo exibido embaixo. ESC volta ao Game Over (rota
  normal, dissolução padrão).
- TRANSIÇÃO DIFERENTE (pedido do usuário -- flash de câmera, não a
  dissolução retrô): TransitionManager ganhou play_flash_transition()
  (branco quase instantâneo 0.06s + esmaecimento 0.45s), usada SÓ
  nesta navegação -- chamada diretamente por game_over.gd (não passa
  por GameManager.change_scene(), que sempre usa a dissolução).
- SCENE_SCENARIO_VIEWER adicionado às constantes de cena do
  GameManager, mas SEM um go_to_scenario_viewer() -- a navegação
  desse caso específico é montada manualmente em game_over.gd junto
  do flash, propositalmente, pra não misturar as duas transições na
  mesma API.

## 7.9 CORRECOES: WARNING DE SOMBREAMENTO + SALVAR CENARIO NA WEB (13/08/2026)

### Warning "size shadowing Control.size"
- drawing_creator_base.gd:124 declarava `var size: int` dentro de uma
  classe que extends Control (que já tem a propriedade size: Vector2)
  -- renomeado para tile_size em toda a função _make_swatch_texture.

### Salvar cenário: NAO funciona de forma confiável num embed itch.io
- PESQUISADO A FUNDO (usuário perguntou se funcionaria publicando via
  embed no itch.io, não só como download): confirmado que user:// no
  export Web da Godot é um filesystem VIRTUAL via IndexedDB, não o
  disco real. Documentação oficial da Godot confirma isso
  explicitamente. Pior: especificamente dentro de IFRAME de terceiros
  (que é como o itch.io hospeda jogos embutidos), navegadores modernos
  costumam BLOQUEAR esse armazenamento por padrão (proteção contra
  rastreio de terceiros) -- confirmado com relatos reais de
  desenvolvedores no fórum do itch.io descrevendo exatamente esse
  problema (autosave que funciona no domínio próprio mas quebra no
  itch.io; erro "nao foi possivel abrir o banco de dados local" em
  modo anonimo/com cookies de terceiros bloqueados).
- CORRIGIDO: GameManager.save_last_canvas_to_disk() agora detecta
  OS.has_feature("web") e, nesse caso, usa
  JavaScriptBridge.download_buffer() (API oficial da Godot para isso,
  documentada especificamente para esse cenário) -- aciona o DOWNLOAD
  REAL do navegador (mecanismo de Blob, não IndexedDB), que NAO sofre
  do mesmo bloqueio de armazenamento de terceiros. Precisa ser
  chamado a partir de uma interação do usuário (nosso caso: clique no
  botão SALVAR CENÁRIO) -- confirmado que já é assim.
- last_saved_scenario_path agora contém a mensagem completa e pronta
  pra exibir em qualquer plataforma ("Salvo em: <caminho do SO>" no
  desktop; "Baixado pelo navegador: <nome do arquivo>" na Web) --
  scenario_viewer.gd só exibe o valor direto, sem prefixo duplicado.
- IMPORTANTE: Claude não tem como testar um export Web real neste
  ambiente (sem Godot/navegador) -- a implementação segue a API
  oficial documentada e o padrão de código recomendado pela própria
  Godot, mas o usuário deve validar ao publicar de verdade no
  itch.io.

## 7.10 FINALIZAÇÃO PARA PUBLICAÇÃO (13/08/2026)

Usuário avisou que NÃO enviará mais nenhum asset (só os sprites de
inimigos já recebidos) e pediu para resolver por conta própria tudo
que dependesse de asset externo, além de renomear o jogo.

### Renomeação: Rogue Doodle → Blank Canvas
- GameManager.DISPLAY_NAME (fonte única da verdade, usada pelo menu).
- project.godot: config/name e config/description.
- main_menu.tscn: texto padrão do TitleLabel (cosmético — o real vem
  de DISPLAY_NAME em runtime).
- Pasta raiz do projeto renomeada de rogue_doodle/ para
  blank_canvas/ (puramente cosmético — Godot usa res://, não depende
  do nome da pasta no SO). ZIP de saída: Blank_Canvas.zip.
- Confirmado por grep: nenhuma ocorrência de "Rogue Doodle" restante
  em nenhum arquivo do projeto.

### Ícone final (icon.svg)
- Trocado o ícone provisório (lápis) por um novo, temático a "Blank
  Canvas": quadro branco emoldurado com 3 traços de pincel nas CORES
  REAIS do jogo (azul/verde/vermelho dos rastros de inimigos).
  Caminho já configurado (config/icon) não mudou, só o conteúdo.
- Renderizado via cairosvg pra conferência visual antes de fechar.

### Fundo da arena: de placeholder pra design final
- Com o nome oficial virando "Blank Canvas", o quadro branco simples
  deixou de ser um placeholder capenga e virou literalmente o
  conceito do jogo — só precisava de acabamento.
- NOVO: scripts/game/board_canvas.gd (class BoardCanvas extends
  Sprite2D) + assets/shaders/canvas_board.gdshader + 
  assets/backgrounds/canvas_grain.png (tile 96x96, textura de trama/
  grão de tela gerada por PIL, seamless por construção — ruído
  independente por pixel não tem costura).
- O shader tileia o grão (fract(UV * tile_count), sem custo de gerar
  uma imagem 4096x4096) e desenha a borda + sombra interna sutil, tudo
  em GPU — substituiu o antigo Arena._draw()/queue_redraw() (removido
  por completo, junto dos exports board_color/board_border_color).
- BoardCanvas.setup(arena_size) chamado no Arena._ready(), mesmo
  padrão do PaintCanvas.setup().

### Áudio: de vazio pra 4 efeitos sintetizados
- assets/audio/ estava completamente vazio (nenhum som no jogo
  inteiro). Gerados via síntese procedural (Python stdlib puro: wave
  + struct + math, sem dependências) -- ondas quadrada/triangular
  com envelope (ataque rápido + decaimento), estilo chiptune 8-bit,
  combinando com o resto da identidade visual retrô já construída:
    click.wav          (900Hz, 0.05s) -- clique de UI
    hit.wav             (520->240Hz, 0.08s) -- inimigo tomou dano
    enemy_death.wav      (620->70Hz, 0.18s, + ruido leve) -- morte
    player_hurt.wav      (220->130Hz triangular, 0.12s) -- jogador tomou dano
  Verificado tecnicamente: zero amostras clipadas em todos os 4
  arquivos, WAV 16-bit mono 22050Hz válido. NÃO verificado
  perceptualmente -- Claude não tem como OUVIR o resultado neste
  ambiente; só a validade técnica do arquivo foi confirmada.
- NOVO AUTOLOAD scripts/managers/audio_manager.gd: toca cada som
  instanciando um AudioStreamPlayer descartável
  (queue_free ao terminar). Clique de UI é conectado
  AUTOMATICAMENTE a QUALQUER Button do jogo via
  get_tree().node_added -- zero mudanças em qualquer .tscn existente,
  inclusive botões futuros herdam o som sem trabalho extra.
- Ganchos de gameplay: enemy_base.gd (take_damage -> play_hit;
  _die -> play_enemy_death), player.gd (take_damage ->
  play_player_hurt). Registrado como 3o autoload em project.godot.

### O que ficou de fora (deliberadamente)
- Música de fundo: não foi gerada -- síntese de música (não apenas
  efeitos curtos) é um problema muito mais complexo; mencionado ao
  usuário como algo a decidir depois, não assumido silenciosamente.

## 7.11 LOCALIZAÇÃO PT-BR/INGLÊS (21/08/2026)

- Novo Autoload `LocalizationManager`: centraliza todos os textos visíveis
  em inglês e português brasileiro, emite `language_changed` e guarda a
  escolha do jogador em `user://settings.cfg`.
- Inglês é o padrão de uma instalação sem configuração salva, incluindo
  textos estáticos das cenas; depois de escolhida, a preferência de idioma é
  preservada entre execuções.
- Menu principal ganhou um botão de globo no canto superior direito. Ele abre
  um painel curto com as opções ENGLISH e PORTUGUÊS; a tela atual é atualizada
  assim que uma opção é escolhida.
- Todos os fluxos de UI foram cobertos: menu, criadores de personagem e
  habilidade (incluindo feedback e contador), HUD, pausa, progressão,
  upgrades, game over e visualizador/salvamento do quadro.
- `README.md` e a descrição do projeto também passaram para inglês, para que a
  página pública e os metadados acompanhem o idioma padrão do jogo.
- `GameManager` agora guarda apenas o caminho/nome bruto do último quadro
  salvo e deixa a frase que o exibe para o `LocalizationManager`; assim a
  mensagem também acompanha o idioma selecionado.
- Arquivos novos: `scripts/managers/localization_manager.gd` e
  `scripts/ui/language_button.gd`. O ícone de globo é desenhado por código,
  sem necessidade de asset externo.

## 8. IDEIAS PARA ITERAÇÃO FUTURA (não é uma "próxima etapa" — o
## roteiro original terminou; isto é só uma lista de sugestões)

- Assets finais do usuário: background definitivo da arena, vídeo
  desfocado para menu/game over (Background de ambas as telas já é
  um ColorRect simples, trocável por VideoStreamPlayer sem tocar no
  resto da cena), ícone definitivo do projeto.
- Playtesting real para ajustar os números de balanceamento (todos
  exportados/configuráveis).
- Object pooling para os números de dano/projéteis, se algum dia o
  perfil de performance pedir (hoje instanciar/destruir é barato o
  bastante para as quantidades do jogo).
- Sons e música (assets/audio/ ainda vazio).
- Camera shake sutil em hits grandes, como possível reforço extra de
  feedback visual.

---

*Gerado ao final da sessão de 12/08/2026, após revisão de consistência
(referências cena↔script íntegras; sem resíduos de código provisório removido).*
