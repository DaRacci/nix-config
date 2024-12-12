# Usage: new-host.sh host-type host-name
# Example: new-host.sh server nixai


set -e
set -o pipefail

# Ensure that the script is running at the root of the repository
if [ ! -f pkgs/helpers/new-host.sh ]; then
  echo "Please run this script from the root of the repository"
  exit 1
fi

# Parse the arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: new-host.sh host-type host-name"
  exit 1
fi

host_type=$1
host_name=$2

if [ ! -d hosts/"$host_type" ]; then
  echo "Invalid host type: $host_type"
  valid_host_types=$(find hosts -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
  echo "Valid host types are: $valid_host_types"
  exit 1
fi

if [ -d hosts/"$host_type"/"$host_name" ]; then
  echo "Host $host_name already exists"
  exit 1
fi

HOST_DIR="hosts/$host_type/$host_name"
mkdir -p "$HOST_DIR"

ssh-keygen -t ed25519 -f "$HOST_DIR"/ssh_host_ed25519_key -N "" -C "root@$host_name" > /dev/null
SSH_PRIVATE_KEY=$(cat "$HOST_DIR"/ssh_host_ed25519_key)
SSH_PUBLIC_KEY=$(cat "$HOST_DIR"/ssh_host_ed25519_key.pub)
rm "$HOST_DIR"/ssh_host_ed25519_key

cat > "$HOST_DIR"/default.nix <<EOF
{ modulesPath, ... }: {
  imports = [
    "\${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];
}
EOF

#section Secrets
SECRET_FILE="$HOST_DIR"/secrets.yaml

echo "Enter the usernames of the users to add as age recipients (comma-separated):"
read -r user_names
declare -a age_recipients
# TODO - Don't hardcode the github workflow runner's public key
age_recipients+=("age1gmc8dd4mj5q0zncy5gq4lccjlq9v84t8cqnlananmxt8g0jezv6szawll8")
for user_name in $(echo "$user_names" | tr "," "\n"); do
  if [ ! -f home/"$user_name"/id_ed25519.pub ]; then
    echo "Public key for user $user_name not found, skipping..."
    continue
  fi

  user_age_key=$(ssh-to-age -i home/"$user_name"/id_ed25519.pub)
  age_recipients+=("$user_age_key")
done

SOPS_FILE=.sops.yaml
HOST_AGE=$(ssh-to-age -i "$HOST_DIR/ssh_host_ed25519_key.pub")
age_recipients+=("$HOST_AGE")
#shellcheck disable=SC2094 disable=SC2002
cat "$SOPS_FILE" | yq --yaml-output "
.creation_rules += [
  {
    \"path_regex\": \"$SECRET_FILE\$\",
    \"key_groups\": [{
      \"age\": $(echo "${age_recipients[@]}" | jq -R 'split(" ")')
    }]
  }
]
| map_values(map(select(.path_regex == \"hosts/secrets.yaml$\").key_groups[].age += [\"$HOST_AGE\"]))
" > "$SOPS_FILE"

#shellcheck disable=SC2001 disable=SC2094
cat <<EOF | sops --config "$SOPS_FILE" --filename-override "$SECRET_FILE" --encrypt /dev/stdin > "$SECRET_FILE"
SSH_PRIVATE_KEY: |
$(echo "SSH_PRIVATE_KEY" | sed 's/^/  /')
EOF
#endsection

echo "---------- Private Key ----------"
echo ""
echo "$SSH_PRIVATE_KEY"
echo ""
echo "---------- Public Key -----------"
echo ""
echo "$SSH_PUBLIC_KEY"
echo ""
echo "---------------------------------"
