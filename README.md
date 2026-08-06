#

# <p align="center"> Configuração BC250 + CachyOS (Bootloader Limine) </p>

#

**Script testado na versão Desktop do CachyOS com Bootloader Limine.**

**Esse tutorial apenas reúne informações dispersas em diferentes GitHubs. Deixarei abaixo de cada etapa, bem como ao final, créditos à fonte e/ou criador de cada uma das etapas reunidas aqui.**

**Etapas [1](#-1-cachyos-), [2](#-2-scripts-com-pacote-de-testes-e-otimizações-), [3](#-3-cpu-) e [4](#-4-gpu-) são suficientes para ter um sistema funcional com todas otimizações necessárias realizadas.**

#

## <p align="center"> ⚠️ Avisos Importantes </p>

- **Riscos:** A gravação da BIOS e a etapa [6](#-6-vram-) podem brickar sua BC250 se feitas inadequadamente. Nesse caso, será necessária a regravação da BIOS com ferramentas adequadas. Proceda por sua conta e risco.

- **Estabilidade:** Teste cada alteração antes de torná-la permanente.

- **Com exceção da etapa [6](#-6-vram-) e alguns procedimentos realizados na etapa [5](#-5-desbloqueio-de-núcleos-), todas configurações feitas nas demais etapas são perdidas ao formatar.**

#
#

## <p align="center"> 1. CachyOS </p>

#

Baixe o CachyOS em [https://cachyos.org/download/](https://cachyos.org/download/) e durante a instalação escolha o **Bootloader Limine**.

#
#

## <p align="center"> 2. Scripts com Pacote de Testes e Otimizações </p>

#

Os comandos abaixo executam scripts que instalam pacotes e configurações que normalmente utilizo no CachyOS.

Comando para ferramentas de testes e repositórios essenciais para utilizar o script de configurações:

```console
curl -s https://raw.githubusercontent.com/LnhoJ/BC250-CachyOS-Limine/refs/heads/main/pacote-de-testes-e-repos.sh | sudo bash
```

O script acima instalará o `Flatpak`, dependências essenciais (`git`, `base-devel`, `python-pipx`, `stress`, `dkms`, `linux-headers`), os helpers AUR `Yay` e `Paru`, `FurMark`, `Unigine Superposition`, `CPU-X` e `CoolerControl`.

> Após o uso do script acima é recomendado reiniciar se quiser usar o FurMark durante o teste de estabilidade das Compute Units (CUs), caso contrário, pode ser reiniciado após o uso do script de otimizações.

Comando para otimizações que instalará `bc250-smu-oc`, `cyan-skillfish-governor`, `sensor NCT6687`, `Swap 16 GB`, `Swappiness 120`, `UMA_SIZE 512MB`, desativação das `Mitigações`, troca do `ZRAM` pelo `ZSWAP`, `ttm_pages_limit 3145728`, `ACPI Fix` e `Desbloqueio das CUs`:

```console
curl -s https://raw.githubusercontent.com/LnhoJ/BC250-CachyOS-Limine/refs/heads/main/configs-bc-250.sh -o /tmp/configs-bc-250.sh
chmod +x /tmp/configs-bc-250.sh
sudo /tmp/configs-bc-250.sh
```

Haverá pedido de confirmação para o ACPI Fix, pois caso tenha feito gravação da nova bios não é necessário aplicar ele.

Esse script desbloqueia todas as 40 CUs sem exceção, portanto, no final do script será perguntado se deseja manter o desbloqueio permanente das 40 CUs, ou seja, uma alteração persistente entre reinicializações. Teste antes de confirmar, pois, caso ocorra alguma instabilidade a ponto de ser necessário desligar a BC-250, você não terá uma configuração instável persistente ao religar sua máquina.

> Em caso de desligamento forçado, todas otimizações feitas permanecem, apenas o Desbloqueio das 40 CUs é revertido para o padrão.

> Reinicie para todas otimizações entrarem em funcionamento.

#

**Caso haja instabilidades:** Será necessário desbloqueio individual de cada CU para saber qual está instável.

Primeiro use o comando:

```console
curl -L -o bc250-cu-live-manager.sh https://raw.githubusercontent.com/WinnieLV/bc250-cu-live-manager/refs/heads/main/bc250-cu-live-manager.sh
chmod +x bc250-cu-live-manager.sh
sudo ./bc250-cu-live-manager.sh
```

Para ativar individualmente: use `e` para editar a tabela das CUs ativas, `h` `j` `k` `l` para mover, `barra de espaço` para ativar ou desativar, `a` ou `enter` para aplicar, em seguida escreva `accept` para aceitar e `y` para aplicar as mudanças.

Após verificar indivualmente cada CU e deixar a instável desativada, use `w` para registrar as alterações e `i` para instalar o serviço e tornar permanente.

#

**Créditos:**
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)

- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)

- [ElektricM/amd-bc250-docs/sensors](https://elektricm.github.io/amd-bc250-docs/system/sensors/#loading-the-sensor-module)

- [ElektricM/amd-bc250-docs/swap](https://elektricm.github.io/amd-bc250-docs/system/power/?h=swap#swap-and-zram-optimization/)

- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg)

- [ElektricM/amd-bc250-docs/vram](https://elektricm.github.io/amd-bc250-docs/bios/vram/)

- [mendesrr/bc250-acpi-fix-updated-8c](https://github.com/mendesrr/bc250-acpi-fix-updated-8c)

- [WinnieLV/bc250-cu-live-manager](https://github.com/WinnieLV/bc250-cu-live-manager)

#
#

## <p align="center"> 3. CPU </p>

#

**O script de otimizações não deixa nenhum perfil de CPU ativo.** O mantive desativado pois sempre há exceções e cada placa pode operar com tensões bem diferentes.

Teste frequência e tensão com:

<pre>
bc250-detect --frequency X --vid Y
</pre>

- `X` = frequência em MHz (cuidado com valores maiores que 3800)

- `Y` = tensão em mV (cuidado com valores maiores que 1200)

Exemplo:

```console
bc250-detect --frequency 3500 --vid 1050
```

Para manter o valor testado com a finalidade de validar fora do Konsole, adicione `-k`:

```console
bc250-detect --frequency 3500 --vid 1050 -k
```

**Teste básico de estabilidade:**

Abra duas janelas no Konsole.

- Uma com:

```console
watch -n 1 "cat /proc/cpuinfo | grep MHz"
```

- Outra com:

```console
stress --cpu 16 --timeout 60
```

Verifique se todos os núcleos mantêm o clock desejado sem instabilidades.

> **Atenção:** Os testes acima servem para verificar instabilidades mais graves, ainda pode haver instabilidades em uso leve. Ajuste conforme necessário.

Para tornar permanente:

```console
bc250-apply --install overclock.conf
sudo systemctl enable --now bc250-smu-oc
```

#

**Créditos:**
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)

#
#

## <p align="center"> 4. GPU </p>

#

**O script de otimizações não ativa o governor.** Embora os valores que deixei pré-setados para o arquivo de configurações possuam valores que dificilmente darão errado, o mantive desativado, pois sempre há exceções e cada placa pode operar com tensões bem diferentes.

Para modificar os valores, edite os seguintes parâmetros no arquivo de configuração `config.toml` na pasta `/etc/cyan-skillfish-governor-smu/`(é possivel copiar e colar o diretório ao lado na barra do gerenciador de arquivos):

<pre>
[frequency-range]
min = 350    # MHz
max = 1500   # MHz
</pre>

<pre>
[[safe-points]]
frequency = 350
voltage = 700

[[safe-points]]
frequency = 700
voltage = 750

[[safe-points]]
frequency = 1000
voltage = 800

[[safe-points]]
frequency = 1250
voltage = 825

[[safe-points]]
frequency = 1500
voltage = 850
</pre>

**Atenção:**
- Frequências acima de **2000 MHz** podem ser perigosas.

- Ajuste os `safe-points` com valores testados para sua placa, pois os valores em `voltage` são apenas exemplos. O silício de cada placa pode exigir ajustes.

- Nunca ultrapasse **1000 mV** em `voltage` (a menos que saiba o que está fazendo).

- Faça **undervolt** gradual: reduza 25 mV de cada vez e, se houver instabilidade, aumente 25 mV. Se quiser um ajuste ainda mais fino, 10 mV.

Salve o arquivo e teste os novos parâmetros com:

```console
sudo systemctl start cyan-skillfish-governor-smu
```

Se alterar algum parâmetro em `config.toml` posteriormente, reinicie o serviço:

```console
sudo systemctl restart cyan-skillfish-governor-smu
```

Para tornar o governor permanente entre reinicializações:

```console
sudo systemctl enable cyan-skillfish-governor-smu
```

> Antes de tornar permanente, execute um teste de estresse (ex.: **Superposition** em 1080p Extreme).

> Para confirmar se a tensão correta foi aplicada, verifique o campo `Tensão principal` na aba `Gráficos` do **CPU-X**.

**Créditos:**
- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)

#
#

## <p align="center"> 5. Desbloqueio de Núcleos </p>

#

**Etapa ainda em fase de testes.**

**O método de desbloqueio é bem recente e portanto há alguns erros. No momento foram identificados o de métricas erradas da GPU (apenas visual), monitoramento térmico de apenas 2 núcleos (apenas visual) e erro de sincronização de áudio.**

Para testar se há a possibilidade do desbloqueio dos núcleos, execute no Konsole:

```console
curl -s https://raw.githubusercontent.com/rw-r-r-0644/bc250-core-unlock/main/bc250-unlock-cores.py | sudo python3
```

Caso o script aplique as mudanças, aparecerá a seguinte mensagem:

<pre>
core presence mask: 0x00000077
after write        : 0x000000FF

OK. Reboot to bring up all 8 cores (16 threads).
</pre>

Após a mensagem de sucesso, basta reiniciar:

```console
sudo reboot
```

Para verificar se a mudança foi aplicada, execute:

```console
nproc
```

Este comando indica o número de threads, deverá aparecer ´16´ se estiver OK.

**Agora é necessário realizar testes.**

Ferramenta de teste:

```console
sudo pacman -S s-tui
```

Para abrir a ferramenta de teste:

```console
s-tui
```

Em `Modes` haverá `(X) Monitor`, basta clicar em `( ) s-tui stress` e abrir vários programas enquanto navega na internet por alguns minutos, há também `( ) Stress (ext)` que consiste em um estresse extremo à CPU, elevando-a a altas temperaturas, essa última opção não é realmente necessária, mas, caso queira, rode por pouco tempo para verificar se alguma instabilidade mais grave ocorre.

**O sistema congelou? A tela ficou preta ou verde? Algum programa fechou inesperadamente? Isso indica instabilidade.**

Para parar o estresse na CPU, clique novamente em `( ) Monitor`.

> Apenas fechar o terminal onde o `s-tui` esta rodando ainda o manterá estressando a CPU em segundo plano.

Utilize também o `stress-ng` com o método `prime`.

Primeiro instale o `stress-ng`:

```console
sudo pacman -S stress-ng
```

Em seguida rode o teste:

```console
stress-ng --cpu 16 --cpu-method prime --timeout 1h --metrics
```

É um teste longo capaz de identificar se há erros. Se ocorrer tudo bem ele mostrará:

<pre>
stress-ng: info:  [3761] skipped: 0
stress-ng: info:  [3761] passed: 16: cpu (16)
stress-ng: info:  [3761] failed: 0
stress-ng: info:  [3761] metrics untrustworthy: 0
</pre>

> É possível encerrar o teste antes com `ctrl + c`, assim como é possivel prolongar alterando o valor em `--timeout 1h` no comando para rodar o teste.

> Teste também em jogos, pois há relatos de que, embora durante o estresse da CPU ocorra tudo normalmente, durante jogos há quedas drásticas de frames que não ocorriam com 6 núcleos.

Encerrados os testes, há três métodos para tornar o desbloqueio dos núcleos "permanente", visto que, ao desligar a BC250 completamente, é necessário executar o comando de teste e reiniciar novamente.

Abaixo estão apenas dois, pois o terceiro envolve a criação de um serviço no sistema operacional, sendo o mais lento dentre as três opções.

**Primeiro Método:**

O primeiro método cria uma entrada na EFI para que esse app seja executado antes do sistema operacional, e depois ele carrega o Linux normalmente.

Essa é a melhor opção caso não queira gravar uma nova BIOS. O tempo de inicialização aumenta em +5s com o método da BIOS e +11s com o método EFI, uma diferença mínima.

Rode o comando:

```console
git clone --recursive https://github.com/Hexxeh/bc250-efi-core-unlock
cd bc250-efi-core-unlock/
make clang
```

Em seguida:

```console
sudo cp bc250-unlock.efi /boot/EFI/BOOT/COREUNLOCK.EFI
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "CoreUnlock" --loader "\\EFI\\BOOT\\COREUNLOCK.EFI"
```
Concluída a etapa, basta reiniciar:

```console
sudo reboot
```

Confirme se a configuração persiste ao desligar e religar novamente com:

```console
nproc
```

> Caso não esteja aplicado, basta mudar a ordem de boot na BIOS, escolhendo como primeira opção a nova entrada EFI criada.

**Segundo Método:**

O segundo método envolve a gravação de uma nova BIOS, que pode ser obtida no GitHub [Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script](https://github.com/Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script/).

Após baixar a versão mais recente, basta extrair e copiar os arquivos dentro da pasta extraida e colocá-los dentro de um pendrive formatado em FAT32.

Em seguida, entre na BIOS e vá até a aba `Save and Exit`, na opção `Boot Override` escolha seu pendrive, geralmente `generic storage device`.

Basta esperar o menu e escolher dentre as opções listadas. Eu, por exemplo, escolhi a opção com a logo da AMD, portanto digitei  `menu 07` e dei `Enter`, em seguida `Enter` novamente para confirmar.

Após cerca de 2 a 3 minutos, aparecerá uma confirmação de gravação da nova BIOS; basta confirmar com `Enter` e `Enter` novamente na mensagem seguinte.

Após gravar a nova BIOS, configure as seguintes opções:

- **Advanced > DXE Driver Configuration**

  - `8 Core Unlock` → `Enabled`
  
  - `ACPI Injection` → `Enabled`

- **Advanced > CPU Configuration**

  - `IOMMU` → `Disabled`

- **Chipset > GFX Configuration > GFX Configuration**

  - `Integrated Graphics Controller` → `Forces`
  
  - `UMA Mode` → `UMA_SPECIFIED`
  
  - `UMA Frame Buffer Size` → `512MB`

- **Chipset > GFX Configuration > NB Configuration**

  - `IOMMU` → `Disabled`


Pressione `F10` em seguida `Enter` para salvar e sair.

> É possível manter o IOMMU habilitado caso você tenha interesse em usá-lo; caso contrário, mantenha desativado, pois são necessárias configurações específicas para torná-lo funcional.

#

Para correções de erros que o desbloqueio dos núcleos acarreta, há um repositório com kernel para CachyOS que inclui não somente o fix de métricas da GPU e sincronização de áudio, como também alguns extras que serão feitos conforme o projeto avança. Ele pode ser encontrado no GitHub [MastaG/linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250).

**Repare que o método usa `TrustAll` porque os pacotes não são assinados digitalmente. Usar este repositório envolveria confiar na fonte.**

Caso queira prosseguir:

Adicione o repositório ao pacman:

```console
printf '%s\n' \
  '' \
  '[bc250-cachyos]' \
  'SigLevel = Optional TrustAll' \
  'Server = https://github.com/MastaG/linux-cachyos-bc250/releases/download/repo' \
  | sudo tee -a /etc/pacman.conf >/dev/null
```

Sincronize a lista de pacotes:

```console
sudo pacman -Syy
```

Verifique se o repositório foi adicionado (opcional):

```console
pacman -Sl bc250-cachyos
```

Instale o kernel e os headers:

```console
sudo pacman -Syu linux-cachyos-bc250 linux-cachyos-bc250-headers
```

Após reiniciar, basta escolher `linux-cachyos-bc250` dentre as opções disponíveis no bootloader.

#

**Créditos:**
- [rw-r-r-0644/bc250-core-unlock](https://github.com/rw-r-r-0644/bc250-core-unlock)

- [Hexxeh/bc250-efi-core-unlock](https://github.com/Hexxeh/bc250-efi-core-unlock)

- [Thread Discord - Gadget](https://discord.com/channels/1315924807128449065/1532700437147418807)

- [Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script](https://github.com/Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script/)

- [MastaG/linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250)

#
#

## <p align="center"> 6. VRAM </p>

#

> **Alterações Sensíveis, Atenção:** Mudanças exageradas nos valores de VRAM podem **brickar** sua placa. Em alguns casos um **Clear CMOS** pode restaurar os valores padrões, mas não é garantido. Alterações realizadas aqui resultam em mudanças mínimas em relação aos valores padrões, com exceção do parâmetro UMA_SIZE que é útil caso você não tenha gravado uma nova BIOS e queira alterar tamanho da VRAM dedicada.

#

### Procedimento

Clone o repositório e compile:

```console
git clone https://github.com/fanoush/bc250_memcfg
cd bc250_memcfg
make
sudo ./bc250memcfg
```

Salve os valores dos parâmetros em um arquivo de texto para futuras reversões. A lista de parâmetros se parece com:

<pre>
ClockSpeed=1750
tCL=24
tRAS=52
tRCDRD=27
tRCDWR=19
tRCAb=78
tRCPb=00
tRPAb=26
tRPPb=00
tRRDS=08
tRRDL=08
tRTP=02
tFAW=32
tREF=9975
RFCPb=0210
tRFC=0280
UMA_SIZE=0512
</pre>

Para alterar o valor de algum parâmetro certifique-se de estar dentro da pasta pasta `bc250_memcfg` com o comando `cd bc250_memcfg` e execute:

<pre>
sudo ./bc250memcfg X Y
</pre>

- `X` = Parâmetro a ser alterado

- `Y` = Valor a ser alterado

Exemplo:

```console
sudo ./bc250memcfg UMA_SIZE 0512
```

Verifique os novos valores setados:

```console
sudo ./bc250memcfg
```

Valores recomendados (pelo NexGen):

```console
sudo ./bc250memcfg tRAS 44
sudo ./bc250memcfg tRCAb 71
sudo ./bc250memcfg tREF 12800
sudo ./bc250memcfg tRFC 0230
sudo ./bc250memcfg UMA_SIZE 0512
```

**Caso queira alterar apenas o parâmetro UMA_SIZE:**

```console
sudo ./bc250memcfg UMA_SIZE 0512
```

Valores válidos e seguros para UMA_SIZE: ´0256´;´0512´; ´1024´; ´3072´; ´4096´; ´6144´; ´8192´; ´10240´; ´12288´.

> Valores acima são em MB.

Teste de estabilidade:

```console
sudo pacman -S memtest_vulkan
memtest_vulkan
```

Deixe rodar por cerca de 5 minutos ou até a mensagem de conclusão. Pressione `Ctrl+C` para sair.

**Créditos:**
- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg)

- [NexGen Memory Timings Explained](https://github.com/NexGen-3D-Printing/SteamMachine/blob/main/Memory-Timings-Explained.txt)

- [NexGen 1750 Best.ini](https://github.com/NexGen-3D-Printing/SteamMachine/blob/main/1750-Best.ini)

- [ElektricM/amd-bc250-docs](https://elektricm.github.io/amd-bc250-docs/bios/vram/)

#
#

## <p align="center"> Agradecimentos e Créditos </p>

#

- [rw-r-r-0644/bc250-core-unlock](https://github.com/rw-r-r-0644/bc250-core-unlock)

- [Hexxeh/bc250-efi-core-unlock](https://github.com/Hexxeh/bc250-efi-core-unlock)

- [Thread Discord - Gadget](https://discord.com/channels/1315924807128449065/1532700437147418807)

- [Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script](https://github.com/Forbidden-Darkness/AMD-BC-250-UEFI-v2.2-Firmware-Menu-Script/)

- [MastaG/linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250)

- [mendesrr/bc250-acpi-fix-updated-8c](https://github.com/mendesrr/bc250-acpi-fix-updated-8c)

- [WinnieLV/bc250-cu-live-manager](https://github.com/WinnieLV/bc250-cu-live-manager)

- [Wiljapa/BC250-CachyOS](https://github.com/Wiljapa/BC250-CachyOS)

- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)

- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)

- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg)

- [NexGen-3D-Printing/SteamMachine](https://github.com/NexGen-3D-Printing/SteamMachine)

- [ElektricM/amd-bc250-docs](https://elektricm.github.io/amd-bc250-docs/)

- Toda a Comunidade AMD BC250 [Brasil](https://discord.gg/RJGnwD3Ta) e [Gringa](https://discord.gg/8eZfFWhczz), especialmente **Neto** e **Wilton**, que me tiraram muitas dúvidas e contribuíram ativamente com conhecimento.

- Thiago Mesquita, por ter criado o tutorial em PDF para Bazzite, que é inclusive a inspiração para criação deste tutorial com CachyOS.

- **Recomendo pessoalmente** os tutoriais da **Renata**, ela fez um trabalho excelente, com um guia detalhado e muito bem explicado, tanto em texto no [GitHub](https://github.com/renatas1m03s/CachyOS-on-BC250) quanto em vídeo no [YouTube](https://www.youtube.com/watch?v=wMqUmxJdXNo) sobre todas as adaptações no CachyOS.

#
#
