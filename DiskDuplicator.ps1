#region INFO E VERIFICAÇÕES INICIAIS
# =================================================================================================
# Disk Duplicator PS - Ferramenta de Clonagem e Backup de Discos para Windows
# Versao: 2.9 - DD WIZ Edition
# Autor: tuninho kjr
#
# CHANGELOG v2.9:
# - ADICIONADO: Ao criar uma nova particao, o script agora permite escolher o
#   sistema de arquivos (NTFS, exFAT, FAT32), alem do estilo de particao (GPT/MBR).
#
# CHANGELOG v2.8:
# - ADICIONADO: Opcao para escolher o estilo de particao (GPT/MBR) apos a limpeza.
# =================================================================================================

# --- Garante que todos os caracteres especiais sejam exibidos corretamente no console.
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Verifica se o script esta sendo executado como Administrador ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n🛑 ERRO: Este script precisa ser executado com privilegios de Administrador." -ForegroundColor Red
    Write-Host "   Por favor, clique com o botao direito no arquivo .ps1 e selecione 'Executar com o PowerShell' como Administrador." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Exit
}

# --- Define o caminho para as ferramentas externas e inicia o Log ---
$scriptPath = $PSScriptRoot
$ddPath = Join-Path $scriptPath "dd.exe"
$zstdPath = Join-Path $scriptPath "zstd.exe"
$LogFile = Join-Path $scriptPath "DiskDuplicator-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
Start-Transcript -Path $LogFile

# --- Verifica se as dependencias existem ---
if (-not (Test-Path $ddPath) -or (-not (Test-Path $zstdPath))) {
    Write-Host "`n🛑 ERRO: Ferramentas externas nao encontradas." -ForegroundColor Red
    Write-Host "   Certifique-se de que 'dd.exe' e 'zstd.exe' estao na mesma pasta que este script." -ForegroundColor Yellow
    Write-Host "   - dd for windows: http://www.chrysocome.net/dd"
    Write-Host "   - zstd releases: https://github.com/facebook/zstd/releases"
    Invoke-Pause
    Exit
}

#endregion

#region FUNÇÕES PRINCIPAIS

function Show-MainMenu {
    Clear-Host
    $asciiArt = @"
 ____  ____      _ _   _
|  _ \ |  _ \    (_) | (_)
| | | || | | |  _ __  | |  _
| | | || | | | || '_ \ | | / /
| |_| || |_| || | | ||   <
|____/ |____/ |_| |_||_|\_\
                          _/ |
                         |__/
                 DD WIZ Edition v2.9
"@
    Write-Host $asciiArt -ForegroundColor Cyan

    Write-Host "=================================================================================" -ForegroundColor Blue
    Write-Host "   1) Criar imagem de um disco (backup)"
    Write-Host "   2) Restaurar imagem para um disco"
    Write-Host "   3) Clonar um disco para outro (direto)"
    Write-Host "   4) Verificar integridade de uma imagem (.sha256)"
    Write-Host "   5) Listar discos disponiveis"
    Write-Host "   6) Formatar um volume (por Letra)"
    Write-Host "   7) Limpar um disco (remover particoes, por Numero)"
    Write-Host "   8) Sair"
    Write-Host "=================================================================================" -ForegroundColor Blue
}

function Invoke-Pause {
    Write-Host "`nPressione qualquer tecla para continuar..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

function Get-DiskList {
    Write-Host "`n--- Discos Fisicos Disponiveis ---" -ForegroundColor Cyan
    Get-Disk | Format-Table -AutoSize Number, FriendlyName, @{Name = "Tamanho (GB)"; Expression = { [math]::Round($_.Size / 1GB, 2) } }, SerialNumber
    Write-Host "`n--- Volumes (Particoes) ---" -ForegroundColor Cyan
    Get-Volume | Format-Table -AutoSize DriveLetter, FileSystemLabel, FileSystem, @{Name = "Tamanho (GB)"; Expression = { [math]::Round($_.Size / 1GB, 2) } }, @{Name = "Espaco Livre (GB)"; Expression = { [math]::Round($_.SizeRemaining / 1GB, 2) } }
}

# ... (As funções New-DiskImage, Restore-DiskImage, Start-DiskClone, Test-ImageIntegrity, Start-VolumeFormat não mudaram)
function New-DiskImage {
    Clear-Host
    Get-DiskList
    try {
        $sourceDiskNum = Read-Host "`n[PASSO 1/3] Digite o NUMERO do disco de ORIGEM para criar a imagem"
        $sourceDisk = Get-Disk -Number $sourceDiskNum
    } catch {
        Write-Host "ERRO: Numero de disco invalido. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }

    $imagePath = Read-Host "`n[PASSO 2/3] Digite o caminho completo para salvar o arquivo de imagem (ex: D:\backups\meudisco.img)"
    if ([string]::IsNullOrWhiteSpace($imagePath)) {
        Write-Host "ERRO: O caminho do arquivo nao pode ser vazio. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }

    $compressChoice = Read-Host "`n[PASSO 3/3] Deseja comprimir a imagem com Zstandard (zstd)? [s/n]"
    $useCompression = $compressChoice -eq 's'
    if ($useCompression) {
        $imagePath += ".zst"
    }

    $sourceDiskSizeStr = "{0:N2} GB" -f ($sourceDisk.Size / 1GB)
    $compressionStatus = if ($useCompression) { 'SIM' } else { 'NAO' }
    Write-Host "`n========================= CONFIRMACAO =========================" -ForegroundColor Yellow
    Write-Host "Voce esta prestes a criar uma imagem do disco:"
    Write-Host "   - ORIGEM: Disco $($sourceDisk.Number) - $($sourceDisk.FriendlyName) ($sourceDiskSizeStr)"
    Write-Host "   - DESTINO: '$imagePath'"
    Write-Host "   - Compressao: $compressionStatus"
    Write-Host "=================================================================" -ForegroundColor Yellow
    $confirm = Read-Host "Tem certeza que deseja continuar? [s/n]"
    if ($confirm -ne 's') {
        Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Green
        Invoke-Pause
        return
    }

    Write-Host "`nIniciando a criacao da imagem... Isso pode levar MUITO tempo." -ForegroundColor Green
    $ddCommand = """$ddPath"" if=\\.\PhysicalDrive$($sourceDisk.Number) bs=8M --progress"
    if ($useCompression) {
        $fullCommand = "$ddCommand | ""$zstdPath"" -o ""$imagePath"""
    } else {
        $fullCommand = "$ddCommand of=""$imagePath"""
    }
    $commandToRun = "cmd.exe /c ""$fullCommand"""
    Invoke-Expression $commandToRun

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n🛑 ERRO: A operacao de disco falhou (Codigo de saida: $LASTEXITCODE). Verifique o log para mais detalhes." -ForegroundColor Red
    } else {
        Write-Host "`n✅ Processo de criacao de imagem concluido." -ForegroundColor Green
        $hashChoice = Read-Host "Deseja criar um arquivo de verificacao SHA-256 para esta imagem? [s/n]"
        if ($hashChoice -eq 's') {
            Write-Host "Gerando hash SHA-256... Isso pode demorar." -ForegroundColor Cyan
            try {
                Get-FileHash -Algorithm SHA256 -Path $imagePath | ForEach-Object { $_.Hash } | Set-Content -Path "$($imagePath).sha256" -Encoding utf8
                Write-Host "✅ Arquivo de hash '$($imagePath).sha256' criado com sucesso." -ForegroundColor Green
            } catch {
                Write-Host "🛑 ERRO ao gerar o arquivo de hash." -ForegroundColor Red
            }
        }
    }
    Invoke-Pause
}
function Restore-DiskImage {
    Clear-Host
    $imagePath = Read-Host "`n[PASSO 1/3] Digite o caminho completo do arquivo de imagem a ser restaurado (ex: D:\backups\meudisco.img.zst)"
    if (-not (Test-Path $imagePath)) {
        Write-Host "ERRO: Arquivo de imagem nao encontrado. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }
    Get-DiskList
    try {
        $destDiskNum = Read-Host "`n[PASSO 2/3] Digite o NUMERO do disco de DESTINO que sera sobrescrito"
        $destDisk = Get-Disk -Number $destDiskNum
    } catch {
        Write-Host "ERRO: Numero de disco invalido. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }
    $isCompressed = $imagePath.EndsWith(".zst")
    if (-not $isCompressed) {
        $imageSize = (Get-Item $imagePath).Length
        if ($destDisk.Size -lt $imageSize) {
            Write-Host "🛑 ERRO CRITICO: O disco de destino ($("{0:N2} GB" -f ($destDisk.Size/1GB))) e MENOR que a imagem de backup ($("{0:N2} GB" -f ($imageSize/1GB)))." -ForegroundColor Red
            Write-Host "   A restauracao foi cancelada para evitar corrompimento de dados." -ForegroundColor Yellow
            Invoke-Pause
            return
        }
    }
    $destDiskSizeStr = "{0:N2} GB" -f ($destDisk.Size / 1GB)
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!! AVISO DE PERDA DE DADOS !!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "A operacao a seguir ira APAGAR COMPLETAMENTE E PERMANENTEMENTE todos os dados" -ForegroundColor Red
    Write-Host "no disco de destino. Esta acao e IRREVERSIVEL." -ForegroundColor Red
    Write-Host "   - IMAGEM: '$imagePath'"
    Write-Host "   - DESTINO: Disco $($destDisk.Number) - $($destDisk.FriendlyName) ($destDiskSizeStr) - Serial: $($destDisk.SerialNumber)"
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    $confirmation = Read-Host "`n[PASSO 3/3] Para confirmar, digite o modelo completo do disco de destino: '$($destDisk.FriendlyName)'"
    if ($confirmation -ne $destDisk.FriendlyName) {
        Write-Host "`nConfirmacao incorreta. A seguranca prevaleceu. Operacao cancelada." -ForegroundColor Yellow
        Invoke-Pause
        return
    }

    Write-Host "`nConfirmacao aceita." -ForegroundColor Green
    
    try {
        Write-Host "Colocando o disco de destino offline para acesso exclusivo..." -ForegroundColor Yellow
        Set-Disk -Number $destDisk.Number -IsOffline $true
        
        Write-Host "Iniciando a restauracao... Isso pode levar MUITO tempo." -ForegroundColor Green
        if ($isCompressed) {
            $fullCommand = """$zstdPath"" -d -c ""$imagePath"" | ""$ddPath"" of=\\.\PhysicalDrive$($destDisk.Number) bs=8M --progress"
        } else {
            $fullCommand = """$ddPath"" if=""$imagePath"" of=\\.\PhysicalDrive$($destDisk.Number) bs=8M --progress"
        }
        $commandToRun = "cmd.exe /c ""$fullCommand"""
        Invoke-Expression $commandToRun

        if ($LASTEXITCODE -ne 0) {
            Write-Host "`n🛑 ERRO: A operacao de disco falhou (Codigo de saida: $LASTEXITCODE). Verifique o log para mais detalhes." -ForegroundColor Red
        } else {
            Write-Host "`n✅ Restauracao concluida com sucesso." -ForegroundColor Green
        }
    }
    finally {
        Write-Host "Colocando o disco de destino online novamente..." -ForegroundColor Yellow
        Set-Disk -Number $destDisk.Number -IsOffline $false
    }
    Invoke-Pause
}
function Start-DiskClone {
    Clear-Host
    Get-DiskList
    try {
        $sourceDiskNum = Read-Host "`n[PASSO 1/4] Digite o NUMERO do disco de ORIGEM"
        $sourceDisk = Get-Disk -Number $sourceDiskNum
        $destDiskNum = Read-Host "`n[PASSO 2/4] Digite o NUMERO do disco de DESTINO (sera APAGADO)"
        $destDisk = Get-Disk -Number $destDiskNum
    } catch {
        Write-Host "ERRO: Numero de disco invalido. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }

    if ($sourceDisk.Number -eq $destDisk.Number) {
        Write-Host "ERRO: O disco de origem e destino nao podem ser o mesmo. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }
    if ($destDisk.Size -lt $sourceDisk.Size) {
        Write-Host "🛑 ERRO CRITICO: O disco de destino ($("{0:N2} GB" -f ($destDisk.Size/1GB))) e MENOR que o disco de origem ($("{0:N2} GB" -f ($sourceDisk.Size/1GB)))." -ForegroundColor Red
        Write-Host "   A clonagem foi cancelada para evitar corrompimento de dados." -ForegroundColor Yellow
        Invoke-Pause
        return
    }

    $sourceDiskSizeStr = "{0:N2} GB" -f ($sourceDisk.Size / 1GB)
    $destDiskSizeStr = "{0:N2} GB" -f ($destDisk.Size / 1GB)
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!! AVISO DE PERDA DE DADOS !!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "A operacao a seguir ira APAGAR COMPLETAMENTE E PERMANENTEMENTE todos os dados" -ForegroundColor Red
    Write-Host "no disco de destino. Esta acao e IRREVERSIVEL." -ForegroundColor Red
    Write-Host "   - ORIGEM:  Disco $($sourceDisk.Number) - $($sourceDisk.FriendlyName) ($sourceDiskSizeStr)"
    Write-Host "   - DESTINO: Disco $($destDisk.Number) - $($destDisk.FriendlyName) ($destDiskSizeStr) - Serial: $($destDisk.SerialNumber)"
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red

    $confirmation = Read-Host "`n[PASSO 3/4] Para confirmar, digite o modelo completo do disco de destino: '$($destDisk.FriendlyName)'"
    if ($confirmation -ne $destDisk.FriendlyName) {
        Write-Host "`nConfirmacao incorreta. A seguranca prevaleceu. Operacao cancelada." -ForegroundColor Yellow
        Invoke-Pause
        return
    }
    
    Write-Host "`nConfirmacao aceita." -ForegroundColor Green
    $finalConfirm = Read-Host "[PASSO 4/4] Esta e sua ultima chance. Continuar com a clonagem? [s/n]"
    if($finalConfirm -ne 's'){
        Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Green
        Invoke-Pause
        return
    }

    try {
        Write-Host "Colocando o disco de destino offline para acesso exclusivo..." -ForegroundColor Yellow
        Set-Disk -Number $destDisk.Number -IsOffline $true
        
        Write-Host "Iniciando a clonagem... Isso pode levar MUITO tempo." -ForegroundColor Green
        $fullCommand = """$ddPath"" if=\\.\PhysicalDrive$($sourceDisk.Number) of=\\.\PhysicalDrive$($destDisk.Number) bs=8M --progress"
        $commandToRun = "cmd.exe /c ""$fullCommand"""
        Invoke-Expression $commandToRun

        if ($LASTEXITCODE -ne 0) {
            Write-Host "`n🛑 ERRO: A operacao de disco falhou (Codigo de saida: $LASTEXITCODE). Verifique o log para mais detalhes." -ForegroundColor Red
        } else {
            Write-Host "`n✅ Clonagem concluida com sucesso." -ForegroundColor Green
        }
    }
    finally {
        Write-Host "Colocando o disco de destino online novamente..." -ForegroundColor Yellow
        Set-Disk -Number $destDisk.Number -IsOffline $false
    }
    Invoke-Pause
}
function Test-ImageIntegrity {
    Clear-Host
    $imagePath = Read-Host "`n[PASSO 1/2] Digite o caminho completo do arquivo de imagem a ser verificado"
    $hashPath = "$imagePath.sha256"
    if (-not (Test-Path $imagePath)) {
        Write-Host "ERRO: Arquivo de imagem '$imagePath' nao encontrado." -ForegroundColor Red
        Invoke-Pause
        return
    }
    if (-not (Test-Path $hashPath)) {
        Write-Host "ERRO: Arquivo de hash '$hashPath' nao encontrado. Nao e possivel verificar." -ForegroundColor Red
        Invoke-Pause
        return
    }

    Write-Host "`nIniciando verificacao... Isso pode demorar dependendo do tamanho do arquivo." -ForegroundColor Cyan
    $storedHash = Get-Content $hashPath
    $calculatedHash = (Get-FileHash -Algorithm SHA256 -Path $imagePath).Hash
    Write-Host "`nHash armazenado no arquivo: $storedHash"
    Write-Host "Hash calculado da imagem  : $calculatedHash"
    if ($storedHash.Trim().ToUpperInvariant() -eq $calculatedHash.Trim().ToUpperInvariant()) {
        Write-Host "`n✅ INTEGRIDADE CONFIRMADA: Os hashes sao identicos." -ForegroundColor Green
    } else {
        Write-Host "`n🛑 FALHA NA VERIFICACAO: Os hashes sao DIFERENTES. O arquivo pode estar corrompido!" -ForegroundColor Red
    }
    Invoke-Pause
}
function Start-VolumeFormat {
    Clear-Host
    Get-DiskList
    
    $targetLetter = Read-Host "`n[PASSO 1/5] Digite a LETRA da unidade que deseja formatar (ex: E)"
    $targetVolume = Get-Volume -DriveLetter $targetLetter -ErrorAction SilentlyContinue
    if (-not $targetVolume) {
        Write-Host "ERRO: Letra de unidade invalida ou nao encontrada. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }

    Write-Host "`n[PASSO 2/5] Escolha o sistema de arquivos:"
    Write-Host "   1) NTFS (Padrao para Windows, mais seguro)"
    Write-Host "   2) exFAT (Para pendrives/HDs externos maiores que 32GB)"
    Write-Host "   3) FAT32 (Compatibilidade maxima com aparelhos antigos)"
    $fsChoice = Read-Host "Escolha uma opcao"
    switch ($fsChoice) {
        '1' { $fileSystem = "NTFS" }
        '2' { $fileSystem = "exFAT" }
        '3' { $fileSystem = "FAT32" }
        default {
            Write-Host "Opcao invalida. Operacao cancelada." -ForegroundColor Yellow
            Invoke-Pause
            return
        }
    }

    $newLabel = Read-Host "`n[PASSO 3/5] Digite um novo nome para o volume (opcional, deixe em branco para nenhum)"

    $quickFormatChoice = Read-Host "`n[PASSO 4/5] Deseja realizar uma Formatacao Rapida? (s/n)"
    $isQuickFormat = $quickFormatChoice -eq 's'

    $currentLabel = if ([string]::IsNullOrWhiteSpace($targetVolume.FileSystemLabel)) { "[vazio]" } else { $targetVolume.FileSystemLabel }
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!! AVISO DE PERDA DE DADOS !!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "A operacao a seguir ira APAGAR COMPLETAMENTE E PERMANENTEMENTE todos os dados" -ForegroundColor Red
    Write-Host "no volume selecionado. Esta acao e IRREVERSIVEL." -ForegroundColor Red
    Write-Host "   - VOLUME ALVO: $($targetVolume.DriveLetter): ($("{0:N2} GB" -f ($targetVolume.Size/1GB)))"
    Write-Host "   - NOME ATUAL: '$($currentLabel)'"
    Write-Host "   - NOVO SISTEMA DE ARQUIVOS: $fileSystem"
    Write-Host "   - NOVO NOME: '$newLabel'"
    Write-Host "   - TIPO: $(if ($isQuickFormat) {'Rapida'} else {'Completa'})"
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    
    $confirmLabel = if ($currentLabel -eq "[vazio]") { $targetVolume.DriveLetter } else { $currentLabel }
    $confirmation = Read-Host "`n[PASSO 5/5] Para confirmar, digite o NOME ATUAL do volume ('$confirmLabel')"
    if ($confirmation -ne $confirmLabel) {
        Write-Host "`nConfirmacao incorreta. A seguranca prevaleceu. Operacao cancelada." -ForegroundColor Yellow
        Invoke-Pause
        return
    }

    Write-Host "`nConfirmacao aceita. Iniciando a formatacao..." -ForegroundColor Green
    try {
        $params = @{
            DriveLetter        = $targetLetter
            FileSystem         = $fileSystem
            NewFileSystemLabel = $newLabel
            Force              = $true
        }
        if (-not $isQuickFormat) {
            $params.Add("Full", $true)
        }
        
        Format-Volume @params
        Write-Host "`n✅ Volume $($targetLetter): formatado com sucesso para $fileSystem." -ForegroundColor Green
    } catch {
        Write-Host "`n🛑 ERRO: A formatacao falhou. Mensagem do sistema: $($_.Exception.Message)" -ForegroundColor Red
    }
    Invoke-Pause
}


function Invoke-DiskWipe {
    Clear-Host
    Get-DiskList

    try {
        $targetDiskNum = Read-Host "`n[PASSO 1/2] Digite o NUMERO do disco que sera COMPLETAMENTE APAGADO"
        $targetDisk = Get-Disk -Number $targetDiskNum
    } catch {
        Write-Host "ERRO: Numero de disco invalido. Operacao cancelada." -ForegroundColor Red
        Invoke-Pause
        return
    }
    
    try {
        $systemPartition = Get-Partition | Where-Object { $_.IsSystem } | Select-Object -First 1
        if ($systemPartition -and $systemPartition.DiskNumber -eq $targetDisk.Number) {
            Write-Host "`n🛑 ERRO CRITICO: Voce selecionou o disco que contem a particao do sistema." -ForegroundColor Red
            Write-Host "   A limpeza do disco do sistema operacional e bloqueada por seguranca." -ForegroundColor Yellow
            Invoke-Pause
            return
        }
    } catch {}

    $serialNumber = $targetDisk.SerialNumber.Trim()
    if ([string]::IsNullOrWhiteSpace($serialNumber)) {
        $serialNumber = "NAO_DISPONIVEL"
    }
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!! AVISO DE DESTRUICAO DE DADOS !!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "Esta operacao e a mais destrutiva deste programa. Ela ira remover TODAS as" -ForegroundColor Red
    Write-Host "particoes e apagar a tabela de particao. O disco ficara como 'nao inicializado'," -ForegroundColor Red
    Write-Host "sem nenhum dado acessivel. ACAO IRREVERSIVEL." -ForegroundColor Red
    Write-Host "   - DISCO ALVO: $($targetDisk.Number) - $($targetDisk.FriendlyName) ($("{0:N2} GB" -f ($targetDisk.Size/1GB)))"
    Write-Host "   - NUMERO DE SERIE: '$($serialNumber)'"
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    
    $confirmation = Read-Host "`n[PASSO 2/2] Para confirmar, digite o NUMERO DE SERIE completo do disco: '$($serialNumber)'"
    if ($confirmation -ne $serialNumber) {
        Write-Host "`nConfirmacao incorreta. A seguranca prevaleceu. Operacao cancelada." -ForegroundColor Yellow
        Invoke-Pause
        return
    }

    Write-Host "`nConfirmacao aceita. Iniciando a limpeza do disco..." -ForegroundColor Green
    
    try {
        Write-Host "Limpando todas as informacoes de particao..." -ForegroundColor Yellow
        Clear-Disk -Number $targetDisk.Number -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
        
        Write-Host "`n✅ Disco $($targetDisk.Number) limpo com sucesso!" -ForegroundColor Green
        
        Write-Host ""
        $createPartitionChoice = Read-Host "Deseja inicializar e criar uma nova particao agora? [s/n]"
        if ($createPartitionChoice -eq 's') {
            
            Write-Host "`nEscolha o estilo da particao:" -ForegroundColor Cyan
            Write-Host "   1) GPT (Recomendado para discos > 2TB e sistemas modernos/UEFI)"
            Write-Host "   2) MBR (Para compatibilidade com sistemas antigos)"
            $partitionStyleChoice = Read-Host "Escolha uma opcao"
            switch ($partitionStyleChoice) {
                '1' { $partitionStyle = "GPT" }
                '2' { $partitionStyle = "MBR" }
                default {
                    Write-Host "Opcao invalida. A criacao da particao foi cancelada." -ForegroundColor Yellow
                    return 
                }
            }
            
            # ATUALIZADO v2.9: Pergunta sobre o sistema de arquivos
            Write-Host "`nEscolha o sistema de arquivos para formatar:" -ForegroundColor Cyan
            Write-Host "   1) NTFS (Padrao para Windows, mais seguro)"
            Write-Host "   2) exFAT (Para pendrives/HDs externos maiores que 32GB)"
            Write-Host "   3) FAT32 (Compatibilidade maxima com aparelhos antigos)"
            $fsChoice = Read-Host "Escolha uma opcao"
            switch ($fsChoice) {
                '1' { $fileSystem = "NTFS" }
                '2' { $fileSystem = "exFAT" }
                '3' { $fileSystem = "FAT32" }
                default {
                    Write-Host "Opcao invalida. A criacao da particao foi cancelada." -ForegroundColor Yellow
                    return
                }
            }

            try {
                Write-Host "Inicializando o disco com particionamento $partitionStyle..." -ForegroundColor Yellow
                Initialize-Disk -Number $targetDisk.Number -PartitionStyle $partitionStyle -ErrorAction Stop

                Write-Host "Criando nova particao e atribuindo uma letra..." -ForegroundColor Yellow
                $newPartition = New-Partition -DiskNumber $targetDisk.Number -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
                
                Start-Sleep -Seconds 3

                Write-Host "Particao criada. Formatando como $fileSystem (Rapido)..." -ForegroundColor Yellow
                Format-Volume -Partition $newPartition -FileSystem $fileSystem -Confirm:$false -ErrorAction Stop

                $driveLetter = ($newPartition | Get-Partition).DriveLetter
                Write-Host "`n✅ SUCESSO! Particao criada e formatada. A nova unidade e '$($driveLetter):'." -ForegroundColor Green
            } catch {
                Write-Host "`n🛑 ERRO: Falha ao inicializar, criar ou formatar a nova particao. Mensagem: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   O disco foi limpo, mas voce precisara concluir o processo manualmente no 'Gerenciamento de Disco'."
            }
        } else {
            Write-Host "   O disco esta limpo e pronto para ser inicializado e particionado no 'Gerenciamento de Disco' do Windows." -ForegroundColor Green
        }

    } catch {
        Write-Host "`n🛑 ERRO: A limpeza do disco falhou. Mensagem do sistema: $($_.Exception.Message)" -ForegroundColor Red
    }
    Invoke-Pause
}

#endregion

#region LOOP PRINCIPAL DO MENU

while ($true) {
    Show-MainMenu
    $choice = Read-Host "Escolha uma opcao"

    switch ($choice) {
        '1' { New-DiskImage }
        '2' { Restore-DiskImage }
        '3' { Start-DiskClone }
        '4' { Test-ImageIntegrity }
        '5' { 
            Clear-Host
            Get-DiskList
            Invoke-Pause 
        }
        '6' { Start-VolumeFormat }
        '7' { Invoke-DiskWipe }
        '8' {
            Write-Host "Saindo... O log da sessao foi salvo em: $LogFile" -ForegroundColor Green
            Stop-Transcript
            Exit
        }
        default {
            Write-Host "Opcao invalida. Tente novamente." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

#endregion