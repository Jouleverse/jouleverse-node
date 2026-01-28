# jouleverse-node

Binary and config files for running jouleverse nodes. env: ubuntu:20.04 (docker).

## revision history

2026.1.28
- downgrade docker image requirement from ubuntu 22.04 to 20.04
- fix ~ to $HOME in docker-compose config for root run
- improve security for clef-rules.js

2026.1.26
- fix docker-compose permission issue
- fix version tag x20260126
- update bootnode lists
- integrate clef signer for geth miner
- wrap jnode mgmt scripts for easier node operation

2026.1.25
- clean up bootnodes
- integrate clef for miner
- use docker compose
- scripts for easier jnode mgmt

2024.2.29
- use geth 1.11.4-jouleverse with tag support
- fix enode for bootnode-koant and bootnode-wenqinghuo in witness config

2024.1.15
- fill all 11 ledger nodes to miner config
- fill all 7 bootnode-witness nodes to witness config

2024.1.3
- remove bootnode.j.blockcoach.com from witness node config
- add new 4 miner nodes to miner node config

2023.10.7
- for docker use

## contributors

- Evan Liu 🆔J25 (evan.j)
