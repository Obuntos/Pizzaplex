class_name AnimatronicosPlex
extends RefCounted
const INCREMENTOS={"media":0.2,"boa":0.1,"otima":0.05}
var jogo: Node
var palcos: PalcosPlex
func _init(cena: Node) -> void:
	jogo=cena
	palcos=PalcosPlex.new(jogo.planta)
static func base(id: String) -> String:
	for nome in ["coelho","ovelha","raposa"]:
		if id==nome or id.begins_with(nome+"_"): return nome
	return ""
static func garantir(a: PersonagemPlex) -> void:
	if not a.robo: return
	var desgaste:=2.0 if CatalogoMontagemPlex.quebrado(a.modelo) else 1.0 if "travad" in a.modelo else 0.0
	var qualidade:=a.caixa_qualidade
	if qualidade in ["perfeita","perfeito","otimo"]: qualidade="otima"
	if not INCREMENTOS.has(qualidade): qualidade="boa"
	var padrao: Dictionary={"modo":"automatico","estado":"desligado","tempo_estado":0.0,"segundos_uso":0.0,"minutos_uso":0,"desgaste":desgaste,"qualidade":qualidade,"avariado":desgaste>=2.0,"reparo_por":0,"manutencao_solicitada":false,"desligado_manual":false,"reparos":0}
	for chave in padrao:
		if not a.robotica.has(chave): a.robotica[chave]=padrao[chave]
static func pausado(a: PersonagemPlex) -> bool:
	return bool(a.robotica.get("desligado_manual",false)) or bool(a.robotica.get("manutencao_solicitada",false)) or int(a.robotica.get("reparo_por",0))>0
static func comandar_energia(a: PersonagemPlex, ligar: bool) -> void:
	garantir(a)
	a.robotica.desligado_manual=not ligar
	if ligar:
		a.robotica.manutencao_solicitada=false
	else:
		a.movimento.cancelar()
static func titulo(a: PersonagemPlex) -> String:
	garantir(a)
	return {"deslocando":"Em deslocamento","desligado":"Desligado","ativando":"Ativando","ligado":"Ligado","desligando":"Desligando","avariado":"Avariado"}.get(str(a.robotica.get("estado","desligado")),"Desligado")
func plateia(a: PersonagemPlex) -> bool:
	var palco:=palcos.da_pose(a.pose)
	return palco>=0 and jogo.personagens.any(func(p): return p.cargo in ["crianca","adolescente"] and p.trabalho=="assistir" and not p.ocupado() and palcos.da_pose(int(p.visita.get("pose",-1)))==palco)
static func mudar(a: PersonagemPlex, estado: String) -> void:
	if str(a.robotica.estado)==estado: return
	a.robotica.estado=estado
	a.robotica.tempo_estado=0.0
static func duracao_partida(a: PersonagemPlex) -> float:
	ClipesPlex.carregar()
	return float(ClipesPlex.modelos.get(a.modelo,{}).get("clipes",{}).get("ativando",{}).get("duracao",1.6))
func limpar_cache(a: PersonagemPlex) -> void:
	var nome:=base(a.modelo)
	if nome.is_empty(): return
	var ativos: Array[String]=[]
	for outro in jogo.personagens:
		if base(outro.modelo)!=nome or outro.robotica.is_empty(): continue
		var nivel:=clampi(roundi(float(outro.robotica.get("desgaste",0.0))*10),0,20)
		ativos.append("/deterioracao/"+nome+"/"+str(nivel)+"/")
	for chave in CatalogoPlex.texturas.keys():
		var caminho:=str(chave).replace("/iluminacao/","/")
		if caminho.contains("/deterioracao/"+nome+"/") and not ativos.any(func(prefixo): return caminho.contains(prefixo)): CatalogoPlex.texturas.erase(chave)
func atualizar(delta: float) -> void:
	palcos.atualizar()
	var ativos: Dictionary={}
	for p in jogo.personagens:
		if p.cargo in ["crianca","adolescente"] and p.trabalho=="assistir" and not p.ocupado():
			var id:=palcos.da_pose(int(p.visita.get("pose",-1)))
			if id>=0: ativos[id]=true
	for a in jogo.personagens:
		if not a.robo: continue
		garantir(a)
		var palco:=palcos.da_pose(a.pose)
		if palco>=0 and a.trabalho=="apresentar" and not a.ocupado() and a.robotica.modo=="sempre" and not a.robotica.avariado and not pausado(a): ativos[palco]=true
	for a in jogo.personagens:
		if not a.robo: continue
		garantir(a)
		if not a.pronto_para_destino(): continue
		a.robotica.tempo_estado=float(a.robotica.tempo_estado)+delta
		if pausado(a): a.movimento.cancelar()
		if a.ocupado():
			mudar(a,"deslocando")
			continue
		if bool(a.robotica.avariado):
			mudar(a,"avariado")
			continue
		if int(a.robotica.reparo_por)>0:
			mudar(a,"desligado")
			continue
		var no_palco: bool=a.trabalho=="apresentar" and palcos.da_pose(a.pose)>=0
		var deve_ligar: bool=not pausado(a) and (ativos.has(palcos.da_pose(a.pose)) if no_palco else a.robotica.modo=="sempre" and a.trabalho!="reservado_pecas")
		if deve_ligar:
			if a.robotica.estado=="deslocando": mudar(a,"ligado")
			elif a.robotica.estado in ["desligado","desligando"]: mudar(a,"ativando")
			elif a.robotica.estado=="ativando" and a.robotica.tempo_estado>=duracao_partida(a): mudar(a,"ligado")
		elif a.robotica.estado in ["deslocando","ligado","ativando"]: mudar(a,"desligando")
		elif a.robotica.estado=="desligando" and a.robotica.tempo_estado>=1.6: mudar(a,"desligado")
		if a.robotica.estado!="ligado": continue
		a.robotica.segundos_uso=float(a.robotica.segundos_uso)+delta
		var alterou:=false
		while float(a.robotica.segundos_uso)>=60.0:
			a.robotica.segundos_uso-=60.0
			a.robotica.minutos_uso=int(a.robotica.minutos_uso)+1
			a.robotica.desgaste=minf(2.0,float(a.robotica.desgaste)+float(INCREMENTOS.get(str(a.robotica.qualidade),0.2)))
			alterou=true
			if float(a.robotica.desgaste)>=1.99999:
				a.robotica.desgaste=2.0
				a.robotica.avariado=true
				mudar(a,"avariado")
				break
		if alterou: limpar_cache(a)

