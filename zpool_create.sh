#!/bin/bash

# Function Declaration

function new_line {
  sed -e 's/\ /\
/g'
}

function splitify {
  sed -e 's/-/\ /g'
}

function disk_size {
  echo "$2" | grep $1 | grep -v "${1}[0-9]" | awk '{printf $3 $4}' | sed -e 's/\,//g'
}

function whiptailify {
  awk '{printf "%s %s off ", $1, $2}'
}

function nqecho {
  echo $@ | sed -e 's/\"//g'
}
function pause {
  read -p "Press [Enter] key to return..."
}

# Script

if [[ "$EUID" != "0" ]];then
  echo "Script must be run as root."
  exit 1
fi

echo "ZPOOL Creation Tool"
echo -n "ZPOOL Name:"
read zname
fdisk_array=`fdisk -l 2>/dev/null`
array_line=""
while [[ ("${next}" != "cancel") && ("${next}" != "finish") ]]; do
next=$(whiptail --nocancel --radiolist "Add Disk Group" 15 44 10 raidz "RAID-Z Single Parity" on raidz2 "RAID-Z2 Double Parity" off mirror "Mirror" off l2arc "Read Cache" off zil "Write Cache" off check "Check pending changes" off cancel "Exit without creation" off finish "Create and Exit" off 3>&1 1>&2 2>&3)
_list=`ls /dev/sd* | grep -v [0-9]`
for disk in ${disk_array[*]}; do
  _list=$(echo $_list | new_line | grep -v $disk)
done
unset list
for item in ${_list}; do
  list+="${item}-$(disk_size $item "$fdisk_array") "
done
_list=$list
case $next in
  raidz*)
    disks=$(whiptail --checklist "Add Disks" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    unset _disks
    for _disk in $(nqecho $disks); do
      _disks+=("$_disk")
    done
    if [[ (("$next" == "raidz") && ("${#_disks[*]}" -ge "3")) || (("$next" == "raidz2") && ("${#_disks[*]}" -ge 4)) ]]; then 
      [[ "$disks" != "" ]] && array_line="$array_line $next $(nqecho $disks)"
      [[ "$disks" != "" ]] && for disk in $(nqecho $disks); do
        disk_array+=("$disk")
      done
    else
      if [[ "${#_disks[*]}" != "0" ]];then 
        echo "No enough disks were selected for a $next disk group"
        pause
      fi
    fi
    ;;
  mirror*)
    disk1=$(whiptail --radiolist "Add Primary" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    [[ "$disk1" != "" ]] && disk2=$(whiptail --radiolist "Add Secondary" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    [[ "$disk1" != "" ]] && [[ "$disk2" != "" ]] && array_line="$array_line $next $(nqecho $disk1) $(nqecho $disk2)"
    [[ "$disk1" != "" ]] && [[ "$disk2" != "" ]] && disk_array+=("$disk1") && disk_array+=("$disk2")
    ;;
  l2arc)
    disks=$(whiptail --checklist "Add Cache Disks" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    [[ "$disks" != "" ]] && array_line="$array_line $next $(nqecho $disks)"
    [[ "$disks" != "" ]] && for disk in $(nqecho disks); do
      disk_array+=("$disk")
    done
    ;;
  zil)
    disk1=$(whiptail --radiolist "Add ZIL Mirror Disk 1" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    [[ "$disk1" != "" ]] && disk2=$(whiptail --radiolist "Add ZIL Mirror Disk 2" 16 32 8 `echo $_list | new_line | splitify | whiptailify` 3>&1 1>&2 2>&3)
    [[ "$disk1" != "" ]] && [[ "$disk2" != "" ]] && array_line="$array_line log mirror $(nqecho $disk1) $(nqecho $disk2)"
    [[ "$disk1" != "" ]] && [[ "$disk2" != "" ]] && disk_array+=("$disk1") && disk_array+=("$disk2")
    ;;
  check)
    echo "zpool create -f $zname $array_line"
    pause
    ;;
  cancel)
    echo "ZPOOL Creation has been cancelled"
    exit 1
    ;;
  finish) 
    echo "Creating ZPOOL with $array_line"
    zpool create -f $zname $array_line
    ;;
esac
done
