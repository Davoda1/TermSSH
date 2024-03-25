#!/bin/bash

# Use this to show help information on how to use the script.
helptext () {
  echo " HELP:"
  echo " - The MENU has options from 0 to 6 and the letters."
  echo " - The options are:"
  echo " - 1/n) Adding new SSH server."
  echo " - 2/v) Show all saved server(s)."
  echo " - 3/s) Connect to SSH server."
  echo " - 4/d) Delete server."
  echo " - 5/f) Send data via SCP."
  echo " - 6/q) Exit from program."
  echo " - 0/c) Clear the screan."
  echo " - h)   Show this help text."
  echo " - l)   Show directory contents."
}

# Check for the help flags on start.
if [[ $1 == "-h" || $1 == "--help" ]];then
  helptext; exit 0
fi

# Check for the existence of the config file, if not create it.
if [ ! -f ~/.config/termssh-manager.conf ]; then
  # echo "Configuration file not found, create new file..."
  echo "$(tput bold)$(tput setaf 255)Configuration file not found, without one being created the program will close."
  read -p "Do you wish to create it now? [Y/n]: " filecreator
  printf "$(tput sgr0)"
  if [[ $filecreator = [Yy] || $filecreator = [Yy][Ee][Ss] ]]; then
    echo "Config file is created ~/.config/termssh-manager.conf"
    echo "declare -A SSH_CONFIGS" > ~/.config/termssh-manager.conf
  else
    printf "$(tput bold)$(tput setaf 1)The program will close.$(tput sgr0)\n"
    exit 0
  fi
fi

# Load the config file
source ~/.config/termssh-manager.conf

# Add new server to use for SSH and SCP connection
configure_ssh() {
  echo "Add new server"
  echo -n "$(tput sgr0)Server name: $(tput bold)$(tput setaf 153)"
  read server_name
  if [ -z $server_name ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  # If the server's name exists abort
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $server_name == $server ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)This name already in existance, \nuse an other one or \ndelete the existing one!\n$(tput sgr0)" && return 1; fi
  done
  echo -n "$(tput sgr0)Host/IP addreas: $(tput bold)"
  read SSH_HOST
  if [ -z $SSH_HOST ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  echo -n "$(tput sgr0)Port (optional): $(tput bold)"
  read SSH_PORT
  echo -n "$(tput sgr0)Username: $(tput bold)"
  read SSH_USER
  if [ -z $SSH_USER ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  printf "$(tput sgr0)"
  if [ -z "$SSH_PORT" ];then
    SSH_CONFIGS[$server_name]="$SSH_USER@$SSH_HOST"
  else
    SSH_CONFIGS[$server_name]="$SSH_USER@$SSH_HOST -p $SSH_PORT"
  fi
  echo "declare -A SSH_CONFIGS" > ~/.config/termssh-manager.conf
  for key in "${!SSH_CONFIGS[@]}"; do
    echo "SSH_CONFIGS[$key]='${SSH_CONFIGS[$key]}'" >> ~/.config/termssh-manager.conf
  done
  echo "$(tput bold)$(tput setaf 2)Config saved!$(tput sgr0)"
}

# Show the contents of the config file
show_config() {
  scounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done

  echo "$(tput bold)$(tput setaf 255)List SSH config:$(tput sgr0)"
  for server in "${!SSH_CONFIGS[@]}"; do
    printf "Server: $(tput bold)$(tput setaf 153)$server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq 0 ]; do
      printf " "
      let COUNTER-=1
    done
    printf "  ($scounter)$(tput sgr0)\n"
    scounter=$((scounter + 1))
    temp_var=${SSH_CONFIGS[$server]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    printf "Config: $(tput bold)$cutservername$(tput sgr0)\n"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      printf "         on port: $(tput bold)$serverport$(tput sgr0)"
    fi
    printf "\n"
  done
  echo "$(tput setaf 2)End of list.$(tput sgr0)"
}

# Connect to server via SSH
connect_ssh() {
  echo "Available server(s):"
  scounter=0
  stcounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done
  for server in "${!SSH_CONFIGS[@]}"; do
    printf "$(tput bold)$(tput setaf 153)$server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq 0 ]; do
      printf " "
      let COUNTER-=1
    done
    printf "\t---\t($scounter)$(tput sgr0)\n"
    scounter=$((scounter + 1))
  done
  echo -n "Select server: $(tput bold)"
  read server_name
  if [ -z $server_name ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  printf "$(tput sgr0)"

  # If the input is a number
  if [[ "$server_name" =~ ^[0-9]+$ ]]; then
    for server in "${!SSH_CONFIGS[@]}"; do
      if [ $stcounter -eq $server_name ]; then server_name=$server && break; fi
      stcounter=$((stcounter + 1))
    done
  fi

  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    echo "$(tput bold)$(tput setaf 1)Server Not found.$(tput sgr0)"
  else
    temp_var=${SSH_CONFIGS[$server_name]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    printf "Connecting to $(tput bold)$(tput setaf 2)$cutservername$(tput sgr0)"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      printf " on port: $(tput bold)$(tput setaf 2)$serverport$(tput sgr0)"
    fi
    printf "...\n"
    echo -n "Are you sure you want to connect? [Y/n]: $(tput bold)"
    read -n 1 confirm
    if [ -z $confirm ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && confirm="n"; fi
    printf "$(tput sgr0)\n"
    if [[ $confirm = [Yy] ]]; then
      ssh ${SSH_CONFIGS[$server_name]}
    else
      echo "$(tput bold)$(tput setaf 1)Cancel connect.$(tput sgr0)"
    fi
  fi
}

# Send file to server via SCP
fileshare_scp() {
  echo "Available server(s) for SCP:"
  scounter=0
  stcounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done
  for server in "${!SSH_CONFIGS[@]}"; do
    printf "$(tput bold)$(tput setaf 153)$server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq 0 ]; do
      printf " "
      let COUNTER-=1
    done
    printf "\t---\t($scounter)$(tput sgr0)\n"
    scounter=$((scounter + 1))
  done
  echo -n "Select server: $(tput bold)"
  read server_name
  if [ -z $server_name ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  printf "$(tput sgr0)"

  # If the input is a number
  if [[ "$server_name" =~ ^[0-9]+$ ]]; then
    for server in "${!SSH_CONFIGS[@]}"; do
      if [ $stcounter -eq $server_name ]; then server_name=$server && break; fi
      stcounter=$((stcounter + 1))
    done
  fi

  isSendDir=0 # 0 == false
  dirText="error"
  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    echo "$(tput bold)$(tput setaf 1)Server Not found.$(tput sgr0)"
  else
# Get paths to the files/directories
    read -p "Path to the file to send: " fsend
    if [ ${fsend:0:1} == '~' ]; then
      fsend=$HOME${fsend:1}
    fi
    if [[ -d $fsend ]]; then
      # directory
      isSendDir=1
      dirText="directory"
    elif [[ -f $fsend ]]; then
      # file
      isSendDir=0
      dirText="file"
    else
      # invalid
      printf "$(tput sgr0)$(tput bold)$(tput setaf 1)The given PATH to file is INVALID!\n$(tput sgr0)"
      return 1
    fi
    read -p "Path to the location to receive: " freceive
    if [ -z $freceive ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
# Connecting to the server to send data
    temp_var=${SSH_CONFIGS[$server_name]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    printf "Connecting to $(tput bold)$(tput setaf 2)$cutservername$(tput sgr0)"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      printf " on port: $(tput bold)$(tput setaf 2)$serverport$(tput sgr0)"
    fi
    printf "\n"
    echo "Sending the $(tput bold)$(tput setaf 4)$fsend $dirText$(tput sgr0) to $(tput bold)$(tput setaf 4)$freceive$(tput sgr0)..."
    echo -n "Are you sure you want to continue to send? [Y/n]: $(tput bold)"
    read -n 1 confirm
    if [ -z $confirm ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && confirm="n"; fi
    printf "$(tput sgr0)\n"
    if [[ $confirm = [Yy] ]]; then
      if [ $isSendDir -eq 1 ]; then
        temp_var=${SSH_CONFIGS[$server_name]}
        cutservername=$(echo $temp_var | cut -d' ' -f 1)
        if [[ $temp_var = *"-p"* ]]; then 
          serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
          scp -P $serverport -r $fsend $cutservername:$freceive
        else
          scp -r $fsend ${SSH_CONFIGS[$server_name]}:$freceive
        fi
      else
        temp_var=${SSH_CONFIGS[$server_name]}
        cutservername=$(echo $temp_var | cut -d' ' -f 1)
        if [[ $temp_var = *"-p"* ]]; then 
          serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
          scp -P $serverport $fsend $cutservername:$freceive
        else
          scp $fsend ${SSH_CONFIGS[$server_name]}:$freceive
        fi
      fi
    else
      echo "$(tput bold)$(tput setaf 1)Cancel sending.$(tput sgr0)"
    fi
  fi
}

# Delete a server from config
delete_server() {
  echo "Available server(s):"
  for server in "${!SSH_CONFIGS[@]}"; do
    echo "$(tput bold)$(tput setaf 153)$server$(tput sgr0)"
  done
  echo -n "Select the server you want to delete: $(tput bold)"
  read server_name
  if [ -z $server_name ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  printf "$(tput sgr0)"
  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    echo "$(tput bold)$(tput setaf 1)Server not found.$(tput sgr0)"
  else
    unset SSH_CONFIGS[$server_name]
    echo "declare -A SSH_CONFIGS" > ~/.config/termssh-manager.conf
    for key in "${!SSH_CONFIGS[@]}"; do
      echo "SSH_CONFIGS[$key]='${SSH_CONFIGS[$key]}'" >> ~/.config/termssh-manager.conf
    done
    echo "$(tput bold)$(tput setaf 2)Server deleted successfully.$(tput sgr0)"
  fi
}

# Run LS command
list_folder () {
  if [ -f /bin/lsd ]; then
    doesLSD=1
  else
    doesLSD=0
  fi
  if [ -f /bin/exa ]; then
    doesEXA=1
  else
    doesEXA=0
  fi

  read -p "$(tput sgr0)Select a folder: $(tput bold)" listfolder
  if [ ${listfolder:0:1} == '~' ]; then
    listfolder=$HOME${listfolder:1}
  fi
  if [ -z $listfolder ]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Field cannot be empty!\n$(tput sgr0)" && return 1; fi
  if ! [[ -d $listfolder ]]; then printf "$(tput sgr0)$(tput bold)$(tput setaf 1)Not valid directory!\n$(tput sgr0)" && return 1; fi

  if [ $doesEXA -eq 1 ]; then
    if [ $doesLSD -eq 1 ]; then
      read -p "$(tput sgr0)What program would you like to use (LSD/EXA): $(tput bold)" lister
      if [[ $lister == [Ee] || $lister == [Ee][Xx][Aa] ]]; then
        exa -la $listfolder
        return 0
      fi
      if [[ $lister == [Ll] || $lister == [Ll][Ss][Dd] ]]; then
        lsd -lA $listfolder
        return 0
      fi
      ls -la $listfolder
      return 0
    else
      exa -la $listfolder
      return 0
    fi
    if [ $doesLSD -eq 1 ]; then
      lsd -lA $listfolder
      return 0
    fi
    ls -la $listfolder
  fi
}

# Menu
while true; do
  echo ".-----------------------------------o"
  echo "| Select an option:                 |"
  echo "| 1/N. Setting SSH configuration    |"
  echo "| 2/V. Show SSH configuration       |"
  echo "| 3/S. Connect to SSH               |"
  echo "| 4/D. Delete server                |"
  echo "| 5/F. Send data via SCP            |"
  echo "| 6/Q. Exit                         |"
  echo "| 0/C. Clear the screan             |"
  echo "| Enter choice (1/2/3/4/5/6/0):     |"
  echo "*-----------------------------------o"
  printf "$(tput bold)"
  read -n 1 -p "`tput cuu 2``tput cuf 32`" choice
  printf "$(tput sgr0)"
  echo;echo "`tput ll`"
  case $choice in
    1) configure_ssh;;
    [Nn]) configure_ssh;;
    2) show_config;;
    [Vv]) show_config;;
    3) connect_ssh;;
    [Ss]) connect_ssh;;
    4) delete_server;;
    [Dd]) delete_server;;
    5) fileshare_scp;;
    [Ff]) fileshare_scp;;
    6) printf "$(tput bold)$(tput setaf 2)Closing SSH Manager...$(tput sgr0)\n" && break;;
    [Qq]) printf "$(tput bold)$(tput setaf 2)Closing SSH Manager...$(tput sgr0)\n" && break;;
    0) printf '\033[2J\033[3J\033[1;1H';; # Clear screen
    [Cc]) printf '\033[2J\033[3J\033[1;1H';; # Clear screen
    [Hh]) helptext;;
    [Ll]) list_folder;;
  esac
done
