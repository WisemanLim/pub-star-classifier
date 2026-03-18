#!/usr/bin/env bash
set -euo pipefail

APP_NAME="pub-star-classifier"
BIN_PATH="${HOME}/.local/bin/${APP_NAME}"
CFG_DIR="${HOME}/.pub-star-classifier"
CRON_MARKER="# ${APP_NAME}"

echo "삭제를 진행합니다."

if command -v crontab >/dev/null 2>&1; then
  if crontab -l >/dev/null 2>&1; then
    CURRENT="$(crontab -l || true)"
    FILTERED="$(printf "%s\n" "${CURRENT}" | awk -v m="${CRON_MARKER}" 'index($0,m)==0')"
    if [[ "${FILTERED}" != "${CURRENT}" ]]; then
      echo "crontab 항목이 감지되었습니다. 제거합니다."
      printf "%s\n" "${FILTERED}" | crontab -
    fi
  fi
fi

if [[ -f "${BIN_PATH}" ]]; then
  rm -f "${BIN_PATH}"
  echo "삭제됨: ${BIN_PATH}"
else
  echo "없음: ${BIN_PATH}"
fi

if [[ -d "${CFG_DIR}" ]]; then
  echo ""
  read -r -p "설정 디렉토리(${CFG_DIR})도 삭제할까요? [y/N] " ans || true
  if [[ "${ans}" == "y" || "${ans}" == "Y" ]]; then
    rm -rf "${CFG_DIR}"
    echo "삭제됨: ${CFG_DIR}"
  else
    echo "유지됨: ${CFG_DIR}"
  fi
fi

echo "완료."

