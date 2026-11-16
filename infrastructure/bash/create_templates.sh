#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source configs/versions.sh

ISO="$ROOT/artifacts/images/debian/$DEBIAN_ISO"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "$DEBIAN_SHA256  $ISO" | sha256sum -c -

test -s configs/ssh/vcorp-auditor.pub
test -s configs/ssh/vcorp_sysadmin.pub

read -rsp "Contraseña sysadmin/root: " PASS
echo
printf '%s' "$PASS" > "$TMP/password"
chmod 600 "$TMP/password"
unset PASS

# Clave temporal para comprobar SSH automáticamente
ssh-keygen -q -t ed25519 -N "" \
    -f "$TMP/check_key" \
    -C vcorp-verificacion-temporal

# Preparar instalación desatendida de Debian
python3 - "$TMP/preseed.cfg" <<'PY'
from pathlib import Path
import sys

archivo = Path(
    "/usr/share/virtualbox/UnattendedTemplates/debian_preseed.cfg"
)

s = archivo.read_text()

s = s.replace(
    "d-i pkgsel/include string openssh-server",
    ""
)

s = s.replace(
    "# Users",
    "d-i pkgsel/run_tasksel boolean false\n"
    "d-i pkgsel/upgrade select none\n"
    "# Users",
    1
)

Path(sys.argv[1]).write_text(s)
PY

for tipo in server desktop; do

    vm="debian-${tipo}-template"

    # Conservar templates terminados
    if VBoxManage showvminfo "$vm" >/dev/null 2>&1; then
        if VBoxManage snapshot "$vm" list 2>/dev/null | grep -q "Name: Base"; then
            echo "OK: $vm ya preparado"
            continue
        fi

        echo "ERROR: $vm existe pero no esta terminado"
        exit 1
    fi

    if [ "$tipo" = server ]; then
        RAM=1024
        PORT=2290
        PAQUETES="openssh-server sudo"
    else
        RAM=2048
        PORT=2291
        PAQUETES="openssh-server sudo xorg lxqt-core sddm falkon dbus-x11 openbox"
    fi

    POST="$TMP/post-$tipo.sh"

    cat > "$POST" <<'POST1'
#!/bin/sh
set -eu

mkdir -p /target/home/sysadmin/.ssh

cat > /target/home/sysadmin/.ssh/authorized_keys <<'KEYS'
POST1

    cat configs/ssh/vcorp-auditor.pub >> "$POST"
    echo >> "$POST"
    cat configs/ssh/vcorp_sysadmin.pub >> "$POST"
    echo >> "$POST"
    cat "$TMP/check_key.pub" >> "$POST"
    echo >> "$POST"

    cat >> "$POST" <<'POST2'
KEYS

chmod 700 /target/home/sysadmin/.ssh
chmod 600 /target/home/sysadmin/.ssh/authorized_keys

chroot /target chown -R sysadmin:sysadmin \
    /home/sysadmin/.ssh

mkdir -p /target/usr/local/sbin

cat > /target/usr/local/sbin/vcorp-firstboot <<'FIRSTBOOT'
#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive

# APT utilizara repositorios oficiales firmados.

POST2

    printf 'PAQUETES="%s"\n' "$PAQUETES" >> "$POST"

    cat >> "$POST" <<'POST3'

# Utilizar repositorios oficiales de Debian 13.
# El sistema verificara las firmas de los paquetes.

vapt() {
    apt-get \
        -o Dir::Etc::sourcelist=/tmp/vcorp-install.sources \
        -o Dir::Etc::sourceparts=- \
        -o Acquire::Retries=5 \
        -o Acquire::ForceIPv4=true \
        -o Acquire::http::Timeout=30 \
        -o APT::Update::Error-Mode=any \
        "$@"
}

for mirror in \
    http://deb.debian.org/debian \
    http://ftp.caliu.cat/debian \
    http://debian.redimadrid.es/debian
do

    cat > /tmp/vcorp-install.sources <<SOURCES
Types: deb
URIs: $mirror
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SOURCES

    for intento in 1 2 3; do

        echo "Instalando desde $mirror - intento $intento"

        dpkg --configure -a || true

        if vapt update &&
           vapt -y --no-install-recommends install $PAQUETES &&
           dpkg --configure -a; then

            correcto=1

            for paquete in $PAQUETES; do
                if ! dpkg-query -W -f='${Status}' "$paquete" 2>/dev/null |
                     grep -qx 'install ok installed'; then
                    correcto=0
                    break
                fi
            done

            if [ "$correcto" = 1 ]; then

                systemctl enable ssh

                if dpkg-query -W sddm >/dev/null 2>&1; then
                    systemctl enable sddm
                fi

                touch /var/lib/vcorp-template-ready

                systemctl disable vcorp-firstboot.service || true

                echo "OK: Instalacion completada"
                exit 0
            fi
        fi

        sleep 10
    done
done

echo "ERROR: No se pudieron instalar los paquetes" >&2
exit 1

FIRSTBOOT

chmod 755 /target/usr/local/sbin/vcorp-firstboot

cat > /target/etc/systemd/system/vcorp-firstboot.service <<'UNIT'
[Unit]
Description=VirtualCorp template setup
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vcorp-firstboot
StandardOutput=journal+console
StandardError=journal+console
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
UNIT

mkdir -p /target/etc/systemd/system/multi-user.target.wants

ln -sf ../vcorp-firstboot.service \
    /target/etc/systemd/system/multi-user.target.wants/vcorp-firstboot.service
POST3

    sh -n "$POST"

    echo "Creando $vm ..."

    VBoxManage createvm \
        --name "$vm" \
        --ostype Debian_64 \
        --register \
        --groups /VirtualCorp/templates

    VBoxManage modifyvm "$vm" \
        --memory "$RAM" \
        --cpus 2 \
        --nic1 nat \
        --natpf1 "ssh,tcp,127.0.0.1,${PORT},,22" \
        --boot1 dvd \
        --boot2 disk

    VBoxManage storagectl "$vm" \
        --name SATA \
        --add sata \
        --controller IntelAhci

    VM_DIR="$(dirname "$(VBoxManage showvminfo "$vm" --machinereadable | sed -n 's/^CfgFile="\([^"]*\)"/\1/p')")"

    VBoxManage createmedium disk \
        --filename "$VM_DIR/$vm.vdi" \
        --size 16384 \
        --format VDI

    VBoxManage storageattach "$vm" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$VM_DIR/$vm.vdi"

    VBoxManage unattended install "$vm" \
        --iso="$ISO" \
        --user=sysadmin \
        --user-password-file="$TMP/password" \
        --admin-password-file="$TMP/password" \
        --full-user-name=sysadmin \
        --hostname="${vm}.virtualcorp.local" \
        --country=ES \
        --package-selection-adjustment=minimal \
        --no-install-additions \
        --script-template="$TMP/preseed.cfg" \
        --post-install-template="$POST" \
        --start-vm=headless > "$TMP/install.log" 2>&1 || {
            echo "ERROR: VirtualBox no pudo iniciar la instalación"
            exit 1
        }

    echo "Verificando instalación automática de $vm ..."

    LISTO=0

    for ((i=1; i<=360; i++)); do

        if ssh \
            -q \
            -o IdentitiesOnly=yes \
            -o BatchMode=yes \
            -o ConnectTimeout=4 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -i "$TMP/check_key" \
            -p "$PORT" \
            sysadmin@127.0.0.1 \
            'test -f /var/lib/vcorp-template-ready' \
            >/dev/null 2>&1; then

            LISTO=1
            break
        fi

        if (( i % 6 == 0 )); then
            echo "Comprobando $vm: intento $i"
        fi

        sleep 10
    done

    if [ "$LISTO" != 1 ]; then
        echo "ERROR: instalación o SSH incompletos en $vm"
        exit 1
    fi

    echo "OK: Debian y SSH configurados"

    # Quitar clave temporal. Conservar las dos claves oficiales.
    ssh \
        -q \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i "$TMP/check_key" \
        -p "$PORT" \
        sysadmin@127.0.0.1 \
        "sed -i '/vcorp-verificacion-temporal$/d' ~/.ssh/authorized_keys && sync"

    # Apagar la máquina
    VBoxManage controlvm "$vm" acpipowerbutton || true

    APAGADA=0

    for ((i=1; i<=60; i++)); do
        ESTADO="$(VBoxManage showvminfo "$vm" --machinereadable | sed -n 's/^VMState="\([^"]*\)"/\1/p')"

        if [ "$ESTADO" = poweroff ]; then
            APAGADA=1
            break
        fi

        sleep 2
    done

    if [ "$APAGADA" != 1 ]; then
        VBoxManage controlvm "$vm" poweroff
    fi

    # Red interna y snapshot
    VBoxManage modifyvm "$vm" --natpf1 delete ssh

    VBoxManage modifyvm "$vm" \
        --nic1 intnet \
        --intnet1 pl0

    VBoxManage snapshot "$vm" take Base

    echo "OK: $vm creado con snapshot Base"

done
