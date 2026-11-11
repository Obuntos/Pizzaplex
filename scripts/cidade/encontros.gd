class_name EncontrosBairroPlex
extends RefCounted

var bairro: RefCounted
var vinculos: Dictionary = {}
var conversa: Dictionary = {}
var proximas: Dictionary = {}
var espera := 0.0
var iniciadas := 0

func _init(gerente: RefCounted) -> void:
	bairro=gerente
	var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/vinculos_bairro.json"))
	for par in dados.vinculos:
		vinculos[chave(str(par.a),str(par.b))]=true

static func chave(a: String, b: String) -> String:
	return a+":"+b if a<b else b+":"+a

func conhece(a: String, b: String) -> bool:
	return a!=b and vinculos.has(chave(a,b))

func disponivel(id: String) -> bool:
	if not bairro.atores.ativos.has(id): return false
	var a: PersonagemPlex=bairro.atores.ativos[id]
	var s: Dictionary=bairro.estados[id]
	return a.cargo=="morador" and a.visible and not ControleAdministradorPlex.ocupado(a) and not a.visita.get("socializando",false) and not s.get("morto",false) and not s.get("restaurante",false) and s.get("modo","") == "livre" and not s.has("escola_grupo") and bairro.agora()>=float(proximas.get(id,0.0)) and float(s.get("proximo",INF))-bairro.agora()>5.0 and bairro.locais.parada_segura(Vector2i(bairro.posicao(s).round()))

func iniciar(a: String, b: String) -> bool:
	if not conversa.is_empty() or not conhece(a,b) or not disponivel(a) or not disponivel(b): return false
	var pa: Vector2=bairro.posicao(bairro.estados[a])
	var pb: Vector2=bairro.posicao(bairro.estados[b])
	if pa.distance_to(pb)>2.0 or pa.distance_to(pb)<.65: return false
	var caminho: Array[Vector2i]=bairro.locais.caminho(Vector2i(pa.round()),Vector2i(pb.round()))
	if caminho.is_empty() or caminho.size()>4: return false
	conversa={"ids":[a,b],"tempo":0.0,"duracao":5.0+float(posmod(hash(chave(a,b)),4))}
	for id in [a,b]:
		var s: Dictionary=bairro.estados[id]
		var ponto: Vector2=bairro.posicao(s)
		s.pausa_social=[ponto.x,ponto.y]
		var ator: PersonagemPlex=bairro.atores.ativos[id]
		ator.local=ponto;ator.celula=Vector2i(ponto.round());ator.visita.conversa_bairro=true
		ator.visita.expressao_conversa=ator.animacao.expressao
		var feliz: bool=ResourceLoader.exists("res://assets/personagens/"+ator.modelo+"/feliz_olhos.png") and ResourceLoader.exists("res://assets/personagens/"+ator.modelo+"/feliz_boca.png")
		ator.animacao.expressao="feliz" if feliz else "neutro"
		ator.trabalho="conversar_bairro"
	iniciadas+=1
	return true

func cancelar(id: String = "") -> void:
	if conversa.is_empty() or (not id.is_empty() and id not in conversa.ids): return
	for pessoa in conversa.ids:
		var s: Dictionary=bairro.estados.get(pessoa,{})
		if s.has("pausa_social"):
			s.posicao=s.pausa_social;s.erase("pausa_social");s.rota=[];s.local="rua"
			bairro.solicitar_rota(pessoa)
		proximas[pessoa]=bairro.agora()+60.0
		var ator: PersonagemPlex=bairro.atores.ativos.get(pessoa)
		if is_instance_valid(ator):
			ator.visita.erase("conversa_bairro");ator.trabalho=""
			ator.animacao.expressao=str(ator.visita.get("expressao_conversa","neutro"));ator.visita.erase("expressao_conversa")
	conversa.clear()

func atualizar(delta: float) -> void:
	if not conversa.is_empty():
		for id in conversa.ids:
			if not bairro.atores.ativos.has(id) or bairro.atores.ativos[id].cargo!="morador" or bairro.estados[id].get("morto",false) or bairro.estados[id].get("modo","")=="compromisso" or bairro.atores.ativos[id].visita.get("socializando",false) or ControleAdministradorPlex.ocupado(bairro.atores.ativos[id]): cancelar();return
		var a: PersonagemPlex=bairro.atores.ativos[conversa.ids[0]]
		var b: PersonagemPlex=bairro.atores.ativos[conversa.ids[1]]
		bairro.jogo.tarefas.orientar(a,b.local);bairro.jogo.tarefas.orientar(b,a.local)
		conversa.tempo=float(conversa.tempo)+delta
		if float(conversa.tempo)>=float(conversa.duracao): cancelar()
		return
	espera+=delta
	if espera<1.0: return
	espera=fmod(espera,1.0)
	var ids: Array=bairro.atores.ativos.keys()
	for i in ids.size():
		if not disponivel(ids[i]): continue
		for j in range(i+1,ids.size()):
			if iniciar(ids[i],ids[j]): return
