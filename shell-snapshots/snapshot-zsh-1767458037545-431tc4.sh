# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
cleanup () {
	find . -type f -name "._*" -delete
	find . -type f -name ".DS_Store" -delete
	find . -type f -name "*~" -delete
	find . -type f -name "*.swp" -delete
	echo "Cleaned up temporary and metadata files"
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
copy () {
	if [[ -f "$1" ]]
	then
		cat "$1" | pbcopy
		echo "Copied contents of $1 to clipboard"
	else
		echo "File not found: $1"
	fi
}
dsize () {
	if command -v dust > /dev/null
	then
		dust -r "$1"
	else
		du -sh "${1:-.}"/*
	fi
}
enable_poshtooltips () {
	local widget=${$(bindkey ' '):2} 
	if [[ -z $widget ]]
	then
		widget=self-insert 
	fi
	_omp_create_widget $widget _omp_render_tooltip
}
enable_poshtransientprompt () {
	
}
extract () {
	if [ -f $1 ]
	then
		case $1 in
			(*.tar.bz2) tar xjf $1 ;;
			(*.tar.gz) tar xzf $1 ;;
			(*.bz2) bunzip2 $1 ;;
			(*.rar) unrar e $1 ;;
			(*.gz) gunzip $1 ;;
			(*.tar) tar xf $1 ;;
			(*.tbz2) tar xjf $1 ;;
			(*.tgz) tar xzf $1 ;;
			(*.zip) unzip $1 ;;
			(*.Z) uncompress $1 ;;
			(*.7z) 7z x $1 ;;
			(*) echo "'$1' cannot be extracted" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}
getent () {
	if [[ $1 = hosts ]]
	then
		sed 's/#.*//' /etc/$1 | grep -w $2
	elif [[ $2 = <-> ]]
	then
		grep ":$2:[^:]*$" /etc/$1
	else
		grep "^$2:" /etc/$1
	fi
}
gitlog () {
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
}
mkcd () {
	mkdir -p "$1" && cd "$1"
}
nvm () {
	unfunction nvm 2> /dev/null
	[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm "$@"
}
rbenv () {
	unfunction rbenv 2> /dev/null
	if command -v rbenv > /dev/null 2>&1
	then
		eval "$(command rbenv init - zsh)"
		rbenv "$@"
	fi
}
set_kitty_tab_title () {
	local title
	if git rev-parse --is-inside-work-tree &> /dev/null
	then
		local repo=$(basename "$(git rev-parse --show-toplevel)") 
		local branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD) 
		title="$repo ($branch)" 
	else
		title="${PWD##*/}" 
	fi
	print -Pn "\e]0;$title\a"
}
set_poshcontext () {
	return
}
update () {
	local start_time=$(date +%s) 
	echo "== Starting system update =="
	if command -v brew &> /dev/null
	then
		echo "Updating Homebrew..."
		brew update && brew upgrade && brew upgrade --cask --greedy && brew cleanup
	fi
	if command -v bundle &> /dev/null
	then
		echo "Updating Fastlane..."
		bundle update fastlane || true
	fi
	local end_time=$(date +%s) 
	echo "Update completed in $((end_time - start_time)) seconds!"
	afplay /System/Library/Sounds/Glass.aiff 2> /dev/null
}
# Shell Options
setopt alwaystoend
setopt autocd
setopt completeinword
setopt nohashdirs
setopt histignorealldups
setopt histignorespace
setopt histreduceblanks
setopt histverify
setopt login
setopt sharehistory
# Aliases
alias -- bye=exit
alias -- cal='cal -3'
alias -- cat='bat --paging=never'
alias -- catp=bat
alias -- cdConvergio='cd /Users/roberdan/GitHub/convergio'
alias -- cdMirrorHR='cd /Users/roberdan/GitHub/MirrorHR'
alias -- cdMirrorHRCloud='cd /Users/roberdan/GitHub/research-cloud-api/research-cloud-api/reader-research-cloud-api'
alias -- cdNovoHack='cd /Users/roberdan/Library/CloudStorage/OneDrive-Microsoft/FY26/Customers/\!Novo\ Nordisk/hackathon/AIPP-Hack'
alias -- cl=claude
alias -- cls=clear
alias -- commit='git commit -m'
alias -- diff=delta
alias -- dir=yazi
alias -- du=dust
alias -- editz='windsurf ~/.zshrc'
alias -- editzsh='zed ~/.zshrc'
alias -- fetch='git fetch'
alias -- find=fd
alias -- ga='git add'
alias -- gaa='git add --all'
alias -- gb='git branch'
alias -- gba='git branch -a'
alias -- gcb='git checkout -b'
alias -- gcm='git commit -m'
alias -- gco='git checkout'
alias -- gd='git diff'
alias -- gds='git diff --staged'
alias -- gf='git fetch'
alias -- gl='git pull'
alias -- glog='git log --oneline --graph --decorate'
alias -- gp='git push'
alias -- grep=rg
alias -- gst='git status'
alias -- gsta='git stash'
alias -- gstp='git stash pop'
alias -- htop=btm
alias -- ll='eza -la --git'
alias -- loc=tokei
alias -- ls=eza
alias -- myalias='grep '\''^alias'\'' ~/.zshrc'
alias -- now='date +"%T"'
alias -- pgbackup='pg_dump -h localhost -p 5432 -U $USER'
alias -- pglog='tail -f /opt/homebrew/var/postgresql17/server.log'
alias -- pgrestart='brew services restart postgresql@17'
alias -- pgrestore='pg_restore -h localhost -p 5432 -U $USER'
alias -- pgstart='brew services start postgresql@17'
alias -- pgstatus='brew services list | grep postgresql'
alias -- pgstop='brew services stop postgresql@17'
alias -- pip3=/opt/homebrew/bin/pip3.11
alias -- psql='psql -h localhost -p 5432 -U $USER'
alias -- pull='git pull'
alias -- push='git push'
alias -- pycheck='echo "python3: $(python3 --version)"; echo "pip3: $(pip3 --version | grep -oE "python [0-9.]+")"'
alias -- python3=/opt/homebrew/bin/python3.11
alias -- q=exit
alias -- quit=exit
alias -- reload='source ~/.zshrc'
alias -- reloadzsh='source ~/.zshrc'
alias -- run-help=man
alias -- setTeams='SwitchAudioSource -t output -s "AirPods Pro 2 di Roberto" && SwitchAudioSource -t input -s "RODECaster Duo Main Multitrack"'
alias -- setrode='SwitchAudioSource -t output -s "RODECaster Duo Chat" && SwitchAudioSource -t input -s "RODECaster Duo Main Multitrack"'
alias -- showAudioAlias='alias | grep -E "set(Rode|StudioDisplay|Bose|Teams)"'
alias -- status='git status'
alias -- stopwatch='time read -p "Press enter to stop..."'
alias -- today='date +"%A, %B %d, %Y"'
alias -- top=btm
alias -- tree='eza --tree'
alias -- virtual-bpm='cd ~/GitHub/VirtualBPM && claude --dangerously-skip-permissions'
alias -- virtualBPM='cd ~/GitHub/VirtualBPM && claude --dangerously-skip-permissions'
alias -- virtualBPM-check='bash ~/GitHub/VirtualBPM/.claude/renew-token.sh check'
alias -- virtualBPM-renew='bash ~/GitHub/VirtualBPM/.claude/renew-token.sh'
alias -- which-command=whence
alias -- wildClaude='claude --dangerously-skip-permissions'
alias -- wttr='curl wttr.in'
alias -- x=exit
# Check for rg availability
if ! command -v rg >/dev/null 2>&1; then
  alias rg='/Users/roberdan/.local/share/claude/versions/2.0.76 --ripgrep'
fi
export PATH='/Users/roberdan/.nvm/versions/node/v22.21.1/bin:/Users/roberdan/.local/bin:/Users/roberdan/bin:/opt/homebrew/opt/python@3.11/bin:/opt/homebrew/opt/python@3.11/libexec/bin:/usr/local/bin:/usr/bin:/bin:/Users/roberdan/.rbenv/bin:/opt/homebrew/Cellar/mlx/0.20.0/bin:/Users/roberdan/GitHub/MyAIAgents:/Users/roberdan/Library/Application Support/reflex/bun/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/System/Cryptexes/App/usr/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/opt/pmk/env/global/bin:/Library/Apple/usr/bin:/usr/local/share/dotnet:/usr/local/go/bin:/opt/podman/bin:/Applications/Warp.app/Contents/Resources/bin'
