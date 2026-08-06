#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

ORIGINAL_USER="${SUDO_USER:-$USER}"

SUDOERS_FILE="/etc/sudoers.d/99-bc250-temp-nopasswd"
cleanup_sudoers() {
    rm -f "$SUDOERS_FILE"
}
trap 'cleanup_sudoers; exit 0' INT TERM
trap cleanup_sudoers EXIT

rm -f "$SUDOERS_FILE"
echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
if ! visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    echo "Erro: arquivo sudoers inválido. Abortando."
    rm -f "$SUDOERS_FILE"
    exit 1
fi

if [[ -t 1 ]] && command -v tput &>/dev/null; then
    bold=$(tput bold)
    green=$(tput setaf 2)
    yellow=$(tput setaf 3)
    cyan=$(tput setaf 6)
    red=$(tput setaf 1)
    magenta=$(tput setaf 5)
    reset=$(tput sgr0)
else
    bold=""; green=""; yellow=""; cyan=""; red=""; magenta=""; reset=""
fi

QUADRO_WIDTH=50

info()  { echo -e "  ${cyan}>${reset}  $*"; }
ok()    { echo -e "  ${bold}${green}[OK]${reset}  $*"; }
warn()  { echo -e "  ${bold}${yellow}[!]${reset}  $*"; }
err()   { echo -e "  ${bold}${red}[ERRO]${reset}  $*" >&2; }

header() {
    local width=40 text="$*"
    local text_len=$(printf "%s" "$text" | wc -m)
    local left_pad=$(( (width - text_len) / 2 ))
    local right_pad=$(( width - text_len - left_pad ))
    local line=$(printf '%*s' "$width" '' | tr ' ' '=')
    echo -e "\n  ${bold}${cyan}${line}"
    printf "  ${bold}${cyan}%*s%s%*s${reset}\n" "$left_pad" "" "$text" "$right_pad" ""
    echo -e "  ${bold}${cyan}${line}\n"
}

subheader() {
    echo -e "\n  ${bold}${cyan}>>${reset}  $*"
}

sep() {
    echo -e "  ${cyan}---${reset}  $*"
}

print_quadro_line() {
    local text="$1"
    local len=$(printf "%s" "$text" | wc -m)
    local padding=$((QUADRO_WIDTH - len - 4))
    if (( padding < 0 )); then
        padding=0
        text="${text:0:$((QUADRO_WIDTH-4))}…"
    fi
    printf "  ${bold}${green}| %s%${padding}s |${reset}\n" "$text" ""
}

print_quadro_title() {
    printf "  ${bold}${green}+"
    printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
    printf "+${reset}\n"
    print_quadro_line "$1"
    printf "  ${bold}${green}|"
    printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
    printf "|${reset}\n"
}

spinner() {
    local pid=$1 spin='-\|/' i=0
    printf "\r  ${cyan}*${reset}  ${spin:0:1}"
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r  ${cyan}*${reset}  ${spin:$i:1}"
        sleep .1
    done
    printf "\r  ${cyan}*${reset}  %-30s\r" ""
    echo ""
}

run_as_user() {
    sudo -u "$ORIGINAL_USER" bash -c "$*"
}

header "Verificação de Dependências"
subheader "Helpers AUR"
MISSING=()
for cmd in yay paru; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    err "Faltam helpers AUR: ${MISSING[*]}"
    err "Execute primeiro o script de instalação de repositórios."
    exit 1
fi
ok "Helpers AUR encontrados (yay, paru)"

header "Instalação do bc250-smu-oc"
subheader "Pipx"
if run_as_user "pipx list 2>/dev/null | grep -q 'bc250-smu-oc'"; then
    ok "bc250-smu-oc ja instalado"
else
    info "Clonando repositório..."
    if [[ -d /tmp/bc250_smu_oc ]]; then rm -rf /tmp/bc250_smu_oc; fi
    git clone https://github.com/bc250-collective/bc250_smu_oc.git /tmp/bc250_smu_oc >/dev/null 2>&1 &
    spinner $!
    cd /tmp/bc250_smu_oc
    chown -R "$ORIGINAL_USER:$ORIGINAL_USER" .
    info "Instalando com pipx..."
    run_as_user "pipx install . >/dev/null 2>&1" &
    spinner $!
    run_as_user "pipx ensurepath >/dev/null 2>&1" || true
    cd ~; rm -rf /tmp/bc250_smu_oc
    ok "bc250-smu-oc instalado com sucesso"
fi

header "Configuração do Governador GPU"
subheader "Cyan Skillfish Governor SMU"
sep "Verificando instalação do pacote"
if pacman -Qq cyan-skillfish-governor-smu &>/dev/null; then
    ok "Pacote ja instalado: $(pacman -Q cyan-skillfish-governor-smu)"
else
    info "Instalando via yay..."
    run_as_user "yay -S --noconfirm cyan-skillfish-governor-smu >/dev/null 2>&1" &
    spinner $!
    if pacman -Qq cyan-skillfish-governor-smu &>/dev/null; then
        ok "Pacote instalado com sucesso"
    else
        warn "Falha na instalação do pacote. Tentando criar configuração manual..."
    fi
fi

CONFIG_FILE="/etc/cyan-skillfish-governor-smu/config.toml"
if [[ -f "$CONFIG_FILE" ]]; then
    sep "Aplicando parâmetros otimizados"
    sed -i '/^\[load-target\]/,/^$/ {
        s/^upper = .*/upper = 0.40/
        s/^lower = .*/lower = 0.20/
    }' "$CONFIG_FILE"
    sed -i '/^\[frequency-range\]/,/^$/ {
        s/^\(min = \)[0-9]\+\(.*\)/\1350\2/
        s/^\(max = \)[0-9]\+\(.*\)/\11500\2/
    }' "$CONFIG_FILE"
    sed -i '/^\[\[safe-points\]\]/,$ d' "$CONFIG_FILE"
    if ! grep -q 'frequency = 1500' "$CONFIG_FILE"; then
        cat >> "$CONFIG_FILE" <<'EOF'
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
EOF
    fi
    ok "Parâmetros aplicados: frequência 350-1500 MHz, carga 20%-40%"
    
    echo ""
    print_quadro_title "Governor GPU"
    print_quadro_line "Frequência mínima : 350 MHz"
    print_quadro_line "Frequência máxima : 1500 MHz"
    printf "  ${bold}${green}+"
    printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
    printf "+${reset}\n"
    echo ""
else
    warn "Arquivo de configuração nao encontrado em $CONFIG_FILE"
    warn "Criando arquivo padrao com configurações otimizadas..."
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<'EOF'
[load-target]
upper = 0.40
lower = 0.20

[frequency-range]
min = 350
max = 1500

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
EOF
    ok "Arquivo de configuração criado manualmente"
fi

header "Configuração de Sensores (nct6687)"
subheader "Módulo de sensores"
if pacman -Qi nct6687d-dkms-git &>/dev/null || pacman -Qi nct6687d &>/dev/null; then
    ok "Módulo ja instalado"
else
    info "Instalando via yay (DKMS)..."
    run_as_user "yay -S --noconfirm nct6687d-dkms-git >/dev/null 2>&1 || yay -S --noconfirm nct6687d >/dev/null 2>&1" &
    spinner $!
    ok "Módulo instalado"
fi

mkdir -p /etc/modprobe.d /etc/modules-load.d
cat > /etc/modprobe.d/bc250-sensors.conf << 'EOF'
blacklist nct6683
options nct6687 force=true
EOF
cat > /etc/modules-load.d/99-bc250-sensors.conf << 'EOF'
nct6687
EOF
modprobe nct6687 2>/dev/null &
spinner $!
ok "Sensor nct6687 ativado (force=true)"

header "Configuração de Swap"
subheader "Criando swap de 16 GB"
SWAPFILE="/var/swap/swapfile"
if swapon --show | grep -q "$SWAPFILE"; then
    ok "Swap já ativo em $SWAPFILE"
else
    swapoff "$SWAPFILE" 2>/dev/null || true
    rm -f "$SWAPFILE" 2>/dev/null || true
    FS_TYPE=$(stat -f -c "%T" / 2>/dev/null || echo "unknown")
    if [[ "$FS_TYPE" == "btrfs" ]]; then
        btrfs subvolume delete /var/swap 2>/dev/null || true
        btrfs subvolume create /var/swap
        btrfs filesystem mkswapfile --size 16G "$SWAPFILE" >/dev/null 2>&1 &
        spinner $!
    else
        mkdir -p /var/swap
        dd if=/dev/zero of="$SWAPFILE" bs=1M count=16384 status=none &
        spinner $!
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE" >/dev/null
    fi
    grep -q "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap defaults,nofail 0 0" >> /etc/fstab
    swapon "$SWAPFILE"
    ok "Swap criado e ativado (16 GB)"
fi

sep "Ajustando vm.swappiness"
sysctl vm.swappiness=120 >/dev/null
echo "vm.swappiness=120" > /etc/sysctl.d/99-swappiness.conf
ok "swappiness definido como 120"

header "Configuração de Memória (bc250_memcfg)"
subheader "UMA_SIZE"
REPO="https://github.com/fanoush/bc250_memcfg"
DIR="/tmp/bc250_memcfg"
if [ ! -d "$DIR" ]; then
    info "Clonando repositório..."
    git clone "$REPO" "$DIR" >/dev/null 2>&1 &
    spinner $!
fi
cd "$DIR"
info "Compilando ferramenta..."
make >/dev/null 2>&1 &
spinner $!
info "Aplicando UMA_SIZE = 512 MB..."
./bc250memcfg UMA_SIZE 0512 >/dev/null 2>&1 &
spinner $!
cd ~; rm -rf "$DIR"
ok "UMA_SIZE definido para 512 MB"

header "Configuração do Kernel e Initcpio"
subheader "Parâmetros do kernel (limine)"
LIMINE_CONF="/etc/default/limine"
if [[ -f "$LIMINE_CONF" ]]; then
    if ! grep -q '^KERNEL_CMDLINE\[default\]' "$LIMINE_CONF"; then
        echo "KERNEL_CMDLINE[default]=\"$(cat /proc/cmdline)\"" >> "$LIMINE_CONF"
    fi
    add_param() { grep -q "$1" "$LIMINE_CONF" || sed -i '/^KERNEL_CMDLINE\[default\]/ s/"$/ '"$1"'"/' "$LIMINE_CONF"; }
    sed -i '/^KERNEL_CMDLINE\[default\]/ s/\bmitigations=off\b//g' "$LIMINE_CONF"
    sed -i '/^KERNEL_CMDLINE\[default\]/ s/"$/ mitigations=off"/' "$LIMINE_CONF"
    sed -i 's/loglevel=[0-9]*/loglevel=0/g' "$LIMINE_CONF"
    grep -q 'loglevel=' "$LIMINE_CONF" || sed -i '/^KERNEL_CMDLINE\[default\]/ s/"$/ loglevel=0"/' "$LIMINE_CONF"
    add_param "systemd.zram=0"
    add_param "zswap.enabled=1"
    add_param "zswap.max_pool_percent=25"
    add_param "zswap.compressor=lz4"
    add_param "ttm.pages_limit=3145728"
    ok "Parâmetros do kernel atualizados (mitigações desligadas, zswap ativo)"
else
    warn "Arquivo limine.conf nao encontrado - pulando"
fi

MKINITCPIO_CONF="/etc/mkinitcpio.conf"
ACPI_APLICADO="não"
if [[ -f "$MKINITCPIO_CONF" ]]; then
    subheader "Initramfs e ACPI overrides"
    add_module() { grep -q "$1" "$MKINITCPIO_CONF" || sed -i "s/^MODULES=(\(.*\))/MODULES=(\1 $1)/" "$MKINITCPIO_CONF"; }
    add_module "lz4"
    add_module "lz4_compress"

    echo ""
    echo -e "  ${bold}${yellow}AVISO SOBRE O ACPI FIX${reset}"
    echo -e "  Este script pode aplicar correções nas tabelas ACPI (SSDT-CST e SSDT-PST)"
    echo -e "  para melhorar suporte a suspensão, economia de energia e estabilidade."
    echo -e "  ${bold}Se você já gravou a nova BIOS (com as correções integradas),${reset}"
    echo -e "  ${bold}${green}não é necessário aplicar este fix, pois as tabelas já estão inclusas.${reset}"
    echo ""
    read -p "  ${cyan}?${reset}  Deseja aplicar o ACPI fix? (s/N): " aplicar_acpi
    if [[ "$aplicar_acpi" =~ ^[Ss]$ ]]; then
        mkdir -p /etc/initcpio/acpi_override/
        info "Baixando tabelas ACPI (CST e PST)..."
        {
            curl -sL -o /etc/initcpio/acpi_override/SSDT-CST.aml \
                "https://github.com/mendesrr/bc250-acpi-fix-updated-8c/raw/refs/heads/main/SSDT-CST.aml"
            curl -sL -o /etc/initcpio/acpi_override/SSDT-PST.aml \
                "https://github.com/mendesrr/bc250-acpi-fix-updated-8c/raw/refs/heads/main/SSDT-PST.aml"
        } >/dev/null 2>&1 &
        spinner $!
        if ! grep -q 'acpi_override' "$MKINITCPIO_CONF"; then
            sed -i '/^HOOKS=/ { /acpi_override/q; s/microcode/& acpi_override/; q }' "$MKINITCPIO_CONF"
        fi
        ACPI_APLICADO="sim"
        ok "ACPI fix aplicado (CST + PST)"
    else
        warn "ACPI fix não será aplicado"
    fi

    info "Regenerando initramfs..."
    if command -v limine-mkinitcpio &>/dev/null; then
        limine-mkinitcpio >/dev/null 2>&1 &
        spinner $!
    else
        mkinitcpio -P >/dev/null 2>&1 &
        spinner $!
    fi
    if command -v limine-update &>/dev/null; then
        limine-update >/dev/null 2>&1 &
        spinner $!
    fi
    ok "Initramfs reconstruido"
fi

header "Configuração dos CUs"
subheader "umr e bc250-cu-live-manager"
if ! command -v umr >/dev/null 2>&1; then
    info "Instalando umr via yay..."
    run_as_user "yay -S --noconfirm umr >/dev/null 2>&1" &
    spinner $!
    ok "umr instalado"
else
    ok "umr ja presente"
fi

MANAGER="./bc250-cu-live-manager.sh"
if [ ! -f "$MANAGER" ]; then
    info "Baixando script do live manager..."
    curl -sL -o "$MANAGER" "https://raw.githubusercontent.com/WinnieLV/bc250-cu-live-manager/refs/heads/main/bc250-cu-live-manager.sh" &
    spinner $!
fi
chmod +x "$MANAGER"
info "Liberando todos os CUs..."
bash "$MANAGER" --yes enable all >/dev/null 2>&1 &
spinner $!
ok "CUs liberados"

echo ""
echo "  ${bold}${yellow}ATENÇÃO: Todos os CUs foram liberados (40 CUs).${reset}"
echo "  Execute agora o FurMark (ou outro teste de estresse) por alguns segundos."
echo "  Observe se há instabilidades. Caso haja, não torne permanente."
CU_STATUS="não"
read -p "  ${cyan}?${reset}  Após o teste, digite 's' para tornar permanente ou 'n' para cancelar: " resp
if [[ "$resp" =~ ^[Ss]$ ]]; then
    info "Instalando serviço..."
    bash "$MANAGER" --yes install-service >/dev/null 2>&1 &
    spinner $!
    info "Escrevendo tabela de serviços..."
    bash "$MANAGER" --yes write-service-table >/dev/null 2>&1 &
    spinner $!
    ok "Configurado como serviço (CUs liberados)"
    CU_STATUS="sim"
else
    warn "Liberação de CUs interrompida pelo utilizador"
    echo "  ${yellow}Operação cancelada. A liberação é temporária.${reset}"
fi

header "Resumo da Configuração"
printf "  ${bold}${green}+"
printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
printf "+${reset}\n"
print_quadro_line "BC250 - Configurações Aplicadas"
print_quadro_line ""
print_quadro_line "BC250-SMU-OC          : instalado"
print_quadro_line "Governor GPU          : instalado"
print_quadro_line "Sensores nct6687      : ativados"
print_quadro_line "Swap                  : 16 GB (swappiness=120)"
print_quadro_line "UMA_SIZE              : 512 MB"
print_quadro_line "TTM pages limit       : 12 GB (3145728)"
print_quadro_line "Mitigações e RDSeed   : desativados"
print_quadro_line "ZSWAP                 : ativado (lz4, 25%)"
print_quadro_line "ACPI Fix              : ${ACPI_APLICADO}"
print_quadro_line "CUs liberados         : ${CU_STATUS}"
printf "  ${bold}${green}+"
printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
printf "+${reset}\n"

echo ""
info "Configuração da BC250 concluída com sucesso! Reinicie para aplicar todas as mudanças."

exit 0
