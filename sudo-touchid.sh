#!/bin/bash

VERSION=0.4
readable_name='[TouchID for sudo]'
executable_name='sudo-touchid'
is_sonoma_or_newer=$(bc -l <<< "$(sw_vers -productVersion) >= 14.0")

usage() {
  cat <<EOF

  Usage: $executable_name [options]
    Running without options adds TouchID parameter to sudo configuration

  Options:
    -d,  --disable     Remove TouchID from sudo config

    -v,  --version     Output version
    -h,  --help        This message.

EOF
}

backup_ext='.bak'

touch_pam='auth       sufficient     pam_tid.so'
sudo_path=$([[ $is_sonoma_or_newer == 1 ]] && echo '/etc/pam.d/sudo_local' || echo '/etc/pam.d/sudo')

nl=$'\n'

# Source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}
wait_for_user() {
  local c
  echo
  echo "Press RETURN to continue or any other key to abort"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]; then
    exit 1
  fi
}
# Source end.

display_backup_info() {
  echo "Created a backup file at $sudo_path$backup_ext"
  echo
}
display_sonoma_info() {
  [[ $is_sonoma_or_newer -eq 0 ]] && return
  echo "Feel free to delete the $executable_name CLI (if you have it, and unless you'd want to disable TouchID in sudo later). This is possible since macOS Sonoma introduced a way to make actually persisting changes to sudo authorization module."
  echo
}

display_sudo_without_touch_pam() {
  grep -v "^$touch_pam$" "$sudo_path"
}

touch_pam_at_sudo_path_check_exists() {
  grep -q -e "^$touch_pam$" "$sudo_path" &> /dev/null
}

touch_pam_at_sudo_path_insert() {
  sudo sed -E -i "$backup_ext" "1s/^(#.*)?$/\1\\${nl}$touch_pam/" "$sudo_path"
}
with_sonoma_touch_pam_at_sudo_path_insert() {
  if [[ $is_sonoma_or_newer == 1 ]]; then
    if [[ -f "$sudo_path" ]]; then
      sudo cp "$sudo_path" "$sudo_path$backup_ext"
      echo "$touch_pam" | sudo tee -a "$sudo_path" > /dev/null
    else
      echo "$touch_pam" | sudo tee "$sudo_path" > /dev/null
    fi
  else
    touch_pam_at_sudo_path_insert
  fi
}

touch_pam_at_sudo_path_remove() {
  sudo sed -i "$backup_ext" -e "/^$touch_pam$/d" "$sudo_path"
}

sudo_touchid_disable() {
  if touch_pam_at_sudo_path_check_exists; then
    echo "The following will be your $sudo_path after disabling:"
    echo
    display_sudo_without_touch_pam
    wait_for_user
    if touch_pam_at_sudo_path_remove; then
      display_backup_info
      echo "$readable_name has been disabled."
    else
      echo "$readable_name failed to disable"
    fi
  else
    echo "$readable_name seems to be already disabled"
  fi
}

sudo_touchid_enable() {
  if touch_pam_at_sudo_path_check_exists; then
    echo "$readable_name seems to be enabled already"
  else
    if with_sonoma_touch_pam_at_sudo_path_insert; then
      display_backup_info
      echo "$readable_name enabled successfully."
      echo
      display_sonoma_info
    else
      echo "$readable_name failed to execute"
    fi
  fi
}

sudo_touchid() {
  for opt in "${@}"; do
    case "$opt" in
    -v | --version)
      echo "v$VERSION"
      return 0
      ;;
    -d | --disable)
      sudo_touchid_disable
      return 0
      ;;
    -h | --help)
      usage
      return 0
      ;;
    *)
      echo "Unknown option: $opt"
      usage
      return 0
      ;;
    esac
  done

  sudo_touchid_enable
}

sudo_touchid "${@}"
