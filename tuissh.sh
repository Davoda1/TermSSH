#!/bin/bash

# Use this to show help information on how to use the script.
helptext () {
  dialog --backtitle "TUI SSH Manager" --title "HELP" --msgbox " - The MENU has options from 0 to 6 and the letters.\n - The options are:\n - 1/n) Adding new SSH server.\n - 2/v) Show all saved server(s).\n - 3/s) Connect to SSH server.\n - 4/d) Delete server.\n - 5/f) Send data via SCP.\n - 6/q) Exit from program.\n - 0/c) Clear the screen.\n - h)   Show this help text.\n - l)   Show directory contents." 30 30
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
  server_name=""
  SSH_HOST=""
  SSH_PORT=" "
  SSH_USER=""
  IFS=$'\n' read -r -d '' server_name SSH_HOST SSH_PORT SSH_USER < <(dialog --ok-label "Submit" --backtitle "TUI SSH Manager" --title "Configure SSH Server" --form "\nAdd new server:" 25 60 16 "Server name:" 1 1 "$server_name" 1 25 25 30 "Host/IP addreas:" 2 1 "$SSH_HOST" 2 25 25 30 "Port (optional):" 3 1 "$SSH_PORT" 3 25 25 30 "Username:" 4 1 "$SSH_USER" 4 25 25 30 3>&1 1>&2 2>&3 3>&-)
if [ -z "$server_name$SSH_HOST$SSH_USER" ]; then return 0; fi
if [[ "$SSH_PORT" == " " ]]; then SSH_PORT=""; fi

  if [ -z $server_name ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Server name cannot be empty!" 6 35 && return 1; fi
  # If the server's name exists abort
  for server in "${!SSH_CONFIGS[@]}"; do
    if [[ $server_name = $server ]]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "This name already in existance, \nuse an other one or \ndelete the existing one!" 6 35 && return 1; fi
  done
  if [ -z $SSH_HOST ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Host/IP cannot be empty!" 6 35 && return 1; fi

  if [ -z $SSH_USER ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Username cannot be empty!" 6 35 && return 1; fi

  if [ -z "$SSH_PORT" ];then
    SSH_CONFIGS[$server_name]="$SSH_USER@$SSH_HOST"
  else
    SSH_CONFIGS[$server_name]="$SSH_USER@$SSH_HOST -p $SSH_PORT"
  fi
  echo "declare -A SSH_CONFIGS" > ~/.config/termssh-manager.conf
  for key in "${!SSH_CONFIGS[@]}"; do
    echo "SSH_CONFIGS[$key]='${SSH_CONFIGS[$key]}'" >> ~/.config/termssh-manager.conf
  done
  dialog --backtitle "TUI SSH Manager" --title "Server added" --msgbox "Config saved!" 5 35
}

# Show the contents of the config file
show_config() {
  showbox=""
  scounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done

  showbox="List SSH config:\n"
  for server in "${!SSH_CONFIGS[@]}"; do
    showbox=$showbox"Server: $server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq "0" ]; do
      showbox=$showbox" "
      let COUNTER-=1
    done
    showbox=$showbox"  ($scounter)\n"
    scounter=$((scounter + 1))
    temp_var=${SSH_CONFIGS[$server]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    showbox=$showbox"Config: $cutservername\n"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      showbox=$showbox" on port: $serverport"
    fi
    showbox=$showbox"\n"
  done
  showbox=$showbox"End of list.\n"
  dialog --backtitle "TUI SSH Manager" --title "Saved server(s)" --msgbox "$showbox" 18 55
}

# Connect to server via SSH
connect_ssh() {
  connectbox=""
  scounter=0
  stcounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done
  for server in "${!SSH_CONFIGS[@]}"; do
    connectbox="$connectbox$server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq 0 ]; do
      connectbox=$connectbox" "
      let COUNTER-=1
    done
    connectbox=$connectbox" --- ($scounter)\n"
    scounter=$((scounter + 1))
  done

  server_name=$(dialog --backtitle "TUI SSH Manager" --title "Connect to server via SSH" --inputbox "Available server(s):\n$connectbox\n\nSelect server:" 18 55 3>&1 1>&2 2>&3 3>&-)
  if [ $? -eq 1 ]; then return 0; fi
  if [ -z $server_name ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Field cannot be empty!" 6 35 && return 1; fi

  # If the input is a number
  if [[ "$server_name" =~ ^[0-9]+$ ]]; then
    for server in "${!SSH_CONFIGS[@]}"; do
      if [ $stcounter -eq $server_name ]; then server_name=$server && break; fi
      stcounter=$((stcounter + 1))
    done
  fi

  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Server Not found." 6 35
  else
    temp_var=${SSH_CONFIGS[$server_name]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    connectbox="Connecting to $cutservername"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      connectbox=$connectbox" on port: $serverport"
    fi
    connectbox=$connectbox"...\n"
    connectbox=$connectbox"Are you sure you want to connect?"
    dialog --backtitle "TUI SSH Manager" --title "Connecting..." --yesno "$connectbox" 8 55
    confirm=$?
    if [[ $confirm -eq 0 ]]; then
      printf '\033[2J\033[3J\033[1;1H'
      ssh ${SSH_CONFIGS[$server_name]}
    fi
  fi
}

# Send file to server via SCP
fileshare_scp() {
  scpbox=""
  isSendDir=0 # 0 == false

  # dialog --backtitle "TUI SSH Manager" --title "SCP Fileshare" --yesno "Do you want to send a file?" 6 35
  # isSendDir=$?

  scounter=0
  stcounter=0
  maxname_len=0
  for server in "${!SSH_CONFIGS[@]}"; do
    if [ $maxname_len -lt ${#server} ]; then maxname_len=${#server}; fi
  done
  for server in "${!SSH_CONFIGS[@]}"; do
    scpbox=$scpbox"$server"
    COUNTER=$((maxname_len - ${#server}))
    until [ $COUNTER -eq 0 ]; do
      scpbox=$scpbox" "
      let COUNTER-=1
    done
    scpbox=$scpbox" --- ($scounter)\n"
    scounter=$((scounter + 1))
  done # Available server(s) for SCP:
  server_name=$(dialog --backtitle "TUI SSH Manager" --title "SCP Fileshare" --inputbox "Select server:\n$scpbox" 18 55 3>&1 1>&2 2>&3 3>&-)
  if [ $? -eq 1 ]; then return 0; fi
  if [ -z $server_name ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Field cannot be empty!" 6 35 && return 1; fi
  

  # If the input is a number
  if [[ "$server_name" =~ ^[0-9]+$ ]]; then
    for server in "${!SSH_CONFIGS[@]}"; do
      if [ $stcounter -eq $server_name ]; then server_name=$server && break; fi
      stcounter=$((stcounter + 1))
    done
  fi

  dirText="error"
  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Server Not found." 6 35
  else
# Get paths to the files/directories
    fsend=$(dialog --backtitle "TUI SSH Manager" --stdout --title "Please choose a file or directory" --fselect $HOME/ 12 60)
    if [ $? -eq 1 ]; then return 0; fi
    if [ ${fsend:0:1} == '~' ]; then # not needed for TUI
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
      dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "The given PATH to file is INVALID!" 6 35
      return 1
    fi
    freceive=$(dialog --backtitle "TUI SSH Manager" --title "Path to the location to receive" --inputbox "Sending $fsend [$dirText] to:" 7 55 3>&1 1>&2 2>&3 3>&-)
    if [ $? -eq 1 ]; then return 0; fi
    if [ -z $freceive ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Field cannot be empty!" 6 35 && return 1; fi
# Connecting to the server to send data
    temp_var=${SSH_CONFIGS[$server_name]}
    scpbox=""
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    scpbox=$scpbox"Connecting to $cutservername"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      scpbox=$scpbox" on port: [$serverport]"
    fi
    scpbox=$scpbox"\n"
    scpbox=$scpbox"Sending the $fsend [$dirText] \n        to $freceive\n"
    scpbox=$scpbox"Are you sure you want to continue to send?"
    dialog --backtitle "TUI SSH Manager" --title "SCP Fileshare" --yesno "$scpbox" 8 55 3>&1 1>&2 2>&3 3>&-
    confirm=$?
    if [ -z $confirm ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Field cannot be empty!" 6 35 && confirm="n"; fi

    if [ $confirm -eq 0 ]; then
      if [ $isSendDir -eq 1 ]; then
        temp_var=${SSH_CONFIGS[$server_name]}
        cutservername=$(echo $temp_var | cut -d' ' -f 1)
        if [[ $temp_var = *"-p"* ]]; then 
          serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
          printf '\033[2J\033[3J\033[1;1H'
          scp -P $serverport -r $fsend $cutservername:$freceive
          sleep 2
          printf '\033[2J\033[3J\033[1;1H'
        else
          printf '\033[2J\033[3J\033[1;1H'
          scp -r $fsend ${SSH_CONFIGS[$server_name]}:$freceive
          sleep 2
          printf '\033[2J\033[3J\033[1;1H'
        fi
      else
        temp_var=${SSH_CONFIGS[$server_name]}
        cutservername=$(echo $temp_var | cut -d' ' -f 1)
        if [[ $temp_var = *"-p"* ]]; then 
          serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
          printf '\033[2J\033[3J\033[1;1H'
          scp -P $serverport $fsend $cutservername:$freceive
          sleep 2
          printf '\033[2J\033[3J\033[1;1H'
        else
          printf '\033[2J\033[3J\033[1;1H'
          scp $fsend ${SSH_CONFIGS[$server_name]}:$freceive
          sleep 2
          printf '\033[2J\033[3J\033[1;1H'
        fi
      fi
    else
      dialog --backtitle "TUI SSH Manager" --title "SCP Fileshare" --msgbox "Cancel sending." 6 35
    fi
  fi
}

# Delete a server from config
delete_server() {
  rmbox=""
  dans=""
  for server in "${!SSH_CONFIGS[@]}"; do
    rmbox="$rmbox\n$server"
  done
  server_name=$(dialog --backtitle "TUI SSH Manager" --title "Select the server you want to delete" --inputbox "Available server(s):\n$rmbox\n\nSelect server:" 15 55 3>&1 1>&2 2>&3 3>&-)
  if [ $? -eq 1 ]; then return 0; fi
  if [ -z $server_name ]; then dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Field cannot be empty!" 6 35 && return 1; fi

  if [[ ! ${SSH_CONFIGS[$server_name]+_} ]]; then
    dialog --backtitle "TUI SSH Manager" --title "ERROR" --msgbox "Server not found." 6 35
  else
    temp_var=${SSH_CONFIGS[$server_name]}
    cutservername=$(echo $temp_var | cut -d' ' -f 1)
    confirmbox="Are you sure you want to delete\n$cutservername"
    if [[ $temp_var = *"-p"* ]]; then 
      serverport=$(echo "${temp_var/-p/"&"}" | cut -d'&' -f 2);
      confirmbox=$confirmbox" port: [$serverport]"
    fi
    confirmbox=$confirmbox"?"
    dialog --backtitle "TUI SSH Manager" --title "Deleting server" --yesno "$confirmbox" 7 55
    if [ $? -eq 0 ];then
      dans="yes"
    else
      dans="no"
    fi
    if [[ $dans = [Yy] || $dans = [Yy][Ee][Ss] ]]; then
      unset SSH_CONFIGS[$server_name]
      echo "declare -A SSH_CONFIGS" > ~/.config/termssh-manager.conf
      for key in "${!SSH_CONFIGS[@]}"; do
        echo "SSH_CONFIGS[$key]='${SSH_CONFIGS[$key]}'" >> ~/.config/termssh-manager.conf
      done
      dialog --backtitle "TUI SSH Manager" --title "Deleting server" --msgbox "Server deleted successfully." 6 35
    else
      if [[ $dans = [Nn] || $dans = [Nn][Oo] ]]; then
        dialog --backtitle "TUI SSH Manager" --title "Deleting server" --msgbox "Canceling server deletion." 6 35
      else
        dialog --backtitle "TUI SSH Manager" --title "Deleting server" --msgbox "Server has not been removed." 6 35
      fi
    fi
  fi
}

# Menu
while true; do
  MENUVAR=$(dialog --backtitle "TUI SSH Manager" --title "MENU" --menu "Select an option:" 7 32 0 1 "Setting SSH configuration" \
  2 "Show SSH configuration" 3 "Connect to SSH" 4 "Delete server" 5 "Send data via SCP" 6 "Exit" 3>&1 1>&2 2>&3 3>&-)
  if [ $? -eq 1 ]; then MENUVAR=6; fi ## Cancel will exit
  printf '\033[2J\033[3J\033[1;1H'
  case $MENUVAR in
    1) configure_ssh;; #OK
    2) show_config;;   #OK
    3) connect_ssh;;   #OK
    4) delete_server;; #OK
    5) fileshare_scp;;
    6) printf "$(tput bold)$(tput setaf 2)Closing SSH Manager...$(tput sgr0)\n" && break;;
  esac
done
