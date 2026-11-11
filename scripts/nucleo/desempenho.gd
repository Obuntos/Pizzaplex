class_name DesempenhoPlex
extends RefCounted
var tempos:Dictionary={}
var quadros:Array[float]=[]
var espera:=0.0
var ultimo:=0
var neste_quadro:Dictionary={}
var piores:Array=[]
var espera_registro:=0.0
func medir(nome:String,inicio:int) -> void:
	var ms:float=(Time.get_ticks_usec()-inicio)/1000.0
	var d:Dictionary=tempos.get(nome,{"media":ms,"pico":0.0,"amostras":0})
	d.media=lerpf(float(d.media),ms,.08);d.pico=maxf(float(d.pico)*.995,ms);d.amostras=int(d.amostras)+1;tempos[nome]=d
	neste_quadro[nome]=float(neste_quadro.get(nome,0.0))+ms
func quadro(delta:float) -> void:
	if delta<=0:return
	quadros.append(delta*1000.0)
	if quadros.size()>300:quadros.pop_front()
	if delta*1000.0>=50.0:
		var nomes:Array=neste_quadro.keys();nomes.sort_custom(func(a,b):return float(neste_quadro[a])>float(neste_quadro[b]))
		var partes:=PackedStringArray()
		for n in nomes.slice(0,3):partes.append(str(n)+" %.1f ms"%float(neste_quadro[n]))
		piores.append({"ms":delta*1000.0,"quando":Time.get_datetime_string_from_system(),"sistemas":", ".join(partes)})
		piores.sort_custom(func(a,b):return float(a.ms)>float(b.ms))
		if piores.size()>10:piores.resize(10)
	neste_quadro.clear()
	espera_registro+=delta
	if espera_registro>=30.0:espera_registro=0.0;registrar()
func registrar() -> void:
	if piores.is_empty():return
	var arquivo:=FileAccess.open("user://desempenho.txt",FileAccess.WRITE)
	if arquivo==null:return
	arquivo.store_line("Piores quadros (ms) · "+Time.get_datetime_string_from_system())
	for p in piores:arquivo.store_line("%.0f ms · %s · %s"%[float(p.ms),str(p.quando),str(p.sistemas)])
	arquivo.close()
func resumo() -> String:
	var linhas:=PackedStringArray(["FPS: %d"%Engine.get_frames_per_second(),"Memória: %.0f MB"%(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)])
	if not quadros.is_empty():
		var ordenados:=quadros.duplicate();ordenados.sort();linhas.append("Quadro p95: %.1f ms"%float(ordenados[mini(ordenados.size()-1,floori(ordenados.size()*.95))]))
	var nomes:Array=tempos.keys();nomes.sort_custom(func(a,b):return float(tempos[a].media)>float(tempos[b].media))
	for n in nomes.slice(0,5):linhas.append(str(n)+": %.2f ms · pico %.1f"%[float(tempos[n].media),float(tempos[n].pico)])
	return "\n".join(linhas)
