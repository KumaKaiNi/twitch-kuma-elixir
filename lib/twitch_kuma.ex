defmodule TwitchKuma do
  use Kaguya.Module, "main"

  validator :is_rekyuu do
    :rekyuu_check
  end

  def rekyuu_check(%{user: %{nick: nick}, args: [chan]}) do
    require Logger

    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    Logger.log :info, user.nick

    if user == nil do
      false
    else
      user.nick == "rekyuu_senkan!rekyuu_senkan@rekyuu_senkan.tmi.twitch.tv"
    end
  end

  handle "PRIVMSG" do
    match "hi", :hiHandler
    match "!say ~message", :sayHandler

    validate :is_rekyuu do
      match ["!ping", "!p"], :pingHandler
    end
  end

  defh pingHandler, do: reply "pong!"
  defh hiHandler(%{user: %{nick: nick}}), do: reply "hi #{nick}!"
  defh sayHandler(%{"message" => response}), do: reply response
end
