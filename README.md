# DD-WIZ-PowerShell
Ferramenta de clonagem e gerenciamento de disco para Windows via PowerShell
# DD WIZ - PowerShell Edition

**Autor:** tuninho kjr
**Versão:** 2.9

Um utilitário de disco poderoso e seguro para Windows, escrito em PowerShell. O DD WIZ oferece uma interface de menu guiada para realizar operações críticas de disco como clonagem, backup, restauração e formatação, com múltiplas camadas de segurança para prevenir a perda de dados.

## ⚙️ Pré-requisitos (Download Obrigatório)

Este script **não inclui** as ferramentas de linha de comando necessárias para funcionar. Você precisa baixá-las manualmente e colocá-las na mesma pasta que o script.

1.  **`dd for Windows`**: Essencial para as operações de cópia de baixo nível.
    * **Download:** [**http://www.chrysocome.net/dd**](http://www.chrysocome.net/dd)
    * *Instruções: Baixe o arquivo .zip e extraia o `dd.exe` para a pasta do projeto.*

2.  **`Zstandard (zstd)`**: Necessário para a compressão e descompressão de imagens.
    * **Download:** [**Página de releases do Zstandard no GitHub**](https://github.com/facebook/zstd/releases)
    * *Instruções: Baixe a versão mais recente para Windows (ex: `zstd-v1.5.5-win64.zip`), extraia e coloque o `zstd.exe` na pasta do projeto.*

### Estrutura da Pasta do Projeto

Após baixar tudo, sua pasta deve ficar assim para que o script funcione:

/Sua-Pasta-DD-WIZ/
|
|-- DiskDuplicator.ps1  (Este script)
|-- dd.exe              (Baixado do site oficial)
|-- zstd.exe            (Baixado do site oficial)

## 🚀 Como Usar

1.  **Passo 1: Baixar o Script:** Faça o download do arquivo `DiskDuplicator.ps1` desta página do GitHub.
2.  **Passo 2: Baixar as Dependências:** Baixe o `dd.exe` e o `zstd.exe` usando os links na seção de Pré-requisitos.
3.  **Passo 3: Organizar a Pasta:** Crie uma nova pasta em seu computador e coloque os 3 arquivos (`DiskDuplicator.ps1`, `dd.exe`, `zstd.exe`) juntos dentro dela.
4.  **Passo 4: Executar:** Clique com o **botão direito** no arquivo `DiskDuplicator.ps1` e selecione **"Executar com o PowerShell"**.

## ✅ Funcionalidades

* Menu Interativo e Segurança Reforçada.
* Clonagem, Backup, Restauração, Formatação e Limpeza de Discos.
* Compressão zstd e Verificação de Integridade com SHA-256.
* Criação de Partições GPT/MBR com formatação NTFS/exFAT/FAT32.

## ⚠️ Aviso Legal

Este script realiza operações de disco de baixo nível que podem **destruir permanentemente** todos os dados em um disco. Use com extrema cautela e por sua conta e risco. O autor não se responsabiliza por qualquer perda de dados.

