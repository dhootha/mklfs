#!/bin/bash

set -o nounset
set -o errexit

o='\e[0m'
r="$o"'\e[1;31m'
g="$o"'\e[1;32m'

: << EOF

estados:

NEWLINE
VARNAME
EQUALS
CONTENT_SIMPLE
CONTENT_QUOTE
ARRAY_SIMPLE
ARRAY_QUOTE
ARRAY_NL
ARRAY_VARNAME
ARRAY_WAITEQ
ARRAY_EQUALS
ARRAY_DCLEND
CONTENT_ARREND
COMMENT
ESCAPE
DECL_END

chars:
#
 
[a-zA-Z_]
[0-9]
[/.-]
=
"
\
(
)
*

EOF

hardnl='
'

estado=NEWLINE
escape_goback=''
comm_goback=''
assignment=''
varname=''

linha=0
got_it='no'
while IFS='' read -r l || [[ $l ]]; do
    #printf "$g%s$o" "$l"
    this_line="$(echo "$l" | sed -e 's/\(.\)/x\1x\n/g')"
    this_line_var=""
    while read ch; do
        beg_estado=$estado
        if [[ ! $ch ]]; then
            #printf "$r<>$o"
            break
        fi
        ch="${ch:1:1}"
        #printf "$r<%s>$o" "$ch"
        # here, parse non-newline chars
        assignment="${assignment}$ch"
        case $estado in

        NEWLINE)
            case $ch in
            '#')
                comm_goback=$estado
                estado=COMMENT
                ;;
            ' ')
                :
                ;;
            [a-zA-Z_])
                varname=$ch
                estado=VARNAME
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "first character can't be \`${ch}':" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        VARNAME)
            case $ch in
            '#')
                echo "parse error attempting to read configuration file" >&2
                echo "line consists of only one word (and a comment):" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            ' ')
                if [[ $varname == 'export' ]]; then
                    varname=''
                    estado=NEWLINE
                else
                    echo "parse error attempting to read configuration file" \
                        >&2
                    echo "found whitespace after the variable name \`$var':" \
                        >&2
                    echo "line ${linha}: $l" >&2
                    exit
                fi
                ;;
            [a-zA-Z0-9_])
                varname="${varname}$ch"
                ;;
            '=')
                this_line_var="$varname"
                estado=EQUALS
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' inside variable name:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        EQUALS)
            case $ch in
            ' ')
                estado=DECL_END
                ;;
            [a-zA-Z0-9_/.-])
                estado=CONTENT_SIMPLE
                ;;
            '"')
                estado=CONTENT_QUOTE
                ;;
            '(')
                estado=ARRAY_DCLEND
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' unquoted:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        CONTENT_SIMPLE|ARRAY_SIMPLE)
            case $ch in
            ' ')
                if [[ $estado == CONTENT* ]]; then
                    estado=DECL_END
                else
                    estado=ARRAY_DCLEND
                fi
                ;;
            [a-zA-Z0-9_/.-])
                :
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' unquoted:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        CONTENT_QUOTE|ARRAY_QUOTE)
            case $ch in
            '$'|'`')
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' unescaped inside quotes:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            '"')
                if [[ $estado == CONTENT* ]]; then
                    estado=CONTENT_SIMPLE
                else
                    estado=ARRAY_SIMPLE
                fi
                ;;
            '\')
                escape_goback=$estado
                estado=ESCAPE
                ;;
            *)
                :
                ;;
            esac
            ;;

        ARRAY_NL)
            case $ch in
            '#')
                comm_goback=$estado
                estado=COMMENT
                ;;
            ' ')
                :
                #printf "$r<%s>$o" "$assignment"
                ;;
            '[')
                estado=ARRAY_VARNAME
                ;;
            ')')
                estado=CONTENT_ARREND
                ;;
            [a-zA-Z0-9_/.-])
                estado=ARRAY_SIMPLE
                ;;
            '"')
                estado=ARRAY_QUOTE
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "line starts with bad character \`$ch' unquoted:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        ARRAY_VARNAME)
            case $ch in
            [0-9])
                :
                ;;
            ']')
                estado=ARRAY_WAITEQ
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "array index has bad character \`$ch':" >&2
                echo "line ${linha}: $l" >&2
                exit
            esac
            ;;

        ARRAY_WAITEQ)
            case $ch in
            =)
                estado=ARRAY_EQUALS
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "expecting \`=' after array index, found \`$ch':" >&2
                echo "line ${linha}: $l" >&2
                exit
            esac
            ;;

        ARRAY_EQUALS)
            case $ch in
            ' ')
                estado=ARRAY_DCLEND
                ;;
            [a-zA-Z0-9_/.-])
                estado=ARRAY_SIMPLE
                ;;
            '"')
                estado=ARRAY_QUOTE
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' unquoted:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        CONTENT_ARREND)
            case $ch in
            ' ')
                estado=DECL_END
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found bad character \`$ch' after array:" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        DECL_END|ARRAY_DCLEND)
            case $ch in
            '#')
                if [[ $estado == ARRRAY* ]]; then
                    comm_goback=ARRAY_NL
                else
                    comm_goback=NEWLINE
                fi
                estado=COMMENT
                ;;
            ' ')
                :
                ;;
            ')')
                if [[ $estado == ARRAY* ]]; then
                    estado=CONTENT_ARREND
                else
                    echo "parse error attempting to read configuration file" \
                        >&2
                    echo "found \`)' at the end of non-array assignment" >&2
                    echo "line ${linha}: $l" >&2
                    exit
                fi
                ;;
            *)
                echo "parse error attempting to read configuration file" >&2
                echo "found commands after end of declaration" >&2
                echo "line ${linha}: $l" >&2
                exit
                ;;
            esac
            ;;

        COMMENT)
            :
            ;;

        ESCAPE)
            estado=$escape_goback
            escape_goback=''
            ;;

        esac
        if [[ $estado != $beg_estado ]]; then
            : #printf "$r<%s>$o" "$estado"
        fi
    done <<<"$this_line"

    # here, parse new-line chars (identical to whitespace)
    #printf "$r<\\\\n %s>$o" $estado
    beg_estado=$estado
    case $estado in
    NEWLINE)
        assignment=''
        #printf '%-20s<<<<%s>>>>\n' "" ""
        printf '\n'
        ;;
    VARNAME)
        echo "parse error attempting to read configuration file" >&2
        echo "after the variable name is a bad time for a newline:" >&2
        echo "line ${linha}: $l" >&2
        exit
        ;;
    EQUALS|CONTENT_SIMPLE|DECL_END|CONTENT_ARREND)
        #printf '%-20s<<<<%s>>>>\n' "$varname" "$assignment"
        if [[ $varname == $1 ]]; then
            got_it="yes"
            printf '%s\n' "$2"
        else
            printf '%s\n' "$assignment"
        fi
        varname=''
        assignment=''
        estado=NEWLINE
        ;;
    CONTENT_QUOTE|ARRAY_QUOTE)
        assignment="${assignment}$hardnl"
        ;;
    ARRAY_SIMPLE|ARRAY_NL|ARRAY_EQUALS|ARRAY_DCLEND)
        assignment="${assignment}$hardnl"
        estado=ARRAY_NL
        ;;
    ARRAY_VARNAME)
        echo "parse error attempting to read configuration file" >&2
        echo "inside array index is a bad time for a newline:" >&2
        echo "line ${linha}: $l" >&2
        exit
        ;;
    ARRAY_WAITEQ)
        echo "parse error attempting to read configuration file" >&2
        echo "missing array element contents:" >&2
        echo "line ${linha}: $l" >&2
        exit
        ;;
    COMMENT)
        if [[ $comm_goback == ARRAY* ]]; then
            assignment="${assignment}$hardnl"
        else
            #printf '%-20s<<<<%s>>>>\n' "$varname" "$assignment"
            if [[ $varname == $1 ]]; then
                got_it='yes'
                printf '%s\n' "$2"
            else
                printf '%s\n' "$assignment"
            fi
            varname=''
            assignment=''
        fi
        estado=$comm_goback
        comm_goback=''
        ;;
    ESCAPE)
        assignment="${assignment}$hardnl"
        estado=$escape_goback
        ;;
    esac
    if [[ $estado != $beg_estado ]]; then
        : #printf "$r<%s>$o" "$estado"
    fi

    let linha+=1
done

if [[ $got_it == 'no' ]]; then
    printf '%s\n' "$2"
fi
