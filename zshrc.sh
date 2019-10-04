# To install source this file from your .zshrc file

# see documentation at http://linux.die.net/man/1/zshexpn
# A: finds the absolute path, even if this is symlinked
# h: equivalent to dirname
export __GIT_PROMPT_DIR=${0:A:h}

export GIT_PROMPT_EXECUTABLE=${GIT_PROMPT_EXECUTABLE:-"python"}

# Initialize colors.
autoload -U colors
colors

# Allow for functions in the prompt.
setopt PROMPT_SUBST

autoload -U add-zsh-hook

PROMPTCACHE=${PROMPTCACHE:-~/.prompts}

[ -d $PROMPTCACHE ] || mkdir $PROMPTCACHE

function TRAPUSR2 {
  # Force zsh to redisplay the prompt.
  zle && zle reset-prompt
  rm $PROMPTCACHE/pid.$$
}

function set_git_dirs {
  local git_cdup=`git rev-parse --show-cdup 2>/dev/null || echo 'nun'`

  if [[ $git_cdup = "nun" ]]; then
    GIT_DIR=""
    GIT_STATUS=""
  else
    GIT_DIR="$PWD/$git_cdup/.git"
    GIT_STATUS="$GIT_DIR/last-status"
  fi
}


function cached_git_super_status {
  set_git_dirs

  if [[ -e "$GIT_STATUS" ]]; then
    load_current_git_vars >$PROMPTCACHE/prompt.$$
  elif [[ -z $GIT_DIR ]]; then
    echo "" >$PROMPTCACHE/prompt.$$
  fi

  [ -f $PROMPTCACHE/prompt.$$ ] && cat $PROMPTCACHE/prompt.$$
}

function async_git_super_status {
  echo $(update_current_git_vars) >$PROMPTCACHE/prompt.$$

  kill -s SIGUSR2 $$
}

function init_async_git_super_status {
  function zle-async-init {
    local cachePidFile="$PROMPTCACHE/pid.$$"
    if [ -f $cachePidFile ]; then
      local pid=$(cat $cachePidFile)
      kill $(cat "$PROMPTCACHE/pid.$$") >/dev/null 2>&1
      rm "$PROMPTCACHE/pid.$$"
    fi

    set_git_dirs

    if [[ ! -z "$GIT_DIR" ]]; then
      (async_git_super_status) &!
      echo $! >$PROMPTCACHE/pid.$$
    fi
  }

  zle -N zle-line-init zle-async-init
}

function update_current_git_vars() {
  local git_statusindex="$GIT_DIR/status-index"

  cp "$GIT_DIR/index" $git_statusindex

  if [[ "$GIT_PROMPT_EXECUTABLE" == "python" ]]; then
      GIT_INDEX_FILE=$git_statusindex python "$__GIT_PROMPT_DIR/gitstatus.py" >$GIT_STATUS 2>/dev/null
  elif [[ "$GIT_PROMPT_EXECUTABLE" == "haskell" ]]; then
      GIT_INDEX_FILE=$git_statusindex git status --porcelain --branch &> /dev/null | $__GIT_PROMPT_DIR/src/.bin/gitstatus >$GIT_STATUS
  fi

  load_current_git_vars
}

function load_current_git_vars {
  local _git_status=`cat $GIT_STATUS`
  __CURRENT_GIT_STATUS=("${(@s: :)_git_status}")

  GIT_BRANCH=$__CURRENT_GIT_STATUS[1]
  GIT_AHEAD=$__CURRENT_GIT_STATUS[2]
  GIT_BEHIND=$__CURRENT_GIT_STATUS[3]
  GIT_STAGED=$__CURRENT_GIT_STATUS[4]
  GIT_CONFLICTS=$__CURRENT_GIT_STATUS[5]
  GIT_CHANGED=$__CURRENT_GIT_STATUS[6]
  GIT_UNTRACKED=$__CURRENT_GIT_STATUS[7]

  if [ -n "$__CURRENT_GIT_STATUS" ]; then
    STATUS="$ZSH_THEME_GIT_PROMPT_PREFIX$ZSH_THEME_GIT_PROMPT_BRANCH$GIT_BRANCH%{${reset_color}%}"
    if [ "$GIT_BEHIND" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_BEHIND$GIT_BEHIND%{${reset_color}%}"
    fi
    if [ "$GIT_AHEAD" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_AHEAD$GIT_AHEAD%{${reset_color}%}"
    fi
    STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_SEPARATOR"
    if [ "$GIT_STAGED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STAGED$GIT_STAGED%{${reset_color}%}"
    fi
    if [ "$GIT_CONFLICTS" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CONFLICTS$GIT_CONFLICTS%{${reset_color}%}"
    fi
    if [ "$GIT_CHANGED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CHANGED$GIT_CHANGED%{${reset_color}%}"
    fi
    if [ "$GIT_UNTRACKED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNTRACKED%{${reset_color}%}"
    fi
    if [ "$GIT_CHANGED" -eq "0" ] && [ "$GIT_CONFLICTS" -eq "0" ] && [ "$GIT_STAGED" -eq "0" ] && [ "$GIT_UNTRACKED" -eq "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi
    STATUS="$STATUS%{${reset_color}%}$ZSH_THEME_GIT_PROMPT_SUFFIX"
    echo "$STATUS"
  fi
}

# Default values for the appearance of the prompt. Configure at will.
ZSH_THEME_GIT_PROMPT_PREFIX="("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_SEPARATOR="|"
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg_bold[magenta]%}"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg[red]%}%{●%G%}"
ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg[red]%}%{✖%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg[green]%}%{✚%G%}"
ZSH_THEME_GIT_PROMPT_BEHIND="%{↓%G%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{↑%G%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED=" %{…%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]%}%{✔%G%}"

