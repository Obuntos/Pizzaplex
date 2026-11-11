class_name VisitasBairroPlex
extends RefCounted

var bairro: RefCounted
var pendentes: Array[String]=[]
var plano: Dictionary={}
var historico: Dictionary={}
var espera:=0.0

func _init(p: RefCounted) -> void:
	bairro=p

func disponivel(id: String) -> bool:
	var s: Dictionary=bairro.estados[id]
	return not bairro.perfis[id].fora_mapa and not s.get("morto",false) and not s.get("restaurante",false) and s.get("modo","") not in ["sono","compromisso"] and int(s.get("ultima_visita",-10))<bairro.jogo.calendario.dias and not s.has("pausa_social") and not bairro.escola.ocupado(id)

func solicitar(local: Vector2i, salao: bool, arcade: bool) -> bool:
	if not bairro.iniciado or not plano.is_empty(): return false
	var clima: float={"Chuva":.75,"Neve":.6,"Calor":1.15}.get(bairro.jogo.calendario.previsao(),1.0)
	if clima<1.0 and randf()>clima: return false
	var presentes: int=bairro.atores.ativos.values().filter(func(a): return a.cargo!="morador").size()
	if presentes>=int(float(bairro.limites.visitas)*maxf(1.0,clima)): return false
	var familias_ordenadas:Array=bairro.familias.values()
	familias_ordenadas.sort_custom(func(a,b):return float(bairro.jogo.sistemas.fidelidade.get(str(a.id),0))>float(bairro.jogo.sistemas.fidelidade.get(str(b.id),0)))
	for familia in familias_ordenadas:
		if familia.fora_mapa: continue
		var membros: Array=familia.membros.filter(func(id): return disponivel(id))
		var adultos: Array=membros.filter(func(id): return bairro.perfis[id].grupo=="adulto")
		var adolescentes: Array=membros.filter(func(id): return bairro.perfis[id].grupo=="adolescente")
		var criancas: Array=membros.filter(func(id): return bairro.perfis[id].grupo=="criança" and int(bairro.perfis[id].idade)>=4)
		var ids: Array=[]
		var solo: bool=arcade and not adolescentes.is_empty() and (not salao or adultos.is_empty() or posmod(hash([familia.id,bairro.jogo.calendario.dias]),4)==0)
		if solo: ids.append(adolescentes[0])
		elif salao and not adultos.is_empty():
			var bebe: bool=familia.membros.any(func(id): return int(bairro.perfis[id].idade)<4)
			if bebe and adultos.size()<2: continue
			ids.append_array(adultos.slice(0,1 if bebe else mini(2,adultos.size())))
			ids.append_array(criancas.slice(0,2));ids.append_array(adolescentes.slice(0,mini(2,6-ids.size())))
		else: continue
		var aniversario:=not solo and not criancas.is_empty() and ReputacaoClientesPlex.quer_festa(bairro.jogo,str(familia.id))
		var convidados:=0
		if aniversario:
			for perfil in BandosCriancasPlex.convidados(bairro.jogo,bairro.perfis.values(),criancas):
				if perfil.grupo!="criança" or int(perfil.idade)<4 or perfil.familia==familia.id or not disponivel(str(perfil.id)):continue
				if ids.filter(func(id): return bairro.perfis[id].grupo=="criança").size()>=3 or ids.size()>=6:break
				ids.append(perfil.id);convidados+=1
			ids.sort_custom(func(a,b): return (["adulto","criança","adolescente"].find(bairro.perfis[a].grupo))<(["adulto","criança","adolescente"].find(bairro.perfis[b].grupo)))
		if ids.size()+presentes>int(float(bairro.limites.visitas)*maxf(1.0,clima)): continue
		if not solo and not bairro.jogo.clientes.recepcao.tem_vaga(ids.size()): continue
		if solo and not bairro.jogo.clientes.recepcao.vaga_arcade(): continue
		plano={"ids":ids,"familia":familia.id,"local":[local.x,local.y],"solo":solo,"inicio":bairro.agora(),"aniversario":aniversario,"convidados":convidados}
		pendentes.assign(ids);return true
	return false

func cancelar() -> void:
	for id in pendentes: bairro.atores.ocultar(id)
	pendentes.clear();plano.clear()

func atualizar(delta: float) -> void:
	if plano.is_empty(): return
	if not bairro.jogo.operacao.aberto or bairro.agora()-float(plano.inicio)>15.0: cancelar();return
	espera+=delta
	if espera<.1: return
	espera=0
	for id in pendentes:
		if not bairro.atores.ativos.has(id):
			var origem:=Vector2i(bairro.posicao(bairro.estados[id]).round())
			if not bairro.locais.parada_segura(origem): origem=bairro.locais.parada_proxima(origem)
			if origem.x<0: cancelar();return
			bairro.estados[id].posicao=[origem.x,origem.y]
			bairro.estados[id].rota=[]
			var a: PersonagemPlex=bairro.atores.adquirir(id,origem)
			if not is_instance_valid(a): return
			a.hide();a.set_meta("visivel_cena",false);return
	var ids: Array=plano.ids.duplicate()
	var local:=PopulacaoBairroPlex.celula(plano.local)
	var sucesso:=false
	if plano.solo:
		var perfil: Dictionary=bairro.perfis[ids[0]]
		sucesso=bairro.jogo.lazer.criar(local,perfil.sexo=="feminino",-1,ids[0])
	else:
		var adultos: int=ids.filter(func(id): return bairro.perfis[id].grupo=="adulto").size()
		var criancas: int=ids.filter(func(id): return bairro.perfis[id].grupo=="criança").size()
		sucesso=FamiliasVisitantesPlex.criar(bairro.jogo.clientes,local,adultos,criancas,ids.size()-adultos-criancas,"",ids)
	if sucesso:
		for id in ids:
			var s: Dictionary=bairro.estados[id];s.restaurante=true;s.rota=[];s.ultima_visita=bairro.jogo.calendario.dias;s.visitas=int(s.get("visitas",0))+1
			historico[id]=int(historico.get(id,0))+1
		if plano.get("aniversario",false):
			var grupo: Dictionary=bairro.jogo.clientes.grupos.get(bairro.jogo.clientes.proximo_grupo-1,{})
			if not grupo.is_empty():bairro.jogo.festas.solicitar_aniversario(grupo,int(plano.get("convidados",0)))
		bairro.versao+=1;pendentes.clear();plano.clear()
	else: cancelar()

func vincular(grupo: Dictionary, ids: Array) -> void:
	grupo.familia_bairro=bairro.perfis[ids[0]].familia
	var membros: Array=FamiliasVisitantesPlex.membros(grupo)
	for i in mini(ids.size(),membros.size()):
		var a: PersonagemPlex=bairro.jogo.clientes.ator(membros[i])
		if not is_instance_valid(a): continue
		a.visita.morador_id=ids[i]
		var p: Dictionary=bairro.perfis[ids[i]]
		a.identidade={"nome":p.nome,"sobrenome":"","apelido":"","idade":p.idade,"sexo":p.sexo,"morador_id":p.id,"familia_bairro":p.familia}
		AparenciasFamiliaPlex.aplicar(a,p)
		a.visita.afinidade=p.afinidade;a.visita.medo_animatronico=p.medo_animatronico;a.visita.medo_fantasia=p.medo_fantasia
		a.visita.paciencia=p.temperamento.paciencia;a.visita.satisfacao=60+int(p.temperamento.sociabilidade)*4
		a.show();a.atualizar_visual(false);bairro.jogo.composicao.atualizar_personagem(a)

func sair(id: String) -> void:
	if not bairro.atores.ativos.has(id): liberar_morador(id);return
	var a: PersonagemPlex=bairro.atores.ativos[id]
	var grupo: Dictionary=bairro.jogo.clientes.grupos.get(a.familia,{})
	if not grupo.is_empty(): bairro.jogo.clientes.sair(grupo)
	elif a.cargo=="adolescente": a.visita.etapa="sair"

func liberar_morador(id: String) -> void:
	var s: Dictionary=bairro.estados[id];s.restaurante=false
	var p: Dictionary=bairro.perfis[id]
	var e: Dictionary=AgendaMoradoresPlex.situacao(p,bairro.agora()).atual
	s.objetivo=bairro.moradia(p,e);s.atividade=e.atividade;s.modo=e.modo
	if not bairro.cidade_presente: s.local=s.objetivo;s.rota=[];bairro.versao+=1;return
	var ator: PersonagemPlex=bairro.atores.ativos.get(id)
	var origem: Vector2i=ator.celula if is_instance_valid(ator) else PopulacaoBairroPlex.celula(s.posicao)
	var mais_perto:=Vector2i(-1,-1)
	var distancia:=INF
	for tile in bairro.locais.tiles:
		var d: float=Vector2(tile).distance_squared_to(Vector2(origem))
		if d<distancia: distancia=d;mais_perto=tile
	s.local="rua";s.posicao=PopulacaoBairroPlex.vetor(mais_perto);s.rota=[]
	bairro.solicitar_rota(id);bairro.versao+=1

