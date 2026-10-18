#!/bin/sh

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MOCK="$ROOT/tests/mock/bin"
UPDATE="$ROOT/luci-app-ddns-lite/root/usr/bin/ddns-lite-update"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run_case() {
	mode=$1
	current_ip=${2:-}
	root_domain=${3:-}
	export TEST_AUTH_MODE="$mode"
	export TEST_CURRENT_IP="$current_ip"
	export TEST_ROOT_DOMAIN="$root_domain"
	export TEST_LOG="$TMP/$mode.log"
	export TEST_SECRET_ID="AKIDEXAMPLE"
	export TEST_SECRET_KEY="SecretExample"
	: > "$TEST_LOG"

	PATH="$MOCK:$PATH" DNSPOD_API_BASE="https://legacy.test" sh "$UPDATE"

	if [ "$current_ip" = "112.231.219.236" ]; then
		grep -q 'ipv4.yu1998.com -> 112.231.219.236 (unchanged)' "$TEST_LOG"
	else
		grep -q 'updated ipv4.yu1998.com: 1.1.1.1 -> 112.231.219.236' "$TEST_LOG"
	fi
	grep -q 'created \*.ipv4.yu1998.com -> 112.231.219.236' "$TEST_LOG"
	grep -q 'ipv4 112.231.219.236: 2 succeeded, 0 failed' "$TEST_LOG"
}

run_case token
run_case tc3
run_case token "" yu1998.com
run_case token 112.231.219.236

if grep -q "tr '\\[:upper:\\]' '\\[:lower:\\]'" "$UPDATE"; then
	echo "case conversion must not depend on BusyBox tr" >&2
	exit 1
fi

echo "ddns-lite tests passed"
