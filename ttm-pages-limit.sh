DEFAULT_PAGES=3145728
PAGES_LIMIT=${1:-$DEFAULT_PAGES}
LIMINE_DEFAULT="/etc/default/limine"
if [ ! -f "$LIMINE_DEFAULT" ]; then
    echo "❌ Arquivo $LIMINE_DEFAULT não encontrado."
    exit 1
fi
BACKUP_FILE="$LIMINE_DEFAULT.bak.$(date +%Y%m%d%H%M%S)"
sudo cp "$LIMINE_DEFAULT" "$BACKUP_FILE"
echo "✅ Backup criado em $BACKUP_FILE"
sudo sed -i '/^KERNEL_CMDLINE\[default\]/ s/\bttm.pages_limit=[0-9]*\b//g' "$LIMINE_DEFAULT"
sudo sed -i '/^KERNEL_CMDLINE\[default\]/ s/" $/ ttm.pages_limit='$PAGES_LIMIT'"/' "$LIMINE_DEFAULT"
sudo sed -i '/^KERNEL_CMDLINE\[default\]/ s/"$/ ttm.pages_limit='$PAGES_LIMIT'"/' "$LIMINE_DEFAULT"
if ! grep -q '^KERNEL_CMDLINE\[default\]=' "$LIMINE_DEFAULT" && ! grep -q '^KERNEL_CMDLINE\[default\]\+=' "$LIMINE_DEFAULT"; then
    CURRENT_CMDLINE=$(cat /proc/cmdline)
    echo "KERNEL_CMDLINE[default]=\"$CURRENT_CMDLINE ttm.pages_limit=$PAGES_LIMIT\"" | sudo tee -a "$LIMINE_DEFAULT" > /dev/null
    echo "✅ Linha KERNEL_CMDLINE[default] criada."
fi
if command -v limine-update &> /dev/null; then
    sudo limine-update
    echo "✅ Limine atualizado com limine-update"
elif command -v limine-mkinitcpio &> /dev/null; then
    sudo limine-mkinitcpio
    echo "✅ Limine atualizado com limine-mkinitcpio"
else
    echo "⚠️ Nenhum comando limine-update ou limine-mkinitcpio encontrado."
    echo "   Verifique se o Limine está instalado corretamente."
    exit 1
fi
echo ""
echo "✅ Configuração aplicada com sucesso!"
echo "   Valor definido: $PAGES_LIMIT páginas (~$((PAGES_LIMIT * 4 / 1024 / 1024)) GB)"
echo "   Backup: $BACKUP_FILE"
echo ""
echo "🔁 Reinicie o sistema para ativar: sudo reboot"
