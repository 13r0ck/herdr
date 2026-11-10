test_integration() {
TERM_PROGRAM=herdr
PROMPT='original> '
PROMPT2='more> '
precmd_functions=(existing)
existing() { :; }
source shell/herdr.zsh
source shell/herdr.zsh
[[ ${(M)#precmd_functions:#_herdr_precmd} == 1 ]] || exit 1
[[ ${precmd_functions[1]} == existing ]] || exit 1
_herdr_command_running=1
false
_herdr_precmd > /tmp/herdr-shell-marker-test.$$
[[ $? == 1 ]] || exit 1
[[ $PROMPT == *'original> '* && $PROMPT2 == *'more> '* ]] || exit 1
[[ $(</tmp/herdr-shell-marker-test.$$) == $'\e]133;D;1\a' ]] || exit 1
rm /tmp/herdr-shell-marker-test.$$
_herdr_precmd
[[ $PROMPT == $'%{\e]133;A\a%}original> %{\e]133;B\a%}' ]] || exit 1

}
test_integration
