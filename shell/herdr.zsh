# Source explicitly on remote hosts too. Only newly printed content is marked.
[[ -o interactive ]] || return 0
(( ${+_herdr_shell_integration} )) && return 0
typeset -g _herdr_shell_integration=1 _herdr_command_running=0
autoload -Uz add-zsh-hook
_herdr_precmd() {
  local code=$?
  if (( _herdr_command_running )); then
    printf '\e]133;D;%s\a' "$code"
    _herdr_command_running=0
  fi
  # Themes may replace prompts each turn. Remove only our own wrappers.
  local a=$'%{\e]133;A\a%}' b=$'%{\e]133;B\a%}' c=$'%{\e]133;A;k=s\a%}' r=$'%{\e]133;A;k=r\a%}'
  PROMPT=${PROMPT//$a/}; PROMPT=${PROMPT//$b/}
  PROMPT="$a$PROMPT$b"
  PROMPT2=${PROMPT2//$c/}; PROMPT2=${PROMPT2//$b/}
  PROMPT2="$c$PROMPT2$b"
  RPROMPT=${RPROMPT//$r/}; RPROMPT=${RPROMPT//$b/}
  [[ -z $RPROMPT ]] || RPROMPT="$r$RPROMPT$b"
  return $code
}
_herdr_preexec() {
  printf '\e]133;C\a'
  _herdr_command_running=1
}
add-zsh-hook precmd _herdr_precmd
add-zsh-hook preexec _herdr_preexec
