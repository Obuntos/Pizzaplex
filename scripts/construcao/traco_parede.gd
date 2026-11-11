class_name TracoParedePlex
extends RefCounted

var mudancas := 0
var ativo: bool = false
var anterior := Vector2i.ZERO
var visitadas: Dictionary = {}
var inicio_pintura:=Vector2i.ZERO
var tempo_pressionado:=0.0
var arrastou:=false
var preencheu:=false
var area_preenchimento:Array[Vector2i]=[]
var editor_pintura:EditorPlex

static func aceita(editor: EditorPlex) -> bool:
	return editor.item_movendo<0 and (PinturaPisosPlex.eh(editor.ferramenta) or CatalogoPlex.base(editor.ferramenta)=="parede" and not editor.ferramenta.begins_with("janela"))

func iniciar(celula: Vector2i, editor: EditorPlex) -> void:
	encerrar()
	if not editor.permitido(celula):
		editor.aviso.emit("Construa apenas dentro do terreno do restaurante. Os tiles vermelhos marcam o limite.")
		return
	if not aceita(editor): return
	ativo = true
	inicio_pintura=celula;tempo_pressionado=0.0;arrastou=false;preencheu=false
	anterior = celula
	if PinturaPisosPlex.eh(editor.ferramenta):
		editor_pintura=editor;editor.pintura_ativa=true;editor.pintura_acao={}
		area_preenchimento=PinturaPisosPlex.sala(editor.planta,celula)
	pintar(celula, editor)

func pintar(celula: Vector2i, editor: EditorPlex) -> void:
	if visitadas.has(celula) or not GradePlex.dentro(celula) or not editor.permitido(celula):
		return
	visitadas[celula] = true
	if PinturaPisosPlex.eh(editor.ferramenta):
		mudancas+=PinturaPisosPlex.aplicar(editor,[celula])
		return
	if editor.planta.em(celula).is_empty() or SubstituicaoParedesPlex.permite(editor.planta,editor.ferramenta,celula):
		var antes:=hash(editor.planta.em(celula))
		editor.aplicar(celula)
		if antes!=hash(editor.planta.em(celula)): mudancas+=1

func estender(celula: Vector2i, editor: EditorPlex) -> void:
	if not ativo or celula==anterior or not aceita(editor) or not GradePlex.dentro(celula):
		return
	if celula!=inicio_pintura: arrastou=true
	var inicio := anterior
	var bloqueados := editor.planta.is_blocking_signals()
	var quantidade := mudancas
	editor.planta.set_block_signals(true)
	var diferenca := celula - inicio
	var dx := absi(diferenca.x)
	var dy := absi(diferenca.y)
	var x: int = 0
	var y: int = 0
	var locais: Array[Vector2i]=[]
	var ponto := inicio
	while x < dx or y < dy:
		if x < dx and (y >= dy or (1 + 2 * x) * dy <= (1 + 2 * y) * dx):
			ponto.x += signi(diferenca.x)
			x += 1
		else:
			ponto.y += signi(diferenca.y)
			y += 1
		if PinturaPisosPlex.eh(editor.ferramenta):
			if not visitadas.has(ponto) and editor.permitido(ponto):
				visitadas[ponto]=true;locais.append(ponto)
		else: pintar(ponto, editor)
	anterior = celula
	editor.planta.set_block_signals(bloqueados)
	if not locais.is_empty(): mudancas+=PinturaPisosPlex.aplicar(editor,locais)
	if not bloqueados and mudancas!=quantidade and not PinturaPisosPlex.eh(editor.ferramenta):
		editor.planta.alterada.emit()

func atualizar(delta: float, editor: EditorPlex) -> void:
	if not ativo or arrastou or preencheu or not PinturaPisosPlex.eh(editor.ferramenta): return
	tempo_pressionado+=delta
	if tempo_pressionado>=.55:
		preencheu=true
		mudancas+=PinturaPisosPlex.aplicar(editor,area_preenchimento)

func encerrar() -> void:
	if editor_pintura!=null:editor_pintura.pintura_ativa=false;editor_pintura.pintura_acao={};editor_pintura=null
	area_preenchimento.clear()
	ativo = false
	visitadas.clear()


