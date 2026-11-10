"""Exercise real zsh hooks, continuation prompts, failure and Ctrl-C."""
import os
import pty
import select
import signal
import shutil
import shlex
import tempfile
import time

pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM_PROGRAM'] = 'herdr'
    os.execv(shutil.which('zsh'), ['zsh', '-dfi'])

def until(marker):
    data = b''
    deadline = time.monotonic() + 10
    while marker not in data:
        if time.monotonic() > deadline:
            raise AssertionError((marker, data))
        if select.select([fd], [], [], .1)[0]:
            data += os.read(fd, 65536)
    return data

def send(text):
    os.write(fd, text.encode())

try:
    if os.environ.get('TEST_OH_MY_ZSH'):
        directory = tempfile.mkdtemp(prefix='herdr-omz-', dir='/private/tmp')
        omz = shlex.quote(os.environ['TEST_OH_MY_ZSH'])
        send(f'ZSH={omz}; ZSH_CACHE_DIR={directory}; ZSH_COMPDUMP={directory}/dump; ZSH_THEME=robbyrussell; plugins=(docker); source "$ZSH/oh-my-zsh.sh"\n')
    send("PROMPT='ready> '; PROMPT2='more> '; source shell/herdr.zsh\n")
    until(b'\x1b]133;B\x07')
    send('false\n')
    until(b'\x1b]133;D;1\x07')
    send('for x in a; do\n')
    until(b'\x1b]133;A;k=s\x07')
    send('print -r -- "  $x 界"; done\n')
    until(b'\x1b]133;D;0\x07')
    send('sleep 10\n')
    until(b'\x1b]133;C\x07')
    time.sleep(.2)  # Let the foreground sleep take ownership of the PTY.
    os.write(fd, b'\x03')
    until(b'\x1b]133;D;130\x07')
finally:
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
    os.close(fd)
