#
# <p align="center"> Guia de Configuração – BC250 + CachyOS (bootloader Limine) </p>

#

**Testado na versão Desktop do CachyOS com bootloader Limine.**

No final há uma lista de softwares úteis que podem ser usados em algumas etapas.

#

## <p align="center"> ⚠️ Avisos Importantes </p>

- **Riscos:** A gravação da BIOS e a etapa [7]([#-7-vram-] podem brickar sua BC250 se feitas inadequadamente. Nesse caso, será necessária a regravação da BIOS com ferramentas adequadas. Proceda por sua conta e risco.

- **Backup:** Salve em um arquivo de texto todos os valores originais antes de modificar qualquer parâmetro.

- **Estabilidade:** Teste cada alteração exaustivamente antes de torná-la permanente.

- **Com exceção da etapa 7, todas configurações feitas nas demais etapas são perdidas ao formatar.**

#
#

## <p align="center"> 1. BIOS </p>

#

Grave a BIOS versão **3.00** seguindo o guia:
[https://elektricm.github.io/amd-bc250-docs/bios/flashing/#method-1-usb-flashing-efi-shell-method](https://elektricm.github.io/amd-bc250-docs/bios/flashing/#method-1-usb-flashing-efi-shell-method)

Após gravar a nova BIOS e fazer o **Clear CMOS**, configure as seguintes opções:

- **Chipset > GFX Configuration > GFX Configuration**

  - `Integrated Graphics Controller` → `Forces`
  
  - `UMA Mode` → `UMA_SPECIFIED`
  
  - `UMA Frame Buffer Size` → `512MB`

- **Chipset > GFX Configuration > NB Configuration**

  - `IOMMU` → `Disabled`

- **Advanced > CPU Configuration**

  - `IOMMU` → `Disabled`

Pressione `F10` em seguida `Enter` para salvar e sair.

> **Alternativa:** Se não quiser gravar uma nova BIOS, você pode desabilitar o `IOMMU` na BIOS padrão e alterar apenas o parâmetro `UMA_SIZE` para `0512` seguindo a **etapa 7 (VRAM)**, pois é relativamente mais seguro.

#
#

## <p align="center"> 2. CachyOS </p>

#

Baixe o CachyOS em [https://cachyos.org/download/](https://cachyos.org/download/) e durante a instalação escolha o **bootloader Limine**.

#
#

## <p align="center"> 3. CPU Governor, GPU Governor, Swap, ZRAM → ZSWAP, Ocultar Avisos RDSEED, Desativar Mitigações e Desbloqueio de Unidades Computacionais </p>

#

### Explicações breves

- **CPU Governor** – permite ajustar frequência e tensão da CPU.

- **GPU Governor** – além de controlar frequência/tensão, reduz o consumo quando a GPU não está em uso (em vez de manter 1500 MHz fixos).

- **Swap + ZRAM → ZSWAP** – melhora a estabilidade do sistema devido às particularidades da memória unificada da BC250.

- **Ocultar avisos RDSEED** – silencia mensagens de erro repetitivas geradas pelo kernel.

- **Desativar mitigações** – aumenta o desempenho da CPU.

- **Desbloqueio de Unidades Computacionais (UCs)** – ativa mais núcleos da GPU (por padrão vem com 24 de 40 ativos; a quantidade total utilizável varia de placa para placa).

#

### Procedimento

No **Konsole**, execute:

```console
curl -sSLO https://raw.githubusercontent.com/redbeard1083/bc250-toolkit/main/bc250-toolkit.sh && chmod +x bc250-toolkit.sh && ./bc250-toolkit.sh
```

- Digite 2 para escolher a opção **`[2] Initial Setup`**

- Agora vá na opção **`[8] Compute Units Unlock`**

- Digite `unlock` quando for solicitado o reconhecimento dos riscos.

- Opção **`[1] Install umr`**

- Digite `y` quando for solicitada a confirmação dos procedimentos e `1` quando solicitada a escolha de dependências.

- Depois opção **`[3] Edit Compute Pairs`**

- Use as teclas `hjkl` para navegar, `Espaço` para ativar/desativar e `a` ou `Enter` para aplicar.

> **Ative e aplique uma unidade por vez** enquanto executa algo pesado (ex.: FurMark) para verificar se há instabilidades em cada um dos núcleos ativados.

Depois de testar todos, torne a configuração permanente com:

- **`[7] Install Boot Service`**

- **`[6] Save Boot Profile`**

- Retorne com `0` e vá na opção **`[A] Run All (1-7)`**

- Durante a configuração do arquivo `Swap`, será perguntado o tamanho do arquivo *Swap* e o valor de *Swappiness*. Escolha `32` caso tenha uma boa quantidade de armazenamento e defina o *Swappiness* como `180`.

- Reinicie e verifique status no toolkit com a opção **`[S] Status`**.

Deve aparecer as seguintes linhas:

<pre>
CPU Service       enabled
GPU Service       active
Active CUs        40/40
ZSWAP             Y  lz4 / pool 25%
ZRAM              inactive
Swappiness        180
Swapfile          present
Mitigations       off
ZRAM (cmdline)    disabled
ZSWAP (cmdline)   enabled
lz4 in initramfs  yes
</pre>

**Créditos:**
- [redbeard1083/bc250-toolkit](https://github.com/redbeard1083/bc250-toolkit)

#
#

## <p align="center"> 4. ACPI Fix + Sensores </p>

#

### Explicações breves

- **ACPI Fix** – permite que a CPU reduza a frequência mínima para até 800 MHz quando ociosa, reduzindo drasticamente o consumo.

- **Sensores** – habilita o monitoramento térmico e de tensão.

#

### Procedimento

Instale o `paru` (AUR helper):

```console
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

Execute o script ACPI Fix + Sensores:

```console
curl -s https://raw.githubusercontent.com/Wiljapa/BC250-CachyOS/main/novoacpifix | bash
```

Reinicie:

```console
sudo reboot
```

Para verificar as leituras dos sensores:

```console
sensors
```

Instale e habilite o **CoolerControl**:

```console
sudo pacman -S coolercontrol
sudo systemctl enable --now coolercontrold
```

> Desabilite os sensores que não estão em uso no **CoolerControl**.

Para confirmar se o ACPI Fix está ativo, verifique o campo *CPU Freq Min* no **CoolerControl**.

**Créditos:**
- [Wiljapa/BC250-CachyOS](https://github.com/Wiljapa/BC250-CachyOS)

- [Documentação BC250](https://elektricm.github.io/amd-bc250-docs/system/sensors/#loading-the-sensor-module)

#
#

## <p align="center"> 5. GPU </p>

#

O toolkit do redbeard1083 já deixa um governor ativo entre reinicializações. Para evitar que alterações instáveis persistam durante seus testes:

```console
sudo systemctl stop cyan-skillfish-governor-smu
sudo systemctl disable cyan-skillfish-governor-smu
```

Agora edite os seguintes parâmetros no arquivo de configuração `config.toml` na pasta `/etc/cyan-skillfish-governor-smu/`:

```toml
[frequency-range]
min = 350    # MHz
max = 1500   # MHz
```

```toml
[[safe-points]]
frequency = 350
voltage = 700

[[safe-points]]
frequency = 700
voltage = 725

[[safe-points]]
frequency = 1000
voltage = 750

[[safe-points]]
frequency = 1250
voltage = 775

[[safe-points]]
frequency = 1500
voltage = 800
```
**Atenção:**
- Frequências acima de **2000 MHz** podem ser perigosas.

- Ajuste os `safe-points` com valores testados para sua placa, pois os valores em `voltage` são apenas exemplos. O silício de cada placa pode exigir ajustes.

- Nunca ultrapasse **1000 mV** em `voltage` (a menos que saiba o que está fazendo).

- Faça **undervolt** gradual: reduza 25 mV de cada vez e, se houver instabilidade, aumente 25 mV.

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

Instale o **CPU-X**:

```console
sudo pacman -S cpu-x
```

Para confirmar se a tensão foi aplicada, verifique o campo `Tensão principal` na aba `Gráficos` do **CPU-X**.

**Créditos:**
- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)

#
#

## <p align="center"> 6. CPU </p>

#

Se o comando `bc250-detect --help` retornar erro:

```console
cd bc250_smu_oc
sudo chown -R $USER:$USER ~/bc250_smu_oc
rm -rf bc250_smu_oc.egg-info build dist
pipx install .
sudo reboot
```

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

**Créditos:**
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)

#
#

## <p align="center"> 7. VRAM </p>

#

> **Atenção:** Mexer nos valores de VRAM pode **brickar** sua placa. Em alguns casos um **Clear CMOS** pode restaurar os valores padrões, mas não é garantido. Alterações realizadas aqui resultam em mudanças mínimas em relação aos valores padrões, com exceção do parâmetro UMA_SIZE que é útil alterar caso você não tenha gravado uma nova BIOS.

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

#
#

## <p align="center"> 8. VRAM Split </p>

#

### Explicações breves

Alterar o parâmetro `UMA_SIZE` para `512` define apenas 512 MB de VRAM dedicada, permitindo que o restante da memória seja alocado dinamicamente entre RAM e VRAM conforme a demanda. Entretanto, no Linux, o driver gráfico limita essa realocação dinâmica a aproximadamente 50% da memória disponível, o que, em uma BC250 com 16 GB de memória unificada, resulta em um limite prático de cerca de 8,25 GB de VRAM total. Esse limite pode causar instabilidades ou falhas em jogos que exigem uma quantidade maior de memória de vídeo.

Uma alternativa seria configurar `UMA_SIZE=8192`, reservando 8 GB de VRAM dedicada. Nesse cenário, o sistema ainda pode alocar dinamicamente aproximadamente metade dos 8 GB restantes, permitindo atingir cerca de 12 GB de VRAM total. Contudo, essa abordagem reduz permanentemente a memória disponível para o sistema operacional para apenas 8 GB de RAM, mesmo quando essa VRAM adicional não está sendo utilizada.

Uma solução mais eficiente consiste em manter `UMA_SIZE=512` e alterar o valor do parâmetro `ttm.pages_limit`. Dessa forma, o driver passa a poder alocar mais memória dinamicamente para a VRAM, ultrapassando o limite padrão de 50%. Na prática, isso permite atingir aproximadamente 12 GB de VRAM durante cargas intensivas, como jogos, enquanto, ao encerrar essas aplicações, a memória é automaticamente devolvida ao sistema, preservando cerca de 15,5 GB de RAM disponíveis para uso geral.

#

### Procedimento

Veja o valor atual de `ttm.pages_limit` e salve-o para futuras reversões:

```console
cat /sys/module/ttm/parameters/pages_limit
```

A fórmula para o valor do parâmetro `ttm.pages_limit` é:

<pre>
(X * 1024 * 1024) / 4
</pre>

Onde `X` corresponde à quantidade máxima de VRAM desejada, em GB.

O script abaixo aplica automaticamente o valor recomendado `3145728`, equivalente a um limite de 12 GB de VRAM. No entanto, é possível definir um valor personalizado informando-o como argumento após `bash /tmp/ttm.sh`.

Execute:

```console
curl -s https://raw.githubusercontent.com/LnhoJ/BC250-CachyOS-Limine/main/ttm-pages-limit.sh > /tmp/ttm.sh
bash /tmp/ttm.sh
```

Reinicie e verifique se houve alteração:

```console
cat /sys/module/ttm/parameters/pages_limit
```

**Créditos:**
- [Documentação BC250](https://elektricm.github.io/amd-bc250-docs/bios/vram/)

#
#

## <p align="center"> Úteis </p>

#

### Flatpak e Yay

```console
sudo pacman -S flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo pacman -Syu yay
sudo reboot
```

### FurMark

```console
flatpak install flathub com.geeks3d.furmark
```

### Unigine Superposition

```console
yay -S unigine-superposition
sudo chmod -R a+rX /opt/unigine-superposition
```

### Helium Browser (navegador):

```console
sudo pacman -S helium-browser-bin
```

### LocalSend (transferência de arquivos na mesma rede):

```console
sudo pacman -S localsend
sudo ufw allow 53317/tcp
sudo ufw allow 53317/udp
sudo ufw reload
```

#
#

## <p align="center"> Agradecimentos e Créditos </p>

#

- [redbeard1083/bc250-toolkit](https://github.com/redbeard1083/bc250-toolkit)
- [Wiljapa/BC250-CachyOS](https://github.com/Wiljapa/BC250-CachyOS)
- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)
- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg)
- [NexGen-3D-Printing/SteamMachine](https://github.com/NexGen-3D-Printing/SteamMachine)
- [ElektricM/amd-bc250-docs](https://elektricm.github.io/amd-bc250-docs/)
- Thiago Mesquita, por ter criado o tutorial em PDF para Bazzite, que é inclusive a inspiração para criação deste tutorial com CachyOS.
- Toda a [Comunidade AMD BC250 Brasil](https://discord.gg/RJGnwD3Ta), especialmente Neto e Wilton, que me tiraram muitas dúvidas.

#
#
