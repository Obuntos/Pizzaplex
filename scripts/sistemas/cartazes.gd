class_name CartazesPlex
extends RefCounted

const DESBOTA:=10
const RASGA:=25
const PRECO:=8
var jogo:Node
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
static func eh(o:Dictionary) -> bool:return bool(MobiliaPlex.dados(o).get("cartaz_envelhece",false))
func dia() -> int:return int(jogo.calendario.dias)

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<3.0:return
	espera=0.0
	var mudou:=false
	for o in jogo.planta.objetos.values():
		if not eh(o):continue
		if not o.has("cartaz_dia"):o.cartaz_dia=dia()
		var idade:=dia()-int(o.cartaz_dia)
		var estado:="rasgado" if idade>=RASGA else "desbotado" if idade>=DESBOTA else "novo"
		if str(o.get("estado",""))!=estado:o.estado=estado;mudou=true
	if mudou:jogo.planta.alterada.emit()

func restaurar(o:Dictionary) -> void:
	if not jogo.editor.cobrar(PRECO):return
	o.cartaz_dia=dia();o.estado="novo"
	jogo.planta.alterada.emit()

func opcoes(menu:CanvasLayer,o:Dictionary) -> void:
	if not eh(o) or str(o.get("estado","novo"))=="novo":return
	menu.adicionar("Restaurar · US$ %d"%PRECO,func():restaurar(o))

func morte(celula:Vector2i) -> void:
	var sala:Dictionary=jogo.ambientes.em(celula)
	if str(sala.get("tipo",""))!="armazem_robos":return
	var mudou:=false
	for o in jogo.planta.objetos.values():
		if str(o.tipo)!="of_estante_pecas" or jogo.ambientes.em(o.celula).get("id",-1)!=sala.get("id",-2):continue
		o.estado="olhos";o.estado_visual="olhos";mudou=true
	if mudou:jogo.planta.alterada.emit()
