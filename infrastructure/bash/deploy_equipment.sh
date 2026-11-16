#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/configs/versions.sh"
cd "$ROOT"

test -f configs/equipment.csv

for template in debian-server-template debian-desktop-template; do
    VBoxManage snapshot "$template" list | grep -q 'Base' || exit 1
done

while IFS='|' read -r nombre tipo red; do
    [[ -z "$nombre" || "$nombre" == \#* ]] && continue

    case "$tipo" in
        server)
            plantilla=debian-server-template
            ram=768
            ;;
        desktop)
            plantilla=debian-desktop-template
            ram=1536
            ;;
        *)
            echo "Tipo no válido: $tipo"
            exit 1
            ;;
    esac

    case "$red" in
        dmz|privada|pl0|pl1|pl2|pl3|pl3_direccio)
            ;;
        *)
            echo "Red no válida: $red"
            exit 1
            ;;
    esac

    if VBoxManage showvminfo "$nombre" >/dev/null 2>&1; then
        echo "Ya existe $nombre"
        continue
    fi

    VBoxManage clonevm "$plantilla" \
        --snapshot Base \
        --options link \
        --name "$nombre" \
        --register \
        --groups /VirtualCorp/equipment

    VBoxManage modifyvm "$nombre" \
        --memory "$ram" \
        --cpus 1 \
        --nic1 intnet \
        --intnet1 "$red"

    echo "Clon creado: $nombre -> $red"

done < configs/equipment.csv

if VBoxManage showvminfo pve01 >/dev/null 2>&1; then
    echo "pve01 ya existe"
    exit 0
fi

read -rsp 'Contraseña de pve01: ' PASS
echo

ISO_DIR="$ROOT/artifacts/images/proxmox"
mkdir -p "$ISO_DIR"

if [[ ! -f "$ISO_DIR/$PROXMOX_ISO" ]]; then
    curl -fL "$PROXMOX_URL" -o "$ISO_DIR/$PROXMOX_ISO"
fi

echo "$PROXMOX_SHA256  $ISO_DIR/$PROXMOX_ISO" | sha256sum -c -

test -s configs/ssh/vcorp-auditor.pub
test -s configs/ssh/vcorp_sysadmin.pub

cat > "$ISO_DIR/answer.toml" <<TOML
[global]
keyboard = "es"
country = "es"
fqdn = "pve01.virtualcorp.local"
mailto = "root@virtualcorp.local"
timezone = "Europe/Madrid"
root-password-hashed = "$(openssl passwd -6 "$PASS")"
root-ssh-keys = ["$(cat configs/ssh/vcorp-auditor.pub)", "$(cat configs/ssh/vcorp_sysadmin.pub)"]
reboot-mode = "power-off"

[network]
filter.ID_NET_NAME_PATH = "enp0s3"
source = "from-answer"
cidr = "10.11.0.133/26"
gateway = "10.11.0.129"
dns = "1.1.1.1"

[disk-setup]
filesystem = "ext4"
disk-list = ["sda"]
TOML

unset PASS

CHROOT="$ROOT/artifacts/proxmox-trixie"

if [[ ! -d "$CHROOT/bin" ]]; then
    sudo debootstrap --variant=minbase trixie "$CHROOT" https://deb.debian.org/debian
fi


# CORRECCION APT VIRTUALCORP
sudo mkdir -p "$CHROOT/etc/ssl/certs"

sudo cp /etc/ssl/certs/ca-certificates.crt     "$CHROOT/etc/ssl/certs/ca-certificates.crt"

for archivo in     "$CHROOT/etc/apt/sources.list"     "$CHROOT"/etc/apt/sources.list.d/*.list     "$CHROOT"/etc/apt/sources.list.d/*.sources
do
    if [ -f "$archivo" ]; then
        sudo sed -i             -e 's|http://deb.debian.org|https://deb.debian.org|g'             -e 's|http://security.debian.org|https://security.debian.org|g'             "$archivo"
    fi
done

# VIRTUALCORP_PVE_HTTP_FIX
for fuente in     "$CHROOT/etc/apt/sources.list"     "$CHROOT"/etc/apt/sources.list.d/*.list     "$CHROOT"/etc/apt/sources.list.d/*.sources
do
    [ -f "$fuente" ] || continue
    sudo sed -i         's|https://download.proxmox.com/debian/pve|http://download.proxmox.com/debian/pve|g'         "$fuente"
done

sudo chroot "$CHROOT" apt-get -o Acquire::Retries=8 -o Acquire::ForceIPv4=true update
# VIRTUALCORP_PVE_HTTP_FIX
for fuente in     "$CHROOT/etc/apt/sources.list"     "$CHROOT"/etc/apt/sources.list.d/*.list     "$CHROOT"/etc/apt/sources.list.d/*.sources
do
    [ -f "$fuente" ] || continue
    sudo sed -i         's|https://download.proxmox.com/debian/pve|http://download.proxmox.com/debian/pve|g'         "$fuente"
done

sudo chroot "$CHROOT" apt-get -o Acquire::Retries=8 -o Acquire::ForceIPv4=true install -y --no-install-recommends ca-certificates curl

sudo mkdir -p "$CHROOT/usr/share/keyrings"

sudo curl -fsSL \
    https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
    -o "$CHROOT/usr/share/keyrings/proxmox-archive-keyring.gpg"

echo 'deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription' | sudo tee "$CHROOT/etc/apt/sources.list.d/pve.list" >/dev/null

# VIRTUALCORP_PVE_HTTP_FIX
for fuente in     "$CHROOT/etc/apt/sources.list"     "$CHROOT"/etc/apt/sources.list.d/*.list     "$CHROOT"/etc/apt/sources.list.d/*.sources
do
    [ -f "$fuente" ] || continue
    sudo sed -i         's|https://download.proxmox.com/debian/pve|http://download.proxmox.com/debian/pve|g'         "$fuente"
done

sudo chroot "$CHROOT" apt-get -o Acquire::Retries=8 -o Acquire::ForceIPv4=true update
# VIRTUALCORP_PVE_HTTP_FIX
for fuente in     "$CHROOT/etc/apt/sources.list"     "$CHROOT"/etc/apt/sources.list.d/*.list     "$CHROOT"/etc/apt/sources.list.d/*.sources
do
    [ -f "$fuente" ] || continue
    sudo sed -i         's|https://download.proxmox.com/debian/pve|http://download.proxmox.com/debian/pve|g'         "$fuente"
done

sudo chroot "$CHROOT" apt-get -o Acquire::Retries=8 -o Acquire::ForceIPv4=true install -y --no-install-recommends proxmox-auto-install-assistant

sudo mkdir -p "$CHROOT/work"
sudo mount --bind "$ISO_DIR" "$CHROOT/work"

trap 'sudo umount "$CHROOT/work" 2>/dev/null || true' EXIT

# VIRTUALCORP_XORRISO_FIX
# Herramienta necesaria para generar la ISO desatendida
sudo chroot "$CHROOT" apt-get     -o Acquire::Retries=8     -o Acquire::ForceIPv4=true     install -y --no-install-recommends xorriso

sudo chroot "$CHROOT" proxmox-auto-install-assistant validate-answer /work/answer.toml

# VIRTUALCORP_REBUILD_ISO
sudo rm -f "$CHROOT/work/proxmox-auto.iso"
rm -f "$ISO_DIR/proxmox-auto.iso"

sudo chroot "$CHROOT" proxmox-auto-install-assistant prepare-iso \
    "/work/$PROXMOX_ISO" \
    --fetch-from iso \
    --answer-file /work/answer.toml \
    --output /work/proxmox-auto.iso

sudo umount "$CHROOT/work"
trap - EXIT

# VIRTUALCORP_CHECK_ISO
if [ ! -s "$ISO_DIR/proxmox-auto.iso" ]; then
    echo "ERROR: No se ha generado la ISO automática de Proxmox." >&2
    exit 1
fi

VBoxManage createvm \
    --name pve01 \
    --ostype Debian_64 \
    --register \
    --groups /VirtualCorp/equipment

VBoxManage modifyvm pve01 \
    --memory 8192 \
    --cpus 4 \
    --nic1 intnet \
    --intnet1 privada \
    --nested-hw-virt on \
    --boot1 dvd \
    --boot2 disk

VBoxManage storagectl pve01 \
    --name SATA \
    --add sata \
    --controller IntelAhci

VM_DIR="$(dirname "$(VBoxManage showvminfo pve01 --machinereadable | sed -n 's/^CfgFile="\([^"]*\)"/\1/p')")"

VBoxManage createmedium disk \
    --filename "$VM_DIR/pve01.vdi" \
    --size 65536 \
    --format VDI

VBoxManage storageattach pve01 \
    --storagectl SATA \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$VM_DIR/pve01.vdi"

VBoxManage storageattach pve01 \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "$ISO_DIR/proxmox-auto.iso"

VBoxManage startvm pve01 --type headless

echo "Instalación desatendida de pve01 iniciada"

for i in $(seq 1 300); do
    estado="$(VBoxManage showvminfo pve01 --machinereadable | grep '^VMState=' || true)"
    [[ "$estado" == 'VMState="poweroff"' ]] && break
    sleep 10
done

[[ "$(VBoxManage showvminfo pve01 --machinereadable | grep '^VMState=')" == 'VMState="poweroff"' ]] || {
    echo "La instalación de Proxmox no ha terminado"
    exit 1
}

VBoxManage storageattach pve01 \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium none

echo "pve01 preparado"
