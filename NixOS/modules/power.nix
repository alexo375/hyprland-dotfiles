{ config, pkgs, lib, ... }:

let
  desktopUser = builtins.head (builtins.attrNames config.home-manager.users);
in
{
  # Настройки поведения при закрытии крышки ноутбука: сон в RAM, затем гибернация на диск
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
  };

  # Задержка перед переходом из suspend в hibernate (30 минут сна, затем гибернация)
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30min";
  };

  # Использование power-profiles-daemon для явного ручного переключения профилей питания
  # (TLP отключен, так как он конфликтует, автоматически переопределяя профили AC/BAT)
  services.power-profiles-daemon.enable = true;

  # Демон мониторинга батареи: предупреждения о низком заряде и гибернация до отключения питания
  systemd.services.low-battery-monitor = {
    description = "Notify on low battery and hibernate before power loss";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-logind.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 10;
    };
    script = ''
      # Constants
      USER_NAME=${lib.escapeShellArg desktopUser}
      USER_UID=$(${pkgs.coreutils}/bin/id -u "$USER_NAME")
      POLL_INTERVAL_SECONDS=60
      FIRST_WARNING_PERCENT=15
      CRITICAL_WARNING_PERCENT=5
      HIBERNATE_PERCENT=2
      HIBERNATE_DELAY_SECONDS=5
      STATE_FILE=/run/low-battery-monitor.state

      notify_user() {
        urgency=$1
        summary=$2
        body=$3
        runtime_dir="/run/user/$USER_UID"
        bus="unix:path=$runtime_dir/bus"

        if [ -S "$runtime_dir/bus" ]; then
          ${pkgs.util-linux}/bin/runuser -u "$USER_NAME" -- \
            env XDG_RUNTIME_DIR="$runtime_dir" DBUS_SESSION_BUS_ADDRESS="$bus" \
            ${pkgs.libnotify}/bin/notify-send -u "$urgency" "$summary" "$body" || true
        fi
      }

      while true; do
        mains_online=0
        battery_capacity=
        battery_status=

        for ps in /sys/class/power_supply/*; do
          [ -e "$ps" ] || continue

          if [ -f "$ps/type" ] && [ -f "$ps/online" ] && [ "$(cat "$ps/type")" = "Mains" ]; then
            if [ "$(cat "$ps/online")" = "1" ]; then
              mains_online=1
            fi
          fi

          if [ -f "$ps/type" ] && [ -f "$ps/capacity" ] && [ "$(cat "$ps/type")" = "Battery" ]; then
            status=Unknown
            [ -f "$ps/status" ] && status=$(cat "$ps/status")

            if [ -z "$battery_capacity" ] || [ "$status" = "Discharging" ]; then
              battery_capacity=$(cat "$ps/capacity")
              battery_status=$status
            fi
          fi
        done

        if [ -z "$battery_capacity" ]; then
          sleep "$POLL_INTERVAL_SECONDS"
          continue
        fi

        case "$battery_capacity" in
          ""|*[!0-9]*)
            sleep "$POLL_INTERVAL_SECONDS"
            continue
            ;;
        esac

        if [ "$mains_online" = "1" ] || [ "$battery_status" != "Discharging" ]; then
          printf '%s\n' reset > "$STATE_FILE"
          sleep "$POLL_INTERVAL_SECONDS"
          continue
        fi

        last_state=
        [ -r "$STATE_FILE" ] && last_state=$(cat "$STATE_FILE")

        if [ "$battery_capacity" -le "$HIBERNATE_PERCENT" ]; then
          notify_user critical "Battery critical" "Battery is at $battery_capacity%. Hibernating now."
          printf '%s\n' hibernate > "$STATE_FILE"
          sleep "$HIBERNATE_DELAY_SECONDS"
          ${pkgs.systemd}/bin/systemctl hibernate
        elif [ "$battery_capacity" -le "$CRITICAL_WARNING_PERCENT" ] && [ "$last_state" != "$CRITICAL_WARNING_PERCENT" ]; then
          notify_user critical "Battery low" "Battery is at $battery_capacity%. Hibernation starts at $HIBERNATE_PERCENT%."
          printf '%s\n' "$CRITICAL_WARNING_PERCENT" > "$STATE_FILE"
        elif [ "$battery_capacity" -le "$FIRST_WARNING_PERCENT" ] && [ "$last_state" != "$FIRST_WARNING_PERCENT" ] && [ "$last_state" != "$CRITICAL_WARNING_PERCENT" ]; then
          notify_user normal "Battery low" "Battery is at $battery_capacity%. Plug in the charger."
          printf '%s\n' "$FIRST_WARNING_PERCENT" > "$STATE_FILE"
        fi

        sleep "$POLL_INTERVAL_SECONDS"
      done
    '';
  };
}
