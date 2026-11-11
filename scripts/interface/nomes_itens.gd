class_name NomesItensPlex
extends RefCounted
const CURTOS={
"porta":"Porta de madeira","porta_dupla":"Porta dupla","porta_principal":"Porta de vidro","porta_servico":"Porta de serviço","antigo_porta_antiga_1":"Porta de madeira","antigo_porta_antiga_2":"Porta madeira dupla","janela":"Janela pequena","janela_2":"Janela média","janela_3":"Janela grande","antigo_escada_madeira_3":"Escada velha","cortina_central_2":"Cortina média","cortina_central_3":"Cortina grande","cortina_central_9":"Cortina longa","bancada_montagem_coelho":"Bancada de montagem","oficina_bancada_trabalho":"Bancada de montagem","antigo_estante_velha_1":"Estante velha","antigo_estante_velha_2":"Estante velha grande","antigo_cadeira_velha":"Cadeira velha","antigo_mesa_velha_1":"Mesa velha pequena","antigo_mesa_velha_3":"Mesa velha grande","antigo_barril_escuro":"Lixeira","oficina_duto_grade":"Ventilação",
"amb_mesa_roxa_estrelas":"Mesa estrelas","amb_mesa_amarela_confetes":"Mesa confetes","mesa_longa":"Mesa retangular","mesa_longa_arredondada":"Mesa arredondada","amb_cadeira_vinho":"Cadeira vinho","amb_cadeira_roxa":"Cadeira concha","amb_cadeira_verde":"Cadeira verde","sistema_triturador_residuos":"Triturador","sistema_caixa_som_chao":"Caixa de som","sistema_caixa_som_teto":"Alto-falante","amb_espelho_banheiro":"Espelho","amb_dispensador_papel":"Papel toalha","area_montagem_atracao":"Base de montagem","amb_painel_diagnostico":"Diagnóstico","amb_carregador_oficina":"Carregador","amb_livro_reservas":"Reservas","amb_quadro_energia":"Caixa de energia","amb_relogio_ponto":"Relógio de ponto","amb_carrinho_louca":"Carrinho de louça","amb_escorredor_louca":"Escorredor","amb_interruptor_antigo":"Energia","amb_telefone_disco":"Telefone","amb_maquina_premios":"Prêmios","amb_maquina_fichas":"Fichas","amb_balcao_tickets":"Balcão tickets","amb_fliperama_estrelar":"Arcade estrelas","amb_fliperama_corrida":"Arcade corrida","cenario_gerador_novo":"Gerador","cenario_gerador_antigo":"Gerador antigo","terminal_ibm":"IBM","registradora":"Registradora","ponto_recebimento":"Recebimento","pia_banheiro":"Pia","vaso_sanitario":"Vaso sanitário","divisoria_porta":"Divisória","armario_limpeza":"Armário limpeza","armario_funcionarios":"Vestiário","bancada_preparo":"Preparo","lixeira_salao":"Lixeira salão"}
static var en:Dictionary={}
static func carregar_en() -> void:
	if not en.is_empty():return
	var d=JSON.parse_string(FileAccess.get_file_as_string("res://dados/nomes_itens_en.json"))
	if typeof(d)==TYPE_DICTIONARY:en=d
static func original(tipo:String) -> String:
	return str(CatalogoPlex.objetos[tipo].nome)
static func nome_pt(tipo:String) -> String:
	return str(CURTOS.get(tipo,original(tipo)))
static func nome(tipo:String) -> String:
	if IdiomaPlex.idioma_atual()=="en":
		carregar_en()
		if en.has("tipos") and en.tipos.has(tipo):return str(en.tipos[tipo])
		var o:=original(tipo)
		if en.has("nomes") and en.nomes.has(o):
			var t:=str(en.nomes[o])
			return t if t.length()<=34 else t.left(33).strip_edges()+"."
		return IdiomaPlex.traduzir(o)
	if CURTOS.has(tipo):return CURTOS[tipo]
	var n:=str(CatalogoPlex.objetos[tipo].nome)
	for par in [["Quadriculado","Xadrez"],["quadriculado","xadrez"],[" industrial",""],[" de banheiro",""],[" de cozinha",""],[" decorativo",""],[" antiga",""],[" antigo",""],[" de parede",""],[" de madeira",""],[" suspensa",""],[" · abre/fecha",""],[" de chão",""]]:n=n.replace(par[0],par[1])
	n=n.replace(" de "," ").replace(" da "," ").replace(" do "," ")
	var palavras:=n.split(" ",false)
	while " ".join(palavras).length()>28 and palavras.size()>3:palavras.remove_at(palavras.size()-2)
	n=" ".join(palavras)
	if n.length()>28:n=n.left(27).strip_edges()+"."
	return n
