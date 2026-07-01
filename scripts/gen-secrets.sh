#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$ROOT_DIR/.env.secrets"
ENV_FILE="$ROOT_DIR/.env"

XRAY_VER=$(grep '^XRAY_VER=' "$ENV_FILE" | cut -d= -f2)

if [[ -f "$SECRETS_FILE" ]]; then
  echo "[warn] $SECRETS_FILE already exists. Overwriting..."
fi

echo "[*] Pulling xray-core image: ghcr.io/xtls/xray-core:${XRAY_VER}"
docker pull --quiet "ghcr.io/xtls/xray-core:${XRAY_VER}"

# Идентификатор клиента — сервер пускает только его
XRAY_UUID=$(docker run --rm "ghcr.io/xtls/xray-core:${XRAY_VER}" uuid)
echo "[+] UUID: $XRAY_UUID"

# Ключи Reality (x25519): приватный — на сервере, публичный — у клиента
REALITY_KEYS=$(docker run --rm "ghcr.io/xtls/xray-core:${XRAY_VER}" x25519)
REALITY_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep 'PrivateKey:' | awk '{print $NF}')
REALITY_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep 'Password (PublicKey):' | awk '{print $NF}')
echo "[+] Reality private key: $REALITY_PRIVATE_KEY"
echo "[+] Reality public key:  $REALITY_PUBLIC_KEY"

# Токен в TLS handshake — сервер по нему отличает своих от чужих
REALITY_SHORT_ID=$(openssl rand -hex 8)
echo "[+] Reality short ID:    $REALITY_SHORT_ID"

cat > "$SECRETS_FILE" <<EOF
XRAY_UUID=${XRAY_UUID}
REALITY_PRIVATE_KEY=${REALITY_PRIVATE_KEY}
REALITY_PUBLIC_KEY=${REALITY_PUBLIC_KEY}
REALITY_SHORT_ID=${REALITY_SHORT_ID}
EOF

# Подставляем значения в шаблоны конфигов — xray-core не умеет читать env-переменные
SERVER_ADDR=$(grep '^SERVER_ADDR=' "$ENV_FILE" | cut -d= -f2)
SERVER_PORT=$(grep '^SERVER_PORT=' "$ENV_FILE" | cut -d= -f2)
export XRAY_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID SERVER_ADDR SERVER_PORT
envsubst < "$ROOT_DIR/configs/server/config.template.json" > "$ROOT_DIR/configs/server/config.json"
envsubst < "$ROOT_DIR/configs/client/config.template.json" > "$ROOT_DIR/configs/client/config.json"
echo "[+] Configs generated: configs/server/config.json, configs/client/config.json"

VLESS_LINK="vless://${XRAY_UUID}@${SERVER_ADDR}:${SERVER_PORT}?security=reality&encryption=none&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&fp=chrome&flow=xtls-rprx-vision&type=tcp&sni=addons.mozilla.org#xray-lab"

echo ""
echo "[ok] Secrets written to $SECRETS_FILE"
echo ""
echo "Client link:"
echo "$VLESS_LINK"
echo ""
echo "     Run 'make up' to start the stack."
