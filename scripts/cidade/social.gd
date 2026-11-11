class_name SocialBairroPlex
extends RefCounted

var jogo: Node
var registros: Dictionary={}
var conversa: Dictionary={}

func _init(cena: Node) -> void:
	jogo=cena

func chave(a: PersonagemPlex) -> String:
	return str(a.identidade.get("morador_id","pessoa:"+IdentidadesPlex.completo(a)))

func nivel(a: PersonagemPlex) -> int:
	if a.robo or a.cargo=="funcionario" or AdministradorPlex.eh(a): return 3
	return int(registros.get(chave(a),{}).get("nivel",0))

func nome(a: PersonagemPlex) -> String:
	return IdentidadesPlex.completo(a) if nivel(a)>0 else "Pessoa desconhecida"

func relacao(alvo: PersonagemPlex) -> int:
	return clampi(int(registros.get(chave(alvo),{}).get("relacao",0)),-100,100)

func iniciar(alvo: PersonagemPlex, tipo: String = "conversar") -> bool:
	var admin: PersonagemPlex=jogo.controle.administrador()
	if not is_instance_valid(admin) or not is_instance_valid(alvo) or alvo==admin or alvo.robo or alvo.visita.get("morto",false) or admin.visita.get("morto",false): return false
	if admin.carga_item>=0 or admin.carregando or int(admin.visita.get("corpo_carregado",-1))>0:
		jogo.painel.mensagem("Libere as mãos antes de conversar.");return false
	if alvo.funcao=="seguranca":jogo.painel.mensagem("O guarda organiza sua rotina sozinho. Consulte sua carteira ou a área de segurança do IBM.");return false
	if bool(alvo.visita.get("fugindo",false)): return false
	var id_escolar:=str(alvo.identidade.get("morador_id",""))
	if not id_escolar.is_empty() and jogo.populacao.escola.ocupado(id_escolar):
		jogo.painel.mensagem("Esta pessoa está acompanhando a saída da escola.");return false
	cancelar()
	var morador_alvo:=str(alvo.identidade.get("morador_id",""))
	if not morador_alvo.is_empty(): jogo.populacao.encontros.cancelar(morador_alvo)
	jogo.rotina_adm.cancelar(admin);jogo.controle.interromper(admin);jogo.controle.acao.clear()
	var atravessando:=str(jogo.planta.pisos.get(alvo.celula,"")).begins_with("cidade_faixa_de_pedestre")
	conversa={"tipo":tipo,"alvo":alvo,"admin":admin,"automatico":admin.automatico,"tempo":0.0,"tentativa":0.0,"espera":0.0,"trabalho":alvo.trabalho,"inicio":jogo.populacao.agora(),"aguardar_calcada":atravessando}
	admin.visita.autonomia_social=admin.automatico;admin.automatico=false;admin.visita.socializando=true
	if atravessando and alvo.cargo=="morador":
		alvo.visita.aguardar_conversa=true
		var id: String=alvo.visita.get("morador_id","")
		if jogo.populacao.estados.get(id,{}).get("rota",[]).is_empty(): jogo.populacao.solicitar_rota(id)
	else:
		alvo.movimento.cancelar();alvo.visita.socializando=true;conversa.aguardar_calcada=false
	jogo.carteira.fechar();jogo.menu_controle.fechar()
	return true

func cancelar() -> void:
	if conversa.is_empty(): return
	var admin: PersonagemPlex=conversa.get("admin")
	var alvo: PersonagemPlex=conversa.get("alvo")
	if is_instance_valid(admin):
		admin.visita.erase("socializando");admin.visita.erase("autonomia_social");admin.automatico=bool(conversa.get("automatico",true));admin.trabalho="manual" if admin.visita.get("controle_manual",false) else "";admin.movimento.cancelar()
	if is_instance_valid(alvo):
		alvo.visita.erase("aguardar_conversa")
		alvo.visita.erase("socializando");alvo.trabalho="aguardar_familia" if alvo.visita.get("diversao_concluida",false) else str(conversa.get("trabalho",""))
		var id: String=alvo.identidade.get("morador_id","")
		if alvo.cargo=="morador" and jogo.populacao.estados.has(id):
			var s: Dictionary=jogo.populacao.estados[id]
			s.posicao=[alvo.local.x,alvo.local.y];s.rota=[];s.local="rua";jogo.populacao.solicitar_rota(id)
	conversa.clear()

func registrar(alvo: PersonagemPlex, tipo: String = "conversar") -> void:
	if tipo=="brincar":CirculacaoVisitantesPlex.concluir_brincadeira(jogo,alvo)
	if tipo in ["conversar","elogiar","brincar"]:jogo.sistemas.jovens.acolher(alvo)
	var resposta:String={"apresentar":"Prazer em conhecer você!","conversar":"É bom conversar um pouco.","elogiar":"Obrigado pelo carinho!","brincar":"Vamos brincar!","provocar":"Não gostei disso."}.get(tipo,"Olá!")
	jogo.sistemas.baloes.exibir(alvo,resposta,4.5)
	var id:=chave(alvo)
	var conhecido: Dictionary=registros.get(id,{"nivel":0,"ultimo":-1000.0})
	var antes:=relacao(alvo)
	alvo.animacao.expressao="raivoso" if tipo=="provocar" else "muito_feliz" if tipo in ["elogiar","brincar"] else "feliz"
	var variacao:=int({"apresentar":3,"conversar":2,"elogiar":4,"brincar":3,"provocar":-6}.get(tipo,2))
	conhecido.relacao=clampi(antes+variacao,-100,100)
	registros[id]=conhecido
	jogo.menu_controle.mostrar_relacao(alvo,int(conhecido.relacao)-antes)
	var agora: float=jogo.populacao.agora()
	if agora-float(conhecido.ultimo)>=15.0:
		conhecido.nivel=mini(3,int(conhecido.nivel)+1);conhecido.ultimo=agora;registros[id]=conhecido
	if jogo.selecionado==alvo: jogo.painel.selecao.text=nome(alvo)
	jogo.painel.mensagem("Conversa concluída com "+nome(alvo)+".")

func atualizar(delta: float) -> void:
	if conversa.is_empty(): return
	var admin: PersonagemPlex=conversa.admin
	var alvo: PersonagemPlex=conversa.alvo
	if not is_instance_valid(admin) or not is_instance_valid(alvo) or alvo.visita.get("morto",false) or admin.visita.get("morto",false): cancelar();return
	conversa.espera=float(conversa.espera)+delta
	if float(conversa.espera)>90.0: cancelar();jogo.painel.mensagem("Não foi possível se aproximar para conversar.");return
	if conversa.get("aguardar_calcada",false):
		if not jogo.populacao.locais.parada_segura(Vector2i(alvo.local.round())): return
		conversa.aguardar_calcada=false
		alvo.visita.erase("aguardar_conversa");alvo.visita.socializando=true;alvo.movimento.cancelar()
	var perto: bool=admin.local.distance_to(alvo.local)<=1.6 and absf(admin.altura-alvo.altura)<10.0 and jogo.controle.incidentes.linha_livre(admin.local,alvo.local)
	if not perto:
		if admin.ocupado(): return
		conversa.tentativa=float(conversa.tentativa)-delta
		if float(conversa.tentativa)>0.0: return
		conversa.tentativa=2.0
		var melhor: Array[Vector2i]=[]
		for d in GradePlex.VIZINHOS:
			var c: Vector2i=alvo.celula+d
			if not jogo.planta.transitavel(c): continue
			if str(jogo.planta.pisos.get(c,"")).begins_with("cidade_faixa_de_pedestre"): continue
			var rota: Array[Vector2i]=jogo.rotas.caminho(admin.origem_rota(),c)
			if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
		if melhor.is_empty(): cancelar();jogo.painel.mensagem("Não há passagem até esta pessoa.");return
		admin.andar(melhor);admin.trabalho="ir_conversar"
		return
	if admin.ocupado(): return
	admin.trabalho="conversar";alvo.trabalho="conversar"
	jogo.tarefas.orientar(admin,alvo.local);jogo.tarefas.orientar(alvo,admin.local)
	conversa.tempo=float(conversa.tempo)+delta
	if float(conversa.tempo)<4.0: return
	registrar(alvo,str(conversa.get("tipo","conversar")));cancelar();jogo.menu_controle.abrir_social(alvo)

func gravar() -> Dictionary:
	return registros.duplicate(true)

func restaurar(valor: Dictionary) -> void:
	cancelar();registros=valor.duplicate(true)

