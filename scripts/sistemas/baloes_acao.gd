class_name BaloesAcaoPlex
extends RefCounted

var jogo:Node
var ultimos:Dictionary={}
var ativos:Dictionary={}
var tempo:=0.0
func _init(cena:Node) -> void:jogo=cena
func exibir(a:PersonagemPlex,texto:String,_duracao:float=4.5) -> void:
	if not is_instance_valid(a) or a.visita.get("morto",false):return
	var mensagem:=texto.to_lower()
	var cena:bool=a.visita.get("brincando",false) or a.visita.get("debug_evento",false) or mensagem.contains("parabéns") or mensagem.contains("ha, ha")
	var pausa:=.7 if texto.ends_with("...") else 4.0 if cena else 20.0
	if tempo-float(ultimos.get(a.identificador,-30))<pausa:return
	ultimos[a.identificador]=tempo
	var icone:=""
	if mensagem.contains("sozinh") or mensagem.contains("triste") or mensagem.contains("paz"):icone="triste"
	elif mensagem.contains("ha, ha"):icone="feliz"
	elif mensagem.contains("parabéns"):icone="confete"
	elif mensagem.contains("!") or mensagem.contains("restrita") or mensagem.contains("saída"):icone="exclamacao"
	elif mensagem.contains("show começou"):icone="festa"
	if not icone.is_empty():a.emocao.exibir(icone)
func atualizar(delta:float) -> void:tempo+=delta
func limpar() -> void:
	for b in ativos.values():
		if is_instance_valid(b.get("painel")):b.painel.queue_free()
	ativos.clear();ultimos.clear()
