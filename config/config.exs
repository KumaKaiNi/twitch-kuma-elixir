use Mix.Config

import_config "secret.exs"

config :kaguya,
  server: "irc.chat.twitch.tv",
  server_ip_type: :inet,
  port: 6667,
  bot_name: "KumaKaiNi",
  channels: ["#rekyuu_senkan"],
  help_cmd: "!help",
  use_ssl: false,
  reconnect_interval: 5
