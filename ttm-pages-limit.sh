DEFAULT_PAGES=3145728
PAGES_LIMIT=${1:-$DEFAULT_PAGES}
LIMINE_DEFAULT="/etc/default/limine"
if [ ! -f "$LIMINE_DEFAULT" ]; then
    echo "❌ Arquivo $LIMINE_DEFAULT não encontrado."
    exit 1
fi
sudo cp "$LIMINE_DEFAULT" "$LIMINE_DEFAULT.bak.$(date +%Y%m%d%H%M%S)"
echo "✅ Backup criado em $LIMINE_DEFAULT.bak.$(date +%Y%m%d%H%M%S)"
if grep -q '^KERNEL_CMDLINE\[default\]=' "$LIMINE_DEFAULT"; then
    sudo sed -i '/^KERNEL_CMDLINE\[default\]=/ s/\bttm.pages_limit=[0-9]*\b//g' "$LIMINE_DEFAULT"
    sudo sed -i '/^KERNEL_CMDLINE\[default\]=/ s/"$/ ttm.pages_limit='$PAGES_LIMIT'"/' "$LIMINE_DEFAULT"
    echo "✅ Parâmetro atualizado (linha existente)."
else
    CURRENT_CMDLINE=$(cat /proc/cmdline)
    echo "KERNEL_CMDLINE[default]=\"$CURRENT_CMDLINE ttm.pages_limit=$PAGES_LIMIT\"" | sudo tee -a "$LIMINE_DEFAULT" > /dev/null
    echo "✅ Linha KERNEL_CMDLINE[default] criada."
fi
sudo limine-update
echo "✅ Configuração aplicada. Reinicie o sistema."
