# Thing to set in interactive sessions of zsh
setopt auto_cd			#like implicit_cd in tcsh
setopt auto_list		#like autoexpand in tcsh
setopt no_auto_menu
setopt auto_pushd
setopt brace_ccl
setopt cdable_vars
setopt no_clobber		#like noclobber in tcsh
setopt correct			#like correct=cmd in tcsh
setopt extended_history
setopt no_flow_control
setopt hist_ignore_dups
#setopt hist_reduce_blanks
setopt list_ambiguous		#like autolist=ambiguous in tcsh (together with auto_list)
setopt no_list_beep		#like matchbeep=nomatch in tcsh
setopt list_types
setopt mail_warning
setopt numeric_glob_sort
setopt no_prompt_cr		#tcsh like behaviour with the same bugs...
setopt pushd_ignore_dups
setopt rm_star_silent
setopt sh_word_split
#setopt no_unset
setopt prompt_subst
autoload -Uz vcs_info
setopt debug_before_cmd

# these three are mutually exclusive
#setopt append_history
setopt inc_append_history
# setopt share_history

export PREEXEC_TIME=$(date +'%s')
title()
{
    echo -n -e "\033]0;$1\007"
}

git_working_dir()
{
    gitdir=$(git rev-parse --show-toplevel 2> /dev/null)
    if [ $? -eq 0 ]; then
        basename $gitdir
    fi
}

vcs_info_git_ignore()
{
    git check-ignore -q . 2> /dev/null && vcs_info_msg_0_=""
}

vcs_info_repo()
{
    if [ "$vcs_info_msg_0_" = "" ]; then
        vcs_info_repo_msg=""
    else
        vcs_info_repo_msg=$(gitrepo)
    fi
}

# Execute before prompt
precmd()
{
    eval exitcode=$?
    setpromptcolor || true
    vcs_info || true
    vcs_info_git_ignore || true
    vcs_info_repo || true
    saystatus || true
    command=
}

preexec()
{
    eval last_command='$1'
    command=$(echo $last_command | awk '{print $1;}')
    PREEXEC_TIME=$(date +'%s')
}

focusedapp()
{
    /usr/bin/osascript << EOF

tell application "System Events"
	set applicationName to name of every process whose frontmost is true and visible ≠ false
end tell

return applicationName

EOF
}

function setpromptcolor()
{
	eval PROMPT_COLOR=$PR_YELLOW
	if [ "$VIRTUAL_ENV" != "" ]; then
		venv_parent=$(dirname $VIRTUAL_ENV);
		if [ "$venv_parent" != "$PWD" ]; then
			eval PROMPT_COLOR=$PR_RED
		fi
	fi
}

function padnumber()
{
    if [ "$1" -lt 10 ]; then
        echo "0$1"
    else
        echo "$1"
    fi
}

function print_elapsed()
{
    elapsed=$1
    start_time=$(date -r $PREEXEC_TIME "+%H:%M:%S")
    current_time=$(date "+%H:%M:%S")
    elapsed_display="${elapsed}s"
    if [ "$elapsed" -gt 60 ]; then
        hours=$(padnumber $(($elapsed/3600)))
        mins=$(padnumber $(($elapsed/60)))
        secs=$(padnumber $(($elapsed%60)))
        if [ "$hours" -gt 0 ]; then
            elapsed_display="${hours}:${mins}:${secs} (${elapsed}s)"
        else
            elapsed_display="${mins}:${secs} (${elapsed}s)"
        fi
    fi
    echo "\e[90mStart time $start_time, end time $current_time, elapsed $elapsed_display\e[0m"
}

function saystatus()
{
    if [ "$SAYSTATUS" != "" ]; then
        return
    fi
    stop=$(date +'%s')
    start=${PREEXEC_TIME:-$stop}
    let elapsed=$stop-$start
    max=${PREEXEC_MAX:-3}

    if [ $elapsed -gt $max ]; then
        if [ "$command" != "" ]; then
            print_elapsed $elapsed
        fi
        focusedapp_name=$(focusedapp)
        if [ "$focusedapp_name" != "Terminal" ]; then
        	command=$(echo ${command:t:r})
            if [ $exitcode -eq 0 ]; then
                terminal-notifier -message "$command finished" 2>&1 >> /dev/null
                say "$command finished" &!
            else
                terminal-notifier -message "$command aborted with error $exitcode" 2>&1 >> /dev/null
                say "$command aborted with error $exitcode" &!
            fi
        fi
    fi
}

TRAPZERR()
{
    exitcode=$?
    if [ $exitcode -gt 128 ]; then
        signalcode=$(( exitcode - 128 ))
        signalname=$(kill -l $signalcode)
        echo "\e[91mSignal $signalcode $signalname\e[0m"
    fi
    echo "\e[33mExit $exitcode\e[0m"
}

function setcolors()
{
    autoload colors zsh/terminfo
    if [[ "$terminfo[colors]" -ge 8 ]]; then
		colors
    fi
    for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
        eval PR_$color='%{$terminfo[bold]$fg[${(L)color}]%}'
        eval PR_LIGHT_$color='%{$fg[${(L)color}]%}'
    done
    eval PR_NO_COLOR="%{$terminfo[sgr0]%}"
    # Fix color when using the 'set' command
    eval PR__NO_COLOR="%{$terminfo[sgr0]%}"
}
setcolors

function vcs_info_without_master_branch()
{
	echo "${vcs_info_msg_0_}" | sed -e 's/master//'
}

function reload()
{
    source ~/.zshrc
    source ~/.zshenv 2> /dev/null
}

zstyle ':vcs_info:*' stagedstr '+'
zstyle ':vcs_info:*' unstagedstr '*'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' formats '(%b%c%u) '
zstyle ':vcs_info:*' enable git svn

PROMPT_COLOR=$PR_YELLOW
PROMPT_DARK_COLOR=$PR_LIGHT_YELLOW
PROMPT='$PROMPT_COLOR%~ $PR_NO_COLOR$PROMPT_DARK_COLOR${vcs_info_msg_0_}$PROMPT_COLOR%# $PR_NO_COLOR'
LISTMAX=2000
REPORTTIME=60

HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=10000

if [[ "${TERM-}" == "ansi" ]] {
	TERM=vt100
}
bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line
bindkey '\e[3~' delete-char
bindkey '\e[5~' history-beginning-search-backward
bindkey '\e[6~' history-beginning-search-forward
bindkey '\e[H'  beginning-of-line
bindkey '\e[F'  end-of-line
bindkey '\eOH'  beginning-of-line
bindkey '\eOF'  end-of-line

function rehash {
	builtin rehash
	if [[ ${+man_pages} == 1 ]] {
		unset man_pages
	}
}

compctl -a alias
compctl -a unalias

compctl -v set
compctl -v unset
compctl -v export

compctl -o setopt
compctl -o unsetopt

compctl -B builtin

compctl -g '(.*|*)(-/)' cd

compctl -g '/usr/pkg/lst/*(:t)' pkgl

compctl -x 'p[1]' -u -- + chown

function get_pages {
	if [[ ${+man_pages} == 0 ]] {
		if [[ "${manpath-}" == "" ]] {
			man_search=(/usr/man /usr/local/man /usr/X11R6/man)
		} else {
			man_search=($manpath)
		}
		for i in $man_search
		do
			man_pages=(${man_pages-} $i/man*/*(N:t:r:r))
		done
		unset man_search
	}
	reply=(${man_pages-})
}
compctl -x 'C[0,*/*]' -f -- + -K get_pages man

function get_targets {
	if [[ -f makefile ]] {
		local makefile=makefile
	} else {
		local makefile=Makefile
	}
	reply=(`cat $makefile | grep -v ^# | grep '^[[:alnum:]][^:]*:' | sed 's/:.*//'`)
}
compctl -x 's[-f],c[-1,-f]' -f -- + -K get_targets make

# This makes standard shell completion slow or weird
# fpath=(/usr/local/share/zsh-completions $fpath)
# autoload -U compinit
# compinit || true
## bash completion added by simply installer
autoload -U compinit && compinit
autoload -U bashcompinit && bashcompinit

eval "$(rbenv init - || true)"
alias telnet='nc -v'
alias gitrepo='git remote get-url --push origin'
alias shs='python -m SimpleHTTPServer'
