#!/bin/sh
export LC_ALL=en_US.UTF8

# Tmux Helper functions
_current_path() {
    tmux display-message -p -F "#{pane_current_path}"
}

## Git Helper functions
_git_branch() {
    CURRENT_PATH="$(_current_path)"
    BRANCH=$(git -C $CURRENT_PATH rev-parse --abbrev-ref HEAD)

    if [ $? -ne 0 ]; then
        exit 0
    fi
    if [ $BRANCH != "HEAD" ]; then
        echo "  $BRANCH"
        exit 0
    fi
    
    TAG=$(git -C $CURRENT_PATH describe --exact-match --tags)
    if [ $? -eq 0 ]; then
        echo "  $TAG"
        exit 0
    fi

    REV=$(git -C $CURRENT_PATH rev-parse --short HEAD)
    if [ $? -eq 0 ]; then
        echo "  $REV"
        exit 0
    fi
}

_git_dirty() {
    CURRENT_PATH="$(_current_path)"
    STATUS=$(git -C $CURRENT_PATH status --porcelain 2> /dev/null)
    if [[ "$status" != "" ]]; then
        echo '*'
    fi
}

_git_stash() {
    CURRENT_PATH="$(_current_path)"
    if [ -e "$CURRENT_PATH/.git/refs/stash" ]; then    
        echo "($(git -C $CURRENT_PATH stash list | wc -l))"
    fi
}

## Username and Hostname 
# From https://github.com/gpakosz/.tmux/blob/master/.tmux.conf 
_hostname() {
    tty=${1:-$(tmux display -p '#{pane_tty}')}
    ssh_only=$2
    # shellcheck disable=SC2039
    if [ x"$OSTYPE" = x"cygwin" ]; then
        pid=$(ps -a | awk -v tty="${tty##/dev/}" '$5 == tty && /ssh/ && !/vagrant ssh/ && !/autossh/ && !/-W/ { print $1 }')
        [ -n "$pid" ] && ssh_parameters=$(tr '\0' ' ' < "/proc/$pid/cmdline" | sed 's/^ssh //')
    else
        ssh_parameters=$(ps -t "$tty" -o command= | awk '/ssh/ && !/vagrant ssh/ && !/autossh/ && !/-W/ { $1=""; print $0; exit }')
    fi
    if [ -n "$ssh_parameters" ]; then
        # shellcheck disable=SC2086
        hostname=$(ssh -G $ssh_parameters 2>/dev/null | awk 'NR > 2 { exit } ; /^hostname / { print $2 }')
        # shellcheck disable=SC2086
        [ -z "$hostname" ] && hostname=$(ssh -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%hostname%% %h >&2'" $ssh_parameters 2>&1 | awk '/^%hostname% / { print $2; exit }')
        #shellcheck disable=SC1004
        hostname=$(echo "$hostname" | awk '\
        { \
        if ($1~/^[0-9.:]+$/) \
          print $1; \
        else \
          split($1, a, ".") ; print a[1] \
        }')
    else
        #if ! _is_enabled "$ssh_only"; then
        hostname=$(command hostname -s)
        #fi
    fi

    echo "$hostname"
}

_username() {
    tty=${1:-$(tmux display -p '#{pane_tty}')}
    ssh_only=$2
    # shellcheck disable=SC2039
    if [ x"$OSTYPE" = x"cygwin" ]; then
        pid=$(ps -a | awk -v tty="${tty##/dev/}" '$5 == tty && /ssh/ && !/vagrant ssh/ && !/autossh/ && !/-W/ { print $1 }')
        [ -n "$pid" ] && ssh_parameters=$(tr '\0' ' ' < "/proc/$pid/cmdline" | sed 's/^ssh //')
    else
        ssh_parameters=$(ps -t "$tty" -o command= | awk '/ssh/ && !/vagrant ssh/ && !/autossh/ && !/-W/ { $1=""; print $0; exit }')
    fi
    if [ -n "$ssh_parameters" ]; then
        # shellcheck disable=SC2086
        username=$(ssh -G $ssh_parameters 2>/dev/null | awk 'NR > 2 { exit } ; /^user / { print $2 }')
        # shellcheck disable=SC2086
        [ -z "$username" ] && username=$(ssh -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%username%% %r >&2'" $ssh_parameters 2>&1 | awk '/^%username% / { print $2; exit }')
    else
        if ! _is_enabled "$ssh_only"; then
            # shellcheck disable=SC2039
            if [ x"$OSTYPE" = x"cygwin" ]; then
                username=$(whoami)
            else
                username=$(ps -t "$tty" -o user= -o pid= -o ppid= -o command= | awk '
           !/ssh/ { user[$2] = $1; ppid[$3] = 1 }
           END {
             for (i in user)
               if (!(i in ppid))
               {
                 print user[i]
                 exit
               }
           }
              ')
            fi
        fi
    fi

    echo "$username"
}

## System Helper functions
_system_cpu_usage() {
    local CPU_USAGE=$(top -bn 2 -d 0.1 | grep 'Cpu(s)' | tail -n 1 | awk '{print $2+$4+$6}')
    printf "%.f" $CPU_USAGE
}

_system_ram_usage() {
    local MEM_USAGE=$(free | head -2 | tail -1 | awk '{print ($3*100/$2)}')
    printf "%.f" $MEM_USAGE
}

case $1 in 
    GIT_BRANCH) _git_branch;;
    GIT_DIRTY) _git_dirty;;
    GIT_STASH) _git_stash;;
    HOSTNAME) _hostname;;
    SYS_CPU) _system_cpu_usage;;
    SYS_RAM) _system_ram_usage;;
    USERNAME) _username;;
    *) echo "undefined";;
esac

unset LC_ALL

