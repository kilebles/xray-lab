.PHONY: up down logs pull up-client down-client logs-client gen-secrets latest-version capture clean

# --- Сервер (запускать на VPS) ---

up:
	docker compose -f compose.server.yaml up -d

down:
	docker compose -f compose.server.yaml down

logs:
	docker compose -f compose.server.yaml logs -f

pull:
	docker compose -f compose.server.yaml pull

# --- Клиент (запускать локально) ---

up-client:
	docker compose -f compose.client.yaml up -d

down-client:
	docker compose -f compose.client.yaml down

logs-client:
	docker compose -f compose.client.yaml logs -f

# --- Общее ---

# Сгенерировать секреты (.env)
gen-secrets:
	bash scripts/gen-secrets.sh

# Показать актуальную версию xray-core из GitHub Releases
latest-version:
	@curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
		| grep '"tag_name"' | head -1 | cut -d'"' -f4 | tr -d 'v'

# Захватить трафик на порту 443 (требует tcpdump + права)
capture:
	@echo "Capturing on port 443... Ctrl+C to stop."
	tcpdump -i any -w capture_$(shell date +%Y%m%d_%H%M%S).pcap port 443

# Удалить временные артефакты
clean:
	rm -f *.pcap *.pcapng
