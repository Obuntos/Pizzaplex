class_name TracoParedePlex
extends RefCounted

var ativo: bool = false
var anterior := Vector2i.ZERO
var visitadas: Dictionary = {}

func iniciar(celula: Vector2i, editor: EditorPlex) -> void:
	encerrar()
	ativo = true
	anterior = celula
	pintar(celula, editor)

func pintar(celula: Vector2i, editor: EditorPlex) -> void:
	if visitadas.has(celula) or not GradePlex.dentro(celula):
		return
	visitadas[celula] = true
	if editor.planta.em(celula).is_empty():
		editor.aplicar(celula)

func estender(celula: Vector2i, editor: EditorPlex) -> void:
	if not ativo or CatalogoPlex.base(editor.ferramenta) != "parede" or editor.ferramenta.begins_with("janela") or not GradePlex.dentro(celula):
		return
	var inicio := anterior
	var bloqueados := editor.planta.is_blocking_signals()
	var quantidade := editor.planta.objetos.size()
	editor.planta.set_block_signals(true)
	var diferenca := celula - inicio
	var dx := absi(diferenca.x)
	var dy := absi(diferenca.y)
	var x: int = 0
	var y: int = 0
	var ponto := inicio
	while x < dx or y < dy:
		if x < dx and (y >= dy or (1 + 2 * x) * dy <= (1 + 2 * y) * dx):
			ponto.x += signi(diferenca.x)
			x += 1
		else:
			ponto.y += signi(diferenca.y)
			y += 1
		pintar(ponto, editor)
	anterior = celula
	editor.planta.set_block_signals(bloqueados)
	if not bloqueados and editor.planta.objetos.size()!=quantidade:
		editor.planta.alterada.emit()

func encerrar() -> void:
	ativo = false
	visitadas.clear()

