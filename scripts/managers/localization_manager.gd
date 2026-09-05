extends Node


signal language_changed


const DEFAULT_LANGUAGE: String = "en"
const SETTINGS_SECTION: String = "language"
const SETTINGS_KEY: String = "code"

const TRANSLATIONS: Dictionary = {
	"en": {
		"language.tooltip": "Change language",
		"language.title": "LANGUAGE",
		"language.english": "ENGLISH",
		"language.portuguese": "PORTUGUÊS",
		"menu.play": "PLAY",
		"menu.quick_play": "QUICK PLAY",
		"menu.quick_play_tooltip": "Your last drawing",
		"menu.quick_play_error": "Could not load the last drawing. Use PLAY to draw a new one.",
		"menu.best_wave": "BEST WAVE: %d",
		"menu.quit": "QUIT",
		"menu.character_creator_error": "Could not open Character Creator. Check the project files.",
		"audio.tooltip": "Sound",
		"audio.title": "SOUND",
		"audio.volume": "VOLUME: %d%%",
		"audio.mute": "MUTE",
		"audio.unmute": "UNMUTE",
		"creator.character_title": "CREATE YOUR CHARACTER",
		"creator.ability_title": "DRAW YOUR ABILITY",
		"creator.colors": "COLORS",
		"creator.brush": "BRUSH: %d",
		"creator.eraser": "ERASER",
		"creator.clear": "CLEAR",
		"creator.undo": "UNDO",
		"creator.redo": "REDO",
		"creator.confirm": "CONFIRM",
		"creator.back_menu": "BACK TO MENU",
		"creator.back_character": "BACK TO CHARACTER",
		"creator.cancel": "CANCEL",
		"creator.pixels": "OUTLINE: %d / %d",
		"creator.canvas_cleared": "Canvas cleared. Use UNDO to restore it.",
		"creator.draw_character_first": "Draw something before confirming!",
		"creator.character_loaded": "Previous drawing loaded. Edit it or confirm to continue.",
		"creator.draw_new_ability": "Draw your new ability!",
		"creator.draw_ability_first": "Draw your ability before confirming!",
		"creator.ability_too_large": "Outline too large: %d / %d. Only the outline counts — filling it in is free.",
		"creator.arena_error": "Could not open the Arena. Check that scenes/game/arena.tscn exists.",
		"creator.ability_loaded": "Previous ability loaded. Edit it or confirm to continue.",
		"hud.hp": "HP: %d / %d",
		"hud.wave": "WAVE: %d",
		"hud.enemies": "ENEMIES: %d",
		"pause.title": "PAUSED",
		"pause.resume": "RESUME",
		"pause.restart": "RESTART",
		"pause.menu": "MENU",
		"progression.wave_complete": "WAVE %d COMPLETE!",
		"progression.choose_path": "CHOOSE YOUR PATH",
		"progression.upgrade_ability": "UPGRADE ABILITY",
		"progression.upgrade_info": "CHOOSE 1 OF 3 RANDOM UPGRADES",
		"progression.new_ability": "CREATE NEW ABILITY",
		"progression.new_ability_info": "DRAW A NEW PROJECTILE (MAX 100 PIXELS)",
		"progression.choose_upgrade": "CHOOSE AN UPGRADE",
		"progression.back": "BACK",
		"upgrade.damage": "DAMAGE +25%",
		"upgrade.cooldown": "COOLDOWN -15%",
		"upgrade.count": "+1 PROJECTILE",
		"upgrade.size": "SIZE +20%",
		"upgrade.pierce": "PIERCE +1",
		"upgrade.speed": "SPEED +15%",
		"upgrade.range": "RANGE +10%",
		"ability.name": "ABILITY %d",
		"game_over.wave_reached": "WAVE REACHED: %d",
		"game_over.best_wave": "BEST: %d",
		"game_over.new_record": "NEW RECORD!",
		"game_over.retry": "RETRY",
		"game_over.new_drawing": "NEW DRAWING",
		"game_over.save_scenario": "SAVE CANVAS",
		"game_over.menu": "MENU",
		"scenario.final_canvas": "FINAL CANVAS",
		"scenario.no_canvas": "NO CANVAS AVAILABLE",
		"scenario.press_escape": "PRESS ESC TO GO BACK",
		"scenario.saved_to": "SAVED TO: %s",
		"scenario.downloaded": "DOWNLOADED BY BROWSER: %s",
	},
	"pt_BR": {
		"language.tooltip": "Mudar idioma",
		"language.title": "IDIOMA",
		"language.english": "INGLÊS",
		"language.portuguese": "PORTUGUÊS",
		"menu.play": "JOGAR",
		"menu.quick_play": "JOGO RÁPIDO",
		"menu.quick_play_tooltip": "Seu último desenho",
		"menu.quick_play_error": "Não foi possível carregar o último desenho. Use JOGAR para desenhar outro.",
		"menu.best_wave": "MELHOR WAVE: %d",
		"menu.quit": "SAIR",
		"menu.character_creator_error": "Não foi possível abrir o Criador de Personagem. Verifique os arquivos do projeto.",
		"audio.tooltip": "Som",
		"audio.title": "SOM",
		"audio.volume": "VOLUME: %d%%",
		"audio.mute": "MUDO",
		"audio.unmute": "COM SOM",
		"creator.character_title": "CRIE SEU PERSONAGEM",
		"creator.ability_title": "DESENHE SUA HABILIDADE",
		"creator.colors": "CORES",
		"creator.brush": "PINCEL: %d",
		"creator.eraser": "BORRACHA",
		"creator.clear": "LIMPAR",
		"creator.undo": "DESFAZER",
		"creator.redo": "REFAZER",
		"creator.confirm": "CONFIRMAR",
		"creator.back_menu": "VOLTAR AO MENU",
		"creator.back_character": "VOLTAR AO PERSONAGEM",
		"creator.cancel": "CANCELAR",
		"creator.pixels": "CONTORNO: %d / %d",
		"creator.canvas_cleared": "Quadro limpo. Use DESFAZER para recuperar.",
		"creator.draw_character_first": "Desenhe algo antes de confirmar!",
		"creator.character_loaded": "Desenho anterior carregado. Edite ou confirme para continuar.",
		"creator.draw_new_ability": "Desenhe sua nova habilidade!",
		"creator.draw_ability_first": "Desenhe sua habilidade antes de confirmar!",
		"creator.ability_too_large": "Contorno grande demais: %d / %d. Só o contorno conta — preencher é de graça.",
		"creator.arena_error": "Não foi possível abrir a arena. Verifique se scenes/game/arena.tscn existe no projeto.",
		"creator.ability_loaded": "Habilidade anterior carregada. Edite ou confirme para continuar.",
		"hud.hp": "HP: %d / %d",
		"hud.wave": "WAVE: %d",
		"hud.enemies": "INIMIGOS: %d",
		"pause.title": "PAUSADO",
		"pause.resume": "CONTINUAR",
		"pause.restart": "REINICIAR",
		"pause.menu": "MENU",
		"progression.wave_complete": "WAVE %d CONCLUÍDA!",
		"progression.choose_path": "ESCOLHA SEU CAMINHO",
		"progression.upgrade_ability": "MELHORAR HABILIDADE",
		"progression.upgrade_info": "ESCOLHA 1 ENTRE 3 UPGRADES SORTEADOS",
		"progression.new_ability": "CRIAR NOVA HABILIDADE",
		"progression.new_ability_info": "DESENHE UM NOVO PROJÉTIL (MÁX. 100 PIXELS)",
		"progression.choose_upgrade": "ESCOLHA UM UPGRADE",
		"progression.back": "VOLTAR",
		"upgrade.damage": "DANO +25%",
		"upgrade.cooldown": "RECARGA -15%",
		"upgrade.count": "+1 PROJÉTIL",
		"upgrade.size": "TAMANHO +20%",
		"upgrade.pierce": "PERFURAÇÃO +1",
		"upgrade.speed": "VELOCIDADE +15%",
		"upgrade.range": "ALCANCE +10%",
		"ability.name": "HAB. %d",
		"game_over.wave_reached": "WAVE ALCANÇADA: %d",
		"game_over.best_wave": "RECORDE: %d",
		"game_over.new_record": "NOVO RECORDE!",
		"game_over.retry": "TENTAR DE NOVO",
		"game_over.new_drawing": "NOVO DESENHO",
		"game_over.save_scenario": "SALVAR QUADRO",
		"game_over.menu": "MENU",
		"scenario.final_canvas": "QUADRO FINAL",
		"scenario.no_canvas": "NENHUM QUADRO DISPONÍVEL",
		"scenario.press_escape": "PRESSIONE ESC PARA VOLTAR",
		"scenario.saved_to": "SALVO EM: %s",
		"scenario.downloaded": "BAIXADO PELO NAVEGADOR: %s",
	},
}


var language_code: String = DEFAULT_LANGUAGE


func _ready() -> void:
	_load_saved_language()
	TranslationServer.set_locale(language_code)


func text(key: String, values: Array = []) -> String:
	var language: Dictionary = TRANSLATIONS.get(language_code, TRANSLATIONS[DEFAULT_LANGUAGE])
	var translated: String = language.get(key, TRANSLATIONS[DEFAULT_LANGUAGE].get(key, key))
	return translated if values.is_empty() else translated % values


func set_language(new_language_code: String) -> void:
	if not TRANSLATIONS.has(new_language_code) or new_language_code == language_code:
		return
	language_code = new_language_code
	TranslationServer.set_locale(language_code)
	_save_language()
	language_changed.emit()


func is_language_selected(candidate_language_code: String) -> bool:
	return language_code == candidate_language_code


func _load_saved_language() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(GameManager.SETTINGS_PATH) != OK:
		return
	var saved_language: String = settings.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LANGUAGE)
	if TRANSLATIONS.has(saved_language):
		language_code = saved_language


func _save_language() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(GameManager.SETTINGS_PATH)
	settings.set_value(SETTINGS_SECTION, SETTINGS_KEY, language_code)
	var save_error: int = settings.save(GameManager.SETTINGS_PATH)
	if save_error != OK:
		push_warning("[LocalizationManager] Não foi possível salvar o idioma selecionado (erro %d)." % save_error)
