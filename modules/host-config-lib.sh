# Shell helpers for host-config activation scripts.
# Sourced at activation time by modules/host-config.nix.
# Also sourced directly by tests/host-config.bats.

_hc_restore_file() {
  local _hc_file="$1"
  rm -f "$_hc_file.new"
  if [ -L "$_hc_file.lnk" ]; then
    echo -e "\e[32mRestoring link '$_hc_file' from '$_hc_file.lnk'\e[0m"
    mv "$_hc_file.lnk" "$_hc_file"
  fi
}

_hc_create_file() {
  local _hc_file="$1"
  [ -L "$_hc_file" ] || return 0
  local _hc_target
  _hc_target=$(readlink -f "$_hc_file")
  echo -e "\e[32mCopying '$_hc_target' to '$_hc_file'\e[0m"
  cp "$_hc_target" "$_hc_file.new" || return 1
  mv "$_hc_file" "$_hc_file.lnk"
  mv "$_hc_file.new" "$_hc_file"
  # Make sure the configuration file is writable, Nix usually generates the files read only (444)
  chmod 644 "$_hc_file"
}
