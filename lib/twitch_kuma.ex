defmodule TwitchKuma do
  use Kaguya.Module, "main"

  # Validator for mods
  def is_mod(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    if user == nil do
      false
    else
      user.mode == :op
    end
  end

  # Enable Twitch Messaging Interface
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuu_senkan")
  end

  # Commands list
  handle "PRIVMSG" do
    match "!uptime", :uptime
    match "!time", :local_time

    # Mod command list
    enforce :is_mod do
      match ["!kuma"], :ping
    end
  end

  # Command action handlers
  defh ping, do: reply "Kuma~!"

  defh uptime do
    url = "https://decapi.me/twitch/uptime?channel=rekyuu_senkan"
    request =  HTTPoison.get! url

    case request.body do
      "Channel is not live." -> reply "Stream is not online!"
      time -> reply "Stream has been live for #{time}."
    end
  end

  defh local_time do
    {{_, _, _}, {hour, minute, _}} = :calendar.local_time
    reply "It is #{hour}:#{minute} rekyuu's time."
  end
end
