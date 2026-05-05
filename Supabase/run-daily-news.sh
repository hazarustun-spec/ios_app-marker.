#!/bin/bash
# Günlük haberleri üret — her topic için ayrı Edge Function çağrısı
# Kullanım: bash Supabase/run-daily-news.sh

set -euo pipefail

URL="https://zxseytwpunjajypzrmmr.supabase.co/functions/v1/generate-daily-news"
TOPICS=("llms" "robotics" "research" "safety" "vision" "tools" "business" "policy" "generative" "healthcare")

echo "=== $(date '+%Y-%m-%d %H:%M') — Haber üretimi başladı ==="
echo ""

# Önce health check
echo -n "Health check ... "
health=$(curl -sf --max-time 10 "$URL" 2>&1) || { echo "✗ fonksiyon erişilemiyor"; exit 1; }
echo "✓ $health"
echo ""

ok=0; fail=0; dup=0

for topic in "${TOPICS[@]}"; do
  echo -n "→ $topic ... "

  # --max-time 90: Sonnet'in en yavaş günü için bile yeterli
  http_code=""
  result=$(curl -s -o /tmp/fn_response.json -w "%{http_code}" \
    -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "{\"topic_id\": \"$topic\"}" \
    --max-time 120 2>/dev/null) || true

  http_code="$result"
  body=$(cat /tmp/fn_response.json 2>/dev/null || echo "")

  if [[ -z "$body" ]]; then
    echo "✗ boş yanıt (HTTP $http_code) — curl timeout olmuş olabilir"
    ((fail++)) || true
    continue
  fi

  status=$(echo "$body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'unknown'))
except:
    print('parse_error')
" 2>/dev/null)

  case "$status" in
    inserted)
      echo "✓ eklendi"
      ((ok++)) || true
      ;;
    duplicate)
      echo "⊘ zaten var"
      ((dup++)) || true
      ;;
    *)
      err=$(echo "$body" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('error', d.get('message', '')))
except:
    print(sys.stdin.read()[:100])
" 2>/dev/null)
      echo "✗ hata: $err"
      ((fail++)) || true
      ;;
  esac
done

echo ""
echo "=== Bitti: $ok yeni, $dup mevcut, $fail hatalı ==="
