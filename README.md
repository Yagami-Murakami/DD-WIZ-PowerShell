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
```
📁 /Sua-Pasta-DD-WIZ/
|
|-- 📜 DiskDuplicator.ps1  (Este script)
|-- ⚙️ dd.exe              (Baixado do site oficial)
|-- ⚙️ zstd.exe            (Baixado do site oficial)
```
## 🚀 Como Usar

Existem duas maneiras de executar o script. Se a primeira não funcionar, a segunda é garantida.

### Método 1: Simples (Clique com o Botão Direito)

1.  Siga os passos da seção **Pré-requisitos** e **Estrutura da Pasta** para ter os 3 arquivos juntos.
2.  Clique com o **botão direito** no arquivo `DiskDuplicator.ps1`.
3.  Selecione **"Executar com o PowerShell"**.
4.  O script pedirá elevação para Administrador.

*Se este método resultar em um erro vermelho sobre "execução de scripts foi desabilitada neste sistema", use o método via terminal abaixo.*

### Método 2: Via Terminal (Garantido)

1.  **Abra o PowerShell como Administrador.** Para isso, pesquise "PowerShell" no Menu Iniciar, clique com o botão direito no ícone e selecione "Executar como Administrador".
2.  **Navegue até a pasta do projeto.** Use o comando `cd` para entrar na pasta que você criou. Exemplo:
    ```powershell
    cd C:\Users\tuninho\Documents\DD-WIZ
    ```
3.  **Libere a execução do script (apenas para esta janela).** Cole e execute o seguinte comando:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    ```
4.  **Execute o script.** Agora, basta digitar o nome do script e pressionar Enter:
    ```powershell
    .\DiskDuplicator.ps1
    ```

## ✅ Funcionalidades

* Menu Interativo e Segurança Reforçada.
* Clonagem, Backup, Restauração, Formatação e Limpeza de Discos.
* Compressão zstd e Verificação de Integridade com SHA-256.
* Criação de Partições GPT/MBR com formatação NTFS/exFAT/FAT32.

## ⚠️ Aviso Legal

Este script realiza operações de disco de baixo nível que podem **destruir permanentemente** todos os dados em um disco. Use com extrema cautela e por sua conta e risco. O autor não se responsabiliza por qualquer perda de dados.

