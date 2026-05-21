#!/usr/bin/env bash

# ─── Yeni bölge tanımları (Senin jilet gibi hassas koordinatların) ───
GEOMETRY_MAIN="0,971 2560x438"
GEOMETRY_CHOICE="1561,513 916x585"

IMAGE_MAIN="/tmp/wuwa_main.png"
IMAGE_CHOICE="/tmp/wuwa_choice.png"

LAST_MAIN=""
LAST_CHOICE=""

# ─── Tesseract en iyi model dizini ───
TESSDATA_DIR="$HOME/.local/share/tessdata"

# Eğer dizin yoksa Tesseract'ın sistemdeki ana yoluna düşmesi için bir kontrol
[ ! -d "$TESSDATA_DIR" ] && TESSDATA_DIR="/run/current-system/sw/share/tessdata"

# ─── Çeviri önbelleği ───
CACHE_FILE="/tmp/wuwa_translate_cache"
touch "$CACHE_FILE"

# ─── Hızlı çeviri (Argos Translate) ───
translate_fast() {
    echo "$1" | argos-translate --from-lang en --to-lang tr 2>/dev/null
}

# ─── Yedek çeviri (Ollama LLM - Güvenli JSON formatı ile) ───
translate_llm() {
    local text="$1"
    # jq kullanarak girdiyi güvenli bir şekilde JSON stringine çeviriyoruz, asla patlamaz
    local json_payload
    json_payload=$(jq -n --arg mod "wuwa-gemma" --arg pr "EN: $text\nTR:" '{model: $mod, prompt: $pr, stream: false, options: {temperature: 0.0, num_predict: 80}}')

    curl -s http://localhost:11434/api/generate -d "$json_payload" | jq -r '.response' 2>/dev/null | xargs
}

# ─── Genel çeviri (önbellek + Argos → Ollama) ───
translate() {
    local raw="$1"
    local letter_count=$(echo "$raw" | tr -cd 'a-zA-Z' | wc -c)
    [ "$letter_count" -lt 5 ] && { echo ""; return; }

    # Önbellek kontrolü
    local cached=$(grep -F "$raw" "$CACHE_FILE" | head -n 1 | cut -d'|' -f2)
    [ -n "$cached" ] && { echo "$cached"; return; }

    # Hızlı çeviriyi dene
    local fast=$(translate_fast "$raw")
    if [ -n "$fast" ] && [ "${#fast}" -gt 2 ]; then
        echo "$raw|$fast" >> "$CACHE_FILE"
        echo "$fast"
        return
    fi

    # Yedek olarak LLM'ye (Aya/Gemma) sor
    local llm=$(translate_llm "$raw")
    if [ -n "$llm" ]; then
        echo "$raw|$llm" >> "$CACHE_FILE"
        echo "$llm"
        return
    fi
}

# ─── Ana döngü ───
while true; do
    # 1. Ana altyazı
    grim -g "$GEOMETRY_MAIN" "$IMAGE_MAIN" 2>/dev/null
    mogrify -resize 200% \
            -modulate 100,0 \
            -colorspace Gray \
            -lat 20x20+5% \
            -negate \
            -sharpen 0x2 \
            "$IMAGE_MAIN" 2>/dev/null

    RAW_MAIN=$(tesseract "$IMAGE_MAIN" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
    TEXT_MAIN=$(echo "$RAW_MAIN" | tr -d '\f' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

    if [ ${#TEXT_MAIN} -gt 5 ]; then
        if [ "$TEXT_MAIN" != "$LAST_MAIN" ]; then
            LAST_MAIN="$TEXT_MAIN"
            TRANSLATION_MAIN=$(translate "$TEXT_MAIN")
            [ -n "$TRANSLATION_MAIN" ] && notify-send -r 9999 "💬 Wuwa AI (Altyazı)" "$TRANSLATION_MAIN"
        fi
    else
        [ -n "$LAST_MAIN" ] && { LAST_MAIN=""; pkill -f "notify-send -r 9999"; }
    fi
    rm -f "$IMAGE_MAIN" 2>/dev/null

    # 2. Seçenek/cevap alanı
    grim -g "$GEOMETRY_CHOICE" "$IMAGE_CHOICE" 2>/dev/null
    mogrify -resize 200% \
            -modulate 100,0 \
            -colorspace Gray \
            -lat 20x20+5% \
            -negate \
            -sharpen 0x2 \
            "$IMAGE_CHOICE" 2>/dev/null

    RAW_CHOICE=$(tesseract "$IMAGE_CHOICE" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
    TEXT_CHOICE=$(echo "$RAW_CHOICE" | tr -d '\f' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

    if [ ${#TEXT_CHOICE} -gt 5 ]; then
        if [ "$TEXT_CHOICE" != "$LAST_CHOICE" ]; then
            LAST_CHOICE="$TEXT_CHOICE"
            TRANSLATION_CHOICE=$(translate "$TEXT_CHOICE")
            [ -n "$TRANSLATION_CHOICE" ] && notify-send -r 9998 "💡 Wuwa AI (Seçenekler)" "$TRANSLATION_CHOICE"
        fi
    else
        [ -n "$LAST_CHOICE" ] && { LAST_CHOICE=""; pkill -f "notify-send -r 9998"; }
    fi
    rm -f "$IMAGE_CHOICE" 2>/dev/null

    sleep 3
done
