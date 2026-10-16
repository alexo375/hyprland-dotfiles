#!/usr/bin/env bash
set -euo pipefail

# Скрипт перевода системы в режим сна (suspend).
# Вызывается демоном hypridle по истечении таймаута бездействия (3600 сек / 1 час).

systemctl suspend
