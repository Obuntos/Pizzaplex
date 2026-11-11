class_name AtoresBairroPlex
extends RefCounted
var bairro: RefCounted
var ativos: Dictionary={}
var reserva: Array[PersonagemPlex]=[]
var novas_criacoes:=0
var devolvendo:=false
var preparando: Dictionary={}
var arquivos_preparados:=0
var fixados: Dictionary={}
func _init(gerente: RefCounted) -> void:
	bairro=gerente
func pronto(id: String) -> bool:
	if not preparando.has(id):
		if preparando.size()>=4:
			var antigo: String=preparando.keys()[0]
			preparando.erase(antigo)
			if not ativos.has(antigo): fixados.erase(antigo)
		fixados[id]={}
		var reservado:=str(bairro.jogo.operacao.criacao.get("cabelo",""))
		preparando[id]=AparenciasFamiliaPlex.arquivos(bairro.perfis[id],reservado)
	var carregador: PreparacaoRecursosPlex=bairro.jogo.preparacao
	var falta:=false
	for caminho in preparando[id]:
		if carregador.fila.has(caminho) or carregador.ativos.has(caminho): falta=true;continue
		if carregador.falhas.has(caminho): continue
		if CatalogoPlex.texturas.has(caminho): fixados[id][caminho]=CatalogoPlex.texturas[caminho];continue
		if carregador.recursos.has(caminho): fixados[id][caminho]=carregador.recursos[caminho];continue
		if ResourceLoader.has_cached(caminho): fixados[id][caminho]=load(caminho);continue
		carregador.adicionar(caminho);falta=true
	if not falta:
		arquivos_preparados+=preparando[id].size();preparando.erase(id)
	return not falta
func adquirir(id: String, celula: Vector2i, cargo: String = "morador") -> PersonagemPlex:
	var jogo: Node=bairro.jogo
	if not bairro.perfis.has(id) or bairro.perfis[id].fora_mapa or int(bairro.perfis[id].idade)<3 or bairro.estados.get(id,{}).get("morto",false): return null
	if ativos.has(id):
		var existente: PersonagemPlex=ativos[id]
		if ProfissoesBairroPlex.eh(str(bairro.perfis[id].modelo)) and existente.modelo!=str(bairro.perfis[id].modelo):existente.mudar_modelo(str(bairro.perfis[id].modelo))
		if cargo=="morador": return existente
		if jogo.carteira.ator==existente: jogo.carteira.fechar()
		existente.movimento=MovimentoPlex.new()
		existente.cargo=cargo;existente.trabalho="";existente.assento=-1;existente.visita={"morador_id":id}
		AparenciasFamiliaPlex.aplicar(existente,bairro.perfis[id])
		return existente
	if ativos.size()>=int(bairro.limites.ativos) or not pronto(id): return null
	var perfil: Dictionary=bairro.perfis[id]
	var ator: PersonagemPlex
	for outro in reserva:
		if outro.modelo==perfil.modelo: ator=outro;reserva.erase(outro);break
	if not is_instance_valid(ator):
		if novas_criacoes>=1: return null
		ator=jogo.spawn_morador(perfil,celula,cargo)
		novas_criacoes+=1
	else:
		ator.identificador=jogo.proximo_personagem;jogo.proximo_personagem+=1
		ator.reparent(jogo.mundo);jogo.personagens.append(ator)
		var sombra:=SombraLuminariaPlex.new();sombra.configurar(ator,jogo.iluminacao,jogo.composicao);jogo.sombras_luzes.add_child(sombra)
	ator.identidade={"nome":perfil.nome,"sobrenome":"","apelido":"","idade":perfil.idade,"sexo":perfil.sexo,"morador_id":id,"familia_bairro":perfil.familia}
	ator.visita={"morador_id":id};ator.cargo=cargo;ator.automatico=false;ator.funcao="morador";ator.funcoes_secundarias=[]
	ator.celula=celula;ator.local=Vector2(celula);ator.altura=0;ator.direcao=7;ator.movimento=MovimentoPlex.new()
	ator.fase=0.0;ator.animacao.expressao="neutro";ator.em_degraus=false
	ator.familia=-1;ator.responsavel=-1;ator.assento=-1;ator.suporte=-1;ator.pose=-1;ator.trabalho="";ator.carga_item=-1;ator.carga_extra.clear();ator.carregando=false
	ator.necessidades={"banheiro":100.0,"higiene":100.0,"lazer":100.0,"turno":false}
	AparenciasFamiliaPlex.aplicar(ator,perfil)
	ator.selecionado=false;ator.process_mode=Node.PROCESS_MODE_INHERIT;ator.set_meta("visivel_cena",true)
	for meta in ["limites_rota","tarefa_ativa","arma_visual","corpo_visual","corpo_visual_tras"]:
		if ator.has_meta(meta): ator.remove_meta(meta)
	ativos[id]=ator
	ator.show();ator.atualizar_visual(false);jogo.composicao.atualizar_personagem(ator)
	return ator
func recolher(ator: PersonagemPlex) -> bool:
	var id: String=ator.visita.get("morador_id",ator.identidade.get("morador_id",""))
	if not bairro.estados.has(id): return false
	var estado: Dictionary=bairro.estados[id]
	fixados.erase(id)
	if ator.visita.get("morto",false): estado.morto=true;ativos.erase(id);return false
	if not devolvendo and estado.get("restaurante",false): bairro.visitas.liberar_morador(id)
	ativos.erase(id)
	if reserva.size()>=int(bairro.limites.reserva): return false
	ator.hide();ator.selecionado=false;ator.assento=-1;ator.trabalho="";ator.movimento=MovimentoPlex.new()
	ator.set_meta("visivel_cena",false);ator.process_mode=Node.PROCESS_MODE_DISABLED
	ator.reparent(bairro.deposito);reserva.append(ator)
	return true
func ocultar(id: String) -> void:
	if not ativos.has(id): return
	var ator: PersonagemPlex=ativos[id]
	if ator.cargo!="morador" or bairro.jogo.selecionado==ator or bairro.jogo.carteira.ator==ator or ator.visita.get("aguardar_conversa",false) or ator.visita.get("conversa_bairro",false) or ator.visita.get("socializando",false): return
	devolvendo=true; bairro.jogo.despawn(ator); devolvendo=false
func limpar() -> void:
	ativos.clear();preparando.clear();fixados.clear()
	for a in reserva:
		if is_instance_valid(a): a.queue_free()
	reserva.clear()
