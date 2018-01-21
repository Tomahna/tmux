#!/bin/sh
export LC_ALL=en_US.UTF8

## Git
_git_branch() {
    branch=$(git -C $1 rev-parse --abbrev-ref HEAD)

    if [ $? -ne 0 ]; then
        exit 0
    fi
    if [ $branch != "HEAD" ]; then
        echo "  $branch"
        exit 0
    fi
    
    tag=$(git -C $1 describe --exact-match --tags)
    if [ $? -eq 0 ]; then
        echo "  $tag"
        exit 0
    fi

    rev=$(git -C $1 rev-parse --short HEAD)
    if [ $? -eq 0 ]; then
        echo "  $rev"
        exit 0
    fi
}

_git_dirty() {
    status=$(git -C $1 status --porcelain 2> /dev/null)
    if [[ "$status" != "" ]]; then
        echo '*'
    fi
}

_git_stash() {
    if [ -e "$1/.git/refs/stash" ]; then    
        echo "($(git -C $1 stash list | wc -l))"
    fi
}

_git_segment() {
    local current_path=$(tmux display-message -p -F "#{pane_current_path}")
    local branch=$(_git_branch $current_path)
    local dirty=$(_git_dirty $current_path)
    local stash=$(_git_stash $current_path)
    echo "#[fg=colour250,bg=colour236,nobold,noitalics,nounderscore]$branch$dirty $stash"
}

## Identity 
_local_user() {
    tty=$1
    hostname=$(hostname -s)
    username=$(ps -t "$tty" -o user= -o pid= -o ppid= -o command= | awk '
           !/ssh/ { user[$2] = $1; ppid[$3] = 1 }
           END {
             for (i in user)
               if (!(i in ppid))
               {
                 print user[i]
                 exit
               }
           }')
    echo "$username@$hostname"
}

_ssh_user() {
    tty=$1
    ssh_parameters=$(ps -t "$tty" -o command= | awk '/ssh/ && !/vagrant ssh/ && !/autossh/ && !/-W/ { $1=""; print $0; exit }')
    if [ -n "$ssh_parameters" ]; then
        ssh_config=$(ssh -G $ssh_parameters 2>/dev/null)
        username=$(echo $ssh_config | awk 'NR > 2 { exit } ; /^user / { print $2 }')
        hostname=$(echo $ssh_config | awk 'NR > 2 { exit } ; /^hostname / { print $2 }')
        [ -z "$username" ] && username=$(ssh -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%username%% %r >&2'" $ssh_parameters 2>&1 | awk '/^%username% / { print $2; exit }')
        [ -z "$hostname" ] && hostname=$(ssh -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%hostname%% %h >&2'" $ssh_parameters 2>&1 | awk '/^%hostname% / { print $2; exit }')
    fi

    [ -z != $username ] && [ -z != $hostname ] && echo "$username@$hostname"
}

_user_segment() {
    tty=${1:-$(tmux display -p '#{pane_tty}')}
    local user=$(_ssh_user $tty)
    [ -s $user ] && user=$(_local_user $tty)
    echo "#[fg=colour16,bg=colour252,bold,noitalics,nounderscore]  $user"
}

## System
_system_gradient() {
    if [ $1 -le 50 ]; then
      echo "colour2"; exit 0
    elif [ $1 -le 80 ]; then
      echo "colour3"; exit 0
    else
      echo "colour1"; exit 0
    fi
}

_system_cpu_usage() {
    local cpu_usage=$(top -bn 2 -d 0.1 | grep 'Cpu(s)' | tail -n 1 | awk '{print $2+$4+$6}')
    printf "%.f" $cpu_usage
}

_system_ram_usage() {
    local mem_usage=$(free | head -2 | tail -1 | awk '{print ($3*100/$2)}')
    printf "%.f" $mem_usage
}

_system_cpu_segment(){
    local cpu=$(_system_cpu_usage)
    local colour=$(_system_gradient $cpu)
    echo "#[fg=$colour,bg=colour233] CPU $cpu%"
}

_system_ram_segment() {
    local ram=$(_system_ram_usage)
    local colour=$(_system_gradient $ram)
    echo "#[fg=$colour,bg=colour233] RAM $ram%"
}

_system_segment(){
    echo "$(_system_cpu_segment) $(_system_ram_segment)"
}

case $1 in 
    INIT_WINDOW) _init_window;;
    GIT_SEGMENT) _git_segment;;
    USER_SEGMENT) _user_segment;;
    SYSTEM_SEGMENT) _system_segment;;
    *) echo "undefined";;
esac

unset LC_ALL

