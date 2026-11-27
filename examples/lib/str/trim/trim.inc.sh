#!/usr/bin/env bash
# Bash String Trim Utilities - Combined Module File
# Source this file to load all trim family functions:
#   source trim.inc.sh
# Available functions: trim, ltrim, rtrim, trimv, trimall, squeeze
ltrim () 
{ 
    if (($#)); then
        local -- v;
        if [[ $1 == '-e' ]]; then
            shift;
            printf -v v '%b' "$*";
        else
            v="$*";
        fi;
        printf '%s\n' "${v#"${v%%[![:blank:]]*}"}";
        return 0;
    else
        if [[ ! -t 0 ]]; then
            local -- REPLY;
            while IFS= read -r REPLY || [[ -n $REPLY ]]; do
                REPLY=${REPLY#"${REPLY%%[![:blank:]]*}"};
                printf '%s\n' "$REPLY";
            done;
        fi;
    fi;
    return 0
}
declare -fx ltrim

rtrim () 
{ 
    if (($#)); then
        local -- v;
        if [[ $1 == '-e' ]]; then
            shift;
            printf -v v '%b' "$*";
        else
            v="$*";
        fi;
        printf '%s\n' "${v%"${v##*[![:blank:]]}"}";
        return 0;
    else
        if [[ ! -t 0 ]]; then
            local -- REPLY;
            while IFS= read -r REPLY || [[ -n $REPLY ]]; do
                REPLY=${REPLY%"${REPLY##*[![:blank:]]}"};
                printf '%s\n' "$REPLY";
            done;
        fi;
    fi;
    return 0
}
declare -fx rtrim

squeeze () 
{ 
    if (($#)); then
        local -i process_escape=0;
        if [[ ${1:-} == '-e' ]]; then
            process_escape=1;
            shift;
        fi;
        local -- v;
        if ((process_escape)); then
            printf -v v '%b' "$*";
        else
            v="$*";
        fi;
        v=${v//'	'/ };
        while [[ $v == *'  '* ]]; do
            v=${v//  / };
        done;
        printf '%s\n' "$v";
        return 0;
    fi;
    if [[ ! -t 0 ]]; then
        local -- REPLY;
        while IFS= read -r REPLY || [[ -n $REPLY ]]; do
            REPLY=${REPLY//'	'/ };
            while [[ $REPLY == *'  '* ]]; do
                REPLY=${REPLY//  / };
            done;
            printf '%s\n' "$REPLY";
        done;
    fi;
    return 0
}
declare -fx squeeze

trimall () 
{ 
    local -i process_escape=0 _f=0;
    if [[ ${1:-} == '-e' ]]; then
        process_escape=1;
        shift;
    fi;
    if (($#)); then
        local -- v;
        if ((process_escape)); then
            v=$(printf '%b' "$*");
        else
            v="$*";
        fi;
        case $- in 
            *f*)
                _f=1
            ;;
        esac;
        set -f;
        set -- $v;
        printf '%s\n' "$*";
        ((_f)) || set +f;
        return 0;
    fi;
    if [[ ! -t 0 ]]; then
        local -- content='';
        local -- line;
        while IFS= read -r line || [[ -n $line ]]; do
            [[ -z $content ]] || content+=' ';
            content+=$line;
        done;
        if [[ -n $content ]]; then
            case $- in 
                *f*)
                    _f=1
                ;;
            esac;
            set -f;
            set -- $content;
            printf '%s\n' "$*";
            ((_f)) || set +f;
        fi;
    fi;
    return 0
}
declare -fx trimall

trim () 
{ 
    if (($#)); then
        local -- v;
        if [[ $1 == '-e' ]]; then
            shift;
            printf -v v '%b' "$*";
        else
            v="$*";
        fi;
        v=${v#"${v%%[![:blank:]]*}"};
        printf '%s\n' "${v%"${v##*[![:blank:]]}"}";
        return 0;
    else
        if [[ ! -t 0 ]]; then
            local -- REPLY;
            while IFS= read -r REPLY || [[ -n $REPLY ]]; do
                REPLY=${REPLY#"${REPLY%%[![:blank:]]*}"};
                REPLY=${REPLY%"${REPLY##*[![:blank:]]}"};
                printf '%s\n' "$REPLY";
            done;
        fi;
    fi;
    return 0
}
declare -fx trim

trimv () 
{ 
    local -i _trimv__escape=0;
    local -- _trimv__varname='';
    if (($#)); then
        if [[ $1 == '-e' ]]; then
            _trimv__escape=1;
            shift;
        fi;
        if [[ ${1:-} == '-n' ]]; then
            _trimv__varname=${2:-TRIM};
            [[ $_trimv__varname =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { 
                printf "${FUNCNAME[0]}: ✗ %s\n" "invalid variable name ${_trimv__varname@Q}" 1>&2;
                return 1
            };
            if (($# > 1)); then
                shift 2;
            else
                shift;
            fi;
        fi;
    fi;
    if (($#)); then
        local -- _trimv__val;
        if ((_trimv__escape)); then
            printf -v _trimv__val '%b' "$*";
        else
            _trimv__val="$*";
        fi;
        _trimv__val=${_trimv__val#"${_trimv__val%%[![:blank:]]*}"};
        _trimv__val=${_trimv__val%"${_trimv__val##*[![:blank:]]}"};
        if [[ -n $_trimv__varname ]]; then
            local -n _trimv__ref=$_trimv__varname;
            _trimv__ref=$_trimv__val;
        else
            printf '%s\n' "$_trimv__val";
        fi;
        return 0;
    fi;
    if [[ ! -t 0 ]]; then
        if [[ -n $_trimv__varname ]]; then
            local -- _trimv__content='' _trimv__line;
            while IFS= read -r _trimv__line || [[ -n $_trimv__line ]]; do
                _trimv__line=${_trimv__line#"${_trimv__line%%[![:blank:]]*}"};
                _trimv__line=${_trimv__line%"${_trimv__line##*[![:blank:]]}"};
                _trimv__content+="$_trimv__line"'
';
            done;
            _trimv__content=${_trimv__content%'
'};
            local -n _trimv__ref=$_trimv__varname;
            _trimv__ref=$_trimv__content;
        else
            local -- REPLY;
            while IFS= read -r REPLY || [[ -n $REPLY ]]; do
                REPLY=${REPLY#"${REPLY%%[![:blank:]]*}"};
                REPLY=${REPLY%"${REPLY##*[![:blank:]]}"};
                printf '%s\n' "$REPLY";
            done;
        fi;
    fi;
    return 0
}
declare -fx trimv

#fin
