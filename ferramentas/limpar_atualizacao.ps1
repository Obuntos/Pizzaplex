$ErrorActionPreference = 'Stop'
try {
    $raiz = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (!(Test-Path -LiteralPath (Join-Path $raiz 'project.godot') -PathType Leaf)) {
        throw 'Extraia a atualizacao na pasta que contem project.godot.'
    }
    if (Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue) {
        throw 'Feche o Godot antes de executar a limpeza.'
    }
    if (!(Test-Path -LiteralPath (Join-Path $raiz 'dados\roupas_visitantes.json') -PathType Leaf)) {
        throw 'Extraia todos os arquivos da atualizacao de visitantes antes da limpeza.'
    }
    $roupas = Get-Content -LiteralPath (Join-Path $raiz 'dados\roupas_visitantes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$roupas.humano_look_8 -or !$roupas.humana_look_8 -or !$roupas.humana_vestido_8) {
        throw 'O catalogo de roupas da atualizacao esta incompleto.'
    }
    $catalogo = Get-Content -LiteralPath (Join-Path $raiz 'dados\assets_fachada.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($catalogo.parede_fachada.origem_volume -ne 'parede') {
        throw 'A atualizacao das paredes ainda nao foi aplicada.'
    }
    foreach ($arquivo in Get-ChildItem -LiteralPath (Join-Path $raiz 'dados') -Filter '*.json' -File) {
        $texto = Get-Content -LiteralPath $arquivo.FullName -Raw -Encoding UTF8
        if ($texto -match 'assets[/\\]+objetos[/\\]+fachada[/\\]+parede_fachada') {
            throw ('Ainda existe uma referencia ativa a parede antiga em ' + $arquivo.Name + '.')
        }
    }
    $alvos = @('assets\objetos\fachada\parede_fachada', 'ferramentas\__pycache__')
    $removidos = 0
    foreach ($relativo in $alvos) {
        $atual = $raiz
        foreach ($parte in $relativo.Split('\')) {
            $atual = Join-Path $atual $parte
            if (Test-Path -LiteralPath $atual) {
                $item = Get-Item -LiteralPath $atual -Force
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw ('Caminho redirecionado: ' + $relativo + '. Nenhum arquivo desse caminho foi excluido.')
                }
            }
        }
        if (Test-Path -LiteralPath $atual) {
            Remove-Item -LiteralPath $atual -Recurse -Force
            Write-Host ('Removido: ' + $relativo)
            $removidos++
        }
    }
    if ($removidos -eq 0) {
        Write-Host 'Nenhum arquivo antigo pendente de limpeza.'
    } else {
        Write-Host 'Limpeza concluida.'
    }
    Write-Host 'Uniformes, cabelos, roupas de visitantes e modelos ativos foram mantidos.'
    exit 0
} catch {
    Write-Host $_.Exception.Message
    exit 1
}
