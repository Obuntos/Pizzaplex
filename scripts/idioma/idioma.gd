extends Node

signal idioma_alterado(locale: String)

const CAMINHO_TRADUCOES = "res://dados/traducoes_en.json"
const CAMINHO_PREFERENCIAS = "user://idioma.cfg"
const MODOS = ["automatico", "pt_BR", "en"]
var modo = "automatico"
var traducao_ingles: Translation

func _ready() -> void:
	carregar_traducoes()
	var config := ConfigFile.new()
	if config.load(CAMINHO_PREFERENCIAS) == OK:
		var preferencia := str(config.get_value("idioma", "modo", "automatico"))
		if preferencia in MODOS:
			modo = preferencia
	aplicar()

func carregar_traducoes() -> void:
	if not FileAccess.file_exists(CAMINHO_TRADUCOES):
		push_warning("Dicionario de ingles nao encontrado.")
		return
	var conteudo := FileAccess.get_file_as_string(CAMINHO_TRADUCOES)
	var dados = JSON.parse_string(conteudo)
	if typeof(dados) != TYPE_DICTIONARY:
		push_warning("Dicionario de ingles invalido.")
		return
	traducao_ingles = Translation.new()
	traducao_ingles.locale = "en"
	for origem in dados:
		traducao_ingles.add_message(StringName(str(origem)), StringName(str(dados[origem])))

func idioma_do_sistema() -> String:
	return "en" if OS.get_locale_language().to_lower() == "en" else "pt_BR"

func idioma_atual() -> String:
	return idioma_do_sistema() if modo == "automatico" else modo

func aplicar() -> void:
	var locale := idioma_atual()
	if traducao_ingles != null:
		var presentes := TranslationServer.get_translations()
		if locale == "en" and not presentes.has(traducao_ingles):
			TranslationServer.add_translation(traducao_ingles)
		elif locale != "en" and presentes.has(traducao_ingles):
			TranslationServer.remove_translation(traducao_ingles)
	var anterior := TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	if anterior == locale:
		get_tree().root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	idioma_alterado.emit(locale)

func definir_modo(novo_modo: String) -> void:
	if novo_modo not in MODOS:
		return
	modo = novo_modo
	var config := ConfigFile.new()
	config.set_value("idioma", "modo", modo)
	var erro := config.save(CAMINHO_PREFERENCIAS)
	if erro != OK:
		push_warning("Nao foi possivel salvar o idioma selecionado.")
	aplicar()

func traduzir(texto: String) -> String:
	return str(TranslationServer.translate(StringName(texto)))

func atualizar_seletor(seletor: OptionButton) -> void:
	if not is_instance_valid(seletor):
		return
	seletor.set_item_text(0, traduzir("Automático"))
	seletor.set_item_text(1, "Português (Brasil)")
	seletor.set_item_text(2, "English")
	seletor.select(MODOS.find(modo))

func criar_seletor(pai: Node) -> OptionButton:
	var seletor := OptionButton.new()
	seletor.custom_minimum_size.y = 38
	seletor.add_item("Automático")
	seletor.add_item("Português (Brasil)")
	seletor.add_item("English")
	pai.add_child(seletor)
	atualizar_seletor(seletor)
	seletor.item_selected.connect(func(indice: int): definir_modo(str(MODOS[indice])))
	var referencia: WeakRef = weakref(seletor)
	idioma_alterado.connect(func(_locale: String): atualizar_seletor(referencia.get_ref()))
	return seletor
