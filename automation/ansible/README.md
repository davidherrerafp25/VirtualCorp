# Activitat 3 - Ansible i WireGuard

## Ansible

Inventari `inventories/lab.yml`.

Rols `start_vm` i `stop_vm` per iniciar i aturar els quatre routers MikroTik mitjançant VirtualBox.

Playbooks:
- `playbooks/start_routers.yml`
- `playbooks/stop_routers.yml`
- `playbooks/configure_wireguard.yml`

## WireGuard

Servidor: mikrotik0
Interfície: wg-vcorp
Xarxa VPN: 10.11.10.0/24
Servidor: 10.11.10.1
Client: 10.11.10.2
Port: UDP 51820
Endpoint de laboratori: 127.0.0.1:51820
Reenviament: VirtualBox NAT UDP 51820 cap a mikrotik0.

Xarxes autoritzades:
- 10.11.0.0/24
- 10.11.1.0/24
- 10.11.2.0/24
- 10.11.3.0/24

Tallafoc:
- Permetre UDP 51820 a input.
- Permetre forward cap a les xarxes autoritzades.
- Bloquejar la resta de destinacions des de WireGuard.

Encaminament: RIP redistribueix 10.11.10.0/24. Sense NAT entre VPN i xarxes internes.

Fitxer del client: artifacts/vpn/vcorp.conf, exclòs de Git.

## Validacions

- Inventari i sintaxi Ansible correctes.
- Inici i aturada dels quatre routers.
- Segona execució idempotent.
- Handshake WireGuard correcte.
- Ping a 10.11.10.1 i als routers interns.
- Accés SSH remot a RouterOS.
- Internet directe amb túnel dividit.
- Túnel funcional després de desactivar-lo, reactivar-lo i reiniciar mikrotik0.
