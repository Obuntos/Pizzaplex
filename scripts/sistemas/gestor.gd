class_name NovosSistemasPlex
extends RefCounted

var jogo:Node
var tutorial=null
var bonnie:BonnieSemanalPlex
var ambiencia:AmbienciaRestaurantePlex
var shows:ShowsPalcoPlex
var jovens:BrincadeirasBairroPlex
var investigacao:InvestigacaoProgressivaPlex
var fidelidade:Dictionary={}
var relatorio:CanvasLayer
var guarda:GuardaAutonomoPlex
var baloes:BaloesAcaoPlex
var caca:CacaAnimatronicosPlex
var armazem:ArmazemRobosPlex
var bandas:BandasPlex
var jornal:JornalCidadePlex
var entregas:EntregasMercadoPlex
var vhs:FitasVhsPlex
var tempestade:TempestadeEnergiaPlex
var mecanico:MecanicoNoturnoPlex
var acessorios:AcessoriosEquipePlex
var perdidas:CriancasPerdidasPlex
var resumo:ResumoNoitePlex
var escala_ui:EscalaNoturnaUIPlex
var piscina:PiscinaBolinhasPlex
var cartazes:CartazesPlex
var ataques:AtaquesOrelhitasPlex
var npc:AnimacoesNpcPlex
var amigos:AmigosBairroPlex
var espiritos:EspiritosPlex
var cartuchos:CartuchosPlex
func _init(cena:Node) -> void:
	jogo=cena;bonnie=BonnieSemanalPlex.new(cena);ambiencia=AmbienciaRestaurantePlex.new(cena);shows=ShowsPalcoPlex.new(cena);jovens=BrincadeirasBairroPlex.new(cena);investigacao=InvestigacaoProgressivaPlex.new(cena);guarda=GuardaAutonomoPlex.new(cena);baloes=BaloesAcaoPlex.new(cena);caca=CacaAnimatronicosPlex.new(cena);armazem=ArmazemRobosPlex.new(cena);bandas=BandasPlex.new(cena);jornal=JornalCidadePlex.new(cena);entregas=EntregasMercadoPlex.new(cena);vhs=FitasVhsPlex.new(cena);tempestade=TempestadeEnergiaPlex.new(cena);mecanico=MecanicoNoturnoPlex.new(cena);acessorios=AcessoriosEquipePlex.new(cena);perdidas=CriancasPerdidasPlex.new(cena);resumo=ResumoNoitePlex.new(cena);piscina=PiscinaBolinhasPlex.new(cena);cartazes=CartazesPlex.new(cena);ataques=AtaquesOrelhitasPlex.new(cena);npc=AnimacoesNpcPlex.new(cena);amigos=AmigosBairroPlex.new(cena);espiritos=EspiritosPlex.new(cena);cartuchos=CartuchosPlex.new(cena)
func atualizar(delta:float) -> void:
	guarda.atualizar_energia(delta);baloes.atualizar(delta);bonnie.atualizar(delta);ambiencia.atualizar(delta);shows.atualizar(delta);jovens.atualizar(delta);investigacao.atualizar(delta);caca.atualizar(delta);armazem.atualizar(delta);bandas.atualizar(delta);jornal.atualizar(delta);entregas.atualizar(delta);vhs.atualizar(delta);tempestade.atualizar(delta);mecanico.atualizar(delta);acessorios.atualizar(delta);perdidas.atualizar(delta);resumo.atualizar(delta);piscina.atualizar(delta);cartazes.atualizar(delta);ataques.atualizar(delta);npc.atualizar(delta);amigos.atualizar(delta);espiritos.atualizar(delta);cartuchos.atualizar(delta)
static func visual_coelho(a:PersonagemPlex) -> void:
	if not AtracoesCatalogoPlex.permitido(a.modelo) or not a.animacao.camadas.has("modelo"):return
	var sprite:Sprite2D=a.animacao.camadas.modelo
	sprite.scale=Vector2.ONE;sprite.offset=Vector2.ZERO
	if OficinaRobosPlex.visual(a):return
	if not a.visita.has("montagem_passos"):return
	var passo:=clampi(int(a.visita.montagem_passos),0,52);var r:=posmod(floori(float(GradePlex.direcao_visual(a.direcao))/2.0),4)
	if a.visita.has("montagem_rotacao"):r=GradePlex.rotacao_visual(int(a.visita.montagem_rotacao))
	if a.visita.has("montagem_tela"):r=int(a.visita.montagem_tela)
	var atlas:AtlasTexture=a.animacao.atlases.modelo
	atlas.atlas=CatalogoPlex.textura("res://assets/sistemas/vi/"+("patitas" if a.modelo.contains("patitas") else "orelhitas")+"/montagem/"+str(r)+".png");atlas.region=Rect2((passo%8)*192,floori(float(passo)/8)*192,192,192)
	sprite.scale=Vector2.ONE/a.animacao.scale;sprite.position=-Vector2(96,144)*sprite.scale
	a.animacao.arquivos.modelo="montagem:"+str(r)
func trancar(id:int) -> bool:
	var o:Dictionary=jogo.planta.objetos.get(id,{})
	if o.get("tipo","") not in CatalogoPlex.PORTAS:return false
	if not o.get("trancada",false):
		var tiles:Array[Vector2i]=jogo.planta.celulas(o.tipo,o.celula,o.rotacao)
		if jogo.personagens.any(func(a):return tiles.has(a.celula) or a.movimento.atravessando and tiles.has(a.movimento.destino)):
			jogo.painel.mensagem("Espere a pessoa terminar de atravessar a porta.");return false
	o.trancada=not o.get("trancada",false);o.aberta=false
	for a in jogo.personagens:
		if a.movimento.rota.any(func(c):return jogo.planta.celulas(o.tipo,o.celula,o.rotacao).has(c)):a.movimento.cancelar()
	jogo.planta.alterada.emit();return true
func arrombar(a:PersonagemPlex,e:Dictionary) -> bool:
	if e.tipo!="policial":return false
	var portas:Array=jogo.planta.objetos.values().filter(func(o):return o.tipo in CatalogoPlex.PORTAS and o.get("trancada",false))
	portas.sort_custom(func(x,y):return Vector2(x.celula).distance_squared_to(a.local)<Vector2(y.celula).distance_squared_to(a.local))
	for o in portas:
		var perto:=false
		for c in jogo.planta.celulas(o.tipo,o.celula,o.rotacao):
			if a.local.distance_to(Vector2(c))<2:perto=true
		if perto:
			a.movimento.cancelar();a.trabalho="montar";e.arrombar=float(e.get("arrombar",0))+.5
			if float(e.arrombar)>=4:
				o.trancada=false;o.arrombada=true;o.aberta=true;e.arrombar=0.0;jogo.planta.alterada.emit();jogo.painel.mensagem("A polícia arrombou uma porta trancada.")
			return true
		if not a.ocupado():
			for c in jogo.planta.celulas(o.tipo,o.celula,o.rotacao):
				for d in GradePlex.VIZINHOS:
					var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c+d)
					if not rota.is_empty():a.andar(rota);a.trabalho="visita_autoridade";return true
	return false
func gravar() -> Dictionary:return {"tutorial":tutorial.gravar() if is_instance_valid(tutorial) else {},"equipamentos":jogo.equipamentos.gravar(),"bonnie":bonnie.gravar(),"shows":shows.gravar(),"investigacao":investigacao.gravar(),"fidelidade":fidelidade.duplicate(),"escala_noturna":guarda.gravar(),"jornal":jornal.gravar(),"vhs":vhs.gravar(),"mecanico":mecanico.gravar(),"perdidas":perdidas.gravar(),"espiritos":espiritos.gravar()}
func restaurar(d:Dictionary) -> void:
	remover_testes_antigos()
	jogo.equipamentos.restaurar(d.get("equipamentos",{}))
	if is_instance_valid(tutorial):tutorial.restaurar(d.get("tutorial",{}))
	PacotesPratosPlex.compactar(jogo.planta);baloes.limpar();guarda.restaurar(d.get("escala_noturna",{}));ambiencia.limpar();jovens.grupos.clear();jovens.provocacoes.clear();jovens.dinamica.acumulado=0.0;bonnie.restaurar(d.get("bonnie",{}));shows.restaurar(d.get("shows",{}));investigacao.restaurar(d.get("investigacao",{}));fidelidade=d.get("fidelidade",{}).duplicate();jornal.restaurar(d.get("jornal",{}));vhs.restaurar(d.get("vhs",{}));mecanico.restaurar(d.get("mecanico",{}));perdidas.restaurar(d.get("perdidas",{}));espiritos.restaurar(d.get("espiritos",{}));CompraTerrenosPlex.aplicar_moradores(jogo);CompraTerrenosPlex.expandir_lotes(jogo)
	for ordem in jogo.atracoes.fila:
		if ordem.fase in ["caminhando","aguardar_robo"]:continue
		var bancada:Dictionary=jogo.planta.objetos.get(int(ordem.ponto),{});var robo:PersonagemPlex=jogo.clientes.ator(int(ordem.robo))
		if MontagemAtracoesPlex.bancada(bancada) and is_instance_valid(robo):jogo.atracoes.posicionar_na_bancada(robo,bancada)
	piscina.limpar()
	for a in jogo.personagens.duplicate():
		if a.visita.has("brincadeira_tipo") or a.trabalho in ["bullying","contar_esconde","esconder","procurar_criancas","encontrado","brincar_grupo"]:
			for chave in ["brincadeira_tipo","brincadeira_velocidade","correndo","rindo","escondido"]:a.visita.erase(chave)
			a.trabalho="visitar"
		a.visita.erase("brincando");a.visita.erase("obra_atracao")
		if a.visita.get("morto",false) and int(a.visita.get("oculto_em",-1))>=0 and not is_instance_valid(jogo.clientes.ator(int(a.visita.oculto_em))):a.visita.erase("oculto_em")
		if a.robo and not AtracoesCatalogoPlex.permitido(a.modelo):jogo.despawn(a)
		var corpo:PersonagemPlex=jogo.clientes.ator(int(a.visita.get("corpo_oculto",-1)))
		if is_instance_valid(corpo) and (not BonnieSemanalPlex.eh(corpo) or not corpo.visita.get("morto",false)):
			a.visita.erase("corpo_oculto");corpo.visita.erase("oculto_em");corpo.local=a.local;corpo.celula=a.celula

func abrir_escala() -> void:
	if not is_instance_valid(escala_ui):escala_ui=EscalaNoturnaUIPlex.new();jogo.add_child(escala_ui);escala_ui.configurar(jogo)
	escala_ui.abrir()

func escala_aberta() -> bool:return is_instance_valid(escala_ui) and escala_ui.aberto()

func remover_testes_antigos() -> void:
	var ids:Array=[]
	for g in jogo.clientes.grupos.values().duplicate():
		if not g.get("debug_evento",false):continue
		ids.append(int(g.id))
		var mesa:Dictionary=jogo.planta.objetos.get(int(g.get("mesa",-1)),{})
		if int(mesa.get("familia_cliente",-1))==int(g.id):mesa.familia_cliente=-1
		jogo.clientes.grupos.erase(int(g.id))
	for a in jogo.personagens.duplicate():
		if a.visita.get("debug_evento",false):jogo.despawn(a)
	for item in jogo.planta.objetos.values().duplicate():
		if item.get("debug_evento",false):jogo.planta.remover(int(item.id))
	jogo.servicos.pedidos=jogo.servicos.pedidos.filter(func(p):return not p.get("debug_evento",false))
	jogo.servicos.aniversarios=jogo.servicos.aniversarios.filter(func(p):return not ids.has(int(p.get("familia",p.get("grupo",-1)))))
