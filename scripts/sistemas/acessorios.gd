class_name AcessoriosEquipePlex
extends RefCounted

const ITENS={"patins":{"nome":"Patins","preco":30},"mascara":{"nome":"Máscara de bicho","preco":20}}
const VELOCIDADE_PATINS:=1.3
var jogo:Node
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
static func atual(a:PersonagemPlex) -> String:return str(a.identidade.get("acessorio",""))
static func fator(a:PersonagemPlex) -> float:
	return VELOCIDADE_PATINS if atual(a)=="patins" and a.cargo=="funcionario" and a.funcao=="atendimento" else 1.0

func opcoes(menu:CanvasLayer,a:PersonagemPlex) -> void:
	if a.cargo!="funcionario" or a.robo:return
	for id in ITENS:
		if atual(a)==id:continue
		menu.adicionar("Dar %s · US$ %d"%[str(ITENS[id].nome),int(ITENS[id].preco)],func():
			if not jogo.editor.cobrar(int(ITENS[id].preco)):return
			a.identidade.acessorio=id;jogo.sistemas.baloes.exibir(a,"Obrigado! "+str(ITENS[id].nome)+"!",3))
	if not atual(a).is_empty():menu.adicionar("Tirar "+str(ITENS[atual(a)].nome),func():a.identidade.erase("acessorio"))

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<1.0:return
	var passo:=espera;espera=0.0
	for f in jogo.personagens:
		if f.robo or atual(f)!="mascara" or f.visita.get("fora_turno",false):continue
		for a in jogo.personagens:
			if a.cargo not in ["cliente","crianca","adolescente"] or a.local.distance_to(f.local)>4.0:continue
			a.visita.satisfacao=clampf(float(a.visita.get("satisfacao",70.0))+.25*passo,0.0,100.0)
			if a.cargo=="crianca" and not a.visita.get("viu_mascara",false):a.visita.viu_mascara=true;a.emocao.exibir("feliz")
