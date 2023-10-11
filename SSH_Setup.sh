#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Please install Homebrew first."
    echo "You can find instructions at https://brew.sh/"
    exit 1
fi

# Check if the 'openssh' package, which provides ssh-keygen, is installed
if ! brew list --formulae | grep -q "^openssh$"; then
    echo "The openssh package is not installed through Homebrew. Attempting to install..."
    if ! brew install openssh; then
        echo "Error: Failed to install the openssh package via Homebrew. Please check if Homebrew is set up correctly."
        exit 1
    fi
fi

# Define a list of key types and their default paths
declare -A KEY_TYPES
KEY_TYPES=(
    ["rsa"]="$HOME/.ssh/id_rsa"
    ["ecdsa"]="$HOME/.ssh/id_ecdsa"
    ["ed25519"]="$HOME/.ssh/id_ed25519"
)

# Loop through each key type and check if it exists. Generate if not.
for key_type in "${!KEY_TYPES[@]}"; do
    key_path="${KEY_TYPES[$key_type]}"
    if [[ -f "$key_path" ]]; then
        echo "Found existing SSH key of type $key_type at $key_path."
    else
        echo "No $key_type SSH key found. Generating one..."
        ssh-keygen -t $key_type
    fi
done

#WARNING This script assumes that the user's SSH keys are stored in the default location (~/.ssh). Change the script accordingly if a different path is used.

# Initialize an empty array to hold the names of SSH key files
ssh_keys=()

# Check the ~/.ssh directory for key files and add them to the array
echo "Checking for ssh keys in the default directory."
for filename in $HOME/.ssh/id_*; do
  [ -e "$filename" ] || continue
  if [[ ! "$filename" =~ \.pub$ ]]; then
    ssh_keys+=($(basename $filename))
  fi
done

# Check if we found any keys
if [ ${#ssh_keys[@]} -eq 0 ]; then
  echo "No existing SSH keys found."
else
  echo "Found the following SSH keys:"
  for i in "${!ssh_keys[@]}"; do
    echo "$((i+1)). ${ssh_keys[i]}"
  done

  # Ask if the user wants to display a public key
  read -r -p "Would you like to display the public key for any of these so you can copy them? [y/n]: " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if [ ${#ssh_keys[@]} -gt 1 ]; then
      read -r -p "Which one would you like to display? (Enter the number): " choice
      key_to_display=${ssh_keys[$((choice-1))]}
    else
      key_to_display=${ssh_keys[0]}
    fi

    if [ -f "$HOME/.ssh/$key_to_display.pub" ]; then
      echo "Displaying public key for $key_to_display:"
      cat "$HOME/.ssh/$key_to_display.pub"
    else
      echo "Public key file for $key_to_display not found."
    fi
  fi
fi


# 
# Loop asking the user for their CruzID until the user confirms their CruzID
while true; do
  # Ask the user for their CruzID
  read -p "Enter your CruzID: " CruzID
  
  # Show the entered CruzID and ask for confirmation
  read -p "You entered '$CruzID'. Is this correct? [y/n]: " confirm
  
  # Check if the user confirmed
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    break
  elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
    echo "Please re-enter your CruzID."
  else
    echo "Invalid option. Please re-enter your CruzID."
  fi
done

# Define SSH directory and config file
# THIS MAY NEED TO BE CHANGED IF YOUR .SSH IS NOT IN DEFAULT LOCATION
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"

# Check if ~/.ssh directory exists and if it doesn't create it.
if [ ! -d "$SSH_DIR" ]; then
  echo "Creating $SSH_DIR directory..."
  mkdir -p "$SSH_DIR"
else
  echo "Current permissions for $SSH_DIR:"
  stat -c '%A %a %n' "$SSH_DIR"
fi

# Ensure correct permissions for ~/.ssh directory
chmod 700 "$SSH_DIR"		#Give read write & execute permissions to directory

# Check if ~/.ssh/config file exists and if it doesnt create it
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating $CONFIG_FILE..."
  touch "$CONFIG_FILE"
else
  echo "Current permissions for $CONFIG_FILE:"
  stat -c '%A %a %n' "$CONFIG_FILE"
fi

# Ensure correct permissions for ~/.ssh/config file
chmod 600 "$CONFIG_FILE"	#Give read & write permissions to the config file

# A function to add server configurations if they don't already exist
add_server_config() {
  local host="$1"
  local hostname="$2"
  local extra_config="$3"

  if grep -q "^Host $host$" "$CONFIG_FILE"; then
    echo "Server configuration for '$host' already exists in $CONFIG_FILE."
  else
    echo "Appending server configuration for '$host' to $CONFIG_FILE..."
    cat <<EOL >> "$CONFIG_FILE"


# Configuration for $hostname
Host $host
  HostName $hostname
  User $CruzID
  $extra_config
EOL
    echo "Done for $host!"
  fi
}

# Add configurations for the servers
add_server_config "hb" "hb.ucsc.edu" ""
add_server_config "vhe4" "vhe4.ucsc.edu" "HostKeyAlgorithms +ssh-rsa"
add_server_config "vhe7" "vhe7.ucsc.edu" "HostKeyAlgorithms +ssh-rsa"

echo "Done!"
echo "You should be able to ssh into hummingbird by just typing 'ssh hb' now!"
