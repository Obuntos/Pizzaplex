class_name LoucaSecagemPlex
extends RefCounted

static func destino(s:ServicosPlex,prato:Dictionary,secagem:bool=false) -> Dictionary:
	if PratosPlex.papel(prato):return {}
	var tipo:="amb_escorredor_louca" if secagem else "amb_carrinho_louca"
	for p in s.planta.objetos.values():
		if p.tipo!=tipo or int(prato.get("sobre",-1))==int(p.id) or not CozinhaProntaPlex.na_cozinha(s,int(p.id)):continue
		if secagem and int(prato.get("sobre",-1))>=0 and s.salas.do_objeto(int(prato.sobre)).get("id",-1)!=s.salas.do_objeto(int(p.id)).get("id",-2):continue
		if not s.livre(int(p.id)):continue
		var slot:=ApoiosPlex.livre(s.planta,int(p.id),"prato")
		if slot>=0:return {"pai":p.id,"slot":slot}
	return {}
static func pode_recolher(s:ServicosPlex,prato:Dictionary) -> bool:return s.tempo_servico>=float(prato.get("secando_ate",0))
static func apoiar(planta:PlantaPlex,prato:Dictionary,pai:int) -> void:
	var p:Dictionary=planta.objetos.get(pai,{})
	if p.get("tipo","")!="amb_escorredor_louca" or prato.get("sujo",false) or PratosPlex.papel(prato):return
	var cena:=Engine.get_main_loop() as SceneTree
	var jogo:Node=cena.current_scene if cena!=null else null
	if jogo!=null and "servicos" in jogo:prato.secando_ate=jogo.servicos.tempo_servico+5.0/CalendarioPlex.MINUTOS_POR_SEGUNDO
