import csv
import json
from ipaddress import ip_address, ip_network
from pathlib import Path

root = Path(__file__).resolve().parents[2]

networks = [
    ("dmz", "10.11.0.192/27", "10.11.0.193", "10.11.0.210", "10.11.0.220"),
    ("privada", "10.11.0.128/26", "10.11.0.129", "10.11.0.150", "10.11.0.190"),
    ("pl0", "10.11.0.0/25", "10.11.0.1", "10.11.0.20", "10.11.0.120"),
    ("pl1", "10.11.1.0/24", "10.11.1.1", "10.11.1.30", "10.11.1.220"),
    ("pl2", "10.11.2.0/24", "10.11.2.1", "10.11.2.30", "10.11.2.220"),
    ("pl3", "10.11.3.0/25", "10.11.3.1", "10.11.3.20", "10.11.3.120"),
    ("pl3_direccio", "10.11.3.128/25", "10.11.3.129", "10.11.3.150", "10.11.3.240"),
]

with (root / "configs/address-plan.tsv").open() as f:
    devices = list(csv.DictReader(f, delimiter="\t"))

subnets = []

for index, (name, cidr, gateway, start, end) in enumerate(networks, 1):
    reservations = []

    for device in devices:
        if device["network"] != name or device["allocation"] != "reserva":
            continue

        address = ip_address(device["ip"])

        if address not in ip_network(cidr):
            raise ValueError(f"IP fuera de subred: {device['hostname']}")

        if ip_address(start) <= address <= ip_address(end):
            raise ValueError(f"Reserva dentro del pool: {device['hostname']}")

        reservations.append({
            "hw-address": device["mac"],
            "ip-address": device["ip"],
            "hostname": device["hostname"]
        })

    subnets.append({
        "id": index,
        "subnet": cidr,
        "pools": [{"pool": f"{start} - {end}"}],
        "option-data": [{"name": "routers", "data": gateway}],
        "reservations": reservations
    })

config = {
    "Dhcp4": {
        "interfaces-config": {"interfaces": ["eth0"]},
        "valid-lifetime": 3600,
        "renew-timer": 900,
        "rebind-timer": 1800,
        "lease-database": {
            "type": "memfile",
            "persist": True,
            "name": "/var/lib/kea/kea-leases4.csv"
        },
        "option-data": [
            {"name": "domain-name-servers", "data": "10.11.0.137"},
            {"name": "domain-name", "data": "virtualcorp.local"}
        ],
        "subnet4": subnets
    }
}

dest = root / "automation/ansible/roles/kea_dhcp/files/kea-dhcp4.conf"
dest.write_text(json.dumps(config, indent=2) + "\n")

print(f"Configuradas {len(subnets)} redes y {sum(len(s['reservations']) for s in subnets)} reservas")
