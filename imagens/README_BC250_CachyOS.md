# Guia de Configuração – BC250 + CachyOS (bootloader Limine)

> **Testado na versão Desktop do CachyOS com bootloader Limine.**
> No final há uma lista de softwares úteis que podem ser usados em algumas etapas.

---

## ⚠️ Avisos importantes

- **Risco de brick:** Algumas etapas (como a gravação da BIOS e alterações de VRAM) podem brickar sua placa, sendo necessário regravar a BIOS com ferramentas adequadas. Proceda por sua conta e risco.
- **Backup:** Salve todas as configurações originais antes de modificar qualquer parâmetro.
- **Estabilidade:** Teste cada alteração exaustivamente antes de torná-la permanente.

---

## 1. BIOS

Grave a BIOS versão **3.00** seguindo o guia:
[https://elektricm.github.io/amd-bc250-docs/bios/flashing/#method-1-usb-flashing-efi-shell-method](https://elektricm.github.io/amd-bc250-docs/bios/flashing/#method-1-usb-flashing-efi-shell-method)

Após gravar a nova BIOS e fazer o **Clear CMOS**, configure as seguintes opções:

- **Chipset > GFX Configuration**
  - `Integrated Graphics Controller` → `Forces`
  - `UMA Mode` → `UMA_SPECIFIED`
  - `UMA Frame Buffer Size` → `512MB`

- **Advanced > CPU Configuration**
  - `IOMMU` → `Disabled`

Pressione `F10` para salvar e sair.

> **Alternativa mais segura:** Se não quiser gravar a BIOS, você pode alterar as configurações acima e o parâmetro `UMA_SIZE` para `0512` seguindo a **etapa 7** (VRAM). Isso é relativamente mais seguro.

---

## 2. CachyOS

Baixe o CachyOS em [https://cachyos.org/download/](https://cachyos.org/download/) e durante a instalação escolha o **bootloader Limine**.

---

## 3. CPU Governor, GPU Governor, Swap, ZRAM → ZSWAP, Ocultar Avisos RDSEED, Desativar Mitigações e Desbloqueio de Unidades Computacionais

### Explicações breves

- **CPU Governor** – permite ajustar frequência e tensão da CPU.
- **GPU Governor** – além de controlar frequência/tensão, reduz o consumo quando a GPU não está em uso (em vez de manter 1500 MHz fixos).
- **Swap + ZRAM → ZSWAP** – melhora a estabilidade do sistema devido às particularidades da memória unificada da BC250.
- **Ocultar avisos RDSEED** – silencia mensagens de erro repetitivas geradas pelo kernel.
- **Desativar mitigações** – aumenta o desempenho da CPU.
- **Desbloqueio de unidades computacionais (CUs)** – ativa mais núcleos da GPU (padrão vem com 24 de 40 ativos; a quantidade disponível varia de placa para placa).

### Execução

No **Konsole**, execute:

```bash
curl -sSLO https://raw.githubusercontent.com/redbeard1083/bc250-toolkit/main/bc250-toolkit.sh && chmod +x bc250-toolkit.sh && ./bc250-toolkit.sh
```

- Escolha a opção **`[2] Initial Setup`**
- Depois, opção **`[A] Run All (1-7)`**

Ao final, vá para a opção **`[8] Compute Units Unlock`**:

- **`[1] Install umr`**
- **`[3] Edit Compute Pairs`**

Use as teclas `hjkl` para navegar, `Espaço` para ativar/desativar e `a` ou `Enter` para aplicar.

**Ative e aplique uma unidade por vez** enquanto executa algo pesado (ex.: FurMark) para verificar instabilidades.

Depois de testar todas, torne a configuração permanente com:

- **`[7] Install Boot Service`**
- **`[6] Save Boot Profile`**

Reinicie e verifique o status no toolkit (opção **`[S] Status`**). Uma saída saudável deve conter:

```
CPU Service       enabled
GPU Service       active
Active CUs        40/40  (se todos os 40 estiverem funcionais)
ZSWAP             Y  lz4 / pool 25%
ZRAM              inactive
Swapfile          present
Mitigations       off
ZRAM (cmdline)    disabled
ZSWAP (cmdline)   enabled
lz4 in initramfs  yes
```

**Créditos:** [redbeard1083/bc250-toolkit](https://github.com/redbeard1083/bc250-toolkit)

---

## 4. ACPI Fix + Sensores

### Explicações breves

- **ACPI Fix** – permite que a CPU reduza a frequência mínima para até 800 MHz quando ociosa, reduzindo drasticamente o consumo.
- **Sensores** – habilita o monitoramento térmico e de tensão.

### Procedimento

Instale o `paru` (AUR helper):

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

Execute o script de correção ACPI:

```bash
curl -s https://raw.githubusercontent.com/Wiljapa/BC250-CachyOS/main/novoacpifix | bash
```

Instale e configure os sensores:

```bash
sudo pacman -S lm_sensors
sudo sensors-detect
```

Reinicie:

```bash
sudo reboot
```

Use o comando `sensors` para verificar as leituras.  
Para confirmar se o ACPI Fix está ativo, verifique o campo *CPU Freq Min* no **CoolerControl**.

**Créditos:**  
- [Wiljapa/BC250-CachyOS](https://github.com/Wiljapa/BC250-CachyOS)  
- [Documentação de sensores](https://elektricm.github.io/amd-bc250-docs/system/sensors/#loading-the-sensor-module)

---

## 5. GPU

O toolkit do redbeard já deixa um governor ativo entre reinicializações. Para evitar que alterações instáveis persistam, remova o serviço padrão:


```bash
sudo systemctl stop cyan-skillfish-governor-smu
sudo systemctl disable cyan-skillfish-governor-smu
```

Edite o arquivo de configuração `/etc/cyan-skillfish-governor-smu/config.toml`:

```toml
[frequency-range]
min = 350    # MHz
max = 1500   # MHz  (ajuste conforme sua fonte e refrigeração)
```

**Atenção:**  
- Frequências acima de **2000 MHz** podem ser perigosas.  
- Ajuste os `safe-points` com valores testados para sua placa. Exemplo:

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

> **Observação:** Os valores de voltagem são apenas exemplos. O silício de cada placa pode exigir ajustes.  
> **Nunca ultrapasse 1000 mV** (a menos que saiba o que está fazendo).  
> Faça **undervolt** gradual: reduza 25 mV de cada vez e, se houver instabilidade, aumente 25 mV.

Salve o arquivo e teste:


```bash
sudo systemctl start cyan-skillfish-governor-smu
```

Se alterar a configuração, reinicie o serviço:

```bash
sudo systemctl restart cyan-skillfish-governor-smu
```

Antes de tornar permanente, execute um teste de estresse (ex.: **Superposition em 1080p Extreme**).

Para ativar o serviço na inicialização:

```bash
sudo systemctl enable cyan-skillfish-governor-smu
```

Para verificar se a tensão foi aplicada, use o **CPU-X** (aba *Gráficos*).

**Créditos:** [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)

---

## 6. CPU

Se o comando `bc250-detect --help` retornar erro, reinstale o pacote:

```bash
cd bc250_smu_oc
sudo chown -R $USER:$USER ~/bc250_smu_oc
rm -rf bc250_smu_oc.egg-info build dist
pipx install .
bc250-detect --help
```

Teste frequência e voltagem com:

```bash
bc250-detect --frequency X --vid Y
```

- `X` = frequência em MHz (cuidado com valores maiores que 3800)  
- `Y` = voltagem em mV (cuidado com valores maiores que 1200)  

Exemplo:

```bash
bc250-detect --frequency 3500 --vid 1050
```

Para manter o valor testado com a finalidade de validar fora do Konsole, adicione `-k`:

```bash
bc250-detect --frequency 3500 --vid 1050 -k
```

**Teste de estabilidade:**  
Abra duas janelas no Konsole:

- Uma com `watch -n 1 "cat /proc/cpuinfo | grep MHz"`
- Outra com `stress --cpu 16 --timeout 60`

Verifique se todos os núcleos mantêm o clock desejado sem instabilidades.  
Depois, rode **Superposition em 1080p Extreme**.

Para tornar permanente:

```bash
bc250-apply --install overclock.conf
sudo systemctl enable --now bc250-smu-oc
```

**Créditos:** [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc/)

---

## 7. VRAM

> **Atenção:** Mexer nos valores de VRAM pode **brickar** sua placa. Em alguns casos, um Clear CMOS pode restaurar os padrões, mas não é garantido.

Clone o repositório e compile:

```bash
git clone https://github.com/fanoush/bc250_memcfg
cd bc250_memcfg
make
sudo ./bc250memcfg
```

**Salve a saída padrão** em um arquivo de texto – ela se parece com:

```
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
```

Para alterar um valor certifique-se de estar dentro da pasta pasta `bc250_memcfg` (`cd bc250_memcfg`) e execute:

```bash
sudo ./bc250memcfg PARÂMETRO VALOR
```

Exemplo:

```bash
sudo ./bc250memcfg UMA_SIZE 0512
```

Confirme a aplicação rodando:

```bash
sudo ./bc250memcfg
```

**Valores recomendados (pelo NexGen):**

```bash
sudo ./bc250memcfg tRAS 44
sudo ./bc250memcfg tRCAb 71
sudo ./bc250memcfg tREF 12800
sudo ./bc250memcfg tRFC 0230
sudo ./bc250memcfg UMA_SIZE 0512
```

**Teste de estabilidade:**

```bash
sudo pacman -S memtest_vulkan
memtest_vulkan
```

Deixe rodar por cerca de 5 minutos ou até a mensagem de conclusão. Pressione `Ctrl+C` para sair.

**Créditos:**  
- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg)  
- [NexGen Memory Timings](https://github.com/NexGen-3D-Printing/SteamMachine/blob/main/Memory-Timings-Explained.txt)  
- [NexGen 1750 Best.ini](https://github.com/NexGen-3D-Printing/SteamMachine/blob/main/1750-Best.ini)

---

## 8. VRAM Split

### Explicações breves

Com `UMA_SIZE=512`, a VRAM fixa é de apenas 512 MB. O sistema realocará dinamicamente RAM para VRAM quando necessário, mas, por padrão, o Linux limita essa realocação a **metade da RAM total**.  
Isso significa que, com 16 GB de RAM total, você tem 0,5 GB fixos + 7,75 GB dinâmicos = **8,25 GB máximos de VRAM**.  
Para permitir até 12 GB de VRAM (mantendo 15,5 GB RAM livres para o sistema quando a VRAM não estiver em uso), podemos modificar o parâmetro `ttm.pages_limit`.

### Procedimento

Veja o valor atual (e salve-o como backup):

```bash
cat /sys/module/ttm/parameters/pages_limit
```

A fórmula para o valor é: `(X * 1024 * 1024) / 4`, onde `X` é a quantidade em GB desejada para o limite máximo de VRAM.

O script abaixo aplica o valor recomendado `3145728` (equivalente a 12 GB).

Execute:

```bash
curl -s https://raw.githubusercontent.com/LnhoJ/BC250-CachyOS-Limine/main/ttm-pages-limit.sh > /tmp/ttm.sh
bash /tmp/ttm.sh
```

Reinicie e verifique a aplicação:

```bash
cat /sys/module/ttm/parameters/pages_limit
sudo dmesg | grep -i 'gtt.*memory'
```

**Créditos:** [Documentação sobre VRAM](https://elektricm.github.io/amd-bc250-docs/bios/vram/)

---

## Utilitários recomendados

### Flatpak

```bash
sudo pacman -S flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo reboot
```

### Yay (AUR helper)

```bash
sudo pacman -Syu yay
sudo reboot
```

### FurMark (benchmark/stress)

```bash
flatpak install flathub com.geeks3d.furmark
```

### Unigine Superpos
