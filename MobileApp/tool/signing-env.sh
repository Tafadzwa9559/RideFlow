# Source from an interactive Bash terminal: source tool/signing-env.sh
# Loads an EXISTING release key; never generates a key or writes credentials.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo 'Use: source tool/signing-env.sh (so exports reach your build shell).' >&2
  exit 1
fi
if [[ $- == *x* || $- == *v* ]]; then
  echo 'Disable shell tracing first: set +x; set +v' >&2
  return 1
fi

_trivia_load_signing() {
  local key_path alias_name store_secret key_secret
  read -r -p 'Existing release keystore absolute path (no ~): ' key_path || return 1
  if [[ "$key_path" != /* || ! -f "$key_path" || ! -r "$key_path" ]]; then
    echo 'A readable existing keystore at an absolute path is required.' >&2
    return 1
  fi
  read -r -p 'Existing key alias: ' alias_name || return 1
  read -r -s -p 'Keystore password: ' store_secret || return 1
  echo
  read -r -s -p 'Key password: ' key_secret || return 1
  echo
  if [[ -z "$alias_name" || -z "$store_secret" || -z "$key_secret" ]]; then
    echo 'Alias and both passwords must be supplied; environment unchanged.' >&2
    return 1
  fi
  export TRIVIA_KEYSTORE="$key_path" TRIVIA_KEY_ALIAS="$alias_name"
  export TRIVIA_STORE_PASSWORD="$store_secret" TRIVIA_KEY_PASSWORD="$key_secret"
  echo 'Signing environment loaded for this shell. Run flutter build apk --release here.'
}
if _trivia_load_signing; then
  unset -f _trivia_load_signing
else
  unset -f _trivia_load_signing
  return 1
fi
