To use noctalia-greeter, set in /etc/greetd/config.toml:

  [default_session]
  command = "noctalia-greeter-session -- --session-wrapper dbus-run-session"
  user = "_greeter"

then restart greetd. See /usr/share/doc/noctalia-greeter/README.voidlinux
