# Implantació del servei DNS

## Infraestructura

- Contenidor: dns01 (ID 204).
- Sistema operatiu: Debian 13.
- Recursos: 1 CPU, 512 MB RAM i 6 GB de disc.
- Xarxa: privada (vmbr0).
- IP reservada per DHCP: 10.11.0.137/26.
- MAC local: 02:00:00:00:00:89.
- Conversió: 137 decimal = 89 hexadecimal.
- La MAC no coincideix amb les dels equips comprovats.

S'utilitza el direccionament 10.11 de la delegació 11,
en lloc del 10.1 de l'exemple de l'enunciat.

## Terraform i Ansible

Terraform gestiona dhcp01 i dns01 amb el mateix estat.
L'inventari proxmox_lxc.yml es genera amb yamlencode.
Kea obté les reserves dels serveis des de l'inventari.
Els registres DNS utilitzen el mateix pla d'adreçament.

## Zones DNS

- delegacio11.com
- delegacio11.lan
- planta00.delegacio11.lan
- planta01.delegacio11.lan
- planta02.delegacio11.lan
- planta03.delegacio11.lan

Els equips direccio1, direccio2 i direccio3 pertanyen
a la planta 3 i utilitzen adreçament dinàmic.
No tenen registres A fixos.

## Disseny i seguretat

BIND9 combina el servei autoritatiu i recursiu en un
únic contenidor per simplificar el laboratori.

- Reenviador: 8.8.8.8.
- Recursió limitada a les xarxes autoritzades.
- Transferències i actualitzacions de zona desactivades.
- Port 53 UDP i TCP.
- Fitxers de zona: root:bind, permisos 0644.
- Memòria màxima de la memòria cau: 128 MB.
- TTL: 3600 segons.
- SOA: refresh 3600, retry 900 i expire 604800.

El TTL limita el temps de conservació dels registres.
El número de sèrie SOA s'ha d'incrementar quan
es modifiquen les dades de les zones.

La configuració es valida amb named-checkconf i
named-checkzone abans d'aplicar-la.

## Proves realitzades

- Reserva DHCP de dns01 i renovació correctes.
- Resolució SOA, NS i A de les sis zones.
- Resolució interna i externa des de les set xarxes.
- Consultes DNS UDP i TCP correctes.
- Transferència de zona denegada.
- Consulta no autoritzada: REFUSED.
- Reinici del contenidor: IP conservada i BIND9 actiu.
- Ansible: changed=0, failed=0.
- Terraform: 0 added, 0 changed, 0 destroyed.

## Desplegament

    make deploy_dns

## Referències

- https://bind9.readthedocs.io/en/stable/
- https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- https://packages.debian.org/trixie/bind9

## Tallafoc

El tallafoc de Proxmox està desactivat.
BIND9 restringeix les consultes i la recursió mitjançant ACL.
S'ha comprovat l'accés al port 53 TCP i UDP.

El desplegament make deploy_dns funciona correctament.
Els rols Kea i BIND9 són idempotents.
El playbook dels relays informa de canvis en cada execució.
