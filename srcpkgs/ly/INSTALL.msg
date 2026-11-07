Ly is started by runit on tty2, so disable the getty on that TTY first:

  rm /var/service/agetty-tty2
  ln -s /etc/sv/ly /var/service/

The TTY can be changed with TTY= in /etc/sv/ly/conf.
