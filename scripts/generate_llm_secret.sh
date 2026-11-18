#!/bin/bash
# Generates LLMSecret.generated.swift with the LLMApps TOTP key XOR-masked by a random salt.
# The key comes from the LLM_TOTP_KEY build setting (Config/Secrets.xcconfig, git-ignored).
set -euo pipefail

OUT_DIR="${DERIVED_FILE_DIR}"
OUT_FILE="${OUT_DIR}/LLMSecret.generated.swift"
KEY="${LLM_TOTP_KEY:-}"

if [[ "${KEY}" == *REPLACE_WITH_KEY* ]]; then
    KEY=""
fi

mkdir -p "${OUT_DIR}"

masked=()
salt=()
for ((i = 0; i < ${#KEY}; i++)); do
    code=$(printf '%d' "'${KEY:i:1}")
    s=$((RANDOM % 256))
    masked+=("$((code ^ s))")
    salt+=("${s}")
done

join() {
    local IFS=,
    echo "$*"
}

cat > "${OUT_FILE}" <<EOF
// Generated at build time by scripts/generate_llm_secret.sh. Do not edit or commit.
enum LLMSecret {
    static let masked: [UInt8] = [$(join "${masked[@]+"${masked[@]}"}")]
    static let salt: [UInt8] = [$(join "${salt[@]+"${salt[@]}"}")]
}
EOF
