#!/bin/bash

# elastos-node - hardened fork of elastos/Elastos.Node
ELASTOS_NODE_VERSION="1.1.0"

# Reset override flags so a value inherited from the environment cannot silently enable them.
FORCE_ELA=

#
# utility
#
echo_warn()
{
    if [ -t 1 ]; then
        echo -e "\033[1;33mWARNING:\033[0m $1" 1>&2
    else
        echo "WARNING: $1" 1>&2
    fi
}

echo_error()
{
    if [ -t 1 ]; then
        echo -e "\033[1;31mERROR:\033[0m $1" 1>&2
    else
        echo "ERROR: $1" 1>&2
    fi
}

echo_info()
{
    if [ -t 1 ]; then
        echo -e "\033[1;34mINFO:\033[0m $1"
    else
        echo "INFO: $1"
    fi
}

echo_ok()
{
    if [ -t 1 ]; then
        echo -e "\033[1;32mOK:\033[0m $1"
    else
        echo "OK: $1"
    fi
}

#
# UI: color + status glyphs, honoring NO_COLOR, --no-color, and non-TTY output.
#
UI_DOT_OK=$'\xe2\x97\x8f'      # filled circle  (running / healthy)
UI_DOT_OFF=$'\xe2\x97\x8b'     # empty circle   (stopped)
UI_DOT_WARN=$'\xe2\x97\x90'    # half circle    (attention)

ui_use_color()
{
    [ -n "$NO_COLOR" ]    && return 1
    [ -n "$UI_NO_COLOR" ] && return 1
    [ -t 1 ]              || return 1
    return 0
}
ui_c()  { if ui_use_color; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
ui_green()  { ui_c '1;32' "$1"; }
ui_yellow() { ui_c '1;33' "$1"; }
ui_red()    { ui_c '1;31' "$1"; }
ui_dim()    { ui_c '2'    "$1"; }
ui_bold()   { ui_c '1'    "$1"; }

# chain_running <chain>: true if the chain's process is alive (no RPC, cannot hang).
chain_running()
{
    case "$1" in
        ela)        pgrep -x ela     >/dev/null 2>&1 ;;
        arbiter)    pgrep -x arbiter >/dev/null 2>&1 ;;
        esc|eco|pgp|pg|eid)
                    pgrep -f "^\./$1 .*--rpc " >/dev/null 2>&1 ;;
        esc-oracle) pgrep -fx 'node crosschain_oracle.js' >/dev/null 2>&1 ;;
        eid-oracle) pgrep -fx 'node crosschain_eid.js'    >/dev/null 2>&1 ;;
        eco-oracle) pgrep -fx 'node crosschain_eco.js'    >/dev/null 2>&1 ;;
        pgp-oracle) pgrep -fx 'node crosschain_pgp.js'    >/dev/null 2>&1 ;;
        pg-oracle)  pgrep -fx 'node crosschain_pg.js'     >/dev/null 2>&1 ;;
        *)          return 1 ;;
    esac
}

# EVM_CHAINS: the geth-based side chains (single source of truth).
EVM_CHAINS="esc eco pgp pg eid"

# is_evm_chain <chain>: true if <chain> is one of the EVM side chains.
is_evm_chain() { case " $EVM_CHAINS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# evm_rpc_bind: the address EVM chains bind RPC/WS to. Defaults to 127.0.0.1 (localhost
# only). Override with the EVM_RPC_BIND env var (this session) or a persistent
# ~/.config/elastos/evm_rpc_bind file. An invalid value falls back to 127.0.0.1
# (fail-closed - a typo must never bind somewhere unintended).
evm_rpc_bind()
{
    local b=$EVM_RPC_BIND
    [ -z "$b" ] && [ -r ~/.config/elastos/evm_rpc_bind ] && b=$(tr -d '[:space:]' < ~/.config/elastos/evm_rpc_bind 2>/dev/null)
    [ -z "$b" ] && b=127.0.0.1
    echo "$b" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || b=127.0.0.1
    echo "$b"
}

# did_you_mean <input> <valid words...>: print a suggestion for a near miss.
did_you_mean()
{
    local input=$1; shift
    local best= cand
    for cand in $*; do case "$cand" in "$input"*) best=$cand; break ;; esac; done
    [ -z "$best" ] && for cand in $*; do case "$cand" in *"$input"*) best=$cand; break ;; esac; done
    [ -n "$best" ] && echo "  Did you mean '$best'?"
}

# verify_started <chain>: confirm the daemon is alive shortly after a start; if not,
# surface the failure + the tail of its most recent log, so a dead-on-launch daemon is
# reported immediately instead of inferred from a later "stopped" status.
verify_started()
{
    local chain=$1 log bind
    if chain_running "$chain"; then
        if is_evm_chain "$chain"; then
            bind=$(evm_rpc_bind)
            if [ "$bind" == "127.0.0.1" ]; then
                ui_dim "  $chain RPC/WS bound to 127.0.0.1 (localhost only; upstream was public 0.0.0.0). Remote access: SSH tunnel / reverse proxy."
            else
                echo_warn "$chain RPC/WS bound to $bind (PUBLIC - reachable off-box). Firewall it; persist via ~/.config/elastos/evm_rpc_bind, or set 127.0.0.1 to revert."
            fi
        fi
        return 0
    fi
    echo_error "$chain failed to start (not running after launch)"
    log=$(ls -t "$SCRIPT_PATH/$chain/logs/"*.log "$SCRIPT_PATH/$chain/elastos/logs/node/"*.log 2>/dev/null | head -1)
    if [ -n "$log" ]; then
        echo "  last lines of $(basename "$log"):"
        tail -n 6 "$log" 2>/dev/null | sed 's/^/    /'
    fi
    return 1
}

# --- health data substrate (timeout-bounded; never hangs; error != 0) ---

evm_port() { case "$1" in esc) echo 20636;; eco) echo 20656;; pgp) echo 20666;; pg) echo 20676;; eid) echo 20646;; *) return 1;; esac; }

# evm_rpc <chain> <method> [params-json] : raw JSON response (curl capped at 3s)
evm_rpc()
{
    local port; port=$(evm_port "$1") || return 1
    curl -s --max-time 3 -X POST -H 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"$2\",\"params\":${3:-[]},\"id\":1}" \
        "http://127.0.0.1:$port" 2>/dev/null
}

# hex_to_dec <0x..> : decimal, or empty. Avoids the $(( )) octal/zero trap.
hex_to_dec() { case "$1" in 0x*|0X*) echo $((16#${1#0[xX]})) ;; *) return 1 ;; esac; }

evm_height() { local r; r=$(evm_rpc "$1" eth_blockNumber | jq -r '.result // empty' 2>/dev/null); hex_to_dec "$r"; }
evm_peers()  { local r; r=$(evm_rpc "$1" net_peerCount  | jq -r '.result // empty' 2>/dev/null); hex_to_dec "$r"; }
evm_syncing()
{
    local r; r=$(evm_rpc "$1" eth_syncing | jq -r '.result' 2>/dev/null)
    [ -z "$r" ] && return 1
    if [ "$r" == "false" ]; then echo synced; else echo syncing; fi
}

ela_height() { local h; h=$(ela_client info getcurrentheight 2>/dev/null);   [[ "$h" =~ ^[0-9]+$ ]] && echo "$h" || return 1; }
ela_peers()  { local p; p=$(ela_client info getconnectioncount 2>/dev/null); [[ "$p" =~ ^[0-9]+$ ]] && echo "$p" || return 1; }

# unified per-chain probes (ela vs EVM); services (oracle/arbiter) have no height/peers
chain_height() { case "$1" in ela) ela_height ;; esc|eco|pgp|pg|eid) evm_height "$1" ;; *) return 1 ;; esac; }
chain_peers()  { case "$1" in ela) ela_peers  ;; esc|eco|pgp|pg|eid) evm_peers  "$1" ;; *) return 1 ;; esac; }
chain_synced() { case "$1" in ela) ela_synced 2>/dev/null && echo synced || echo syncing ;; esc|eco|pgp|pg|eid) evm_syncing "$1" ;; *) return 1 ;; esac; }

# evm_reward_status <chain> : cold | hot | unset  (hot = reward addr == local keystore acct)
evm_reward_status()
{
    local addr hot kf
    [ -f "$SCRIPT_PATH/$1/data/miner_address.txt" ] && addr=$(tr -d '[:space:]' < "$SCRIPT_PATH/$1/data/miner_address.txt" 2>/dev/null)
    echo "$addr" | grep -qiE '^0x[0-9a-f]{40}$' || { echo unset; return; }
    kf=$(ls "$SCRIPT_PATH/$1/data/keystore/"UTC* 2>/dev/null | head -1)
    [ -n "$kf" ] && hot=$(jq -r .address "$kf" 2>/dev/null)
    if [ -n "$hot" ] && [ "$(echo "${addr#0x}" | tr A-Z a-z)" == "$(echo "$hot" | tr A-Z a-z)" ]; then
        echo hot
    else
        echo cold
    fi
}

# render_health <chain>: print a one-line verdict; exit 0 healthy, 1 if attention needed.
# Designed for monitoring/cron: `node.sh esc health && ok || alert`.
render_health()
{
    local chain=$1 p sy
    "${chain}_installed" 2>/dev/null || { echo "$chain: not installed"; return 1; }
    chain_running "$chain"           || { echo "$chain: stopped";       return 1; }
    case "$chain" in
        *-oracle|arbiter) echo "$chain: running"; return 0 ;;
    esac
    sy=$(chain_synced "$chain" 2>/dev/null)
    p=$(chain_peers  "$chain" 2>/dev/null)
    if [ -z "$sy" ] || [ -z "$p" ]; then echo "$chain: running (rpc unreachable)"; return 1; fi
    [ "$sy" == "syncing" ]         && { echo "$chain: syncing";  return 1; }
    [ -n "$p" ] && [ "$p" == "0" ] && { echo "$chain: no peers"; return 1; }
    echo "$chain: healthy"; return 0
}

# render_health_all: health for every chain in the profile; exit non-zero if any unhealthy.
render_health_all()
{
    local chain rc=0
    for chain in $(profile_chains); do
        render_health "$chain" || rc=1
    done
    return $rc
}

# render_summary: one row per chain in the active profile (the fleet glance).
# chain_pid <chain>: the live PID (same detection as chain_running).
chain_pid()
{
    case "$1" in
        ela)        pgrep -x ela     2>/dev/null | head -1 ;;
        arbiter)    pgrep -x arbiter 2>/dev/null | head -1 ;;
        esc|eco|pgp|pg|eid) pgrep -f "^\./$1 .*--rpc " 2>/dev/null | head -1 ;;
        esc-oracle) pgrep -fx 'node crosschain_oracle.js' 2>/dev/null | head -1 ;;
        eid-oracle) pgrep -fx 'node crosschain_eid.js'    2>/dev/null | head -1 ;;
        eco-oracle) pgrep -fx 'node crosschain_eco.js'    2>/dev/null | head -1 ;;
        pgp-oracle) pgrep -fx 'node crosschain_pgp.js'    2>/dev/null | head -1 ;;
        pg-oracle)  pgrep -fx 'node crosschain_pg.js'     2>/dev/null | head -1 ;;
    esac
}

# render_status_one <chain>: the chain's own status block, with the noise fields
# (Balance / PID / #Files / #TCP / port lists) removed. Labeled + aligned, like the
# classic view the operator preferred - just without the clutter.
render_status_one()
{
    # the familiar upstream labeled block, verbatim - one aligned field per line
    "${1}_status"
}

# render_status_all: a card for every chain in the active profile.
render_status_all()
{
    # one classic labeled block per chain, a blank line between - no extra chrome
    local chain
    echo
    for chain in $(profile_chains); do "${chain}_status"; echo; done
    echo "  $(ui_dim "one-line glance: $SCRIPT_NAME summary")"
    echo
}

render_summary()
{
    local prof total=0 running=0 stopped=0 chain st glyph h p sy issues=
    prof=$(get_profile)
    echo
    printf '  %s   profile: %s\n' "$(ui_bold 'Elastos node')" "$prof"
    printf '  %-12s %-9s %-13s %-6s %s\n' 'CHAIN' 'STATE' 'HEIGHT' 'PEERS' 'HEALTH'
    printf '  %s\n' '-------------------------------------------------------'
    for chain in $(profile_chains); do
        total=$((total + 1)); h='-'; p='-'
        if ! "${chain}_installed" 2>/dev/null; then
            st='-'; glyph=$(ui_dim "$UI_DOT_OFF")
        elif chain_running "$chain"; then
            st='running'; glyph=$(ui_green "$UI_DOT_OK"); running=$((running + 1))
            h=$(chain_height "$chain" 2>/dev/null)
            p=$(chain_peers  "$chain" 2>/dev/null)
            case "$chain" in
                *-oracle|arbiter) [ -z "$h" ] && h='-'; [ -z "$p" ] && p='-' ;;
                *)                [ -z "$h" ] && h='?'; [ -z "$p" ] && p='?' ;;
            esac
            sy=$(chain_synced "$chain" 2>/dev/null)
            if [ "$sy" == "syncing" ]; then glyph=$(ui_yellow "$UI_DOT_WARN"); issues="$issues $chain(syncing)"; fi
            if [ -n "$p" ] && [ "$p" == "0" ]; then glyph=$(ui_red "$UI_DOT_WARN"); issues="$issues $chain(no-peers)"; fi
        else
            st='stopped'; glyph=$(ui_dim "$UI_DOT_OFF"); stopped=$((stopped + 1)); issues="$issues $chain(stopped)"
        fi
        printf '  %-12s %-9s %-13s %-6s %s\n' "$chain" "$st" "$h" "$p" "$glyph"
    done
    printf '  %s\n' '-------------------------------------------------------'
    echo "  $(ui_green "$UI_DOT_OK") healthy   $(ui_yellow "$UI_DOT_WARN") syncing/attention   $(ui_dim "$UI_DOT_OFF") stopped"
    if [ -z "$issues" ]; then
        echo "  $(ui_green '✓') $running/$total running, all healthy"
    else
        echo "  $(ui_yellow '⚠') attention:$issues"
    fi
    echo
}

# chain_health_json <chain> / render_json_one / render_json_all : machine-readable
chain_health_json()
{
    local chain=$1 inst=false run=false h='' p='' sy='' rw=''
    "${chain}_installed" 2>/dev/null && inst=true
    if [ "$inst" == true ] && chain_running "$chain"; then
        run=true
        h=$(chain_height "$chain" 2>/dev/null)
        p=$(chain_peers  "$chain" 2>/dev/null)
        sy=$(chain_synced "$chain" 2>/dev/null)
        case "$chain" in esc|eco|pgp|pg|eid) rw=$(evm_reward_status "$chain" 2>/dev/null) ;; esac
    fi
    jq -n --arg chain "$chain" --argjson installed "$inst" --argjson running "$run" \
          --arg height "$h" --arg peers "$p" --arg sync "$sy" --arg reward "$rw" \
        '{chain:$chain, installed:$installed, running:$running,
          height:(if $height=="" then null else ($height|tonumber) end),
          peers:(if $peers=="" then null else ($peers|tonumber) end),
          sync:(if $sync=="" then null else $sync end),
          reward:(if $reward=="" then null else $reward end)}'
}
render_json_one() { chain_health_json "$1"; }
render_json_all()
{
    local chain first=1
    printf '['
    for chain in $(profile_chains); do
        [ $first -eq 1 ] || printf ','
        first=0
        chain_health_json "$chain"
    done
    printf ']\n'
}

# noninteractive: true when stdin is not a terminal (cron / CI / pipe). Used to take a
# safe default instead of blocking on a read prompt.
noninteractive() { [ ! -t 0 ]; }

# profile_prompt_if_unset: ask main-chain-only vs full stack the first time.
profile_prompt_if_unset()
{
    [ -n "$PROFILE_OVERRIDE" ] && return 0
    [ -f "$PROFILE_FILE" ]     && return 0
    echo "What will this node run?"
    echo "  [1] Main chain only        (ELA)"
    echo "  [2] Full stack             (ELA + side chains + oracles + arbiter)"
    local sel
    read -p '? Your option: [2] ' sel || { sel=2; echo "  (no input - defaulting to full stack)"; }
    case "$sel" in
        1) set_profile mainchain >/dev/null ;;
        *) set_profile full      >/dev/null ;;
    esac
    echo
}

update_script()
{
    # The fork updates ITSELF (not upstream), so the hardening is never reverted.
    local SCRIPT_URL=https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh
    local SHA_URL=https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh.sha256

    local SCRIPT=$SCRIPT_PATH/$(basename $BASH_SOURCE)
    local SCRIPT_TMP=$SCRIPT.tmp

    echo "Downloading $SCRIPT_URL..."
    if ! curl -fsSL -o "$SCRIPT_TMP" "$SCRIPT_URL"; then
        echo_error "download failed"
        rm -f "$SCRIPT_TMP"
        return 1
    fi

    # Integrity: if a published checksum exists, the download MUST match it.
    local WANT=$(curl -fsSL "$SHA_URL" 2>/dev/null | awk '{print $1}')
    if [ -n "$WANT" ]; then
        local GOT=$(shasum -a 256 "$SCRIPT_TMP" 2>/dev/null | awk '{print $1}')
        if [ "$WANT" != "$GOT" ]; then
            echo_error "checksum mismatch - refusing to update (want $WANT, got $GOT)"
            rm -f "$SCRIPT_TMP"
            return 1
        fi
        echo_ok "checksum verified"
    else
        echo_warn "no published checksum found - updating without integrity check"
    fi

    # Never install a script that does not parse.
    if ! bash -n "$SCRIPT_TMP"; then
        echo_error "downloaded script failed syntax check - refusing to update"
        rm -f "$SCRIPT_TMP"
        return 1
    fi

    mv "$SCRIPT_TMP" "$SCRIPT"
    chmod a+x "$SCRIPT"
    echo_ok "$SCRIPT updated"
    echo
    # Re-exec the JUST-DOWNLOADED script's harden, not the old code still in memory, so
    # any newly-added ports are closed in the same step (bash never reloads a running file).
    "$SCRIPT" harden 2>/dev/null || harden_firewall
}
# has_cold_miner <chain>: true when the chain either does not mine or has a valid
# cold reward address set. Silent; used by warn_hot_miner and status displays.
has_cold_miner()
{
    local chain=$1
    is_evm_chain "$chain" || return 0   # only EVM side chains mine
    local pwfile=~/.config/elastos/${chain}.txt
    local addrfile=$SCRIPT_PATH/${chain}/data/miner_address.txt
    [ -f "$pwfile" ] || return 0   # not a mining node; nothing to check
    local addr=
    [ -f "$addrfile" ] && addr=$(tr -d '[:space:]' < "$addrfile" 2>/dev/null)
    echo "$addr" | grep -qiE '^0x[0-9a-f]{40}$'
}

# warn_hot_miner <chain>: a mining chain with no cold reward address still starts,
# but the operator is warned in red: rewards credit the node's LOCAL (hot) account.
warn_hot_miner()
{
    local chain=$1
    has_cold_miner "$chain" && return 0
    echo "$(ui_red "WARNING: $chain is mining WITHOUT a cold reward address.")"
    echo "$(ui_red "         Block rewards will credit this node's LOCAL (hot) account.")"
    echo "  Set one, then restart:  $SCRIPT_NAME reward set 0xYOURCOLDADDRESS"
    return 0
}

set_env()
{
    # ulimit open files: use system setting if it is greater
    if [ $(ulimit -n) -lt 40960 ]; then
        ulimit -n 40960
    fi
}

check_env()
{
    #echo "Checking OS Version..."
    if [ "$(uname -s)" == "Linux" ]; then
        local DIST_NAME=$(lsb_release -s -i 2>/dev/null)
        local DIST_VER=$(lsb_release -s -r 2>/dev/null)
        if [ "$DIST_NAME" == "Ubuntu" ]; then
            if [ "$DIST_VER" \< "18.04" ]; then
                echo_error "this script requires Ubuntu 18.04 or higher"
                exit
            fi
        else
            echo_error "do not support $(cat /etc/issue)"
            exit
        fi
        if [ "$(uname -m)" == "aarch64" ]; then
            # The ARM64 version has not been fully tested.
            # USE ARM64 BUILD AT YOUR OWN RISK!
            # To enable ARM64 version, set ENABLE_ARM64 to 1 or non-empty.
            local ENABLE_ARM64=
            if [ "$ENABLE_ARM64" == "" ]; then
                echo_error "do not support $(uname -m)"
                exit
            else
                echo_warn "the arm64 build have not been fully-tested"
            fi
        elif [ "$(uname -m)" == "x86_64" ]; then
            true
        else
            echo_error "do not support $(uname -m)"
        fi
    else
        echo_error "do not support $(uname -s)"
        exit
    fi

    #echo "Checking sudo permission..."
    sudo -n true 2>/dev/null
    if [ "$?" == "0" ]; then
        echo_warn "it is better to run as a normal user without sudo permission"
    fi

    if [ "$(which jq)" == "" ]; then
        echo_error "cannot find jq (https://github.com/stedolan/jq)"
        echo_info "sudo apt-get install -y jq"
        exit
    fi

    if [ "$(which lsof)" == "" ]; then
        echo_error "cannot find lsof"
        echo_info "sudo apt-get install -y lsof"
        exit
    fi

    if [ "$(which rotatelogs)" == "" ]; then
        echo_error "cannot find rotatelogs"
        echo_info "sudo apt-get install -y apache2-utils"
        exit
    fi

    if [ "${BASH_ARGV[0]}" == "init" ]; then
        check_env_oracle
    fi
}

check_env_oracle()
{
    if [ "$(uname -sm)" == "Linux aarch64" ]; then
        if [ "$(which make)" == "" ]; then
            echo_error "cannot find make"
            echo_info "sudo apt-get install -y make"
            exit
        fi
        if [ "$(which gcc)" == "" ]; then
            echo_error "cannot find gcc"
            echo_info "sudo apt-get install -y gcc"
            exit
        fi
        if [ "$(which g++)" == "" ]; then
            echo_error "cannot find g++"
            echo_info "sudo apt-get install -y g++"
            exit
        fi
    fi
}

init_config()
{
    # the network config is always node.json (Elastos convention), independent of the
    # script's filename - so running this as e.g. node.sh.new (migration rehearsal) still
    # finds the existing config instead of prompting and writing a stray file.
    local CONFIG_FILE=~/.config/elastos/node.json

    if [ -f $CONFIG_FILE ]; then
        echo_error "$CONFIG_FILE exist"
        exit
    fi

    echo "Please select the network:"
    echo
    echo "  1. MainNet"
    echo "  2. TestNet"

    local SELECT=
    while true; do
        echo
        read -p '? Your option: [1] ' SELECT || { SELECT=1; echo_info "no input - defaulting to MainNet"; }

        if [ "$SELECT" == "" ] || [ "$SELECT" == "1" ]; then
            local CHAIN_TYPE=mainnet
            break
        elif [ "$SELECT" == "2" ]; then
            local CHAIN_TYPE=testnet
            break
        else
            echo_error "no such option: $SELECT"
            continue
        fi
    done

    mkdir -p  $(dirname $CONFIG_FILE)
    chmod 700 $(dirname $CONFIG_FILE)

    touch $CONFIG_FILE
    chmod 600 $CONFIG_FILE
    cat <<EOF >$CONFIG_FILE
{
    "chain-type": "$CHAIN_TYPE"
}
EOF

    echo_info "config file: $CONFIG_FILE"
}

load_config()
{
    # the network config is always node.json (Elastos convention), independent of the
    # script's filename - so running this as e.g. node.sh.new (migration rehearsal) still
    # finds the existing config instead of prompting and writing a stray file.
    local CONFIG_FILE=~/.config/elastos/node.json

    if [ ! -f $CONFIG_FILE ]; then
        # First run: choose the network and write the config, then CONTINUE with the
        # requested command instead of exiting (no more running the command twice).
        init_config
    fi

    export CHAIN_TYPE=$(cat $CONFIG_FILE | jq -r '.["chain-type"]')

    if [ "$CHAIN_TYPE" != "mainnet" ] && \
       [ "$CHAIN_TYPE" != "testnet" ]; then

        echo_error "no chain type selected"
        echo_info "Please edit $CONFIG_FILE and set chain-type as mainnet or testnet"
        exit
    fi
}

set_path()
{
    # bash will not read .profile if .bash_profile exists
    if [ -f ~/.bash_profile ]; then
        local PROFILE_FILE=~/.bash_profile
    elif [ -f ~/.profile ]; then
        local PROFILE_FILE=~/.profile
    else
        touch ~/.profile
        local PROFILE_FILE=~/.profile
    fi

    if [ ! -f $PROFILE_FILE ]; then
        echo "ASSERT: no $PROFILE_FILE found, skip..."
    fi

    grep "export PATH=$SCRIPT_PATH:\$PATH" $PROFILE_FILE >/dev/null
    if [ "$?" != "0" ]; then
        echo "Updating $PROFILE_FILE..."
        echo "export PATH=$SCRIPT_PATH:\$PATH" >>$PROFILE_FILE
        echo_info "please re-login to make PATH effective"
    fi
}

set_cron()
{
    local SP0='[[:space:]]*'
    local SP1='[[:space:]]\+'

    crontab -l 2>/dev/null |
        grep -q "^${SP0}@reboot${SP1}~/node/node.sh${SP1}start${SP0}$"
    if [ "$?" != "0" ]; then
    (
        crontab -l 2>/dev/null
        echo '@reboot      ~/node/node.sh start'
    ) | crontab -
    fi

    crontab -l 2>/dev/null |
        grep -q "^${SP0}\*/10${SP1}\*${SP1}\*${SP1}\*${SP1}\*${SP1}~/node/node.sh${SP1}compress_log${SP0}$"
    if [ "$?" != "0" ]; then
    (
        crontab -l 2>/dev/null
        echo '*/10 * * * * ~/node/node.sh compress_log'
    ) | crontab -
    fi

    crontab -l 2>/dev/null
}

extip()
{
    curl -s https://checkip.amazonaws.com
}

trim()
{
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

mem_free()
{
    free -mt | sed -n '4 s/.* //p'
}

mem_usage()
{
    if [ "$1" == "" ]; then
        return
    fi

    pmap $1 | tail -1 | sed 's/.* //' | numfmt --from=iec --to=iec
}

run_time()
{
    if [ "$1" == "" ]; then
        return
    fi

    ps -oetime= -p $PID | trim
}

num_tcps()
{
    if [ "$1" == "" ]; then
        return
    fi

    lsof -n -a -itcp -p $PID 2>/dev/null | wc -l | trim
}

num_files()
{
    if [ "$1" == "" ]; then
        return
    fi

    lsof -n -p $PID 2>/dev/null | wc -l | trim
}

disk_usage()
{
    if [ "$1" == "" ] || [ ! -d "$1" ]; then
        echo N/A
        return
    fi

    du -sh $1 | sed 's/^ *//;s/\t.*$//'
}

list_tcp()
{
    if [ "$1" == "" ]; then
        return
    fi

    for i in $(lsof -nP -iTCP -sTCP:LISTEN -a -p $1 2>/dev/null | sed '1d' |
               awk '{ print $5 "_" $9 }' | sort -t ':' -k 2); do
        echo -n "$i "
    done
    echo
}

list_udp()
{
    if [ "$1" == "" ]; then
        return
    fi

    for i in $(lsof -nP -iUDP -a -p $1 2>/dev/null | sed '1d' | awk '{ print $5 "_" $9 }' | sort -u); do
        echo -n "$i "
    done
    echo
}

status_head()
{
    if [ -t 1 ]; then
        if [ "$3" == "Running" ]; then
            local FG_COLOR=2
        elif [ "$3" == "Stopped" ]; then
            local FG_COLOR=1
        else
            local FG_COLOR=8
        fi
        printf "$(tput smul)%-16s%-20s$(tput setaf $FG_COLOR)$(tput bold)%s$(tput sgr0)\n" $1 $2 $3
    else
        printf "%-16s%-20s%s\n" $1 $2 $3
    fi
}

status_info()
{
    if [ -t 1 ]; then
        printf "$(tput bold)%-16s$(tput sgr0)" "$1:"
        if [ "$1" == "BPoS State" ]; then
            if [ "$2" == "Active" ]; then
                echo "$(tput setaf 2)$(tput bold)$2$(tput sgr0)"
            elif [ "$2" == "Canceled" ] || \
                 [ "$2" == "Illegal"  ] || \
                 [ "$2" == "Inactive" ] || \
                 [ "$2" == "Pending"  ] || \
                 [ "$2" == "Returned" ]; then
                echo "$(tput setaf 1)$(tput bold)$2$(tput sgr0)"
            else
                echo "$2"
            fi
        elif [ "$1" == "CRC State" ]; then
            if [ "$2" == "Elected" ]; then
                echo "$(tput setaf 2)$(tput bold)$2$(tput sgr0)"
            elif [ "$2" == "Illegal"    ] || \
                 [ "$2" == "Impeached"  ] || \
                 [ "$2" == "Inactive"   ] || \
                 [ "$2" == "Returned"   ] || \
                 [ "$2" == "Terminated" ]; then
                echo "$(tput setaf 1)$(tput bold)$2$(tput sgr0)"
            else
                echo "$2"
            fi
        else
            echo "$2"
        fi
    else
        printf "%-16s%s\n" "$1:" "$2"
    fi
}

gen_pass()
{
    KEYSTORE_PASS=
    local KEYSTORE_PASS_VERIFY=

    echo "Please input a password (ENTER to use a random one)"
    while true; do
        read -s -p '? Password: ' KEYSTORE_PASS
        echo

        if [ "$KEYSTORE_PASS" == "" ]; then
            echo "Generating random password..."
            KEYSTORE_PASS=$(openssl rand -base64 100 | head -c 32)
            break
        elif [[ "${#KEYSTORE_PASS}" -lt 16 ]]   || \
             [[ ! "$KEYSTORE_PASS" =~ [a-z] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [A-Z] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [0-9] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [^[:alnum:]] ]]; then

            echo_error "the password does not meet the password policy:"
            echo "  - Minimum password length: 16"
            echo "  - Require at least one uppercase letter (A-Z)"
            echo "  - Require at least one lowercase letter (a-z)"
            echo "  - Require at least one digit (0-9)"
            echo "  - Require at least one non-alphanumeric character"
            continue
        else
            read -s -p '? Password (again): ' KEYSTORE_PASS_VERIFY
            echo
            if [ "$KEYSTORE_PASS" == "$KEYSTORE_PASS_VERIFY" ]; then
                break
            else
                echo_error "password mismatch"
                continue
            fi
        fi
    done
}

compress_log()
{
    if [ "$1" == "" ]; then
        return
    fi

    ls $1 1>/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
        return
    fi

    if [ -d "$1" ]; then
        local LOG_DIR="$1"
        local LOG_PAT=\*.log
    else
        local LOG_DIR=$(dirname "$1")
        local LOG_PAT=$(basename "$1")
    fi

    if [ "$IS_DEBUG" ]; then
        echo "LOG_DIR: $LOG_DIR"
        echo "LOG_PAT: $LOG_PAT"
    fi

    if [ -d $LOG_DIR ]; then
        echo "Compressing log files in $LOG_DIR..."
        cd $LOG_DIR
        for i in $(ls -1 $LOG_PAT 2>/dev/null | sort -r | sed 1d); do
            gzip -v $i
        done
    fi
}

remove_log()
{
    if [ "$1" == "" ]; then
        return
    fi

    ls $1 1>/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
        return
    fi

    if [ -d "$1" ]; then
        local LOG_DIR="$1"
        local LOG_PAT=\*.log
    else
        local LOG_DIR=$(dirname "$1")
        local LOG_PAT=$(basename "$1")
    fi

    if [ "$IS_DEBUG" ]; then
        echo "LOG_DIR: $LOG_DIR"
        echo "LOG_PAT: $LOG_PAT"
    fi

    if [ -d $LOG_DIR ]; then
        echo "Removing log files in $LOG_DIR..."
        cd $LOG_DIR
        for i in $(ls -1 $LOG_PAT 2>/dev/null | sort -r | sed 1d); do
            rm -v $i
        done
        for i in $(ls -1 $LOG_PAT.gz 2>/dev/null); do
            rm -v $i
        done
    fi
}

nodejs_setenv()
{
    local NODEJS_VER=v23.10.0

    local OS_ARCH=$(uname -sm)

    if [ "$OS_ARCH" == "Linux x86_64" ]; then
        local NODEJS_PLATFORM=linux-x64
    elif [ "$OS_ARCH" == "Linux aarch64" ]; then
        local NODEJS_PLATFORM=linux-arm64
    else
        echo_error "do not support $OS_ARCH"
        return
    fi

    local NODEJS_NAME=node-$NODEJS_VER-$NODEJS_PLATFORM
    local NODEJS_TGZ=$NODEJS_NAME.tar.xz
    local NODEJS_URL=https://nodejs.org/download/release/$NODEJS_VER/$NODEJS_TGZ

    if [ $IS_DEBUG ]; then
        echo "NODEJS_VER:  $NODEJS_VER"
        echo "NODEJS_NAME: $NODEJS_NAME"
        echo "NODEJS_TGZ:  $NODEJS_TGZ"
        echo "NODEJS_URL:  $NODEJS_URL"
    fi

    if [ ! -d $SCRIPT_PATH/extern/$NODEJS_NAME ]; then
        mkdir -p $SCRIPT_PATH/extern
        cd $SCRIPT_PATH/extern
        echo "Downloading $NODEJS_URL..."
        curl -O -# $NODEJS_URL
        tar xf $NODEJS_TGZ
    fi

    PATH=$SCRIPT_PATH/extern/$NODEJS_NAME/bin:$PATH

    echo "nodejs: $(which node)"
}

get_elastos_ver_latest()
{
    # URL_PREFIX
    if [ "$1" == "" ]; then
        return
    fi

    curl -s --connect-timeout 10 --max-time 30 "$1/?F=1" | grep '\[DIR\]' \
        | sed -e 's/.*href="//' -e 's/".*//' -e 's/.*-//' -e 's/\/$//' \
        | sort -Vr | head -n 1
}

#
# common chain functions
#
chain_prepare_stage()
{
    local CHAIN_NAME=$1

    if [ "$CHAIN_NAME" != "ela" ] && \
       [ "$CHAIN_NAME" != "esc" ] && \
       [ "$CHAIN_NAME" != "esc-oracle" ] && \
       [ "$CHAIN_NAME" != "eid" ] && \
       [ "$CHAIN_NAME" != "eid-oracle" ] && \
       [ "$CHAIN_NAME" != "eco" ] && \
       [ "$CHAIN_NAME" != "eco-oracle" ] && \
       [ "$CHAIN_NAME" != "pgp" ] && \
       [ "$CHAIN_NAME" != "pgp-oracle" ] && \
       [ "$CHAIN_NAME" != "pg" ] && \
       [ "$CHAIN_NAME" != "pg-oracle" ] && \
       [ "$CHAIN_NAME" != "arbiter" ]; then
        echo_error "do not support chain: $1"
        return 1
    fi

    if [ "$2" == "" ]; then
        return 1
    fi

    local OS_ARCH=$(uname -sm)

    if [ "$CHAIN_NAME" == "ela" ] || \
       [ "$CHAIN_NAME" == "esc" ] || \
       [ "$CHAIN_NAME" == "eid" ] || \
       [ "$CHAIN_NAME" == "eco" ] || \
       [ "$CHAIN_NAME" == "pgp" ] || \
       [ "$CHAIN_NAME" == "pg" ] || \
       [ "$CHAIN_NAME" == "arbiter" ]; then
        if [ "$OS_ARCH" == "Linux aarch64" ]; then
            local RELEASE_PLATFORM=linux-arm64
        elif [ "$OS_ARCH" == "Linux x86_64" ]; then
            local RELEASE_PLATFORM=linux-x86_64
        else
            local RELEASE_PLATFORM=nosupport
        fi
    elif [ "$CHAIN_NAME" == "esc-oracle" ] || \
         [ "$CHAIN_NAME" == "eco-oracle" ] || \
         [ "$CHAIN_NAME" == "pgp-oracle" ] || \
         [ "$CHAIN_NAME" == "pg-oracle" ] || \
         [ "$CHAIN_NAME" == "eid-oracle" ]; then
        local RELEASE_PLATFORM=
    else
        local RELEASE_PLATFORM=nosupport
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/$CHAIN_NAME

    echo "Finding the latest $CHAIN_NAME release..."
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local URL_PREFIX=https://download.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST=$(get_elastos_ver_latest $URL_PREFIX)
    else
        local URL_PREFIX_BETA=https://download-beta.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST_BETA=$(get_elastos_ver_latest $URL_PREFIX_BETA)

        local URL_PREFIX=https://download.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST=$(get_elastos_ver_latest $URL_PREFIX)

        local VER_LATEST_HIGHER=$(echo -e "$VER_LATEST_BETA\n$VER_LATEST" |
            sort -Vr | head -n 1)

        # If beta channel has a higher release
        if [ "$VER_LATEST_HIGHER" == "$VER_LATEST_BETA" ]; then
            local URL_PREFIX=$URL_PREFIX_BETA
            local VER_LATEST=$VER_LATEST_BETA
        fi
    fi

    if [ "$VER_LATEST" == "" ]; then
        echo_error "no VER_LATEST found"
        return 2
    fi

    echo_info "Latest version: $VER_LATEST"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        read -p "Proceed update (No/Yes)? " ANSWER
        if [ "$ANSWER" != "Yes" ]; then
            echo "Updating canceled"
            return 3
        fi
    fi

    if [ "$CHAIN_NAME" == "esc-oracle" ] || \
       [ "$CHAIN_NAME" == "eco-oracle" ] || \
       [ "$CHAIN_NAME" == "pgp-oracle" ] || \
       [ "$CHAIN_NAME" == "pg-oracle" ] || \
       [ "$CHAIN_NAME" == "eid-oracle" ] ; then
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}.tgz
        local URL_LATEST=$URL_PREFIX/elastos-${CHAIN_NAME}-${VER_LATEST}/${TGZ_LATEST}
    else
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}-${RELEASE_PLATFORM}.tgz
        local URL_LATEST=$URL_PREFIX/elastos-${CHAIN_NAME}-${VER_LATEST}/${TGZ_LATEST}
    fi

    mkdir -p $PATH_STAGE
    cd $PATH_STAGE

    echo "Downloading $URL_LATEST..."
    curl -O -# $URL_LATEST
    if [ "$?" != "0" ]; then
        echo_error "curl failed"
        return 4
    fi
    # TODO: verify checksum

    tar --version | grep GNU 1>/dev/null
    if [ "$?" == "0" ]; then
        local TAR_FLAGS=--wildcards
    fi

    echo "Extracting $TGZ_LATEST..."
    shift
    set -f
    for i in $*; do
        tar xf $TGZ_LATEST $TAR_FLAGS --strip=1 \*/$i
        if [ "$?" != "0" ]; then
            echo_error "failed to extract $TGZ_LATEST"
            return 5
        fi
    done
    set +f

    return 0
}

#
# all
#
#
# Deployment profile: mainchain-only vs the full cross-chain stack.
#
# Not every operator runs the whole stack. The profile is chosen once (persisted
# to PROFILE_FILE) and governs the bulk commands (all_*) and the status summary.
# An individual chain always works directly (e.g. `node.sh esc start`).
# ECO and PGP are intentionally excluded (decommissioned).
#
PROFILE_FILE=~/.config/elastos/profile
PROFILE_DEFAULT=full
PROFILE_CHAINS_FULL="ela esc esc-oracle eid eid-oracle pg pg-oracle arbiter"
PROFILE_CHAINS_MAINCHAIN="ela"

# get_profile: echo the active profile, honoring --profile override, then the
# persisted file, then the default. Always echoes a valid value.
get_profile()
{
    local p="$PROFILE_OVERRIDE"
    if [ -z "$p" ] && [ -f "$PROFILE_FILE" ]; then
        p=$(cat "$PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')
    fi
    case "$p" in
        mainchain|full) echo "$p" ;;
        *)              echo "$PROFILE_DEFAULT" ;;
    esac
}

# profile_chains: ordered chain list for the active profile (start order).
profile_chains()
{
    if [ "$(get_profile)" == "mainchain" ]; then
        echo "$PROFILE_CHAINS_MAINCHAIN"
    else
        echo "$PROFILE_CHAINS_FULL"
    fi
}

# set_profile <mainchain|full>: persist the operator's choice.
set_profile()
{
    case "$1" in
        mainchain|full)
            mkdir -p "$(dirname "$PROFILE_FILE")"
            echo "$1" > "$PROFILE_FILE"
            echo "Deployment profile set to: $1"
            echo "Active chains: $(profile_chains)"
            ;;
        *)
            echo_error "unknown profile: '$1' (expected 'mainchain' or 'full')"
            return 1
            ;;
    esac
}

# profile [set <p>]: show or change the deployment profile.
profile()
{
    if [ "$1" == "set" ]; then
        set_profile "$2"
        return
    fi
    echo "Deployment profile: $(get_profile)"
    echo "Active chains:      $(profile_chains)"
    echo
    echo "  mainchain   ELA mainchain only"
    echo "  full        ELA + side chains (esc, eid, pg) + oracles + arbiter"
    echo
    echo "Change with: $SCRIPT_NAME profile set [mainchain|full]"
}

# firewall: open the peer + consensus ports for the active profile.
# RPC/WS are deliberately NOT opened - they bind to 127.0.0.1 and must stay private.
firewall()
{
    if ! command -v ufw >/dev/null 2>&1; then
        echo_error "ufw not found (sudo apt-get install -y ufw)"; return 1
    fi
    local prof p; prof=$(get_profile)
    echo "Opening peer/consensus ports for profile '$prof' (RPC stays on 127.0.0.1)..."
    sudo ufw allow 22/tcp    >/dev/null   # SSH
    sudo ufw allow 20338/tcp >/dev/null   # ELA P2P
    sudo ufw allow 20339/tcp >/dev/null   # ELA DPoS
    if [ "$prof" == "full" ]; then
        for p in 20638 20648 20678; do    # EVM devp2p (tcp + udp discovery)
            sudo ufw allow $p/tcp >/dev/null
            sudo ufw allow $p/udp >/dev/null
        done
        for p in 20639 20649 20679; do    # EVM PBFT consensus
            sudo ufw allow $p/tcp >/dev/null
        done
    fi
    sudo ufw --force enable >/dev/null
    echo_ok "firewall configured"
    sudo ufw status verbose
}

# Local-only service ports that must never be reachable from the internet: EVM RPC/WS,
# the ela RPC, the crosschain oracle HttpJsonPorts, and the arbiter RPC. Every one is
# reached over loopback by the local geth / arbiter / CLI, which a host firewall never
# blocks. P2P + consensus ports (the X8/X9 ports, and arbiter P2P 20538) stay OPEN.
RPC_FIREWALL_PORTS="20336 20635 20636 20645 20646 20655 20656 20675 20676 20536 20632 20642 20652 20672"

# harden_firewall: close public access to the RPC/WS ports. Safe, reversible, idempotent,
# and it never restarts a daemon - so syncing and consensus are untouched. Returns 0.
harden_firewall()
{
    local port closed=
    if ! command -v ufw >/dev/null 2>&1; then
        echo_warn "ufw not installed - make sure your cloud firewall blocks 20636/20646/20676 from the internet"
        return 0
    fi
    if ! ufw status 2>/dev/null | grep -q "Status: active"; then
        echo_warn "ufw inactive - make sure your cloud firewall blocks 20636/20646/20676 from the internet"
        return 0
    fi
    for port in $RPC_FIREWALL_PORTS; do
        if ufw status 2>/dev/null | grep -qE "^${port}/tcp[[:space:]].*ALLOW"; then
            sudo ufw delete allow ${port}/tcp >/dev/null 2>&1 && closed="$closed $port"
        fi
    done
    if [ -n "$closed" ]; then
        echo_ok "firewall: closed public access to RPC ports:$closed"
    else
        echo_ok "firewall: no public RPC ports were open"
    fi
    return 0
}

# harden: the firewall close above, plus a report of which running EVM daemons still
# bind 0.0.0.0 (and so need a restart to fully rebind to 127.0.0.1). Restarts nothing.
harden()
{
    local chain pid cmd exposed=
    ui_bold "Harden - close public RPC exposure"; echo
    harden_firewall
    echo
    for chain in $EVM_CHAINS; do
        pid=$(pgrep -f "^\./$chain .*--rpc " 2>/dev/null | head -1)
        [ -z "$pid" ] && continue
        cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        if echo "$cmd" | grep -qE -- '0[.]0[.]0[.]0|--unlock '; then
            echo "  $(ui_yellow '!') $chain still bound to 0.0.0.0 - restart to rebind:  $SCRIPT_NAME $chain restart"
            exposed=1
        fi
    done
    if [ -n "$exposed" ]; then
        echo
        echo "  The firewall change already blocks the internet. The restart is defense-in-depth"
        echo "  (rebinds RPC to 127.0.0.1, drops --unlock/personal) - do it after each chain is synced."
    else
        echo_ok "all running EVM daemons are bound to 127.0.0.1"
    fi
}


# setup: one-time host prep for a fresh Ubuntu box, then initialize the node.
# Installs dependencies, adds swap, opens the firewall, enables autostart, runs init.
# clean_orphaned_config: a deleted ~/node can leave ~/.config/elastos/<chain>.txt
# (keystore passwords) with no matching keystore, which makes init bail half-way and
# leaves a broken half-install. Detect that split-brain and offer to clear it.
clean_orphaned_config()
{
    local chain orphan= ANSWER
    for chain in ela esc eid pg; do
        [ -f ~/.config/elastos/$chain.txt ] && [ ! -f "$SCRIPT_PATH/$chain/.init" ] && orphan="$orphan $chain"
    done
    [ -z "$orphan" ] && return 0
    echo
    echo_warn "leftover keystore passwords from a previous install (no matching keystore):$orphan"
    echo "  these block init; the keystore they belonged to is already gone, so they are useless."
    read -p "Remove them so init can proceed? (Yes/No) " ANSWER || { ANSWER=No; echo_warn "no input - leaving password files in place (remove manually if truly orphaned)"; }
    case "$ANSWER" in
        Yes|yes|y) for chain in $orphan; do rm -f ~/.config/elastos/$chain.txt && echo_ok "removed $chain.txt"; done ;;
        *) echo_warn "left in place - init will fail for:$orphan  (remove them or run '$SCRIPT_PATH/$SCRIPT_NAME uninstall')" ;;
    esac
}

setup()
{
    echo "=== Elastos node setup ==="
    profile_prompt_if_unset
    local prof; prof=$(get_profile)
    echo "This will: install packages, add 16G swap, configure the firewall, enable"
    echo "autostart, and initialize the '$prof' profile. It uses sudo."
    local ANSWER
    read -p "Proceed (Yes/No)? " ANSWER
    if [ "$ANSWER" != "Yes" ] && [ "$ANSWER" != "yes" ] && [ "$ANSWER" != "y" ]; then
        echo "Aborted."; return 1
    fi

    echo; echo "-- 1/5 dependencies --"
    sudo apt-get update
    sudo apt-get install -y jq lsof apache2-utils curl openssl ufw
    [ "$prof" == "full" ] && sudo apt-get install -y nodejs npm make gcc

    echo; echo "-- 2/5 swap (16G headroom for sync) --"
    if [ "$(swapon --show 2>/dev/null | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
        sudo fallocate -l 16G /swapfile && sudo chmod 600 /swapfile
        sudo mkswap /swapfile && sudo swapon /swapfile
        grep -q '^/swapfile ' /etc/fstab 2>/dev/null || \
            echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab >/dev/null
        echo_ok "16G swap added"
    else
        echo "swap already present - skipping"
    fi

    echo; echo "-- 3/5 firewall --"
    firewall

    echo; echo "-- 4/5 autostart on reboot --"
    ( crontab -l 2>/dev/null | grep -vE "node\.sh[[:space:]]+(start|compress_log)[[:space:]]*$"
      echo "@reboot $SCRIPT_PATH/$SCRIPT_NAME start"
      echo "*/10 * * * * $SCRIPT_PATH/$SCRIPT_NAME compress_log" ) | crontab -
    echo_ok "autostart enabled (@reboot) + log compression every 10 minutes"
    if printf '#!/bin/bash\nexec %s/%s "$@"\n' "$SCRIPT_PATH" "$SCRIPT_NAME" | sudo tee /usr/local/bin/node.sh >/dev/null 2>&1 && sudo chmod +x /usr/local/bin/node.sh 2>/dev/null; then
        echo_ok "global command installed - run 'node.sh <command>' from anywhere"
    else
        echo_warn "could not install a global command; use $SCRIPT_PATH/$SCRIPT_NAME or ./node.sh"
    fi

    echo; echo "-- 5/5 initialize chains --"
    all_init

    echo; echo_ok "setup complete"
    echo "Next steps:"
    if [ "$prof" == "full" ]; then
        echo "  1. set a COLD reward address for the side chains:"
        echo "       node.sh reward set 0xYOURCOLDADDRESS"
    fi
    echo "  2. start:   node.sh up"
    echo "  3. check:   node.sh status"
    echo "  4. after full sync, get the 02/03... public key for Essentials:"
    echo "       node.sh ela status --verbose"
}

# chain_restart <chain>: stop, wait for exit, start.
chain_restart()
{
    local chain=$1 i
    # never restart ELA unless explicitly forced - it would interrupt council consensus
    if [ "$chain" == "ela" ] && [ "$FORCE_ELA" != "1" ]; then
        echo_warn "ela restart refused: it would interrupt council consensus. Re-run with --force to include it."
        return 0
    fi
    "${chain}_stop"
    for i in 1 2 3 4 5; do chain_running "$chain" || break; sleep 1; done
    "${chain}_start"
}

# all_restart: restart every chain in the active profile, one at a time.
all_restart()
{
    local chain failed=
    for chain in $(profile_chains); do
        "${chain}_installed" 2>/dev/null || continue
        chain_restart "$chain" || failed="$failed $chain"
    done
    if [ -n "$failed" ]; then
        echo; echo_error "these chains did not restart:$failed"
        return 1
    fi
    return 0
}

# chain_logs <chain> [-f]: tail the chain's most recent log (-f to follow).
chain_logs()
{
    local chain=$1 follow= log
    { [ "$2" == "-f" ] || [ "$2" == "--follow" ]; } && follow=1
    log=$(ls -t "$SCRIPT_PATH/$chain/logs/"*.log "$SCRIPT_PATH/$chain/elastos/logs/node/"*.log 2>/dev/null | head -1)
    if [ -z "$log" ]; then echo_error "no logs found for $chain yet"; return 1; fi
    ui_dim "==> $log <=="; echo
    if [ -n "$follow" ]; then tail -n 40 -f "$log"; else tail -n 60 "$log"; fi
}

# logs_cmd [<chain>] [-f]: global `logs`, defaults to the mainchain.
logs_cmd()
{
    local chain=$1 flag=$2
    if [ -z "$chain" ] || [ "$chain" == "-f" ] || [ "$chain" == "--follow" ]; then
        flag=$chain; chain=ela
    fi
    chain_logs "$chain" "$flag"
}

# version_cmd: fork version + each installed chain binary version.
version_cmd()
{
    echo "elastos-node $(ui_bold "v$ELASTOS_NODE_VERSION")  (hardened fork of elastos/Elastos.Node)"
    ui_dim "node.sh sha:$SCRIPT_SHA1   profile:$(get_profile)"; echo
    local chain
    for chain in $(profile_chains); do
        case "$chain" in *-oracle|arbiter) continue ;; esac
        "${chain}_installed" 2>/dev/null && echo "  $("${chain}_ver" 2>/dev/null)"
    done
}

# reward_cmd [set <0x..>]: show or set the cold miner reward address (EVM side chains).
reward_cmd()
{
    local chain addr
    if [ "$1" != "set" ]; then
        echo "Cold reward address per side chain:"
        for chain in esc eid pg; do
            if [ -f "$SCRIPT_PATH/$chain/data/miner_address.txt" ]; then
                echo "  $chain  $(cat "$SCRIPT_PATH/$chain/data/miner_address.txt")"
            else
                echo "  $chain  $(ui_yellow '(unset)')"
            fi
        done
        echo; echo "Set for all side chains:  $SCRIPT_NAME reward set 0xYOURCOLDADDRESS"
        return
    fi
    addr=$2
    if ! echo "$addr" | grep -qiE '^0x[0-9a-f]{40}$'; then
        echo_error "invalid address: '$addr' (expected 0x + 40 hex)"; return 1
    fi
    for chain in esc eid pg; do
        mkdir -p "$SCRIPT_PATH/$chain/data"
        echo "$addr" > "$SCRIPT_PATH/$chain/data/miner_address.txt"
        chmod 600 "$SCRIPT_PATH/$chain/data/miner_address.txt"
        echo_ok "$chain reward -> $addr"
    done
    echo "Restart the side chains to apply:  $SCRIPT_NAME esc restart   (etc.)"
}

# uninstall_cmd: stop everything and remove the install + config (destructive).
uninstall_cmd()
{
    local ANSWER bk c
    ui_red "This stops all chains and DELETES the install + config."; echo
    echo "  removes: $SCRIPT_PATH/{ela,esc,eid,pg,*-oracle,arbiter,extern} and ~/.config/elastos"
    echo "  the ELA keystore is backed up to ~/ first; chain DATA is gone."
    if noninteractive; then echo_error "uninstall needs an interactive terminal - refusing to delete unattended"; return 1; fi
    read -p "Type DELETE to confirm: " ANSWER
    if [ "$ANSWER" != "DELETE" ]; then echo "Aborted."; return 1; fi
    if [ -f "$SCRIPT_PATH/ela/keystore.dat" ]; then
        bk=~/keystore.dat.bak.$(date +%s)
        cp -p "$SCRIPT_PATH/ela/keystore.dat" "$bk" && echo_ok "keystore backed up -> $bk"
    fi
    all_stop 2>/dev/null
    pkill -x ela 2>/dev/null; pkill -x arbiter 2>/dev/null
    for c in $EVM_CHAINS; do pkill -f "^\./$c .*--rpc " 2>/dev/null; done
    pkill -f 'node crosschain_' 2>/dev/null
    crontab -l 2>/dev/null | grep -v 'node.sh' | crontab - 2>/dev/null
    rm -rf "$SCRIPT_PATH"/ela "$SCRIPT_PATH"/esc "$SCRIPT_PATH"/eid "$SCRIPT_PATH"/pg \
           "$SCRIPT_PATH"/eco "$SCRIPT_PATH"/pgp \
           "$SCRIPT_PATH"/esc-oracle "$SCRIPT_PATH"/eid-oracle "$SCRIPT_PATH"/eco-oracle \
           "$SCRIPT_PATH"/pgp-oracle "$SCRIPT_PATH"/pg-oracle "$SCRIPT_PATH"/arbiter \
           "$SCRIPT_PATH"/extern "$SCRIPT_PATH"/.node-upload ~/.config/elastos
    echo_ok "uninstalled (node.sh kept; remove with: rm $SCRIPT_PATH/$SCRIPT_NAME)"
}

# migrate_apply [--yes]: apply the hardened RPC binding with near-zero downtime.
# Restarts ONLY stale side chains (esc/eid/pg), one at a time, verifying each comes
# back on 127.0.0.1 before the next. The ELA mainchain is never restarted, so the
# council producer keeps signing throughout. A single node cannot know fleet quorum -
# coordinate across the council so only a few nodes restart a given chain at once.
migrate_apply()
{
    local yes= chain pid cmd stale= ANSWER i ok
    case "$1" in --yes|-y) yes=1 ;; esac

    ui_bold "Apply hardening - staged restart of stale side chains"; echo
    echo "  the ELA mainchain is NOT restarted; your consensus/producer stays online"
    echo

    for chain in $EVM_CHAINS; do
        pid=$(pgrep -f "^\./$chain .*--rpc " 2>/dev/null | head -1)
        [ -z "$pid" ] && continue
        cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        echo "$cmd" | grep -qE -- '0[.]0[.]0[.]0|--unlock ' || { echo_ok "$chain already hardened"; continue; }
        [ "$chain" == "eco" ] && { echo "  $(ui_yellow '!') eco is decommissioned - left untouched; remove it with:  $SCRIPT_NAME eco purge"; continue; }
        stale="$stale $chain"
    done

    if [ -z "$stale" ]; then
        echo "Nothing to do - no stale side chain to restart."
        return 0
    fi
    echo "Will restart, one at a time:$stale"
    if [ -z "$yes" ]; then
        if noninteractive; then echo_error "non-interactive: re-run '$SCRIPT_NAME migrate --apply --yes'"; return 1; fi
        read -p "Proceed (Yes/No)? " ANSWER
        case "$ANSWER" in Yes|yes|y) ;; *) echo "Aborted."; return 1 ;; esac
    fi

    for chain in $stale; do
        echo; echo "-- restarting $chain --"
        chain_restart "$chain"
        ok=
        for i in $(seq 1 30); do
            if chain_running "$chain"; then
                pid=$(pgrep -f "^\./$chain .*--rpc " 2>/dev/null | head -1)
                cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
                echo "$cmd" | grep -qE -- '0[.]0[.]0[.]0|--unlock ' || { ok=1; break; }
            fi
            sleep 2
        done
        if [ -n "$ok" ]; then
            echo_ok "$chain back up, hardened (127.0.0.1)"
        else
            echo_error "$chain did not come back hardened in time - check '$SCRIPT_NAME $chain status' before continuing"
            return 1
        fi
    done

    echo; echo_ok "all stale side chains hardened"
    echo "Verify:  $SCRIPT_NAME summary"
}

# migrate [--dry-run]: move an existing install (old-fork or official Elastos)
# onto this hardened fork. Preserves keystore + chaindata + config; only writes the
# profile + a rollback snapshot; NEVER auto-restarts and NEVER deletes anything.
migrate()
{
    local dryrun= src=fresh prof chain pid cmd a ts stale= need_reward=
    case "$1" in
        --apply)      migrate_apply "$2"; return $? ;;
        --dry-run|-n) dryrun=1 ;;
    esac

    ui_bold "Migrate to the hardened elastos-node fork"; echo
    [ -n "$dryrun" ] && { ui_dim "  dry-run: nothing will be changed"; echo; }
    echo

    # 1. detect the source install
    if [ -f "$PROFILE_FILE" ]; then
        src="old-fork"
    elif [ -d "$SCRIPT_PATH/ela" ] || [ -d "$SCRIPT_PATH/esc" ] || [ -d "$SCRIPT_PATH/eid" ] || [ -d "$SCRIPT_PATH/pg" ]; then
        src="official-upstream"
    fi
    echo "Source: $src"
    if [ "$src" == "fresh" ]; then
        echo "  no existing install found - run '$SCRIPT_NAME setup' instead."
        return 0
    fi

    # 2. preflight - the node identity must be safe
    echo; echo "Preflight:"
    if [ -d "$SCRIPT_PATH/ela" ] && [ ! -f "$SCRIPT_PATH/ela/keystore.dat" ]; then
        echo_error "ela/keystore.dat missing - node identity at risk. ABORTING (nothing changed)."
        return 1
    fi
    [ -f "$SCRIPT_PATH/ela/keystore.dat" ] && echo_ok "ela keystore present (preserved, never touched)"
    if [ -f ~/.config/elastos/node.json ]; then
        if jq -e . ~/.config/elastos/node.json >/dev/null 2>&1; then
            echo_ok "node.json valid"
        else
            echo_error "node.json is not valid JSON - fix it before migrating"; return 1
        fi
    fi

    # 3. profile - official upstream has none, so infer it from what is installed
    if [ -f "$PROFILE_FILE" ]; then
        prof=$(get_profile); echo_ok "profile: $prof (kept)"
    else
        if [ -d "$SCRIPT_PATH/esc" ] || [ -d "$SCRIPT_PATH/eid" ] || [ -d "$SCRIPT_PATH/pg" ]; then prof=full; else prof=mainchain; fi
        echo "  no profile (upstream) -> inferred: $prof"
        if [ -z "$dryrun" ]; then
            mkdir -p "$(dirname "$PROFILE_FILE")"; echo "$prof" > "$PROFILE_FILE"; echo_ok "profile written: $prof"
        fi
    fi

    # 4. cold-miner bridge - a mining chain with no cold address will refuse to start
    echo; echo "Mining reward addresses:"
    for chain in esc eid pg; do
        { [ -d "$SCRIPT_PATH/$chain" ] && [ -f ~/.config/elastos/$chain.txt ]; } || continue
        a=
        [ -f "$SCRIPT_PATH/$chain/data/miner_address.txt" ] && a=$(tr -d '[:space:]' < "$SCRIPT_PATH/$chain/data/miner_address.txt" 2>/dev/null)
        if echo "$a" | grep -qiE '^0x[0-9a-f]{40}$'; then
            echo_ok "$chain cold reward set"
        else
            echo "  $(ui_yellow '!') $chain is mining but has NO cold reward address"; need_reward=1
        fi
    done
    [ -n "$need_reward" ] && echo "  set it before restarting:  $SCRIPT_NAME reward set 0xYOURCOLDADDR"

    # 5. which running EVM chains are still on stale (unhardened) flags
    echo; echo "Restart plan (to apply the hardened RPC binding):"
    for chain in $EVM_CHAINS; do
        pid=$(pgrep -f "^\./$chain .*--rpc " 2>/dev/null | head -1)
        [ -z "$pid" ] && continue
        cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        if echo "$cmd" | grep -qE -- '0[.]0[.]0[.]0|--unlock '; then
            echo "  $(ui_yellow '!') $chain is on OLD flags (public RPC) - restart to harden"; stale="$stale $chain"
        else
            echo_ok "$chain already hardened (127.0.0.1)"
        fi
    done
    [ -z "$stale" ] && echo "  no running EVM chain needs a restart"

    # leftover decommissioned ECO install (common on upstream nodes)
    if [ -d "$SCRIPT_PATH/eco" ] || [ -d "$SCRIPT_PATH/eco-oracle" ] || [ -f ~/.config/elastos/eco.txt ]; then
        echo
        echo "  $(ui_yellow '!') decommissioned ECO chain detected on this node"
        echo "    after migrating, stop + remove it with:  $SCRIPT_NAME eco purge"
    fi

    # 6. snapshot for rollback (live edit only)
    if [ -z "$dryrun" ]; then
        echo; echo "Snapshot (rollback point):"
        ts=$(date +%s).$$
        cp -p "$SCRIPT_PATH/$SCRIPT_NAME" "$SCRIPT_PATH/$SCRIPT_NAME.bak.$ts" 2>/dev/null && echo_ok "node.sh -> $SCRIPT_NAME.bak.$ts"
        [ -d ~/.config/elastos ] && cp -rp ~/.config/elastos ~/.config/elastos.bak.$ts 2>/dev/null && echo_ok "config -> ~/.config/elastos.bak.$ts"
    fi

    # 7. hand control to the operator - never auto-restart
    echo
    if [ -n "$dryrun" ]; then
        ui_bold "DRY-RUN complete"; echo " - re-run '$SCRIPT_NAME migrate' (no flag) to write the profile + snapshot AND close the public RPC firewall ports."
    else
        ui_bold "Migration prepared."; echo " The script is already swapped (zero downtime); daemons are still up."
        echo
        echo "Closing public RPC exposure (firewall only - safe, nothing is restarted):"
        harden_firewall
    fi
    if [ -n "$stale" ]; then
        echo "Apply the hardening - restart these ONE AT A TIME, staying above quorum:"
        for chain in $stale; do echo "    $SCRIPT_NAME $chain restart"; done
    fi
    echo "Check anytime:    $SCRIPT_NAME summary"
    echo "Update later:     $SCRIPT_NAME update_script   (pulls the latest fork, checksum-verified)"
}

all_start()
{
    local chain
    for chain in $(profile_chains); do
        "${chain}_installed" || continue
        "${chain}_start"
    done
}

all_stop()
{
    # stop in reverse start order for a clean shutdown
    local chain reversed=
    for chain in $(profile_chains); do
        reversed="$chain $reversed"
    done
    for chain in $reversed; do
        "${chain}_installed" && "${chain}_stop"
    done
}

all_status()
{
    local chain
    for chain in $(profile_chains); do
        "${chain}_installed" && "${chain}_status"
    done
}

all_update()
{
    local chain
    for chain in $(profile_chains); do
        "${chain}_installed" && "${chain}_update"
    done
}

all_init()
{
    profile_prompt_if_unset
    clean_orphaned_config
    local chain
    for chain in $(profile_chains); do
        "${chain}_init"
    done
}
all_compress_log()
{
    ela_installed        && ela_compress_log
    esc_installed        && esc_compress_log
    esc-oracle_installed && esc-oracle_compress_log
    eid_installed        && eid_compress_log
    eid-oracle_installed && eid-oracle_compress_log
    eco_installed        && eco_compress_log
    eco-oracle_installed && eco-oracle_compress_log
    #pgp_installed        && pgp_compress_log
    #pgp-oracle_installed && pgp-oracle_compress_log
    pg_installed         && pg_compress_log
    pg-oracle_installed  && pg-oracle_compress_log
    arbiter_installed    && arbiter_compress_log
}

all_remove_log()
{
    ela_installed        && ela_remove_log
    esc_installed        && esc_remove_log
    esc-oracle_installed && esc-oracle_remove_log
    eid_installed        && eid_remove_log
    eid-oracle_installed && eid-oracle_remove_log
    eco_installed        && eco_remove_log
    eco-oracle_installed && eco-oracle_remove_log
    #pgp_installed        && pgp_remove_log
    #pgp-oracle_installed && pgp-oracle_remove_log
    pg_installed         && pg_remove_log
    pg-oracle_installed  && pg-oracle_remove_log
    arbiter_installed    && arbiter_remove_log

}

#
# ela
#
ela_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo "  transfer        Send crypto from $CHAIN_NAME_U to sidechain"
    echo
    echo "  register_bpos   Register $CHAIN_NAME_U BPoS"
    echo "  activate_bpos   Activate $CHAIN_NAME_U BPoS"
    echo "  unregister_bpos Unregister $CHAIN_NAME_U BPoS"
    echo "  vote_bpos       Vote $CHAIN_NAME_U BPoS"
    echo "  stake_bpos      Stake $CHAIN_NAME_U BPoS"
    echo "  unstake_bpos    Unstake $CHAIN_NAME_U BPoS"
    echo "  claim_bpos      Claim rewards $CHAIN_NAME_U BPoS"
    echo
    echo "  register_crc    Register $CHAIN_NAME_U CRC"
    echo "  activate_crc    Activate $CHAIN_NAME_U CRC"
    echo "  unregister_crc  Unregister $CHAIN_NAME_U CRC"
    echo
}

# ensure_sponsors: the ELA mainchain needs a `sponsors` file (height->sponsor lookup)
# to validate blocks past the RecordSponsor fork (~1.8M). Upstream never fetches it, so
# fresh nodes stall with "sponsors file not exist!". Download it if missing (mainnet only).
ensure_sponsors()
{
    [ "$CHAIN_TYPE" == "mainnet" ] || return 0
    local f=$SCRIPT_PATH/ela/sponsors
    [ -s "$f" ] && return 0
    local pfx=https://download.elastos.io/elastos-ela ver v
    ver=$(get_elastos_ver_latest "$pfx" 2>/dev/null)
    echo "Fetching the ELA sponsors file (~28MB, one-time; needed past block ~1.8M)..."
    echo "  on a slow link this can take a few minutes - safe to wait; do not interrupt."
    for v in "$ver" v0.9.9; do
        [ -z "$v" ] && continue
        if curl -fsSL --connect-timeout 15 --speed-limit 1024 --speed-time 30 --max-time 600 "$pfx/elastos-ela-$v/sponsors" -o "$f.tmp" 2>/dev/null \
           && [ -s "$f.tmp" ] && ! head -c 200 "$f.tmp" | grep -qi '<html'; then
            mv "$f.tmp" "$f"
            echo_ok "sponsors file installed ($v, $(wc -l < "$f") entries)"
            return 0
        fi
    done
    rm -f "$f.tmp"
    echo_warn "could not fetch the sponsors file - the mainchain may stall past block ~1.8M"
    echo_warn "fetch it manually:  curl -fsSL $pfx/elastos-ela-v0.9.9/sponsors -o $f"
    return 1
}

ela_start()
{
    if [ ! -f $SCRIPT_PATH/ela/ela ]; then
        echo_error "$SCRIPT_PATH/ela/ela is not exist"
        return
    fi

    if [ ! -f $SCRIPT_PATH/ela/config.json ]; then
        echo_error "ela is not initialized (no config.json) - run:  $SCRIPT_PATH/$SCRIPT_NAME ela init"
        return
    fi

    local PID=$(pgrep -x ela)
    if [ "$PID" != "" ]; then
        ela_status
        return
    fi

    ensure_sponsors

    echo "Starting ela..."
    cd $SCRIPT_PATH/ela
    if [ -f ~/.config/elastos/ela.txt ]; then
        cat ~/.config/elastos/ela.txt | nohup ./ela 1>/dev/null 2>output &
    else
        nohup ./ela 1>/dev/null 2>output &
    fi
    sleep 1
    verify_started ela
    ela_status
}

ela_stop()
{
    local PID=$(pgrep -x ela)
    if [ "$PID" != "" ]; then
        echo "Stopping ela..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    ela_status
}

ela_installed()
{
    if [ -f $SCRIPT_PATH/ela/ela ]; then
        true
    else
        false
    fi
}

ela_ver()
{
    if [ -f $SCRIPT_PATH/ela/ela ]; then
        echo "ela $($SCRIPT_PATH/ela/ela -v | sed 's/.*\(v[0-9.][0-9\.]*\).*/\1/')"
    else
        echo "ela N/A"
    fi
}

ela_client()
{
    if [ ! -f $SCRIPT_PATH/ela/ela-cli ]; then
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ELA_RPC_PORT=20336
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ELA_RPC_PORT=21336
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local ELA_CLI="$SCRIPT_PATH/ela/ela-cli"

    cd $SCRIPT_PATH/ela

    if [ "$1" == "wallet" ]; then
        if [ "$2" == "delete" ]; then
            $ELA_CLI $*
        elif [ "$2" == "create"  ] || [ "$2" == "c" ] || \
             [ "$2" == "account" ] || [ "$2" == "a" ] || \
             [ "$2" == "add"     ] || \
             [ "$2" == "addmultisig" ] || \
             [ "$2" == "import"  ] || \
             [ "$2" == "export"  ] || \
             [ "$2" == "signtx"  ]; then
            $ELA_CLI $* --password "$(cat ~/.config/elastos/ela.txt)"
        elif [ "$2" == "balance" ] || [ "$2" == "b" ] || \
             [ "$2" == "sendtx"  ]; then
            $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                 --rpcpassword $ELA_RPC_PASS $*
        elif [ "$2" == "buildtx" ]; then
            if [ "$3" == "withdraw" ] || \
               [ "$3" == "activate" ] || \
               [ "$3" == "vote"     ]; then
                $ELA_CLI $* --password "$(cat ~/.config/elastos/ela.txt)"
            elif [ "$3" == "crc"               ] || \
                 [ "$3" == "dposv2claimreward" ] || \
                 [ "$3" == "producer"          ] || \
                 [ "$3" == "returnvotes"       ] || \
                 [ "$3" == "unstake"           ]; then
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $* \
                    --password "$(cat ~/.config/elastos/ela.txt)"
            elif [ "$3" == "crosschain"    ] || \
                 [ "$3" == "dposv2vote"    ] || \
                 [ "$3" == "exchangevotes" ] || \
                 [ "$3" == "stake"         ]; then
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $*
            else
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $*
            fi
        else
            # showtx, depositaddr, stakeaddress, didaddr, crosschainaddr
            $ELA_CLI $*
        fi
    elif [ "$1" == "info" ] || \
         [ "$1" == "mine" ]; then
        $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
            --rpcpassword $ELA_RPC_PASS $*
    else
        $ELA_CLI $*
    fi
}

ela_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ELA_RPC_PORT=20336
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ELA_RPC_PORT=21336
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    if [[ $1 =~ ^[a-z2]+$ ]] && [ "$2" == "" ]; then
        # auto-expand the command without parameters
        local DATA={\"method\":\"$1\"}
    elif [[ $1 =~ ^[a-z2]+$ ]] &&
         [[ $2 =~ ^[a-z]+$  ]] && [[ $3 =~ ^[[:alnum:]]+ ]] &&
         [ "$4" == "" ]; then
        # auto-expand the command with only one parameter
        local DATA="{\"method\":\"$1\",\"params\":{\"$2\":\"$3\"}}"
    elif [[ $1 =~ ^[a-z2]+$ ]] &&
         [[ $2 =~ ^[a-z]+$  ]] && [[ $3 =~ ^[[:alnum:]]+ ]] &&
         [[ $4 =~ ^[a-z]+$  ]] && [[ $5 =~ ^[[:alnum:]]+ ]] &&
         [ "$6" == "" ]; then
        # auto-expand the command with two parameters
        local DATA="{\"method\": \"$1\",
            \"params\": {\"$2\":\"$3\",\"$4\":\"$5\"}}"
    else
        local DATA=$*
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data "$DATA" \
        -u $ELA_RPC_USER:$ELA_RPC_PASS \
        http://127.0.0.1:$ELA_RPC_PORT | jq .
}

ela_status()
{
    local ELA_VER=$(ela_ver)

    local ELA_DISK_USAGE=$(disk_usage $SCRIPT_PATH/ela)

    if [ -f ~/.config/elastos/ela.txt ]; then
        cd $SCRIPT_PATH/ela
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
        local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    else
        local ELA_ADDRESS=N/A
        local ELA_PUB_KEY=N/A
    fi

    local PID=$(pgrep -x ela)
    if [ "$PID" == "" ]; then
        status_head $ELA_VER     Stopped
        status_info "Disk"       "$ELA_DISK_USAGE"
        status_info "Address"    "$ELA_ADDRESS"
        status_info "Public Key" "$ELA_PUB_KEY"
        echo
        return
    fi

    local ELA_RAM=$(mem_usage $PID)
    local ELA_UPTIME=$(run_time $PID)
    local ELA_NUM_TCPS=$(num_tcps $PID)
    local ELA_TCP_LISTEN=$(list_tcp $PID)
    local ELA_NUM_FILES=$(num_files $PID)

    local ELA_NUM_PEERS=$(ela_client info getconnectioncount)
    if [[ ! "$ELA_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ELA_NUM_PEERS=N/A
    fi
    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    if [[ ! "$ELA_HEIGHT" =~ ^[0-9]+$ ]]; then
        ELA_HEIGHT=N/A
    fi

    local ELA_DPOS_NAME=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .nickname")
    if [ "$ELA_DPOS_NAME" == "" ]; then
        ELA_DPOS_NAME=N/A
    fi

    local ELA_DPOS_STATE=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .state")
    if [ "$ELA_DPOS_STATE" == "" ]; then
        ELA_DPOS_STATE=N/A
    fi

    local ELA_ADDRESS_STAKE=$(ela_client wallet stakeaddress $ELA_ADDRESS 2>/dev/null)
    local ELA_DPOS_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
        \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
        jq -r '.result[0].remainvoteright[4]'
    )
    if [ "$ELA_DPOS_STAKED" == "" ] || [ "$ELA_DPOS_STAKED" == "null" ]; then
        ELA_DPOS_STAKED=N/A
    fi

    local ELA_DPOS_VOTES=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") |
               if .dposv2votes then .dposv2votes else .votes end")
    if [ "$ELA_DPOS_VOTES" == "" ]; then
        ELA_DPOS_VOTES=N/A
    fi

    # dposv2rewardinfo (all-address form) ranges a live, unlocked consensus map in
    # the ELA daemon and panics it during sync (concurrent map iteration + write).
    # Only query it once the node is fully synced; otherwise report N/A.
    local ELA_DPOS_REWARDS=N/A
    if ela_synced 2>/dev/null; then
        ELA_DPOS_REWARDS=$(ela_jsonrpc dposv2rewardinfo |
            jq -r ".result[]? | select(.address == \"$ELA_ADDRESS\") | .claimable")
        if [ "$ELA_DPOS_REWARDS" == "" ]; then
            ELA_DPOS_REWARDS=N/A
        fi
    fi

    local ELA_CRC_NAME=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .nickname")
    if [ "$ELA_CRC_NAME" == "" ]; then
        ELA_CRC_NAME=N/A
    fi

    local ELA_CRC_STATE=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .state")
    if [ "$ELA_CRC_STATE" == "" ]; then
        ELA_CRC_STATE=N/A
    fi

    local ELA_BALANCE=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
    if [ "$ELA_BALANCE" == "" ]; then
        ELA_BALANCE=N/A
    elif [[ $ELA_BALANCE =~ [^.0-9] ]]; then
        ELA_BALANCE=N/A
    fi

    status_head $ELA_VER Running
    status_info "Disk"         "$ELA_DISK_USAGE"
    status_info "Address"      "$ELA_ADDRESS"
    status_info "Public Key"   "$ELA_PUB_KEY"
    status_info "Balance"      "$ELA_BALANCE"
    status_info "PID"          "$PID"
    status_info "RAM"          "$ELA_RAM"
    status_info "Uptime"       "$ELA_UPTIME"
    status_info "#Files"       "$ELA_NUM_FILES"
    status_info "TCP Ports"    "$ELA_TCP_LISTEN"
    status_info "#TCP"         "$ELA_NUM_TCPS"
    status_info "#Peers"       "$ELA_NUM_PEERS"
    status_info "Height"       "$ELA_HEIGHT"
    status_info "BPoS Name"    "$ELA_DPOS_NAME"
    status_info "BPoS State"   "$ELA_DPOS_STATE"
    status_info "BPoS Staked"  "$ELA_DPOS_STAKED"
    status_info "BPoS Votes"   "$ELA_DPOS_VOTES"
    status_info "BPoS Rewards" "$ELA_DPOS_REWARDS"
    status_info "CRC Name"     "$ELA_CRC_NAME"
    status_info "CRC State"    "$ELA_CRC_STATE"
    echo
}

ela_compress_log()
{
    compress_log $SCRIPT_PATH/ela/elastos/logs/dpos
    compress_log $SCRIPT_PATH/ela/elastos/logs/node
}

ela_remove_log()
{
    remove_log $SCRIPT_PATH/ela/elastos/logs/dpos
    remove_log $SCRIPT_PATH/ela/elastos/logs/node
}

ela_update()
{
    unset OPTIND
    while getopts "npy" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            p)
                local PURGE_CHECKPOINTS=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage ela ela ela-cli
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/ela
    local DIR_DEPLOY=$SCRIPT_PATH/ela

    local PID=$(pgrep -x ela)
    if [ $PID ]; then
        ela_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/ela $DIR_DEPLOY/
    cp -v $PATH_STAGE/ela-cli $DIR_DEPLOY/

    if [ $PURGE_CHECKPOINTS ] &&
       [ -d $SCRIPT_PATH/ela/elastos/data/checkpoints ]; then
        echo "Removing $SCRIPT_PATH/ela/elastos/data/checkpoints..."
        rm -rf $SCRIPT_PATH/ela/elastos/data/checkpoints
    fi

    # Start program, if 1 and 2
    # 1. ela was Running before the update
    # 2. user prefer not start ela explicitly
    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        ela_start
    fi
}

ela_init()
{
    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local ELA_KEYSTORE=${SCRIPT_PATH}/ela/keystore.dat
    local ELA_KEYSTORE_PASS_FILE=~/.config/elastos/ela.txt

    if [ ! -f ${SCRIPT_PATH}/ela/ela ] || \
       [ ! -f ${SCRIPT_PATH}/ela/ela-cli ]; then
        ela_update -y
    fi

    if [ -f ${SCRIPT_PATH}/ela/.init ]; then
        echo_error "ela has already been initialized"
        return
    fi

    if [ -f $ELA_CONFIG ]; then
        echo_error "$ELA_CONFIG exists"
        return
    fi

    if [ -f $ELA_KEYSTORE_PASS_FILE ]; then
        echo_error "$ELA_KEYSTORE_PASS_FILE exists"
        return
    fi

    if [ -f $ELA_KEYSTORE ]; then
        echo_error "$ELA_KEYSTORE exists"
        return
    fi

    if [ ! -f $ELA_CONFIG ]; then
        echo "Creating ela config file..."

        if [ "$CHAIN_TYPE" == "testnet" ]; then
            cat >$ELA_CONFIG <<EOF
{
  "Configuration": {
    "ActiveNet": "testnet",
    "Magic": 2018101,
    "DPoSConfiguration": {
      "EnableArbiter": true,
      "IPAddress": "$(extip)"
    },
    "EnableRPC": true,
    "RpcConfiguration": {
      "User": "USER",
      "Pass": "PASSWORD",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
        else
            cat >$ELA_CONFIG <<EOF
{
  "Configuration": {
    "DPoSConfiguration": {
      "EnableArbiter": true,
      "IPAddress": "$(extip)"
    },
    "EnableRPC": true,
    "RpcConfiguration": {
      "User": "USER",
      "Pass": "PASSWORD",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
        fi

        echo "Generating random userpass for ela RPC interface..."
        local ELA_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
        local ELA_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

        echo "Updating ela config file..."
        jq ".Configuration.RpcConfiguration.User=\"$ELA_RPC_USER\" | \
            .Configuration.RpcConfiguration.Pass=\"$ELA_RPC_PASS\"" \
            $ELA_CONFIG >$ELA_CONFIG.tmp
        if [ "$?" == "0" ]; then
            mv $ELA_CONFIG.tmp $ELA_CONFIG
        fi
    fi

    echo "Creating ela keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi
    cd ${SCRIPT_PATH}/ela/
    ./ela-cli wallet create -p "$KEYSTORE_PASS" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create ela keystore"
        return
    fi
    chmod 600 $ELA_KEYSTORE

    echo "Saving ela keystore password..."
    mkdir -p $(dirname $ELA_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ELA_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ELA_KEYSTORE_PASS_FILE
    chmod 600 $ELA_KEYSTORE_PASS_FILE

    echo "Checking ela keystore..."
    ./ela-cli wallet account -p "$KEYSTORE_PASS"
    if [ "$?" != "0" ]; then
        echo_error "failed to dump public key"
        return
    fi

    echo_info "ela config file: $ELA_CONFIG"
    echo_info "ela keystore file: $ELA_KEYSTORE"
    echo_info "ela keystore password file: $ELA_KEYSTORE_PASS_FILE"

    touch ${SCRIPT_PATH}/ela/.init
    echo_ok "ela initialized"
    echo
}

ela_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela send FROM TO AMOUNT [FEE]"
        return
    fi

    local ELA_ADDR_FROM=$1
    local ELA_ADDR_TO=$2
    local ELA_AMOUNT=$3
    local ELA_FEE=$4

    if [ "$ELA_FEE" == "" ]; then
        local ELA_FEE=0.000001
    fi

    if [ "$ELA_AMOUNT" == "All" ]; then
        local ELA_AMOUNT=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
        local ELA_AMOUNT=$(echo "$ELA_AMOUNT-$ELA_FEE" | bc)
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx \
        --from $ELA_ADDR_FROM --to $ELA_ADDR_TO \
        --amount $ELA_AMOUNT --fee $ELA_FEE

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_transfer()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela transfer SIDECHAIN FROM TO AMOUNT [FEE]"
        return
    fi

    local SIDECHAIN=$1
    local ELA_ADDR_FROM=$2
    local ELA_ADDR_TO=$3
    local ELA_AMOUNT=$4
    local ELA_FEE=$5

    if [ "$SIDECHAIN" == "esc" ]; then
        if [ "$CHAIN_TYPE" == "mainnet" ]; then
            local SADDRESS=XVbCTM7vqM1qHKsABSFH4xKN1qbp7ijpWf
        elif [ "$CHAIN_TYPE" == "testnet" ]; then
            local SADDRESS=XWCiyXM1bQyGTawoaYKx9PjRkMUGGocWub
        else
            echo_error "do not support $CHAIN_TYPE"
            return
        fi
    elif [ "$SIDECHAIN" == "eid" ]; then
        if [ "$CHAIN_TYPE" == "mainnet" ]; then
            local SADDRESS=XUgTgCnUEqMUKLFAg3KhGv1nnt9nn8i3wi
        elif [ "$CHAIN_TYPE" == "testnet" ]; then
            local SADDRESS=XPsgiVQC3WucBYDL2DmPixj74Aa9aG3et8
        else
            echo_error "do not support $CHAIN_TYPE"
            return
        fi
    else
        echo_error "do not support sidechain $SIDECHAIN"
        return
    fi

    if [ "$ELA_FEE" == "" ]; then
        local ELA_FEE=0.000001
    fi

    if [ "$ELA_AMOUNT" == "All" ]; then
        local ELA_AMOUNT=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
        local ELA_AMOUNT=$(echo "$ELA_AMOUNT-$ELA_FEE" | bc)
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx crosschain \
        --saddress $SADDRESS \
        --from $ELA_ADDR_FROM --to $ELA_ADDR_TO \
        --amount $ELA_AMOUNT --fee $ELA_FEE

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_synced()
{
    local ELA_BEST_BLOCK_HASH=$(ela_jsonrpc getbestblockhash | jq -r '.result')

    local BEST_BLOCK_SEC=$(
        ela_jsonrpc getblock blockhash $ELA_BEST_BLOCK_HASH verbosity 1 |
        jq -r '.result.time'
    )

    local THREE_MIN_BEFORE=$(($(date +%s)-60*3))

    # echo "BEST_BLOCK_SEC:   $BEST_BLOCK_SEC"
    # echo "THREE_MIN_BEFORE: $THREE_MIN_BEFORE"

    # it is considered fully-synchronized if the best block time is within 3 minutes
    if [ $BEST_BLOCK_SEC -gt $THREE_MIN_BEFORE ]; then
        true
    else
        false
    fi
}

ela_register_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela register_bpos NAME URL BLOCKS [REGION]"
        return
    fi

    local DPOS_NAME=$1
    local DPOS_URL=$2

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        if [ $3 -lt 7201 ]; then
            echo_error "less than 7,201 blocks (around 10 days)"
            return
        fi
    else
        if [ $3 -lt 21601 ]; then
            echo_error "less than 21,601 blocks (around 30 days)"
            return
        fi
    fi
    local DPOS_LOCK=$3

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    local IS_EXIST=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .nodepublickey")

    # echo "IS_EXIST: $IS_EXIST"

    if [ "$4" == "" ]; then
        local DPOS_EXT_IP=$(extip)
        local DPOS_REGION=$(curl -s https://ipapi.co/$DPOS_EXT_IP/json |
            jq -r '.country_calling_code')
        if [ "$DPOS_REGION" == "null" ]; then
            echo_error "failed to find country code automatically"
            return
        fi
        # Calling codes has a prefix +
        local DPOS_REGION=${DPOS_REGION#+}
    else
        local DPOS_REGION=$4
    fi

    echo "BPOS_NAME:   $DPOS_NAME"
    echo "BPOS_URL:    $DPOS_URL"
    echo "BPOS_REGION: $DPOS_REGION"
    echo "BPOS_LOCK:   $DPOS_LOCK"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        if [ ! $IS_EXIST ]; then
            read -p "Proceed registration (No/Yes)? " ANSWER
        else
            read -p "Proceed updating (No/Yes)? " ANSWER
        fi

        if [ "$ANSWER" != "Yes" ]; then
            echo "Canceled"
            return
        fi
    fi

    # TODO: test more prerequisites
    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    local DPOS_UNTIL=$(($ELA_HEIGHT+$DPOS_LOCK+1))

    echo "ELA_HEIGHT:  $ELA_HEIGHT"
    echo "BPOS_UNTIL:  $DPOS_UNTIL"

    if [ ! $IS_EXIST ]; then
        ela_client wallet buildtx producer register v2 \
            --amount 2000 --fee 0.000001 \
            --nodepublickey $ELA_PUB_KEY \
            --nickname $DPOS_NAME --url $DPOS_URL \
            --location $DPOS_REGION --netaddress 127.0.0.1 \
            --stakeuntil $DPOS_UNTIL
    else
        ela_client wallet buildtx producer update v2 \
            --fee 0.000001 \
            --nodepublickey $ELA_PUB_KEY \
            --nickname $DPOS_NAME --url $DPOS_URL \
            --location $DPOS_REGION --netaddress 127.0.0.1 \
            --stakeuntil $DPOS_UNTIL
    fi

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:v2 producer StakeUntil less than DPoSV2DepositCoinMinLockTime]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:stake time is smaller than before]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:DPoS 2.0 node has expired]
}

ela_activate_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    # TODO: test more prerequisites

    cd $SCRIPT_PATH/ela
    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx | grep -q activate
    if [ "$?" == "0" ]; then
        ela_client wallet buildtx activate --nodepublickey $ELA_PUB_KEY
    else
        ela_client wallet buildtx producer activate --nodepublickey $ELA_PUB_KEY
    fi

    ela_client wallet sendtx -f ready_to_send.txn

    # Error message:
    # [ERROR] map[code:-32603 id:<nil> message:Client authenticate failed]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid]
}

ela_unregister_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    # TODO: test more prerequisites

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')

    local AMOUNT=$(ela_jsonrpc getdepositcoin ownerpublickey $ELA_PUB_KEY |
        jq -r '.result.available')

    if [ "$IS_DEBUG" ]; then
        echo "AMOUNT: $AMOUNT"
    fi

    # DPoS 2.0 do not support unregister manually.
    # The command:
    #   ela_client wallet buildtx producer unregister --fee 0.000001
    # will cause sendtx error:
    #   [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:can not cancel DPoS V2 producer]

    ela_client wallet buildtx producer returndeposit --amount $AMOUNT --fee 0.000001

    # Too much amount will cause
    #   error: create transaction failed: map[code:45002 id:<nil> message:not enough utxo]

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:overspend deposit]
}

ela_vote_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela vote_bpos NAME    AMOUNT BLOCKS"
        echo "Usage: $SCRIPT_NAME ela vote_bpos PUB_KEY AMOUNT BLOCKS"
        return
    fi

    local ELA_DPOS_NAME_OR_PUBKEY=$1

    local ELA_DPOS_NAME=
    local ELA_DPOS_PUBKEY=

    local ELA_DPOS_PUBKEY=$(ela_jsonrpc listproducers |
        jq -r ".result.producers[] |
            select(.nickname == \"$ELA_DPOS_NAME_OR_PUBKEY\") |
            .nodepublickey")

    if [ "$ELA_DPOS_PUBKEY" != "" ]; then
        local ELA_DPOS_NAME=$ELA_DPOS_NAME_OR_PUBKEY
    else
        local ELA_DPOS_NAME=$(ela_jsonrpc listproducers |
            jq -r ".result.producers[] |
                select(.nodepublickey == \"$ELA_DPOS_NAME_OR_PUBKEY\") |
                .nickname")

        if [ "$ELA_DPOS_NAME" != "" ]; then
            local ELA_DPOS_PUBKEY=$ELA_DPOS_NAME_OR_PUBKEY
        else
            echo_error "no such node registered: $ELA_DPOS_NAME_OR_PUBKEY"
            return
        fi
    fi

    local ELA_DPOS_VOTE_AMOUNT=$2
    local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_DPOS_VOTE_AMOUNT"
        return
    fi

    if [ $3 -lt 7201 ]; then
        echo_error "less than 7,201 blocks (around 10 days)"
        return
    fi
    if [ $3 -gt 720000 ]; then
        echo_error "greater than 720,000 blocks (around 100 days)"
        return
    fi
    local ELA_DPOS_BLOCKS_LOCK=$3

    local ELA_DPOS_STAKEPOOL=STAKEPooLXXXXXXXXXXXXXXXXXXXpP1PQ2

    cd $SCRIPT_PATH/ela

    local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    local ELA_ADDRESS_STAKE=$(ela_client wallet stakeaddress $ELA_ADDRESS)
    local ELA_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
        \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
        jq -r '.result[0].remainvoteright[4]')

    if [ "$IS_DEBUG" ]; then
        echo "ELA_DPOS_NAME:         $ELA_DPOS_NAME"
        echo "ELA_DPOS_PUBKEY:       $ELA_DPOS_PUBKEY"
        echo "ELA_DPOS_VOTE_AMOUNT:  $ELA_DPOS_VOTE_AMOUNT"
        echo "ELA_DPOS_BLOCKS_LOCK:  $ELA_DPOS_BLOCKS_LOCK"
        echo "ELA_DPOS_STAKEPOOL:    $ELA_DPOS_STAKEPOOL"
        echo "ELA_ADDRESS:           $ELA_ADDRESS"
        echo "ELA_ADDRESS_STAKE:     $ELA_ADDRESS_STAKE"
        echo "ELA_STAKED:            $ELA_STAKED"
    fi

    local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT<=$ELA_STAKED" | bc 2>/dev/null)
    if [ "$BC_OUT" == "1" ]; then
        echo_info "voting rights is enough: $ELA_STAKED"
    elif [ "$BC_OUT" == "0" ]; then
        # voting rights not enough"
        local ELA_STAKE_AMOUNT=$(echo "$ELA_DPOS_VOTE_AMOUNT-$ELA_STAKED" | bc)
        # echo "INFO: voting rights is not enough, an extra ELA_STAKE_AMOUNT is neeeded"
        echo "Staking ELA $ELA_STAKE_AMOUNT..."
        ela_stake_bpos $ELA_STAKE_AMOUNT
        if [ "$?" == "0" ]; then
            echo "OK"
        else
            echo_error "Please wait for at least one new block before re-invoking"
        fi

        echo "Waiting enough vote rights..."
        while true; do
            local ELA_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
                \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
                jq -r '.result[0].remainvoteright[4]')

            local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT<=$ELA_STAKED" |
                bc 2>/dev/null)
            if [ "$BC_OUT" == "1" ]; then
                echo
                break
            fi
            echo -n .
            sleep 1
        done
    else
        echo_error "bc"
        return
    fi

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    local ELA_DPOS_STAKE_UNTIL=$(($ELA_HEIGHT+$ELA_DPOS_BLOCKS_LOCK))

    if [ "$IS_DEBUG" ]; then
        echo "ELA_HEIGHT:            $ELA_HEIGHT"
        echo "ELA_DPOS_STAKE_UNTIL:  $ELA_DPOS_STAKE_UNTIL"
    fi

    echo -e "\n[$(date)]" | tee -a vote_dpos.log
    ela_client wallet buildtx dposv2vote --fee 0.000001 \
        --candidates $ELA_DPOS_PUBKEY --votes $ELA_DPOS_VOTE_AMOUNT \
        --stakeuntils $ELA_DPOS_STAKE_UNTIL --votetype 4 | tee -a vote_dpos.log

    ela_client wallet signtx --file to_be_signed.txn
    ela_client wallet sendtx --file ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:invalid DPoS 2.0 votes lock time]
    # [ERROR] map[code:43001 id:<nil> message:slot Stake verify tx error]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:DPoSV2 vote rights not enough]
}

ela_stake_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela stake_bpos AMOUNT"
        return
    fi

    local ELA_STAKE_AMOUNT=$1
    local BC_OUT=$(echo "$ELA_STAKE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_STAKE_AMOUNT"
        return
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_STAKE_AMOUNT: $ELA_STAKE_AMOUNT"
    fi

    local ELA_DPOS_STAKEPOOL=STAKEPooLXXXXXXXXXXXXXXXXXXXpP1PQ2

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx exchangevotes --amount $ELA_STAKE_AMOUNT \
        --fee 0.000001 --stakepool $ELA_DPOS_STAKEPOOL

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:slot Stake verify tx error]
}

ela_unstake_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela unstake_bpos AMOUNT [ELA_ADDRESS]"
        return
    fi

    local ELA_UNSTAKE_AMOUNT=$1
    local BC_OUT=$(echo "$ELA_UNSTAKE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_UNSTAKE_AMOUNT"
        return
    fi

    local ELA_ADDRESS=$2
    if [ "$ELA_ADDRESS" == "" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_UNSTAKE_AMOUNT: $ELA_UNSTAKE_AMOUNT"
        echo "ELA_ADDRESS:        $ELA_ADDRESS"
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx returnvotes --amount $ELA_UNSTAKE_AMOUNT \
        --fee 0.000001 --to $ELA_ADDRESS

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_claim_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela claim_bpos AMOUNT [ELA_ADDRESS]"
        return
    fi

    local ELA_CLAIM_AMOUNT=$1

    if [ "$ELA_CLAIM_AMOUNT" == "All" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
        local ELA_CLAIM_AMOUNT=$(ela_jsonrpc dposv2rewardinfo |
            jq -r ".result[] | select(.address == \"$ELA_ADDRESS\") |
                   .claimable")
    fi

    local BC_OUT=$(echo "$ELA_CLAIM_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_CLAIM_AMOUNT"
        return
    fi

    local ELA_ADDRESS=$2
    if [ "$ELA_ADDRESS" == "" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_CLAIM_AMOUNT: $ELA_CLAIM_AMOUNT"
        echo "ELA_ADDRESS:      $ELA_ADDRESS"
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx dposv2claimreward \
        --claimamount $ELA_CLAIM_AMOUNT --fee 0.000001 --to $ELA_ADDRESS

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # Wait for at least 3 blocks to receive the reward.
}

ela_register_crc()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$2" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela register_crc NAME URL [REGION]"
        return
    fi

    local CRC_NAME=$1
    local CRC_URL=$2

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    local IS_EXIST=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .dpospublickey")

    if [ $IS_DEBUG ]; then
        echo "IS_EXIST: $IS_EXIST"
    fi

    if [ "$3" == "" ]; then
        local CRC_EXT_IP=$(extip)
        local CRC_REGION=$(curl -s https://ipapi.co/$DPOS_EXT_IP/json |
            jq -r '.country_calling_code')
        # Calling codes has a prefix +
        local CRC_REGION=${CRC_REGION#+}
    fi

    echo "CRC_NAME:   $CRC_NAME"
    echo "CRC_URL:    $CRC_URL"
    echo "CRC_REGION: $CRC_REGION"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        if [ ! $IS_EXIST ]; then
            read -p "Proceed registration (No/Yes)? " ANSWER
        else
            read -p "Proceed updating (No/Yes)? " ANSWER
        fi

        if [ "$ANSWER" != "Yes" ]; then
            echo "Canceled"
            return
        fi
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    if [ ! $IS_EXIST ]; then
        ela_client wallet buildtx crc register \
            --amount 1 --fee 0.000001 \
            --nickname $CRC_NAME --url $CRC_URL \
            --location $CRC_REGION
    else
        ela_client wallet buildtx crc update \
            --amount 1 --fee 0.000001 \
            --nickname $CRC_NAME --url $CRC_URL \
            --location $CRC_REGION
    fi

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error:
    #         payload content invalid:should create tx during voting period]
}

ela_activate_crc()
{
    ela_activate_bpos
}

ela_unregister_crc()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx crc unregister --fee 0.000001
    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error:
    #         payload content invalid:should create tx during voting period]
}

#
# esc
#
esc_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo
}

esc_start()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo_error "$SCRIPT_PATH/esc/esc is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ESC_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ESC_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" != "" ]; then
        esc_status
        return
    fi

    echo "Starting esc..."
    cd $SCRIPT_PATH/esc
    mkdir -p $SCRIPT_PATH/esc/logs/

    if [ -f ~/.config/elastos/esc.txt ]; then
        warn_hot_miner esc
        if [ -f $SCRIPT_PATH/esc/data/miner_address.txt ]; then
            local ESC_OPTS="$ESC_OPTS --pbft.miner.address $SCRIPT_PATH/esc/data/miner_address.txt"
        fi
        nohup $SHELL -c "./esc \
            $ESC_OPTS \
            --datadir $SCRIPT_PATH/esc/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/esc.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20639 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool,pbft' \
            --rpcvhosts '*' \
            --syncmode full \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --frozen.account.list 0xD3651037F719CC3f38ef819f919972e04A0762d4 \
            --frozen.account.list 0xd5300C4091C4C45787C1BcB2b3d089F6a6094498 \
            --frozen.account.list 0xE4F50ec2E5E75d28647ce11Fd249f1Bf44be4269 \
            --frozen.account.list 0x1562996a963fBaff40E23C6Fc544Cc048Bc89E4d \
            --frozen.account.list 0x1A94cCFBAcf5DE728f3429A775bF1889082C96F3 \
            --frozen.account.list 0x6eAB6c04A7a418e3968B44356F0C15FB9ec275db \
            --frozen.account.list 0x415dC0F88C5e8236EE1fC7970bDf5805e717645F \
            --frozen.account.list 0x0D28dC303d1f665B441E5486E152260a805D4857 \
            --frozen.account.list 0x9b4f4E09375bd0F9D6385E9d0a39605a073DD01E \
            --frozen.account.list 0xB7f7f0C40aBb51589A8074665c6c5f5565F5780a \
            --frozen.account.list 0xA7cDb922183f826489707E1E41b68174BFdDbdDC \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/esc/logs/esc-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./esc \
            $ESC_OPTS \
            --datadir $SCRIPT_PATH/esc/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/esc/logs/esc-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    verify_started esc
    esc_status
}

eco_start()
{
    if [ ! -f $SCRIPT_PATH/eco/eco ]; then
        echo_error "$SCRIPT_PATH/eco/eco is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ECO_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ECO_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" != "" ]; then
        eco_status
        return
    fi

    echo "Starting eco..."
    cd $SCRIPT_PATH/eco
    mkdir -p $SCRIPT_PATH/eco/logs/

    if [ -f ~/.config/elastos/eco.txt ]; then
        warn_hot_miner eco
        if [ -f $SCRIPT_PATH/eco/data/miner_address.txt ]; then
            local ECO_OPTS="$ECO_OPTS --pbft.miner.address $SCRIPT_PATH/eco/data/miner_address.txt"
        fi
        nohup $SHELL -c "./eco \
            $ECO_OPTS \
            --datadir $SCRIPT_PATH/eco/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/eco.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20659 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool,pbft' \
            --rpcvhosts '*' \
            --syncmode full \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eco/logs/eco-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./eco \
            $ECO_OPTS \
            --datadir $SCRIPT_PATH/eco/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eco/logs/eco-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    verify_started eco
    eco_status
}

pgp_start()
{
    if [ ! -f $SCRIPT_PATH/pgp/pgp ]; then
        echo_error "$SCRIPT_PATH/pgp/pgp is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PGP_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PGP_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" != "" ]; then
        pgp_status
        return
    fi

    echo "Starting pgp..."
    cd $SCRIPT_PATH/pgp
    mkdir -p $SCRIPT_PATH/pgp/logs/

    if [ -f ~/.config/elastos/pgp.txt ]; then
        warn_hot_miner pgp
        if [ -f $SCRIPT_PATH/pgp/data/miner_address.txt ]; then
            local PGP_OPTS="$PGP_OPTS --pbft.miner.address $SCRIPT_PATH/pgp/data/miner_address.txt"
        fi
        nohup $SHELL -c "./pgp \
            $PGP_OPTS \
            --datadir $SCRIPT_PATH/pgp/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/pgp.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20669 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool,pbft' \
            --rpcvhosts '*' \
            --syncmode full \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pgp/logs/pgp-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./pgp \
            $PGP_OPTS \
            --datadir $SCRIPT_PATH/pgp/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pgp/logs/pgp-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    verify_started pgp
    pgp_status
}


pg_start()
{
    if [ ! -f $SCRIPT_PATH/pg/pg ]; then
        echo_error "$SCRIPT_PATH/pg/pg is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PG_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PG_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" != "" ]; then
        pg_status
        return
    fi

    echo "Starting pg..."
    cd $SCRIPT_PATH/pg
    mkdir -p $SCRIPT_PATH/pg/logs/

    if [ -f ~/.config/elastos/pg.txt ]; then
        warn_hot_miner pg
        if [ -f $SCRIPT_PATH/pg/data/miner_address.txt ]; then
            local PG_OPTS="$PG_OPTS --pbft.miner.address $SCRIPT_PATH/pg/data/miner_address.txt"
        fi
        nohup $SHELL -c "./pg \
            $PG_OPTS \
            --datadir $SCRIPT_PATH/pg/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/pg.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20679 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool,pbft' \
            --rpcvhosts '*' \
            --syncmode full \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pg/logs/pg-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./pg \
            $PG_OPTS \
            --datadir $SCRIPT_PATH/pg/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '$(evm_rpc_bind)' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pg/logs/pg-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    verify_started pg
    pg_status
}

esc_stop()
{
    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping esc..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    esc_status
}
eco_stop()
{
    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping eco..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    eco_status
}

pgp_stop()
{
    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping pgp..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    pgp_status
}

pg_stop()
{
    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping pg..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    pg_status
}

esc_installed()
{
    if [ -f $SCRIPT_PATH/esc/esc ]; then
        true
    else
        false
    fi
}

eco_installed()
{
    if [ -f $SCRIPT_PATH/eco/eco ]; then
        true
    else
        false
    fi
}

pgp_installed()
{
    if [ -f $SCRIPT_PATH/pgp/pgp ]; then
        true
    else
        false
    fi
}

pg_installed()
{
    if [ -f $SCRIPT_PATH/pg/pg ]; then
        true
    else
        false
    fi
}

esc_ver()
{
    if [ -f $SCRIPT_PATH/esc/esc ]; then
        echo "esc $($SCRIPT_PATH/esc/esc version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "esc N/A"
    fi
}

eco_ver()
{
    if [ -f $SCRIPT_PATH/eco/eco ]; then
        echo "eco $($SCRIPT_PATH/eco/eco version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "eco N/A"
    fi
}

pgp_ver()
{
    if [ -f $SCRIPT_PATH/pgp/pgp ]; then
        echo "pgp $($SCRIPT_PATH/pgp/pgp version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "pgp N/A"
    fi
}

pg_ver()
{
    if [ -f $SCRIPT_PATH/pg/pg ]; then
        echo "pg $($SCRIPT_PATH/pg/pg version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "pg N/A"
    fi
}

esc_client()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo_error "$SCRIPT_PATH/esc/esc is not exist"
        return
    fi

    cd $SCRIPT_PATH/esc
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/esc/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/esc/data/geth.ipc ]; then
        return
    else
        ./esc --datadir $SCRIPT_PATH/esc/data --nousb $*
    fi
}

eco_client()
{
    if [ ! -f $SCRIPT_PATH/eco/eco ]; then
        echo_error "$SCRIPT_PATH/eco/eco is not exist"
        return
    fi

    cd $SCRIPT_PATH/eco
    if [ "$1" == "" ]; then
        ./eco --datadir $SCRIPT_PATH/eco/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/eco/data/geth.ipc ]; then
        return
    else
        ./eco --datadir $SCRIPT_PATH/eco/data --nousb $*
    fi
}

pgp_client()
{
    if [ ! -f $SCRIPT_PATH/pgp/pgp ]; then
        echo_error "$SCRIPT_PATH/pgp/pgp is not exist"
        return
    fi

    cd $SCRIPT_PATH/pgp
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/pgp/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/pgp/data/geth.ipc ]; then
        return
    else
        ./pgp --datadir $SCRIPT_PATH/pgp/data --nousb $*
    fi
}

pg_client()
{
    if [ ! -f $SCRIPT_PATH/pg/pg ]; then
        echo_error "$SCRIPT_PATH/pg/pg is not exist"
        return
    fi

    cd $SCRIPT_PATH/pg
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/pg/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/pg/data/geth.ipc ]; then
        return
    else
        ./pg --datadir $SCRIPT_PATH/pg/data --nousb $*
    fi
}

esc_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20636 | jq .
}

eco_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20656 | jq .
}

pgp_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20666 | jq .
}

pg_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20676 | jq .
}

esc_status()
{
    local ESC_VER=$(esc_ver)

    local ESC_DISK_USAGE=$(disk_usage $SCRIPT_PATH/esc)

    if [ -f ~/.config/elastos/esc.txt ]; then
        cd $SCRIPT_PATH/esc
        local ESC_KEYSTORE=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $ESC_KEYSTORE ] && [ -f $ESC_KEYSTORE ]; then
            local ESC_ADDRESS=0x$(cat $ESC_KEYSTORE | jq -r .address)
        else
            local ESC_ADDRESS=N/A
        fi
    else
        local ESC_ADDRESS=N/A
    fi

    local ESC_MINER_ADDRESS=$(cat $SCRIPT_PATH/esc/data/miner_address.txt 2>/dev/null)
    if [ "$ESC_MINER_ADDRESS" == "" ]; then
        local ESC_MINER_ADDRESS=$ESC_ADDRESS
    fi

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $ESC_VER  Stopped
        status_info "Disk"    "$ESC_DISK_USAGE"
        status_info "Address" "$ESC_ADDRESS"
        echo
        return
    fi

    local ESC_RAM=$(mem_usage $PID)
    local ESC_UPTIME=$(run_time $PID)
    local ESC_NUM_TCPS=$(num_tcps $PID)
    local ESC_TCP_LISTEN=$(list_tcp $PID)
    local ESC_UDP_LISTEN=$(list_udp $PID)
    local ESC_NUM_FILES=$(num_files $PID)

    local ESC_NUM_PEERS=$(esc_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    ESC_NUM_PEERS=$(hex_to_dec "$ESC_NUM_PEERS")
    if [[ ! "$ESC_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ESC_NUM_PEERS=N/A
    fi
    local ESC_HEIGHT=$(esc_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    ESC_HEIGHT=$(hex_to_dec "$ESC_HEIGHT")
    if [[ ! "$ESC_HEIGHT" =~ ^[0-9]+$ ]]; then
        ESC_HEIGHT=N/A
    fi

    local ESC_BALANCE=$(esc_client \
        attach --exec "web3.fromWei(eth.getBalance('$ESC_ADDRESS'),'ether')")
    if [ "$ESC_BALANCE" == "" ]; then
        ESC_BALANCE=N/A
    elif [[ $ESC_BALANCE =~ [^.0-9e-] ]]; then
        ESC_BALANCE=N/A
    fi

    status_head $ESC_VER Running
    status_info "Disk"      "$ESC_DISK_USAGE"
    status_info "Address"   "$ESC_ADDRESS"
    status_info "Balance"   "$ESC_BALANCE"
    status_info "Miner"     "$ESC_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ESC_RAM"
    status_info "Uptime"    "$ESC_UPTIME"
    status_info "#Files"    "$ESC_NUM_FILES"
    status_info "TCP Ports" "$ESC_TCP_LISTEN"
    status_info "#TCP"      "$ESC_NUM_TCPS"
    status_info "UDP Ports" "$ESC_UDP_LISTEN"
    status_info "#Peers"    "$ESC_NUM_PEERS"
    status_info "Height"    "$ESC_HEIGHT"
    echo
}

eco_status()
{
    local ECO_VER=$(eco_ver)

    local ECO_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eco)

    if [ -f ~/.config/elastos/eco.txt ]; then
        cd $SCRIPT_PATH/eco
        local ECO_KEYSTORE=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $ECO_KEYSTORE ] && [ -f $ECO_KEYSTORE ]; then
            local ECO_ADDRESS=0x$(cat $ECO_KEYSTORE | jq -r .address)
        else
            local ECO_ADDRESS=N/A
        fi
    else
        local ECO_ADDRESS=N/A
    fi

    local ECO_MINER_ADDRESS=$(cat $SCRIPT_PATH/eco/data/miner_address.txt 2>/dev/null)
    if [ "$ECO_MINER_ADDRESS" == "" ]; then
        local ECO_MINER_ADDRESS=$ECO_ADDRESS
    fi

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $ECO_VER  Stopped
        status_info "Disk"    "$ECO_DISK_USAGE"
        status_info "Address" "$ECO_ADDRESS"
        echo
        return
    fi

    local ECO_RAM=$(mem_usage $PID)
    local ECO_UPTIME=$(run_time $PID)
    local ECO_NUM_TCPS=$(num_tcps $PID)
    local ECO_TCP_LISTEN=$(list_tcp $PID)
    local ECO_UDP_LISTEN=$(list_udp $PID)
    local ECO_NUM_FILES=$(num_files $PID)

    local ECO_NUM_PEERS=$(eco_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    ECO_NUM_PEERS=$(hex_to_dec "$ECO_NUM_PEERS")
    if [[ ! "$ECO_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ECO_NUM_PEERS=N/A
    fi
    local ECO_HEIGHT=$(eco_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    ECO_HEIGHT=$(hex_to_dec "$ECO_HEIGHT")
    if [[ ! "$ECO_HEIGHT" =~ ^[0-9]+$ ]]; then
        ECO_HEIGHT=N/A
    fi

    local ECO_BALANCE=$(eco_client \
        attach --exec "web3.fromWei(eth.getBalance('$ECO_ADDRESS'),'ether')")
    if [ "$ECO_BALANCE" == "" ]; then
        ECO_BALANCE=N/A
    elif [[ $ECO_BALANCE =~ [^.0-9e-] ]]; then
        ECO_BALANCE=N/A
    fi

    status_head $ECO_VER Running
    status_info "Disk"      "$ECO_DISK_USAGE"
    status_info "Address"   "$ECO_ADDRESS"
    status_info "Balance"   "$ECO_BALANCE"
    status_info "Miner"     "$ECO_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ECO_RAM"
    status_info "Uptime"    "$ECO_UPTIME"
    status_info "#Files"    "$ECO_NUM_FILES"
    status_info "TCP Ports" "$ECO_TCP_LISTEN"
    status_info "#TCP"      "$ECO_NUM_TCPS"
    status_info "UDP Ports" "$ECO_UDP_LISTEN"
    status_info "#Peers"    "$ECO_NUM_PEERS"
    status_info "Height"    "$ECO_HEIGHT"
    echo
}


pgp_status()
{
    local PGP_VER=$(pgp_ver)

    local PGP_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pgp)

    if [ -f ~/.config/elastos/pgp.txt ]; then
        cd $SCRIPT_PATH/pgp
        local PGP_KEYSTORE=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $PGP_KEYSTORE ] && [ -f $PGP_KEYSTORE ]; then
            local PGP_ADDRESS=0x$(cat $PGP_KEYSTORE | jq -r .address)
        else
            local PGP_ADDRESS=N/A
        fi
    else
        local PGP_ADDRESS=N/A
    fi

    local PGP_MINER_ADDRESS=$(cat $SCRIPT_PATH/pgp/data/miner_address.txt 2>/dev/null)
    if [ "$PGP_MINER_ADDRESS" == "" ]; then
        local PGP_MINER_ADDRESS=$PGP_ADDRESS
    fi

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $PGP_VER  Stopped
        status_info "Disk"    "$PGP_DISK_USAGE"
        status_info "Address" "$PGP_ADDRESS"
        echo
        return
    fi

    local PGP_RAM=$(mem_usage $PID)
    local PGP_UPTIME=$(run_time $PID)
    local PGP_NUM_TCPS=$(num_tcps $PID)
    local PGP_TCP_LISTEN=$(list_tcp $PID)
    local PGP_UDP_LISTEN=$(list_udp $PID)
    local PGP_NUM_FILES=$(num_files $PID)

    local PGP_NUM_PEERS=$(pgp_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    PGP_NUM_PEERS=$(hex_to_dec "$PGP_NUM_PEERS")
    if [[ ! "$PGP_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        PGP_NUM_PEERS=N/A
    fi
    local PGP_HEIGHT=$(pgp_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    PGP_HEIGHT=$(hex_to_dec "$PGP_HEIGHT")
    if [[ ! "$PGP_HEIGHT" =~ ^[0-9]+$ ]]; then
        PGP_HEIGHT=N/A
    fi

    local PGP_BALANCE=$(pgp_client \
        attach --exec "web3.fromWei(eth.getBalance('$PGP_ADDRESS'),'ether')")
    if [ "$PGP_BALANCE" == "" ]; then
        PGP_BALANCE=N/A
    elif [[ $PGP_BALANCE =~ [^.0-9e-] ]]; then
        PGP_BALANCE=N/A
    fi

    status_head $PGP_VER Running
    status_info "Disk"      "$PGP_DISK_USAGE"
    status_info "Address"   "$PGP_ADDRESS"
    status_info "Balance"   "$PGP_BALANCE"
    status_info "Miner"     "$PGP_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PGP_RAM"
    status_info "Uptime"    "$PGP_UPTIME"
    status_info "#Files"    "$PGP_NUM_FILES"
    status_info "TCP Ports" "$PGP_TCP_LISTEN"
    status_info "#TCP"      "$PGP_NUM_TCPS"
    status_info "UDP Ports" "$PGP_UDP_LISTEN"
    status_info "#Peers"    "$PGP_NUM_PEERS"
    status_info "Height"    "$PGP_HEIGHT"
    echo
}

pg_status()
{
    local PG_VER=$(pg_ver)

    local PG_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pg)

    if [ -f ~/.config/elastos/pg.txt ]; then
        cd $SCRIPT_PATH/pg
        local PG_KEYSTORE=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $PG_KEYSTORE ] && [ -f $PG_KEYSTORE ]; then
            local PG_ADDRESS=0x$(cat $PG_KEYSTORE | jq -r .address)
        else
            local PG_ADDRESS=N/A
        fi
    else
        local PG_ADDRESS=N/A
    fi

    local PG_MINER_ADDRESS=$(cat $SCRIPT_PATH/pg/data/miner_address.txt 2>/dev/null)
    if [ "$PG_MINER_ADDRESS" == "" ]; then
        local PG_MINER_ADDRESS=$PG_ADDRESS
    fi

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $PG_VER  Stopped
        status_info "Disk"    "$PG_DISK_USAGE"
        status_info "Address" "$PG_ADDRESS"
        echo
        return
    fi

    local PG_RAM=$(mem_usage $PID)
    local P_UPTIME=$(run_time $PID)
    local PG_NUM_TCPS=$(num_tcps $PID)
    local PG_TCP_LISTEN=$(list_tcp $PID)
    local PG_UDP_LISTEN=$(list_udp $PID)
    local PG_NUM_FILES=$(num_files $PID)

    local PG_NUM_PEERS=$(pg_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    PG_NUM_PEERS=$(hex_to_dec "$PG_NUM_PEERS")
    if [[ ! "$PG_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        PG_NUM_PEERS=N/A
    fi
    local PG_HEIGHT=$(pg_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    PG_HEIGHT=$(hex_to_dec "$PG_HEIGHT")
    if [[ ! "$PG_HEIGHT" =~ ^[0-9]+$ ]]; then
        PG_HEIGHT=N/A
    fi

    local PG_BALANCE=$(pg_client \
        attach --exec "web3.fromWei(eth.getBalance('$PG_ADDRESS'),'ether')")
    if [ "$PG_BALANCE" == "" ]; then
        PG_BALANCE=N/A
    elif [[ $PG_BALANCE =~ [^.0-9e-] ]]; then
        PG_BALANCE=N/A
    fi

    status_head $PG_VER Running
    status_info "Disk"      "$PG_DISK_USAGE"
    status_info "Address"   "$PG_ADDRESS"
    status_info "Balance"   "$PG_BALANCE"
    status_info "Miner"     "$PG_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PG_RAM"
    status_info "Uptime"    "$PG_UPTIME"
    status_info "#Files"    "$PG_NUM_FILES"
    status_info "TCP Ports" "$PG_TCP_LISTEN"
    status_info "#TCP"      "$PG_NUM_TCPS"
    status_info "UDP Ports" "$PG_UDP_LISTEN"
    status_info "#Peers"    "$PG_NUM_PEERS"
    status_info "Height"    "$PG_HEIGHT"
    echo
}

esc_compress_log()
{
    compress_log $SCRIPT_PATH/esc/data/geth/logs/dpos
    compress_log $SCRIPT_PATH/esc/data/logs-spv
    compress_log $SCRIPT_PATH/esc/logs
}

esc_remove_log()
{
    remove_log $SCRIPT_PATH/esc/data/geth/logs/dpos
    remove_log $SCRIPT_PATH/esc/data/logs-spv
    remove_log $SCRIPT_PATH/esc/logs
}


eco_compress_log()
{
    compress_log $SCRIPT_PATH/eco/data/eco/logs/dpos
    compress_log $SCRIPT_PATH/eco/data/logs-spv
    compress_log $SCRIPT_PATH/eco/logs
}


pgp_compress_log()
{
    compress_log $SCRIPT_PATH/pgp/data/pgp/logs/dpos
    compress_log $SCRIPT_PATH/pgp/data/logs-spv
    compress_log $SCRIPT_PATH/pgp/logs
}

pg_compress_log()
{
    compress_log $SCRIPT_PATH/pg/data/pg/logs/dpos
    compress_log $SCRIPT_PATH/pg/data/logs-spv
    compress_log $SCRIPT_PATH/pg/logs
}

eco_remove_log()
{
    remove_log $SCRIPT_PATH/eco/data/eco/logs/dpos
    remove_log $SCRIPT_PATH/eco/data/logs-spv
    remove_log $SCRIPT_PATH/eco/logs
}

pgp_remove_log()
{
    remove_log $SCRIPT_PATH/pgp/data/pgp/logs/dpos
    remove_log $SCRIPT_PATH/pgp/data/logs-spv
    remove_log $SCRIPT_PATH/pgp/logs
}


pg_remove_log()
{
    remove_log $SCRIPT_PATH/pg/data/pg/logs/dpos
    remove_log $SCRIPT_PATH/pg/data/logs-spv
    remove_log $SCRIPT_PATH/pg/logs
}

esc_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage esc esc
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/esc
    local DIR_DEPLOY=$SCRIPT_PATH/esc

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ $PID ]; then
        esc_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/esc $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        esc_start
    fi
}

# eco_purge: the ECO side chain is decommissioned network-wide. Stop eco + eco-oracle
# and DELETE their data - only when ECO actually exists on this node. The eco keystore
# and its password file are backed up to a tarball first.
eco_purge()
{
    local found= ans ts bk note_tgt=
    [ -d $SCRIPT_PATH/eco ] && found=1
    [ -d $SCRIPT_PATH/eco-oracle ] && found=1
    [ -f ~/.config/elastos/eco.txt ] && found=1
    pgrep -f '^\./eco .*--rpc ' 1>/dev/null 2>&1 && found=1
    pgrep -fx 'node crosschain_eco.js' 1>/dev/null 2>&1 && found=1
    if [ -z "$found" ]; then
        echo "eco is not installed on this node - nothing to remove."
        return 0
    fi

    ui_bold "Remove the decommissioned ECO side chain"; echo
    echo "  This will stop eco + eco-oracle and DELETE:"
    [ -d $SCRIPT_PATH/eco ]          && echo "    $SCRIPT_PATH/eco  ($(du -sh $SCRIPT_PATH/eco 2>/dev/null | cut -f1))"
    [ -d $SCRIPT_PATH/eco-oracle ]   && echo "    $SCRIPT_PATH/eco-oracle"
    [ -f ~/.config/elastos/eco.txt ] && echo "    ~/.config/elastos/eco.txt"
    echo "  The eco keystore + password file are backed up first."
    echo
    if [ "$1" != "--yes" ] && [ "$1" != "-y" ]; then
        if noninteractive; then echo_error "refusing to delete unattended - re-run '$SCRIPT_NAME eco purge --yes'"; return 1; fi
        read -p "Type 'eco' to confirm deletion: " ans
        [ "$ans" == "eco" ] || { echo "Aborted - nothing changed."; return 1; }
    fi

    eco_stop 2>/dev/null
    eco-oracle_stop 2>/dev/null

    ts=$(date '+%F-%H%M%S')
    bk=~/eco-keystore-backup-$ts.tar.gz
    if [ -d $SCRIPT_PATH/eco/data/keystore ] || [ -f ~/.config/elastos/eco.txt ]; then
        if ! tar -czf "$bk" \
            $( [ -d $SCRIPT_PATH/eco/data/keystore ] && echo "$SCRIPT_PATH/eco/data/keystore" ) \
            $( [ -f ~/.config/elastos/eco.txt ] && echo "$HOME/.config/elastos/eco.txt" ) 2>/dev/null; then
            echo_error "keystore backup failed - NOT deleting anything"
            rm -f "$bk"
            return 1
        fi
        chmod 600 "$bk"
        echo_ok "keystore backed up: $bk"
    fi

    # if the data dir was relocated via a symlink, deleting eco/ leaves the target behind
    if [ -L $SCRIPT_PATH/eco/data ]; then
        note_tgt=$(readlink "$SCRIPT_PATH/eco/data" 2>/dev/null)
    fi

    rm -rf $SCRIPT_PATH/eco $SCRIPT_PATH/eco-oracle
    rm -f ~/.config/elastos/eco.txt
    echo_ok "eco + eco-oracle removed"
    [ -n "$note_tgt" ] && echo "  note: eco/data was a symlink to $note_tgt - remove that directory manually to reclaim the space"
    return 0
}

eco_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eco eco
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eco
    local DIR_DEPLOY=$SCRIPT_PATH/eco

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ $PID ]; then
        eco_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/eco $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eco_start
    fi
}

pgp_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pgp pgp
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pgp
    local DIR_DEPLOY=$SCRIPT_PATH/pgp

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ $PID ]; then
        pgp_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/pgp $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pgp_start
    fi
}

pg_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pg pg
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pg
    local DIR_DEPLOY=$SCRIPT_PATH/pg

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ $PID ]; then
        pg_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/pg $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pg_start
    fi
}


esc_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local ESC_KEYSTORE=
    local ESC_KEYSTORE_PASS_FILE=~/.config/elastos/esc.txt

    if [ ! -f ${SCRIPT_PATH}/esc/esc ]; then
        esc_update -y
    fi

    if [ -f $SCRIPT_PATH/esc/.init ]; then
        echo_error "esc has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/esc
    local ESC_NUM_ACCOUNTS=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $ESC_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "esc keystore file exist"
        return
    fi

    if [ -f "$ESC_KEYSTORE_PASS_FILE" ]; then
        echo_error "$ESC_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating esc keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving esc keystore password..."
    mkdir -p $(dirname $ESC_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ESC_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ESC_KEYSTORE_PASS_FILE
    chmod 600 $ESC_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/esc
    ./esc --datadir "$SCRIPT_PATH/esc/data/" --verbosity 0 account new \
        --password "$ESC_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create esc keystore"
        return
    fi

    echo "Checking esc keystore..."
    local ESC_KEYSTORE=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $ESC_KEYSTORE

    local ESC_MINER_ADDRESS_FILE=$SCRIPT_PATH/esc/data/miner_address.txt
    echo "You can input an alternative esc reward address. (ENTER to skip)"
    local ESC_MINER_ADDRESS=
    read -p '? Miner Address: ' ESC_MINER_ADDRESS
    if [ "$ESC_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/esc/data
        echo $ESC_MINER_ADDRESS | tee $ESC_MINER_ADDRESS_FILE
        chmod 600 $ESC_MINER_ADDRESS_FILE
    fi

    echo_info "esc keystore file: $ESC_KEYSTORE"
    echo_info "esc keystore password file: $ESC_KEYSTORE_PASS_FILE"
    if [ -f $ESC_MINER_ADDRESS_FILE ]; then
        echo_info "esc miner address file: $ESC_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/esc/.init
    echo_ok "esc initialized"
    echo
}
eco_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local ECO_KEYSTORE=
    local ECO_KEYSTORE_PASS_FILE=~/.config/elastos/eco.txt

    if [ ! -f ${SCRIPT_PATH}/eco/eco ]; then
        eco_update -y
    fi

    if [ -f $SCRIPT_PATH/eco/.init ]; then
        echo_error "eco has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/eco
    local ECO_NUM_ACCOUNTS=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $ECO_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "eco keystore file exist"
        return
    fi

    if [ -f "$ECO_KEYSTORE_PASS_FILE" ]; then
        echo_error "$ECO_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating eco keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving eco keystore password..."
    mkdir -p $(dirname $ECO_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ECO_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ECO_KEYSTORE_PASS_FILE
    chmod 600 $ECO_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/eco
    ./eco --datadir "$SCRIPT_PATH/eco/data/" --verbosity 0 account new \
        --password "$ECO_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create eco keystore"
        return
    fi

    echo "Checking eco keystore..."
    local ECO_KEYSTORE=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $ECO_KEYSTORE

    local ECO_MINER_ADDRESS_FILE=$SCRIPT_PATH/eco/data/miner_address.txt
    echo "You can input an alternative eco reward address. (ENTER to skip)"
    local ECO_MINER_ADDRESS=
    read -p '? Miner Address: ' ECO_MINER_ADDRESS
    if [ "$ECO_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/eco/data
        echo $ECO_MINER_ADDRESS | tee $ECO_MINER_ADDRESS_FILE
        chmod 600 $ECO_MINER_ADDRESS_FILE
    fi

    echo_info "eco keystore file: $ECO_KEYSTORE"
    echo_info "eco keystore password file: $ECO_KEYSTORE_PASS_FILE"
    if [ -f $ECO_MINER_ADDRESS_FILE ]; then
        echo_info "eco miner address file: $ECO_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/eco/.init
    echo_ok "eco initialized"
    echo
}

pgp_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local PGP_KEYSTORE=
    local PGP_KEYSTORE_PASS_FILE=~/.config/elastos/pgp.txt

    if [ ! -f ${SCRIPT_PATH}/pgp/pgp ]; then
        pgp_update -y
    fi

    if [ -f $SCRIPT_PATH/pgp/.init ]; then
        echo_error "pgp has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/pgp
    local PGP_NUM_ACCOUNTS=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $PGP_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "pgp keystore file exist"
        return
    fi

    if [ -f "$PGP_KEYSTORE_PASS_FILE" ]; then
        echo_error "$PGP_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating pgp keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving pgp keystore password..."
    mkdir -p $(dirname $PGP_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $PGP_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $PGP_KEYSTORE_PASS_FILE
    chmod 600 $PGP_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/pgp
    ./pgp --datadir "$SCRIPT_PATH/pgp/data/" --verbosity 0 account new \
        --password "$PGP_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create pgp keystore"
        return
    fi

    echo "Checking pgp keystore..."
    local PGP_KEYSTORE=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $PGP_KEYSTORE

    local PGP_MINER_ADDRESS_FILE=$SCRIPT_PATH/pgp/data/miner_address.txt
    echo "You can input an alternative pgp reward address. (ENTER to skip)"
    local PGP_MINER_ADDRESS=
    read -p '? Miner Address: ' PGP_MINER_ADDRESS
    if [ "$PGP_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/pgp/data
        echo $PGP_MINER_ADDRESS | tee $PGP_MINER_ADDRESS_FILE
        chmod 600 $PGP_MINER_ADDRESS_FILE
    fi

    echo_info "pgp keystore file: $PGP_KEYSTORE"
    echo_info "pgp keystore password file: $PGP_KEYSTORE_PASS_FILE"
    if [ -f $PGP_MINER_ADDRESS_FILE ]; then
        echo_info "pgp miner address file: $PGP_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/pgp/.init
    echo_ok "pgp initialized"
    echo
}

pg_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local PG_KEYSTORE=
    local PG_KEYSTORE_PASS_FILE=~/.config/elastos/pg.txt

    if [ ! -f ${SCRIPT_PATH}/pg/pg ]; then
        pg_update -y
    fi

    if [ -f $SCRIPT_PATH/pg/.init ]; then
        echo_error "pg has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/pg
    local PG_NUM_ACCOUNTS=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $PG_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "pg keystore file exist"
        return
    fi

    if [ -f "$PG_KEYSTORE_PASS_FILE" ]; then
        echo_error "$PG_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating pg keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving pg keystore password..."
    mkdir -p $(dirname $PG_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $PG_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $PG_KEYSTORE_PASS_FILE
    chmod 600 $PG_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/pg
    ./pg --datadir "$SCRIPT_PATH/pg/data/" --verbosity 0 account new \
        --password "$PG_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create pg keystore"
        return
    fi

    echo "Checking pg keystore..."
    local PG_KEYSTORE=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $PG_KEYSTORE

    local PG_MINER_ADDRESS_FILE=$SCRIPT_PATH/pg/data/miner_address.txt
    echo "You can input an alternative pg reward address. (ENTER to skip)"
    local PG_MINER_ADDRESS=
    read -p '? Miner Address: ' PG_MINER_ADDRESS
    if [ "$PG_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/pg/data
        echo $PG_MINER_ADDRESS | tee $PG_MINER_ADDRESS_FILE
        chmod 600 $PG_MINER_ADDRESS_FILE
    fi

    echo_info "pg keystore file: $PG_KEYSTORE"
    echo_info "pg keystore password file: $PG_KEYSTORE_PASS_FILE"
    if [ -f $PG_MINER_ADDRESS_FILE ]; then
        echo_info "pg miner address file: $PG_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/pg/.init
    echo_ok "pg initialized"
    echo
}

esc_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME esc send FROM TO AMOUNT [FEE]"
        return
    fi

    local ESC_ADDR_FROM=$1
    local ESC_ADDR_TO=$2
    local ESC_AMOUNT=$3
    local ESC_FEE=$4

    if [ "$ESC_FEE" == "" ]; then
        local ESC_FEE=21000
    fi
    local ESC_GAS_PRICE=$(esc_client attach --exec "eth.gasPrice")
    local ESC_FEE_WEI=$(echo $ESC_FEE*$ESC_GAS_PRICE | bc)

    if [ "$ESC_AMOUNT" == "All" ]; then
        local ESC_AMOUNT_WEI=$(esc_client attach --exec "eth.getBalance('$ESC_ADDR_FROM')")
        local ESC_AMOUNT_WEI=$(echo "$ESC_AMOUNT_WEI-$ESC_FEE_WEI" | bc)
    else
        local ESC_AMOUNT_WEI=$(echo "$ESC_AMOUNT*10^18" | bc)
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ESC_ADDR_FROM:  $ESC_ADDR_FROM"
        echo "ESC_ADDR_TO:    $ESC_ADDR_TO"
        echo "ESC_AMOUNT:     $ESC_AMOUNT"
        echo "ESC_AMOUNT_WEI: $ESC_AMOUNT_WEI"
        echo "ESC_FEE:        $ESC_FEE"
        echo "ESC_GAS_PRICE:  $ESC_GAS_PRICE"
        echo "ESC_FEE_WEI:    $ESC_FEE_WEI"
    fi

    esc_client attach --exec "eth.sendTransaction({from:'$ESC_ADDR_FROM',to:'$ESC_ADDR_TO',value:$ESC_AMOUNT_WEI,gas:$ESC_FEE,gasPrice:$ESC_GAS_PRICE})"
}

#
# esc-oracle
#
esc-oracle_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
}

esc-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        echo_error "$SCRIPT_PATH/esc-oracle/crosschain_oracle.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" != "" ]; then
        esc-oracle_status
        return
    fi

    echo "Starting esc-oracle..."
    cd $SCRIPT_PATH/esc-oracle
    mkdir -p $SCRIPT_PATH/esc-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_oracle.js \
        2>$SCRIPT_PATH/esc-oracle/logs/esc-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    verify_started esc-oracle
    esc-oracle_status
}

eco-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        echo_error "$SCRIPT_PATH/eco-oracle/crosschain_eco.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" != "" ]; then
        eco-oracle_status
        return
    fi

    echo "Starting eco-oracle..."
    cd $SCRIPT_PATH/eco-oracle
    mkdir -p $SCRIPT_PATH/eco-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_eco.js \
        2>$SCRIPT_PATH/eco-oracle/logs/eco-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    verify_started eco-oracle
    eco-oracle_status
}

pgp-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        echo_error "$SCRIPT_PATH/pgp-oracle/crosschain_pgp.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" != "" ]; then
        pgp-oracle_status
        return
    fi

    echo "Starting pgp-oracle..."
    cd $SCRIPT_PATH/pgp-oracle
    mkdir -p $SCRIPT_PATH/pgp-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_pgp.js \
        2>$SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    verify_started pgp-oracle
    pgp-oracle_status
}

pg-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        echo_error "$SCRIPT_PATH/pg-oracle/crosschain_pg.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" != "" ]; then
        pg-oracle_status
        return
    fi

    echo "Starting pg-oracle..."
    cd $SCRIPT_PATH/pg-oracle
    mkdir -p $SCRIPT_PATH/pg-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_pg.js \
        2>$SCRIPT_PATH/pg-oracle/logs/pg-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/pg-oracle/logs/pg-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    verify_started pg-oracle
    pg-oracle_status
}

esc-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" != "" ]; then
        echo "Stopping esc-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    esc-oracle_status
}

eco-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" != "" ]; then
        echo "Stopping eco-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    eco-oracle_status
}

pgp-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" != "" ]; then
        echo "Stopping pgp-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    pgp-oracle_status
}

pg-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" != "" ]; then
        echo "Stopping pg-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    pg-oracle_status
}

esc-oracle_installed()
{
    if [ -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        true
    else
        false
    fi
}

eco-oracle_installed()
{
    if [ -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        true
    else
        false
    fi
}

pgp-oracle_installed()
{
    if [ -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        true
    else
        false
    fi
}

pg-oracle_installed()
{
    if [ -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        true
    else
        false
    fi
}

esc-oracle_ver()
{
    if [ -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        echo "esc-oracle $(cat $SCRIPT_PATH/esc-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "esc-oracle N/A"
    fi
}

eco-oracle_ver()
{
    if [ -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        echo "eco-oracle $(cat $SCRIPT_PATH/eco-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "eco-oracle N/A"
    fi
}

pgp-oracle_ver()
{
    if [ -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        echo "pgp-oracle $(cat $SCRIPT_PATH/pgp-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "pgp-oracle N/A"
    fi
}

pg-oracle_ver()
{
    if [ -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        echo "pg-oracle $(cat $SCRIPT_PATH/pg-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "pg-oracle N/A"
    fi
}

esc-oracle_status()
{
    local ESC_ORACLE_VER=$(esc-oracle_ver)

    local ESC_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/esc-oracle)

    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" == "" ]; then
        status_head $ESC_ORACLE_VER Stopped
        status_info "Disk" "$ESC_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local ESC_ORACLE_RAM=$(mem_usage $PID)
    local ESC_ORACLE_UPTIME=$(run_time $PID)
    local ESC_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local ESC_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local ESC_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $ESC_ORACLE_VER Running
    status_info "Disk"      "$ESC_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ESC_ORACLE_RAM"
    status_info "Uptime"    "$ESC_ORACLE_UPTIME"
    status_info "#Files"    "$ESC_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$ESC_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$ESC_ORACLE_NUM_TCPS"
    echo
}

eco-oracle_status()
{
    local ECO_ORACLE_VER=$(eco-oracle_ver)

    local ECO_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eco-oracle)

    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" == "" ]; then
        status_head $ECO_ORACLE_VER Stopped
        status_info "Disk" "$ECO_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local ECO_ORACLE_RAM=$(mem_usage $PID)
    local ECO_ORACLE_UPTIME=$(run_time $PID)
    local ECO_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local ECO_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local ECO_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $ECO_ORACLE_VER Running
    status_info "Disk"      "$ECO_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ECO_ORACLE_RAM"
    status_info "Uptime"    "$ECO_ORACLE_UPTIME"
    status_info "#Files"    "$ECO_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$ECO_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$ECO_ORACLE_NUM_TCPS"
    echo
}

pgp-oracle_status()
{
    local PGP_ORACLE_VER=$(pgp-oracle_ver)

    local PGP_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pgp-oracle)

    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" == "" ]; then
        status_head $PGP_ORACLE_VER Stopped
        status_info "Disk" "$PGP_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local PGP_ORACLE_RAM=$(mem_usage $PID)
    local PGP_ORACLE_UPTIME=$(run_time $PID)
    local PGP_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local PGP_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local PGP_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $PGP_ORACLE_VER Running
    status_info "Disk"      "$PGP_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PGP_ORACLE_RAM"
    status_info "Uptime"    "$PGP_ORACLE_UPTIME"
    status_info "#Files"    "$PGP_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$PGP_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$PGP_ORACLE_NUM_TCPS"
    echo
}

pg-oracle_status()
{
    local PG_ORACLE_VER=$(pg-oracle_ver)

    local PG_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pg-oracle)

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" == "" ]; then
        status_head $PG_ORACLE_VER Stopped
        status_info "Disk" "$PG_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local PG_ORACLE_RAM=$(mem_usage $PID)
    local PG_ORACLE_UPTIME=$(run_time $PID)
    local PG_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local PG_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local PG_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $PG_ORACLE_VER Running
    status_info "Disk"      "$PG_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PG_ORACLE_RAM"
    status_info "Uptime"    "$PG_ORACLE_UPTIME"
    status_info "#Files"    "$PG_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$PG_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$PG_ORACLE_NUM_TCPS"
    echo
}

esc-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
}

esc-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
}

eco-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-\*.log
}

eco-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-\*.log
}

pgp-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-\*.log
}

pg-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/pg-oracle/logs/pg-oracle_out-\*.log
}

pgp-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-\*.log
}

pg-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/pg-oracle/logs/pg-oracle_out-\*.log
}

pg-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pg-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pg-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/pg-oracle

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ $PID ]; then
        pg-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pg-oracle_start
    fi
}

esc-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/esc/.init ]; then
        echo_error "esc not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/esc-oracle/.init ]; then
        echo_error "esc-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        esc-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/esc-oracle
    cd $SCRIPT_PATH/esc-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/esc-oracle/.init
    echo_ok "esc-oracle initialized"
    echo
}

eco-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/eco/.init ]; then
        echo_error "eco not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/eco-oracle/.init ]; then
        echo_error "eco-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        eco-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/eco-oracle
    cd $SCRIPT_PATH/eco-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/eco-oracle/.init
    echo_ok "eco-oracle initialized"
    echo
}


pgp-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/pgp/.init ]; then
        echo_error "pgp not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/pgp-oracle/.init ]; then
        echo_error "pgp-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        pgp-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/pgp-oracle
    cd $SCRIPT_PATH/pgp-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/pgp-oracle/.init
    echo_ok "pgp-oracle initialized"
    echo
}

pg-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/pg/.init ]; then
        echo_error "pg not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/pg-oracle/.init ]; then
        echo_error "pg-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        pg-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/pg-oracle
    cd $SCRIPT_PATH/pg-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/pg-oracle/.init
    echo_ok "pg-oracle initialized"
    echo
}

#
# eid
#
eid_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo
}

eid_start()
{
    if [ ! -f $SCRIPT_PATH/eid/eid ]; then
        echo_error "$SCRIPT_PATH/eid/eid is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local EID_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local EID_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" != "" ]; then
        eid_status
        return
    fi

    echo "Starting eid..."
    cd $SCRIPT_PATH/eid

    if [ "$CHAIN_TYPE" == "testnet" ]; then
        if [ ! -f spvconfig.json ]; then
            cat >spvconfig.json <<EOF
{
  "Configuration": {
    "Magic": 2018101
  }
}
EOF
            chmod 600 spvconfig.json
        fi
    fi

    mkdir -p $SCRIPT_PATH/eid/logs/

    if [ -f ~/.config/elastos/eid.txt ]; then
        warn_hot_miner eid
        if [ -f $SCRIPT_PATH/eid/data/miner_address.txt ]; then
            local EID_OPTS="$EID_OPTS --pbft.miner.address $SCRIPT_PATH/eid/data/miner_address.txt"
        fi
        nohup $SHELL -c "./eid \
            $EID_OPTS \
            --datadir $SCRIPT_PATH/eid/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/eid.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20649 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool,pbft' \
            --rpcvhosts '*' \
            --syncmode full \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eid/logs/eid-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./eid \
            $EID_OPTS \
            --datadir $SCRIPT_PATH/eid/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '$(evm_rpc_bind)' \
            --rpcapi 'eth,net,web3,txpool' \
            --rpcvhosts '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eid/logs/eid-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    verify_started eid
    eid_status
}

eid_stop()
{
    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping eid..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    eid_status
}

eid_installed()
{
    if [ -f $SCRIPT_PATH/eid/eid ]; then
        true
    else
        false
    fi
}

eid_ver()
{
    if [ -f $SCRIPT_PATH/eid/eid ]; then
        echo "eid $($SCRIPT_PATH/eid/eid version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "eid N/A"
    fi
}

eid_client()
{
    if [ ! -f $SCRIPT_PATH/eid/eid ]; then
        echo_error "$SCRIPT_PATH/eid/eid is not exist"
        return
    fi

    cd $SCRIPT_PATH/eid
    if [ "$1" == "" ]; then
        ./eid --datadir $SCRIPT_PATH/eid/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/eid/data/geth.ipc ]; then
        return
    else
        ./eid --datadir $SCRIPT_PATH/eid/data --nousb $*
    fi
}

eid_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20646 | jq .
}

eid_status()
{
    local EID_VER=$(eid_ver)

    local EID_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eid)

    if [ -f ~/.config/elastos/eid.txt ]; then
        cd $SCRIPT_PATH/eid
        local EID_KEYSTORE=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $EID_KEYSTORE ] && [ -f $EID_KEYSTORE ]; then
            local EID_ADDRESS=0x$(cat $EID_KEYSTORE | jq -r .address)
        else
            local EID_ADDRESS=N/A
        fi
    else
        local EID_ADDRESS=N/A
    fi

    local EID_MINER_ADDRESS=$(cat $SCRIPT_PATH/eid/data/miner_address.txt 2>/dev/null)
    if [ "$EID_MINER_ADDRESS" == "" ]; then
        local EID_MINER_ADDRESS=$EID_ADDRESS
    fi

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $EID_VER  Stopped
        status_info "Disk"    "$EID_DISK_USAGE"
        status_info "Address" "$EID_ADDRESS"
        echo
        return
    fi

    local EID_RAM=$(mem_usage $PID)
    local EID_UPTIME=$(run_time $PID)
    local EID_NUM_TCPS=$(num_tcps $PID)
    local EID_TCP_LISTEN=$(list_tcp $PID)
    local EID_UDP_LISTEN=$(list_udp $PID)
    local EID_NUM_FILES=$(num_files $PID)

    local EID_NUM_PEERS=$(eid_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    EID_NUM_PEERS=$(hex_to_dec "$EID_NUM_PEERS")
    if [[ ! "$EID_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        EID_NUM_PEERS=N/A
    fi
    local EID_HEIGHT=$(eid_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    EID_HEIGHT=$(hex_to_dec "$EID_HEIGHT")
    if [[ ! "$EID_HEIGHT" =~ ^[0-9]+$ ]]; then
        EID_HEIGHT=N/A
    fi

    local EID_BALANCE=$(eid_client \
        attach --exec "web3.fromWei(eth.getBalance('$EID_ADDRESS'),'ether')")
    if [ "$EID_BALANCE" == "" ]; then
        EID_BALANCE=N/A
    elif [[ $EID_BALANCE =~ [^.0-9e-] ]]; then
        EID_BALANCE=N/A
    fi

    status_head $EID_VER Running
    status_info "Disk"      "$EID_DISK_USAGE"
    status_info "Address"   "$EID_ADDRESS"
    status_info "Balance"   "$EID_BALANCE"
    status_info "Miner"     "$EID_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$EID_RAM"
    status_info "Uptime"    "$EID_UPTIME"
    status_info "#Files"    "$EID_NUM_FILES"
    status_info "TCP Ports" "$EID_TCP_LISTEN"
    status_info "#TCP"      "$EID_NUM_TCPS"
    status_info "UDP Ports" "$EID_UDP_LISTEN"
    status_info "#Peers"    "$EID_NUM_PEERS"
    status_info "Height"    "$EID_HEIGHT"
    echo
}

eid_compress_log()
{
    compress_log $SCRIPT_PATH/eid/data/geth/logs/dpos
    compress_log $SCRIPT_PATH/eid/data/logs-spv
    compress_log $SCRIPT_PATH/eid/logs
}

eid_remove_log()
{
    remove_log $SCRIPT_PATH/eid/data/geth/logs/dpos
    remove_log $SCRIPT_PATH/eid/data/logs-spv
    remove_log $SCRIPT_PATH/eid/logs
}

eid_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eid eid
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eid
    local DIR_DEPLOY=$SCRIPT_PATH/eid

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ $PID ]; then
        eid_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/eid $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eid_start
    fi
}

eid_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local EID_KEYSTORE=
    local EID_KEYSTORE_PASS_FILE=~/.config/elastos/eid.txt

    if [ ! -f ${SCRIPT_PATH}/eid/eid ]; then
        eid_update -y
    fi

    if [ -f $SCRIPT_PATH/eid/.init ]; then
        echo_error "eid has already been initialized"
        return
    fi

    cd ${SCRIPT_PATH}/eid
    local EID_NUM_ACCOUNTS=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $EID_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "eid keystore file exist"
        return
    fi

    if [ -f "$EID_KEYSTORE_PASS_FILE" ]; then
        echo_error "$EID_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating eid keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving eid keystore password..."
    mkdir -p $(dirname $EID_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $EID_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $EID_KEYSTORE_PASS_FILE
    chmod 600 $EID_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/eid
    ./eid --datadir "$SCRIPT_PATH/eid/data/" --verbosity 0 account new \
        --password "$EID_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create eid keystore"
        return
    fi

    echo "Checking eid keystore..."
    local EID_KEYSTORE=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $EID_KEYSTORE

    local EID_MINER_ADDRESS_FILE=$SCRIPT_PATH/eid/data/miner_address.txt
    echo "You can input an alternative eid reward address. (ENTER to skip)"
    local EID_MINER_ADDRESS=
    read -p '? Miner Address: ' EID_MINER_ADDRESS
    if [ "$EID_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/eid/data
        echo $EID_MINER_ADDRESS | tee $EID_MINER_ADDRESS_FILE
        chmod 600 $EID_MINER_ADDRESS_FILE
    fi

    echo_info "eid keystore file: $EID_KEYSTORE"
    echo_info "eid keystore password file: $EID_KEYSTORE_PASS_FILE"
    if [ -f $EID_MINER_ADDRESS_FILE ]; then
        echo_info "eid miner address file: $EID_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/eid/.init
    echo_ok "eid initialized"
    echo
}

eid_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME eid send FROM TO AMOUNT [FEE]"
        return
    fi

    local EID_ADDR_FROM=$1
    local EID_ADDR_TO=$2
    local EID_AMOUNT=$3
    local EID_FEE=$4

    if [ "$EID_FEE" == "" ]; then
        local EID_FEE=21000
    fi
    local EID_GAS_PRICE=$(eid_client attach --exec "eth.gasPrice")
    local EID_FEE_WEI=$(echo $EID_FEE*$EID_GAS_PRICE | bc)

    if [ "$EID_AMOUNT" == "All" ]; then
        local EID_AMOUNT_WEI=$(eid_client attach --exec "eth.getBalance('$EID_ADDR_FROM')")
        local EID_AMOUNT_WEI=$(echo "$EID_AMOUNT_WEI-$EID_FEE_WEI" | bc)
    else
        local EID_AMOUNT_WEI=$(echo "$EID_AMOUNT*10^18" | bc)
    fi

    if [ "$IS_DEBUG" ]; then
        echo "EID_ADDR_FROM:  $EID_ADDR_FROM"
        echo "EID_ADDR_TO:    $EID_ADDR_TO"
        echo "EID_AMOUNT:     $EID_AMOUNT"
        echo "EID_AMOUNT_WEI: $EID_AMOUNT_WEI"
        echo "EID_FEE:        $EID_FEE"
        echo "EID_GAS_PRICE:  $EID_GAS_PRICE"
        echo "EID_FEE_WEI:    $EID_FEE_WEI"
    fi

    eid_client attach --exec "eth.sendTransaction({from:'$EID_ADDR_FROM',to:'$EID_ADDR_TO',value:$EID_AMOUNT_WEI,gas:$EID_FEE,gasPrice:$EID_GAS_PRICE})"
}

#
# eid-oracle
#
eid-oracle_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
}

eid-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        echo_error "$SCRIPT_PATH/eid-oracle/crosschain_eid.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" != "" ]; then
        eid-oracle_status
        return
    fi

    echo "Starting eid-oracle..."
    cd $SCRIPT_PATH/eid-oracle
    mkdir -p $SCRIPT_PATH/eid-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_eid.js \
        2>$SCRIPT_PATH/eid-oracle/logs/eid-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    verify_started eid-oracle
    eid-oracle_status
}

eid-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" != "" ]; then
        echo "Stopping eid-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    eid-oracle_status
}

eid-oracle_installed()
{
    if [ -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        true
    else
        false
    fi
}

eid-oracle_ver()
{
    if [ -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        echo "eid-oracle $(cat $SCRIPT_PATH/eid-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "eid-oracle N/A"
    fi
}

eid-oracle_status()
{
    local EID_ORACLE_VER=$(eid-oracle_ver)

    local EID_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eid-oracle)

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" == "" ]; then
        status_head $EID_ORACLE_VER Stopped
        status_info "Disk" "$EID_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local EID_ORACLE_RAM=$(mem_usage $PID)
    local EID_ORACLE_UPTIME=$(run_time $PID)
    local EID_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local EID_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local EID_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $EID_ORACLE_VER Running
    status_info "Disk"      "$EID_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$EID_ORACLE_RAM"
    status_info "Uptime"    "$EID_ORACLE_UPTIME"
    status_info "#Files"    "$EID_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$EID_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$EID_ORACLE_NUM_TCPS"
    echo
}

eid-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-\*.log
}

eid-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-\*.log
}

eid-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eid-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eid-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/eid-oracle

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ $PID ]; then
        eid-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eid-oracle_start
    fi
}

eid-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/eid/.init ]; then
        echo_error "eid not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/eid-oracle/.init ]; then
        echo_error "eid-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        eid-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/eid-oracle
    cd $SCRIPT_PATH/eid-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/eid-oracle/.init
    echo_ok "eid-oracle initialized"
    echo
}

#
# arbiter
#
arbiter_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
}

arbiter_start()
{
    if [ ! -f $SCRIPT_PATH/arbiter/arbiter ]; then
        echo_error "$SCRIPT_PATH/arbiter/arbiter is not exist"
        return
    fi

    local PID=$(pgrep -x arbiter)
    if [ "$PID" != "" ]; then
        arbiter_status
        return
    fi

    echo "Starting arbiter..."
    cd $SCRIPT_PATH/arbiter

    until pgrep -x arbiter 1>/dev/null; do
        if [ -f ~/.config/elastos/ela.txt ]; then
            cat ~/.config/elastos/ela.txt | nohup ./arbiter 1>/dev/null 2>output &
        else
            nohup ./arbiter 1>/dev/null 2>output &
        fi
        echo "Waiting for ela, esc-oracle, eid-oracle, eco-oracle to start..."
        sleep 5
    done

    arbiter_status
}

arbiter_stop()
{
    local PID=$(pgrep -x arbiter)
    if [ "$PID" != "" ]; then
        echo "Stopping arbiter..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    arbiter_status
}

arbiter_installed()
{
    if [ -f $SCRIPT_PATH/arbiter/arbiter ]; then
        true
    else
        false
    fi
}

arbiter_ver()
{
    if [ -f $SCRIPT_PATH/arbiter/arbiter ]; then
        echo "arbiter $($SCRIPT_PATH/arbiter/arbiter -v 2>&1 | sed 's/.* //')"
    else
        echo "arbiter N/A"
    fi
}

arbiter_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    local ARBITER_RPC_USER=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ARBITER_RPC_PASS=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ARBITER_RPC_PORT=20536
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ARBITER_RPC_PORT=21536
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    if [[ $1 =~ ^[a-z]+$ ]] && [ "$2" == "" ]; then
        local DATA={\"method\":\"$1\"}
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data $DATA \
        -u $ARBITER_RPC_USER:$ARBITER_RPC_PASS \
        http://127.0.0.1:$ARBITER_RPC_PORT | jq .
}

arbiter_status()
{
    local ARBITER_VER=$(arbiter_ver)

    local ARBITER_DISK_USAGE=$(disk_usage $SCRIPT_PATH/arbiter)

    local PID=$(pgrep -x arbiter)
    if [ "$PID" == "" ]; then
        status_head $ARBITER_VER Stopped
        status_info "Disk" "$ARBITER_DISK_USAGE"
        echo
        return
    fi

    local ARBITER_RAM=$(mem_usage $PID)
    local ARBITER_UPTIME=$(run_time $PID)
    local ARBITER_NUM_TCPS=$(num_tcps $PID)
    local ARBITER_TCP_LISTEN=$(list_tcp $PID)
    local ARBITER_NUM_FILES=$(num_files $PID)

    local ARBITER_SPV_HEIGHT=$(arbiter_jsonrpc '{"method":"getspvheight"}' | jq -r '.result')
    if [[ ! "$ARBITER_SPV_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_SPV_HEIGHT=N/A
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ESC_GENESIS=6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ESC_GENESIS=698e5ec133064dabb7c42eb4b2bdfa21e7b7c2326b0b719d5ab7f452ae8f5ee4
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_ESC_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$ESC_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_ESC_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_ESC_HEIGHT=N/A
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local EID_GENESIS=7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local EID_GENESIS=3d0f9da9320556f6d58129419e041de28cf515eedc6b59f8dae49df98e3f943c
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_EID_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$EID_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_EID_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_EID_HEIGHT=N/A
    fi

    # linda 添加ECO
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ECO_GENESIS=02820c5adc8ee4fb77aad842ac05d95ed8b1041d80c03ba79f8f11c4af60d87c
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ECO_GENESIS=3043bcc03c90a37a292a4357ee972bc392b143e75e1b79205e113688e3bd071b
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_ECO_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$ECO_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_ECO_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_ECO_HEIGHT=N/A
    fi
    # linda 添加

    # linda 添加PGP

    #if [ "$CHAIN_TYPE" == "mainnet" ]; then
    #    local PGP_GENESIS=00b7957fbc9fa62e86d6e664299bebc9a939f108fd015f8de07ce33f4136175e
    #elif [ "$CHAIN_TYPE" == "testnet" ]; then
    #    local PGP_GENESIS=0c2785b9c5bee92aaaa3d8e5a7a579347a9091c6c8c19b7cba7fac69519c58a1
    #else
    #    echo_error "do not support $CHAIN_TYPE"
    #    return
    #fi
    #local ARBITER_PGP_HEIGHT=$(arbiter_jsonrpc \
    #    "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$PGP_GENESIS\"}}" \
    #    | jq -r '.result')
    #if [[ ! "$ARBITER_PGP_HEIGHT" =~ ^[0-9]+$ ]]; then
    #    ARBITER_PGP_HEIGHT=N/A
    #fi

    # linda 添加

    # linda 添加PG
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PG_GENESIS=aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PG_GENESIS=aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_PG_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$PG_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_PG_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_PG_HEIGHT=N/A
    fi
    # linda 添加

    status_head $ARBITER_VER Running
    status_info "Disk"       "$ARBITER_DISK_USAGE"
    status_info "PID"        "$PID"
    status_info "RAM"        "$ARBITER_RAM"
    status_info "Uptime"     "$ARBITER_UPTIME"
    status_info "#Files"     "$ARBITER_NUM_FILES"
    status_info "TCP Ports"  "$ARBITER_TCP_LISTEN"
    status_info "#TCP"       "$ARBITER_NUM_TCPS"
    status_info "SPV Height" "$ARBITER_SPV_HEIGHT"
    status_info "ESC Height" "$ARBITER_ESC_HEIGHT"
    status_info "EID Height" "$ARBITER_EID_HEIGHT"
    # linda 添加
    status_info "ECO Height" "$ARBITER_ECO_HEIGHT"
    # linda 添加
    #status_info "PGP Height" "$ARBITER_PGP_HEIGHT"
    # linda 添加
    status_info "PG Height" "$ARBITER_PG_HEIGHT"
    echo
}

arbiter_compress_log()
{
    compress_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/arbiter
    compress_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/spv
}

arbiter_remove_log()
{
    remove_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/arbiter
    remove_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/spv
}

arbiter_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage arbiter arbiter
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/arbiter
    local DIR_DEPLOY=$SCRIPT_PATH/arbiter

    local PID=$(pgrep -x arbiter)
    if [ $PID ]; then
        arbiter_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/arbiter $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        arbiter_start
    fi
}

arbiter_modify_configfile()
{

  local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json
  local ARBITER_PGP_CONFIG=${SCRIPT_PATH}/arbiter/pgp_config.json
  local ARBITER_PG_CONFIG=${SCRIPT_PATH}/arbiter/pg_config.json

  if [ ! -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG not exists"
        return
  fi

  if grep -qi "20672" "$ARBITER_CONFIG"; then
        echo "config file have PG sidechain configuration"
        return
  fi
  
  echo "stop arbiter node"
  local PID=$(pgrep -x arbiter)
  if [ $PID ]; then
        arbiter_stop
  fi

  echo "backup arbiter config file..."
  cp -v ${SCRIPT_PATH}/arbiter/config.json ${SCRIPT_PATH}/arbiter/config_backup_add_pg_before_2025_11_2.json
  echo "modify arbiter config file..."
  if [ "$CHAIN_TYPE" == "testnet" ]; then
    echo "add testnet pg config"
    jq '.Configuration.SideNodeList += [{
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "ExchangeRate": 1,
        "SyncStartHeight":0,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "PowChain": false,
        "Name": "PG",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false
    }]' $ARBITER_CONFIG > $ARBITER_PG_CONFIG && mv $ARBITER_PG_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  else
    echo "add mainnet pg config"
    jq '.Configuration.SideNodeList += [{
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight":0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
    }]' $ARBITER_CONFIG > $ARBITER_PG_CONFIG && mv $ARBITER_PG_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  fi
  echo_ok "arbiter add PG config completedly"
}

arbiter_remove_sidechain_config()
{

  local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json
  local ARBITER_PGP_CONFIG=${SCRIPT_PATH}/arbiter/pgp_config.json

  if [ ! -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG not exists"
        return
  fi

  if ! grep -qi "20662" "$ARBITER_CONFIG"; then
      echo "config file have not PGP sidechain configuration"
      return
  fi

  echo "stop arbiter node"

  local PID=$(pgrep -x arbiter)
  if [ $PID ]; then
        arbiter_stop
  fi

  echo "backup arbiter config file..."
  cp -v ${SCRIPT_PATH}/arbiter/config.json ${SCRIPT_PATH}/arbiter/config_backup_remove_pgp_before_2025_11_11.json

  echo "modify arbiter config file..."

  if [ "$CHAIN_TYPE" == "testnet" ]; then
      echo "testnet do nothing"
  else
      echo "Remove mainnet pgp config"
      jq 'del(.Configuration.SideNodeList[] | select(.Name == "PGP"))' $ARBITER_CONFIG > $ARBITER_PGP_CONFIG && mv $ARBITER_PGP_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  fi

  echo_ok "arbiter Remove PGP config completedly"
}



arbiter_init()
{
    if [ ! -f $SCRIPT_PATH/ela/.init ]; then
        echo_error "ela not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/esc-oracle/.init ]; then
        echo_error "esc-oracle not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/eid-oracle/.init ]; then
        echo_error "eid-oracle not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/pg-oracle/.init ]; then
        echo_error "pg-oracle not initialized"
        return
    fi


    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json

    if [ ! -f ${SCRIPT_PATH}/arbiter/arbiter ]; then
        arbiter_update -y
    fi

    if [ -f $SCRIPT_PATH/arbiter/.init ]; then
        echo_error "arbiter has already been initialized"
        return
    fi

    if [ -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG exists"
        return
    fi

    echo "Creating arbiter config file..."
    if [ "$CHAIN_TYPE" == "testnet" ]; then
        cat >$ARBITER_CONFIG <<EOF
{
  "Configuration": {
    "ActiveNet": "testnet",
    "MainNode": {
      "Rpc": {
        "IpAddress": "127.0.0.1",
        "HttpJsonPort": 21336,
        "User": "",
        "Pass": ""
      },
      "Magic": 2050102
    },
    "SideNodeList": [
      {
        "Name": "ESC",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 17058000,
        "ExchangeRate": 1,
        "GenesisBlock": "698e5ec133064dabb7c42eb4b2bdfa21e7b7c2326b0b719d5ab7f452ae8f5ee4",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": true,
        "PowChain": false
      },
      {
        "Name": "EID",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20642
        },
        "SyncStartHeight": 9230000,
        "ExchangeRate": 1,
        "GenesisBlock": "3d0f9da9320556f6d58129419e041de28cf515eedc6b59f8dae49df98e3f943c",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "PowChain": false
      },
      {
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      }
    ],
    "RpcConfiguration": {
      "User": "",
      "Pass": "",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
    else
        cat >$ARBITER_CONFIG <<EOF
{
  "Configuration": {
    "MainNode": {
      "Rpc": {
        "IpAddress": "127.0.0.1",
        "HttpJsonPort": 20336,
        "User": "",
        "Pass": ""
      }
    },
    "SideNodeList": [
      {
        "Name": "ESC",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 17886000,
        "ExchangeRate": 1,
        "GenesisBlock": "6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": true,
        "PowChain": false
      },
      {
        "Name": "EID",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20642
        },
        "SyncStartHeight": 9611000,
        "ExchangeRate": 1,
        "GenesisBlock": "7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "PowChain": false
      },
      {
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      }
    ],
    "RpcConfiguration": {
      "User": "",
      "Pass": "",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
    fi

    cd ${SCRIPT_PATH}/arbiter/
    ln -s ../ela/ela-cli

    echo "Copying ela keystore..."
    cp -v ${SCRIPT_PATH}/ela/keystore.dat ${SCRIPT_PATH}/arbiter/
    #ln -s ../ela/keystore.dat
    local KEYSTORE_PASS=$(cat ~/.config/elastos/ela.txt)

    #./ela-cli wallet account -p "$KEYSTORE_PASS"

    echo "Updating arbiter config file..."

    # Arbiter Config: ELA
    local ELA_RPC_USER=$(cat $ELA_CONFIG | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $ELA_CONFIG | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    # Arbiter Config: Arbiter RPC
    echo "Generating random userpass for arbiter RPC interface..."
    local ARBITER_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local ARBITER_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

    echo "Updating arbiter config file..."
    jq ".Configuration.MainNode.Rpc.User=\"$ELA_RPC_USER\"              | \
        .Configuration.MainNode.Rpc.Pass=\"$ELA_RPC_PASS\"              | \
        .Configuration.RpcConfiguration.User=\"$ARBITER_RPC_USER\"      | \
        .Configuration.RpcConfiguration.Pass=\"$ARBITER_RPC_PASS\"" \
        $ARBITER_CONFIG >$ARBITER_CONFIG.tmp

    if [ "$?" == "0" ]; then
        mv $ARBITER_CONFIG.tmp $ARBITER_CONFIG
    fi

    echo_info "arbiter config file: $ARBITER_CONFIG"

    touch ${SCRIPT_PATH}/arbiter/.init
    echo_ok "arbiter initialized"
    echo
}

# chain_help <chain>: the real per-chain command list (replaces the stale *_usage).
chain_help()
{
    local chain=$1
    echo "Usage:  $SCRIPT_NAME $chain <command> [options]"
    echo
    echo "  start   stop   restart   status [--json]   health   logs [-f]"
    echo "  client   rpc   init   update   version"
    case "$chain" in
        ela)
            echo "  send           transfer"
            echo "  governance:    register-bpos activate-bpos unregister-bpos vote-bpos"
            echo "                 stake-bpos unstake-bpos claim-bpos register-crc activate-crc unregister-crc"
            ;;
        esc|eid|pg)
            echo "  reward:        set a cold mining address via  $SCRIPT_NAME reward set 0x.."
            ;;
        eco)
            echo "  purge:         stop eco + eco-oracle and DELETE their data (chain is decommissioned)"
            ;;
    esac
    echo
    echo "  aliases: up=start   down=stop   rpc=jsonrpc   (kebab-case accepted)"
}

usage()
{
    echo "elastos-node v$ELASTOS_NODE_VERSION - hardened Elastos node runner"
    echo
    echo "Usage:  $SCRIPT_NAME <command> [options]"
    echo "        $SCRIPT_NAME <chain> <command> [options]"
    echo
    echo "DAILY"
    echo "  start | stop       start / stop every chain in the profile"
    echo "  summary            one row per chain: state, height, peers (add --json)"
    echo "  status             full status for the profile (--verbose for everything)"
    echo "  logs [chain] [-f]  tail a chain's log"
    echo "  health             exit-code health check (0 = all healthy; cron-friendly)"
    echo
    echo "SETUP"
    echo "  setup              prepare a fresh box + initialize (deps, swap, firewall, autostart)"
    echo "  init               download binaries + create the keystore"
    echo "  profile [set P]    choose what this node runs (mainchain | full)"
    echo "  firewall           open peer/consensus ports (RPC stays on 127.0.0.1)"
    echo "  harden             close public RPC ports + report any restart needed"
    echo "  reward [set 0x..]  cold miner reward address for the side chains"
    echo
    echo "MANAGE"
    echo "  restart            restart the profile's chains, one at a time (ela needs --force)"
    echo "  update             update the chain binaries"
    echo "  migrate            move an upstream install onto this fork (--dry-run | --apply)"
    echo "  uninstall          stop + remove the install (keystore backed up)"
    echo "  version | -v       fork + chain versions"
    echo
    echo "PER-CHAIN    $SCRIPT_NAME <chain> <command>"
    echo "  start stop restart status [--json] health logs [-f] client rpc init update version"
    echo "  run '$SCRIPT_NAME <chain>' for that chain's full list (ela: governance; eco: purge)"
    echo
    echo "CHAINS       $(profile_chains 2>/dev/null || echo 'ela esc eid pg + oracles + arbiter')"
    echo "ALIASES      up=start   down=stop   ps=summary   rpc=jsonrpc   (kebab-case accepted)"
    echo "MAINTAIN     set_cron   update_script   set_path"
    echo "FLAGS        --profile <mainchain|full>   --no-color"
    echo
    ui_dim "  deploy:$SCRIPT_PATH  sha:$SCRIPT_SHA1  network:$CHAIN_TYPE"; echo
}
#
# Main
#
SCRIPT_PATH=$(cd "$(dirname "$(readlink -f "$BASH_SOURCE" 2>/dev/null || echo "$BASH_SOURCE")")" && pwd)
SCRIPT_NAME=$(basename $BASH_SOURCE)
SCRIPT_SHA1=$(shasum $BASH_SOURCE | cut -c1-7)

set_env
check_env
load_config

# global flag: --profile <mainchain|full> overrides the persisted profile for this run
PROFILE_OVERRIDE=
UI_NO_COLOR=
while true; do
    case "$1" in
        --profile)  [ $# -ge 2 ] || { echo_error "--profile needs a value (mainchain|full)"; exit 1; }
                    PROFILE_OVERRIDE="$2"; shift 2 ;;
        --no-color) UI_NO_COLOR=1; shift ;;
        *) break ;;
    esac
done

# modern verb aliases -> canonical command (old commands unchanged)
case "$1" in
    up)   set -- start "${@:2}" ;;
    down) set -- stop "${@:2}" ;;
    ps)   set -- summary "${@:2}" ;;
esac

# script commands
if [ "$1" == "" ]; then
    usage
    exit
elif [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
    exit
elif [ "$1" == "profile" ]; then
    profile "$2" "$3"
    exit
elif [ "$1" == "summary" ]; then
    if [ "$2" == "--json" ]; then render_json_all; else render_summary; fi
    exit
elif [ "$1" == "status" ]; then
    if [ "$2" == "--verbose" ] || [ "$2" == "-v" ] || [ "$2" == "--all" ]; then all_status; else render_status_all; fi
    exit
elif [ "$1" == "health" ]; then
    render_health_all
    exit $?
elif [ "$1" == "restart" ]; then
    case "$2" in --force|--include-ela) FORCE_ELA=1 ;; esac
    all_restart
    exit
elif [ "$1" == "logs" ]; then
    logs_cmd "$2" "$3"
    exit
elif [ "$1" == "version" ] || [ "$1" == "--version" ] || [ "$1" == "-v" ]; then
    version_cmd
    exit
elif [ "$1" == "reward" ]; then
    reward_cmd "$2" "$3"
    exit
elif [ "$1" == "uninstall" ]; then
    uninstall_cmd
    exit
elif [ "$1" == "migrate" ]; then
    migrate "$2" "$3"
    exit $?
elif [ "$1" == "setup" ]; then
    setup
    exit
elif [ "$1" == "firewall" ]; then
    firewall
    exit
elif [ "$1" == "harden" ]; then
    harden
    exit
elif [ "$1" == "set_path" ]; then
    set_path
    exit
elif [ "$1" == "set_cron" ]; then
    set_cron
    exit
elif [ "$1" == "update_script" ] || [ "$1" == "script_update" ]; then
    update_script
    exit
fi

# chain commands
if [ "$1" == "init"    ] || \
   [ "$1" == "start"   ] || \
   [ "$1" == "stop"    ] || \
   [ "$1" == "status"  ] || \
   [ "$1" == "update"  ] || [ "$1" == "upgrade" ] || \
   [ "$1" == "compress_log" ] || \
   [ "$1" == "remove_log" ]; then
    # operate on all chains
    COMMAND=$1
    # command aliases
    if [ "$COMMAND" == "upgrade" ]; then
        COMMAND=update
    fi

    all_$COMMAND
else
    # operate on a single chain

    if [ "$1" != "ela"        ] && \
       [ "$1" != "esc"        ] && \
       [ "$1" != "esc-oracle" ] && \
       [ "$1" != "eid"        ] && \
       [ "$1" != "eid-oracle" ] && \
       [ "$1" != "eco"        ] && \
       [ "$1" != "eco-oracle" ] && \
       [ "$1" != "pgp"        ] && \
       [ "$1" != "pgp-oracle" ] && \
       [ "$1" != "pg"         ] && \
       [ "$1" != "pg-oracle"  ] && \
       [ "$1" != "arbiter"    ]; then
        echo_error "unknown command or chain: $1"
        echo "  run '$SCRIPT_NAME help' for the full list"
        did_you_mean "$1" "up down restart ps status summary health logs version setup init start stop update profile firewall reward uninstall ela esc eid pg arbiter"
        exit 1
    fi
    CHAIN_NAME=$1
    CHAIN_NAME_U=$(echo $CHAIN_NAME | tr "[:lower:]" "[:upper:]")

    # modern per-chain verbs + kebab-case -> canonical command (old commands unchanged)
    _CMD=$2
    case "$_CMD" in
        up)   _CMD=start ;;
        down) _CMD=stop ;;
        ps)   _CMD=status ;;
        rpc)  _CMD=jsonrpc ;;
    esac
    _CMD=${_CMD//-/_}
    if [ -n "$2" ] && [ "$_CMD" != "$2" ]; then set -- "$1" "$_CMD" "${@:3}"; fi

    if [ "$2" == "" ]; then
        # no command: show this chain's commands and exit non-zero (not a silent success)
        chain_help "$CHAIN_NAME"
        exit 1
    elif [ "$2" == "start"   ] || \
         [ "$2" == "stop"    ] || \
         [ "$2" == "status"  ] || \
         [ "$2" == "health"  ] || \
         [ "$2" == "restart" ] || \
         [ "$2" == "logs"    ] || \
         [ "$2" == "version" ] || \
         [ "$2" == "client"  ] || \
         [ "$2" == "jsonrpc" ] || \
         [ "$2" == "update"  ] || [ "$2" == "upgrade" ] || \
         [ "$2" == "init"    ] || \
         [ "$2" == "purge"   ] || \
         [ "$2" == "register_bpos"   ] || \
         [ "$2" == "activate_bpos"   ] || \
         [ "$2" == "unregister_bpos" ] || \
         [ "$2" == "vote_bpos"       ] || \
         [ "$2" == "stake_bpos"      ] || \
         [ "$2" == "unstake_bpos"    ] || \
         [ "$2" == "claim_bpos"      ] || \
         [ "$2" == "register_crc"    ] || \
         [ "$2" == "activate_crc"    ] || \
         [ "$2" == "unregister_crc"  ] || \
         [ "$2" == "send"            ] || \
         [ "$2" == "transfer"        ] || \
         [ "$2" == "compress_log"    ] || \
         [ "$2" == "modify_configfile"    ] || \
         [ "$2" == "remove_sidechain_config"    ] || \
         [ "$2" == "remove_log"      ]; then
        COMMAND=$2
    else
        echo_error "unknown command: $2"
        echo "  run '$SCRIPT_NAME $CHAIN_NAME' to see $CHAIN_NAME commands"
        did_you_mean "$2" "up down restart start stop status health logs init update client rpc jsonrpc send transfer version register_bpos activate_bpos vote_bpos stake_bpos claim_bpos"
        exit 1
    fi
    # command aliases
    if [ "$COMMAND" == "upgrade" ]; then
        COMMAND=update
    fi

    shift 2

    if [ "$COMMAND" == "purge" ] && [ "$CHAIN_NAME" != "eco" ]; then
        echo_error "purge is only available for the decommissioned eco chain"
        exit 1
    fi
    if [ "$COMMAND" == "status" ]; then
        case "$1" in
            --verbose|-v|--all) ${CHAIN_NAME}_status ;;
            --json)             render_json_one $CHAIN_NAME ;;
            *)                  render_status_one $CHAIN_NAME ;;
        esac
        exit
    fi
    if [ "$COMMAND" == "health" ]; then
        render_health $CHAIN_NAME
        exit $?
    fi
    if [ "$COMMAND" == "restart" ]; then
        case "$1" in --force|--include-ela) FORCE_ELA=1 ;; esac
        chain_restart $CHAIN_NAME
        exit $?
    fi
    if [ "$COMMAND" == "logs" ]; then
        chain_logs $CHAIN_NAME "$@"
        exit $?
    fi
    if [ "$COMMAND" == "version" ]; then
        "${CHAIN_NAME}_ver" 2>/dev/null || echo_error "no version for $CHAIN_NAME"
        exit
    fi

    ${CHAIN_NAME}_${COMMAND} "$@"
fi
