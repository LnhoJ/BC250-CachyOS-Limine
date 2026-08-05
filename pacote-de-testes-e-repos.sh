#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

ORIGINAL_USER="${SUDO_USER:-$USER}"

if [[ -n "${SUDO_USER:-}" ]]; then
    SUDOERS_FILE="/etc/sudoers.d/temp_install_$$"
    echo "$ORIGINAL_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    trap 'rm -f "$SUDOERS_FILE"' EXIT
fi

as_user() {
    runuser -u "$ORIGINAL_USER" -- "$@"
}

if [[ -t 1 ]] && command -v tput &>/dev/null; then
    bold=$(tput bold)
    green=$(tput setaf 2)
    yellow=$(tput setaf 3)
    cyan=$(tput setaf 6)
    red=$(tput setaf 1)
    reset=$(tput sgr0)
else
    bold=""; green=""; yellow=""; cyan=""; red=""; reset=""
fi

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

sep() { echo -e "  ${cyan}---${reset}  $*"; }

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

QUADRO_WIDTH=50
print_quadro_line() {
    local text="${1:-}"
    local len=$(printf "%s" "$text" | wc -m)
    local padding=$((QUADRO_WIDTH - len - 4))
    if (( padding < 0 )); then
        padding=0
        text="${text:0:$((QUADRO_WIDTH-4))}…"
    fi
    printf "  ${bold}${green}| %s%${padding}s |${reset}\n" "$text" ""
}

declare -A STATUS
STATUS[flatpak]=true
STATUS[yay]=true
STATUS[paru]=true
STATUS[base_deps]=true
STATUS[furmark]=true
STATUS[superposition]=true
STATUS[cpu-x]=true
STATUS[coolercontrol]=true

mark_fail() { STATUS["$1"]=false; }

choose_build_dir() {
    local candidates=("/home/$ORIGINAL_USER/tmp" "/var/tmp" "/tmp")
    local selected=""
    for dir in "${candidates[@]}"; do
        mkdir -p "$dir" 2>/dev/null || continue
        local avail=$(df --output=avail "$dir" | tail -n1)
        if (( avail >= 4000000 )); then
            selected="$dir"
            break
        fi
    done
    echo "$selected"
}

check_opt_space() {
    local needed_kb=$((2 * 1024 * 1024))
    local avail=$(df --output=avail /opt | tail -n1)
    (( avail >= needed_kb ))
}

clean_tmp() {
    info "Limpando /tmp (arquivos com mais de 1 dia)..."
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    find /tmp -type d -empty -delete 2>/dev/null || true
    rm -rf /tmp/pacman-* 2>/dev/null || true
    ok "Limpeza concluída."
}

tmp_avail=$(df --output=avail /tmp | tail -n1)
if (( tmp_avail < 1048576 )); then
    warn "/tmp está com menos de 1 GB livre. Tentando limpeza automática..."
    clean_tmp
    tmp_avail=$(df --output=avail /tmp | tail -n1)
    if (( tmp_avail < 1048576 )); then
        err "Ainda não há espaço suficiente em /tmp. Recomenda-se reiniciar o sistema para limpar /tmp."
        warn "Pressione ENTER para continuar mesmo assim (pode falhar) ou Ctrl+C para abortar."
        read -r
    fi
fi

header "Preparação de repositórios e dependências"

sep "Flatpak"
if ! command -v flatpak &>/dev/null; then
    info "Instalando Flatpak..."
    pacman -S --noconfirm flatpak > /dev/null 2>&1 &
    spinner $!
    if wait $!; then
        ok "Flatpak instalado"
    else
        err "Falha ao instalar Flatpak"
        mark_fail flatpak
    fi
fi
if ! as_user flatpak remotes --user 2>/dev/null | grep -q flathub; then
    info "Adicionando Flathub..."
    as_user flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1 &
    spinner $!
    if wait $!; then
        ok "Flathub adicionado"
    else
        err "Falha ao adicionar Flathub"
        mark_fail flatpak
    fi
else
    ok "Flatpak + Flathub já prontos"
fi

sep "Dependências base"
info "Instalando git, base-devel, python-pipx, stress, dkms, linux-headers..."
pacman -S --needed --noconfirm git base-devel python-pipx stress dkms linux-headers > /dev/null 2>&1 &
spinner $!
if wait $!; then
    ok "Dependências base instaladas"
else
    err "Falha em algumas dependências"
    mark_fail base_deps
fi

sep "Yay"
if ! command -v yay &>/dev/null; then
    info "Clonando e compilando Yay..."
    as_user git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
    cd /tmp/yay
    as_user makepkg -si --noconfirm > /dev/null 2>&1 &
    spinner $!
    if wait $!; then
        ok "Yay instalado"
    else
        err "Falha ao instalar Yay"
        mark_fail yay
    fi
    cd ~; rm -rf /tmp/yay
else
    ok "Yay já instalado"
fi

sep "Paru"
if ! command -v paru &>/dev/null; then
    info "Clonando e compilando Paru..."
    as_user git clone https://aur.archlinux.org/paru.git /tmp/paru > /dev/null 2>&1
    cd /tmp/paru
    as_user makepkg -si --noconfirm > /dev/null 2>&1 &
    spinner $!
    if wait $!; then
        ok "Paru instalado"
    else
        err "Falha ao instalar Paru"
        mark_fail paru
    fi
    cd ~; rm -rf /tmp/paru
else
    ok "Paru já instalado"
fi

header "Instalação das ferramentas de teste"

sep "FurMark"
if as_user flatpak install --user -y flathub com.geeks3d.furmark > /dev/null 2>&1; then
    ok "FurMark instalado"
else
    warn "FurMark – instalação manual necessária"
    mark_fail furmark
fi

sep "Unigine Superposition"
if [ -d "/opt/unigine-superposition" ] || command -v superposition &>/dev/null; then
    ok "Superposition já instalado – pulando"
else
fi
info "Instalando dependências de compilação..."
pacman -S --needed --noconfirm cmake gcc make mesa mesa-utils opencl-headers > /dev/null 2>&1 &
spinner $!
wait $! || warn "Algumas dependências opcionais podem estar faltando"

if ! check_opt_space; then
    err "Espaço insuficiente em /opt (necessário ~2 GB)."
    warn "Libere espaço e tente novamente."
    mark_fail superposition
else
    BUILD_DIR=$(choose_build_dir)
    if [[ -z "$BUILD_DIR" ]]; then
        warn "Nenhum diretório com 4 GB livres. Tentando limpeza..."
        clean_tmp
        BUILD_DIR=$(choose_build_dir)
    fi
    if [[ -n "$BUILD_DIR" ]]; then
        BUILD_DIR="$BUILD_DIR/superposition-build"
        mkdir -p "$BUILD_DIR"
        chown "$ORIGINAL_USER:" "$BUILD_DIR"
        info "Usando diretório de build: $BUILD_DIR"
        info "Instalando Superposition..."
        as_user env TMPDIR="$BUILD_DIR" yay -S --noconfirm --builddir "$BUILD_DIR" unigine-superposition > /tmp/superposition_stdout.log 2> /tmp/superposition_stderr.log &
        spinner $!
        if wait $!; then
            ok "Superposition instalado"
            chmod -R a+rX /opt/unigine-superposition
        else
            err "Falha ao instalar Superposition."
            echo -e "  ${red}--- Últimas 20 linhas do erro ---${reset}"
            tail -n 20 /tmp/superposition_stderr.log | sed 's/^/    /'
            echo -e "  ${red}--- Fim do erro ---${reset}"
            if grep -q "No space left on device" /tmp/superposition_stderr.log; then
                warn "Erro de espaço em disco. Verifique /tmp e /opt."
                warn "Execute: df -h e libere espaço."
            fi
            mark_fail superposition
            warn "Tente instalar manualmente: yay -S unigine-superposition"
            warn "Ou baixe o binário em: https://benchmark.unigine.com/superposition"
        fi
        rm -rf "$BUILD_DIR" 2>/dev/null || true
    else
        err "Espaço insuficiente mesmo após limpeza."
        mark_fail superposition
        warn "Reinicie o sistema para limpar /tmp ou use um diretório com mais espaço."
    fi
fi

sep "CPU-X"
pacman -S --noconfirm cpu-x > /dev/null 2>&1 &
spinner $!
if wait $!; then
    ok "CPU-X instalado"
else
    err "Falha ao instalar CPU-X"
    mark_fail cpu-x
fi

sep "CoolerControl"
pacman -S --noconfirm coolercontrol > /dev/null 2>&1 &
spinner $!
if wait $!; then
    ok "CoolerControl instalado"
else
    err "Falha ao instalar CoolerControl"
    mark_fail coolercontrol
fi
info "Ativando serviço coolercontrold..."
systemctl enable --now coolercontrold > /dev/null 2>&1 &
spinner $!
if wait $!; then
    ok "Serviço ativado"
else
    warn "Não foi possível ativar o serviço"
fi

echo ""
printf "  ${bold}${green}+"
printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
printf "+${reset}\n"
print_quadro_line "Resumo"
print_quadro_line ""
for comp in flatpak yay paru base_deps furmark superposition cpu-x coolercontrol; do
    if ${STATUS[$comp]}; then
        print_quadro_line "[OK] $comp"
    else
        print_quadro_line "[!!] $comp (verificar)"
    fi
done
printf "  ${bold}${green}+"
printf '%*s' $((QUADRO_WIDTH-2)) '' | tr ' ' '-'
printf "+${reset}\n"
echo ""

exit 0
