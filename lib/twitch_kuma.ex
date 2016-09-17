defmodule TwitchKuma do
  use Kaguya.Module, "main"

  # Validator for mods
  validator :is_mod do
    :mod_check
  end

  def mod_check(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    if user == nil do
      false
    else
      user.mode == :op
    end
  end

  # Required to properly identify mods and such
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})
  end

  # Commands list
  handle "PRIVMSG" do
    match "!uptime", :uptime
    match "!time", :local_time

    # Mod command list
    validate :is_mod do
      match ["!ping", "!p"], :ping
    end
  end

  # Command action handlers
  defh ping, do: reply "Pong!"

  defh uptime do
    url = "https://decapi.me/twitch/uptime?channel=rekyuu_senkan"
    request =  HTTPoison.get! url

    case request.body do
      "Channel is not live." -> reply "Stream is not online!"
      time -> reply "Stream has been live for #{time}."
    end
  end

  defh local_time, do: reply "-local time-"
end
