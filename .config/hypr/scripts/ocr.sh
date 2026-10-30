#!/usr/bin/env bash

# Скрипт оптического распознавания текста (OCR) с экрана:
# 1. Захватывает область через grim и slurp во временный файл.
# 2. Проверяет наличие языковых пакетов Tesseract (rus, eng).
# 3. Распознает текст и копирует его в буфер обмена Wayland (wl-copy).
# Вызывается по комбинации клавиш Super+Shift+T.

# Предотвращение запуска повторных инстансов slurp
if pgrep -x "slurp" > /dev/null; then
    exit 0
fi

# Временный файл для снимка экрана
temp_img="/tmp/ocr_capture.png"

# Выделение области экрана и снимок через grim
if ! grim -g "$(slurp)" "$temp_img"; then
    notify-send -a "OCR" "OCR" "Capture cancelled"
    exit 1
fi

# Определение доступных языков в tesseract (автодобавление русского, если установлен)
available_langs=$(tesseract --list-langs)
langs="eng"

if echo "$available_langs" | grep -q "rus"; then
    langs="rus+eng"
fi

# Выполнение распознавания текста и копирование в буфер обмена
if tesseract "$temp_img" stdout -l "$langs" | wl-copy; then
    text=$(wl-paste)
    if [ -n "$text" ]; then
        notify-send -a "OCR" "OCR" "Copied to clipboard" -i chat-history-symbolic
    else
        notify-send -a "OCR" "OCR" "No text found" -u critical
    fi
else
    notify-send -a "OCR" "OCR" "Recognition failed" -u critical
fi

# Удаление временного файла снимка
rm -f "$temp_img"
