class_name CicloSolarPlex
extends RefCounted

const HORARIOS = [0.0,5.0,5.5,6.5,8.0,12.5,16.0,18.0,19.0,19.5,24.0]
const AMBIENTES = [.008,.008,.025,.18,.52,.62,.46,.18,.035,.008,.008]

static func estado(minutos: float, clima: String) -> Dictionary:
	var hora := fposmod(minutos,1440.0)/60.0
	var ambiente := .008
	for i in range(HORARIOS.size()-1):
		if hora>=HORARIOS[i] and hora<=HORARIOS[i+1]:
			ambiente=lerpf(AMBIENTES[i],AMBIENTES[i+1],smoothstep(HORARIOS[i],HORARIOS[i+1],hora))
			break
	var fase := clampf((hora-5.5)/14.0,0.0,1.0)
	var arco := maxf(0.0,sin(fase*PI))
	var elevacao := arco*1.12
	var direcao := Vector3(cos(fase*PI)*cos(elevacao),-.28*arco*cos(elevacao),sin(elevacao)).normalized()
	var tempo_ruim := .4 if clima in ["Chuva","Neve"] else .72 if clima=="Nublado" else 1.0
	var energia := smoothstep(0.0,.22,arco)*.48*tempo_ruim if hora>5.5 and hora<19.5 else 0.0
	var cor := Color(1.0,.57,.30).lerp(Color(1.0,.95,.80),smoothstep(.08,.7,arco))
	var cor_ambiente := Color(.32,.43,.68).lerp(Color(1.0,.97,.89),smoothstep(.025,.45,ambiente))
	if hora>=16.0 and hora<19.5:
		var por_do_sol := smoothstep(16.0,18.0,hora)*(1.0-smoothstep(18.5,19.5,hora))
		cor_ambiente=cor_ambiente.lerp(Color(1.0,.65,.46),por_do_sol*.65)
	if clima in ["Chuva","Neve"]: ambiente*=.82
	return {"ambiente":ambiente,"direcao":direcao,"energia":energia,"cor":cor,"cor_ambiente":cor_ambiente}
