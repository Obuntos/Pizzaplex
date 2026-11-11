class_name PopulacaoBairroPlex
extends RefCounted

var jogo: Node
var dados: Dictionary
var perfis: Dictionary={}
var familias: Dictionary={}
var estados: Dictionary={}
var limites: Dictionary
var agenda:=AgendaMoradoresPlex.new()
var locais: LocaisBairroPlex
var atores: AtoresBairroPlex
var visitas: VisitasBairroPlex
var encontros: EncontrosBairroPlex
var escola: EscolaBairroPlex
var deposito:=Node2D.new()
var fila_rotas: Array[String]=[]
var iniciado:=false
var cidade_presente:=false
var partidas: Dictionary={}
var espera:=0.0
var selecao:=0.0
var ultimo_agora:=-1.0
var eventos_processados:=0
var rotas_no_quadro:=0
var eventos_no_quadro:=0
var versao:=0

func _init(cena: Node) -> void:
	jogo=cena
	dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/moradores_bairro.json"));limites=dados.limites
	for p in dados.moradores: perfis[p.id]=p
	ProfissoesBairroPlex.preparar(perfis)
	for f in dados.familias: familias[f.id]=f
	locais=LocaisBairroPlex.new(jogo);atores=AtoresBairroPlex.new(self);visitas=VisitasBairroPlex.new(self)
	encontros=EncontrosBairroPlex.new(self);escola=EscolaBairroPlex.new(self)
	deposito.name="ReservaMoradores";deposito.hide();jogo.add_child(deposito)

func agora() -> float:
	return float(jogo.calendario.dias)*1440.0+jogo.calendario.minutos

func moradia(perfil: Dictionary, evento: Dictionary) -> String:
	return str(perfil.moradia) if evento.local=="casa" else str(evento.local)

func preparar(reposicionar: bool = true) -> bool:
	encontros.cancelar()
	cidade_presente=locais.preparar(dados.locais)
	agenda.fila.clear();fila_rotas.clear();partidas.clear()
	for id in perfis:
		var p: Dictionary=perfis[id]
		if not estados.has(id): estados[id]={"id":id,"restaurante":false,"morto":false,"ultima_visita":-10,"visitas":0,"rota":[],"pausa_ate":0.0}
		var s: Dictionary=estados[id]
		if reposicionar:
			s.erase("escola_grupo");s.erase("escola_acompanha");s.erase("escola_busca")
		if p.fora_mapa:
			s.local="fora";s.atividade="Residente fora da área do mapa";s.modo="livre";s.proximo=-1.0
			continue
		var situacao:=AgendaMoradoresPlex.situacao(p,agora())
		var e: Dictionary=situacao.atual
		if e.has("busca_escolar"): s.escola_busca=e.busca_escolar
		if not s.get("restaurante",false):
			var destino:=moradia(p,e)
			s.atividade=e.atividade;s.modo=e.modo
			if reposicionar or not s.has("posicao") or s.get("local","")=="fora":
				s.local=destino;s.objetivo=destino;s.posicao=vetor(locais.ponto(destino,p));s.rota=[]
				if destino=="rua": s.posicao=vetor(locais.ponto(p.moradia));solicitar_rota(id)
				elif str(e.atividade).to_lower().contains("caminha") and agora()-float(e.quando)<10:
					s.posicao=vetor(locais.ponto(moradia(p,situacao.anterior),p));solicitar_rota(id)
			else:
				if not s.get("rota",[]).is_empty() and agora()>=float(s.inicio)+float(s.duracao):
					s.posicao=s.rota[-1];s.rota=[];s.local=s.objetivo
				if str(s.get("objetivo",""))!=destino: s.objetivo=destino;solicitar_rota(id)
		s.proximo=situacao.proximo.quando;agenda.inserir(id,s.proximo)
		if s.get("local","") in ["rua","trajeto"] and s.get("rota",[]).is_empty() and not locais.parada_segura(celula(s.posicao)):
			s.objetivo="rua";solicitar_rota(id)
	escola.preparar(reposicionar)
	iniciado=true;ultimo_agora=agora();versao+=1
	return true

static func vetor(c: Vector2i) -> Array:
	return [c.x,c.y]

static func celula(v: Array) -> Vector2i:
	return Vector2i(roundi(float(v[0])),roundi(float(v[1])))

func solicitar_rota(id: String) -> void:
	if not perfis.has(id) or not estados.has(id): return
	if not fila_rotas.has(id): fila_rotas.append(id)

func aplicar_evento(id: String) -> void:
	var p: Dictionary=perfis[id]
	var s: Dictionary=estados[id]
	var situacao:=AgendaMoradoresPlex.situacao(p,agora())
	s.proximo=situacao.proximo.quando;agenda.inserir(id,s.proximo)
	if s.get("morto",false) or escola.ocupado(id): return
	encontros.cancelar(id)
	var e: Dictionary=situacao.atual
	if e.has("busca_escolar"): s.escola_busca=e.busca_escolar
	s.atividade=e.atividade;s.modo=e.modo
	if s.get("restaurante",false):
		s.atividade="Visitando a pizzaria";s.modo="visita"
		return
	var destino:=moradia(p,e)
	if s.get("objetivo",s.local)!=destino or destino=="rua": s.objetivo=destino;solicitar_rota(id)
	eventos_processados+=1;versao+=1

func processar_rota(id: String) -> void:
	if not cidade_presente: return
	var s: Dictionary=estados[id]
	if s.get("restaurante",false) or s.get("morto",false) or s.has("pausa_social") or s.has("escola_acompanha"): return
	var p: Dictionary=perfis[id]
	var origem:=Vector2i(posicao(s).round())
	var ponto_atual:=posicao(s)
	var destino:=locais.ponto(str(s.objetivo),p)
	if s.objetivo=="rua": destino=locais.passeio(locais.ponto(p.moradia),hash([id,floori(agora()/15.0)]))
	if not locais.parada_segura(destino): destino=locais.parada_proxima(destino)
	if origem==destino and ponto_atual.distance_to(Vector2(destino))<.001 and s.objetivo!="rua":
		s.posicao=vetor(destino);s.rota=[];s.local=s.objetivo;s.pausa_ate=agora()+10.0
		return
	var preferencia:=hash([p.familia,id,floori(agora()/45.0)])
	var rota:=locais.caminho(origem,destino,preferencia)
	if rota.is_empty():
		if not locais.parada_segura(origem): rota=locais.caminho(origem,locais.parada_proxima(origem))
		if rota.is_empty():
			s.posicao=[ponto_atual.x,ponto_atual.y];s.rota=[];s.pausa_ate=agora()+15.0;s.bloqueado=true
			return
	if rota.size()==1 and ponto_atual.distance_to(Vector2(rota[0]))>.001: rota.append(destino)
	s.bloqueado=false;s.rota=rota.map(func(c): return vetor(c))
	s.rota[0]=[ponto_atual.x,ponto_atual.y]
	s.posicao=[ponto_atual.x,ponto_atual.y]
	var intervalo:=.22+float(posmod(hash(id),7))*.07
	if s.has("escola_grupo") and not s.has("escola_acompanha"):
		intervalo=float(escola.grupos.get(s.escola_grupo,{}).get("alunos",[]).size()+1)*1.35+.35
	s.inicio=maxf(agora(),float(partidas.get(origem,0.0))) if locais.parada_segura(origem) else agora();partidas[origem]=s.inicio+intervalo
	PercursoMoradoresPlex.preparar(s,jogo.planta)
	s.duracao=maxf(.01,float(s.comprimento_percurso)/(CaminhosCidadePlex.PASSO_EXTERNO*(.92+float(posmod(hash(id),9))*.025))*CalendarioPlex.MINUTOS_POR_SEGUNDO)
	s.ritmo_real=2
	s.local="trajeto";s.pausa_ate=0.0

func posicao(s: Dictionary) -> Vector2:
	if s.has("pausa_social"): return Vector2(s.pausa_social[0],s.pausa_social[1])
	var rota: Array=s.get("rota",[])
	if rota.is_empty(): return Vector2(s.posicao[0],s.posicao[1])
	return PercursoMoradoresPlex.posicao(s,agora(),jogo.planta)

func atividade(id: String) -> String:
	var s: Dictionary=estados.get(id,{})
	return "Visitando a pizzaria" if s.get("restaurante",false) else str(s.get("atividade",""))

func contar() -> Dictionary:
	var c: Dictionary={"total":perfis.size(),"familias":familias.size(),"em_casa":0,"na_cidade":0,"restaurante":0,"fora_mapa":0,"mortos":0,"ativos":atores.ativos.size(),"adultos":0,"adolescentes":0,"criancas":0}
	for id in perfis:
		var p: Dictionary=perfis[id];var s: Dictionary=estados.get(id,{})
		c["adultos" if p.grupo=="adulto" else "adolescentes" if p.grupo=="adolescente" else "criancas"]+=1
		if p.fora_mapa: c.fora_mapa+=1
		elif s.get("morto",false): c.mortos+=1
		elif s.get("restaurante",false): c.restaurante+=1
		elif s.get("local",p.moradia)==p.moradia: c.em_casa+=1
		else: c.na_cidade+=1
	return c

func atualizar_cidade(delta: float) -> void:
	if not cidade_presente: return
	var tamanho: Vector2=jogo.get_viewport_rect().size/jogo.camera.zoom
	var area:=Rect2(jogo.camera.get_screen_center_position()-tamanho*.5,tamanho).grow(90)
	var desenhar: bool=jogo.atividade_janela.permite_desenhar()
	for id in atores.ativos.keys():
		var a: PersonagemPlex=atores.ativos[id]
		if a.visita.get("morto",false): estados[id].morto=true;continue
		if a.cargo!="morador" or ControleAdministradorPlex.ocupado(a) or id in visitas.pendentes: continue
		var s: Dictionary=estados[id]
		if a.visita.get("conversa_bairro",false) or a.visita.get("socializando",false):
			a.relogio+=delta
			if desenhar: a.atualizar_visual(false);jogo.composicao.atualizar_personagem(a)
			continue
		var ponto:=posicao(s)
		if not area.grow(160).has_point(GradePlex.projetar(ponto)) or s.local not in ["trajeto","rua"]: atores.ocultar(id);continue
		var deslocamento:=GradePlex.projetar_local(ponto-a.local)
		var distancia:=a.local.distance_to(ponto)
		a.local=ponto;a.celula=Vector2i(ponto.round());a.relogio+=delta
		if distancia>.00001:
			a.fase+=distancia/.42;a.direcao=posmod(roundi(atan2(deslocamento.x,deslocamento.y*2.0)/(PI/4.0)),8)
		a.trabalho="circular_bairro";a.visible=true;a.set_meta("visivel_cena",true)
		if desenhar: a.atualizar_visual(distancia>.00001);jogo.composicao.atualizar_personagem(a)
	if not desenhar: return
	selecao+=delta
	if selecao<.2: return
	selecao=0
	var quantidade:=atores.ativos.values().filter(func(a): return a.cargo=="morador").size()
	if quantidade>=int(limites.cidade) or atores.novas_criacoes>0: return
	for id in estados:
		var s: Dictionary=estados[id];var p: Dictionary=perfis[id]
		if p.fora_mapa or int(p.idade)<3 or s.get("morto",false) or s.get("restaurante",false) or atores.ativos.has(id) or id in visitas.pendentes: continue
		if s.local not in ["rua","trajeto"] or agora()<float(s.get("inicio",0.0)): continue
		if s.has("escola_acompanha") and not atores.ativos.has(s.escola_acompanha): continue
		var ponto:=posicao(s)
		if not area.has_point(GradePlex.projetar(ponto)): continue
		var novo_ator:=atores.adquirir(id,Vector2i(ponto.round()))
		if is_instance_valid(novo_ator): novo_ator.local=ponto
		break

func atualizar(delta: float) -> void:
	atores.novas_criacoes=0;rotas_no_quadro=0;eventos_no_quadro=0
	if not iniciado:
		espera+=delta
		if espera>=1.0: espera=0;preparar()
		return
	var tempo:=agora()
	if tempo<ultimo_agora or tempo-ultimo_agora>180.0: preparar()
	ultimo_agora=tempo
	while not agenda.fila.is_empty() and float(agenda.fila[0].quando)<=tempo and eventos_no_quadro<int(limites.eventos_quadro):
		var e:=agenda.retirar();aplicar_evento(e.id);eventos_no_quadro+=1
	if not fila_rotas.is_empty(): processar_rota(fila_rotas.pop_front());rotas_no_quadro=1
	espera+=delta
	if espera>=1.0:
		espera=0
		if not cidade_presente and CidadeInicialPlex.presente(jogo.planta): preparar()
		for id in estados:
			var s: Dictionary=estados[id]
			if perfis[id].fora_mapa or s.get("restaurante",false) or s.get("morto",false) or s.has("pausa_social"): continue
			if not s.get("rota",[]).is_empty() and tempo>=float(s.inicio)+float(s.duracao):
				s.posicao=s.rota[-1];s.rota=[];s.local=s.objetivo;s.pausa_ate=tempo+10.0;versao+=1
			elif s.local=="rua" and not s.has("escola_grupo") and tempo>=float(s.pausa_ate): solicitar_rota(id);s.pausa_ate=tempo+10.0
	escola.atualizar(delta)
	encontros.atualizar(delta)
	visitas.atualizar(delta);atualizar_cidade(delta)

func gravar() -> Dictionary:
	var registros: Dictionary=estados.duplicate(true)
	for id in registros:
		if registros[id].has("pausa_social"):
			registros[id].posicao=registros[id].pausa_social;registros[id].erase("pausa_social");registros[id].rota=[];registros[id].local="rua"
	for id in atores.ativos:
		var a: PersonagemPlex=atores.ativos[id]
		if a.cargo=="morador" and a.visita.get("socializando",false):
			registros[id].posicao=[a.local.x,a.local.y];registros[id].rota=[];registros[id].local="rua"
	return {"versao":1,"estados":registros,"familias_visitadas":visitas.historico.duplicate(true)}

func restaurar(valor: Dictionary) -> void:
	encontros.cancelar();atores.limpar();estados=valor.get("estados",{}).duplicate(true)
	for id in estados.keys():
		if not perfis.has(id): estados.erase(id)
	iniciado=false;locais.assinatura=-1;preparar(false)
	visitas.historico=valor.get("familias_visitadas",{}).duplicate(true)
	for a in jogo.personagens:
		var id: String=a.visita.get("morador_id",a.identidade.get("morador_id",""))
		if not perfis.has(id): continue
		atores.ativos[id]=a
		AparenciasFamiliaPlex.aplicar(a,perfis[id])
		if a.cargo!="morador": estados[id].restaurante=true

func finalizar() -> void:
	encontros.cancelar();encontros.bairro=null;escola.bairro=null;atores.bairro=null;visitas.bairro=null;jogo=null

