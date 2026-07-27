#!/usr/bin/env bash
set -Eeuo pipefail

PACK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${PACK_ROOT}/dist}"
PACKWIZ_RELEASE_PORT="${PACKWIZ_RELEASE_PORT:-18080}"
BOOTSTRAP_URL="${BOOTSTRAP_URL:-https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar}"

cd "$PACK_ROOT"

for command_name in packwiz java curl zip; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Ошибка: не найдена команда %s\n' "$command_name" >&2
        exit 1
    fi
done

if [[ ! -f pack.toml ]]; then
    printf 'Ошибка: %s/pack.toml не найден\n' "$PACK_ROOT" >&2
    exit 1
fi

PACK_VERSION="$(
    sed -nE 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)".*$/\1/p' pack.toml |
        sed -n '1p'
)"

if [[ -z "$PACK_VERSION" ]]; then
    printf 'Ошибка: не удалось прочитать version из pack.toml\n' >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/40ch-war-release.XXXXXXXX")"
CLIENT_ARCHIVE="${BUILD_DIR}/40ch-War-S1-${PACK_VERSION}.zip"
SERVER_ARCHIVE="${BUILD_DIR}/40ch-War-S1-${PACK_VERSION}-server.zip"
CLIENT_OUTPUT="${OUTPUT_DIR}/40ch-War-S1-${PACK_VERSION}.zip"
SERVER_OUTPUT="${OUTPUT_DIR}/40ch-War-S1-${PACK_VERSION}-server.zip"
PACKWIZ_SERVER_PID=""

cleanup() {
    if [[ -n "$PACKWIZ_SERVER_PID" ]] && kill -0 "$PACKWIZ_SERVER_PID" 2>/dev/null; then
        kill "$PACKWIZ_SERVER_PID" 2>/dev/null || true
        wait "$PACKWIZ_SERVER_PID" 2>/dev/null || true
    fi
    rm -rf -- "$BUILD_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR/server"

printf 'Обновляю index.toml...\n'
packwiz refresh

printf 'Собираю клиент: %s\n' "$CLIENT_OUTPUT"
packwiz curseforge export \
    --output "$CLIENT_ARCHIVE" \
    --side client

printf 'Скачиваю packwiz installer bootstrap...\n'
curl --fail --location --silent --show-error \
    "$BOOTSTRAP_URL" \
    --output "$BUILD_DIR/packwiz-installer-bootstrap.jar"

printf 'Запускаю временный Packwiz-сервер на порту %s...\n' "$PACKWIZ_RELEASE_PORT"
packwiz serve --port "$PACKWIZ_RELEASE_PORT" >"$BUILD_DIR/packwiz-serve.log" 2>&1 &
PACKWIZ_SERVER_PID="$!"

PACK_URL="http://127.0.0.1:${PACKWIZ_RELEASE_PORT}/pack.toml"
for _ in {1..50}; do
    if curl --fail --silent "$PACK_URL" >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$PACKWIZ_SERVER_PID" 2>/dev/null; then
        printf 'Ошибка: packwiz serve завершился аварийно\n' >&2
        cat "$BUILD_DIR/packwiz-serve.log" >&2
        exit 1
    fi
    sleep 0.1
done

if ! curl --fail --silent "$PACK_URL" >/dev/null 2>&1; then
    printf 'Ошибка: packwiz serve не запустился вовремя\n' >&2
    cat "$BUILD_DIR/packwiz-serve.log" >&2
    exit 1
fi

printf 'Разворачиваю серверную сторону сборки...\n'
(
    cd "$BUILD_DIR/server"
    java -jar "$BUILD_DIR/packwiz-installer-bootstrap.jar" \
        -g \
        -s server \
        "$PACK_URL"
)

printf 'Упаковываю сервер: %s\n' "$SERVER_OUTPUT"
(
    cd "$BUILD_DIR/server"
    zip -q -r "$SERVER_ARCHIVE" .
)

mv -f -- "$CLIENT_ARCHIVE" "$CLIENT_OUTPUT"
mv -f -- "$SERVER_ARCHIVE" "$SERVER_OUTPUT"

printf '\nГотово:\n'
printf '  %s\n' "$CLIENT_OUTPUT"
printf '  %s\n' "$SERVER_OUTPUT"
