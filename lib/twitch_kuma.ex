defmodule TwitchKuma do
  use Kaguya.Module, "main"
  require Logger

  # Enable Twitch Messaging Interface and whispers
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/commands"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuus")
  end

  handle "PRIVMSG", do: match_all :make_call
  handle "WHISPER", do: match_all :make_call

  defh make_call do
    [chan] = message.args
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, message.user.nick})

    moderator = cond do
      user == nil -> false
      message.user.nick == "rekyuus" -> true
      true -> message.user.mode == :op
    end

    private = case message.command do
      "WHISPER" -> true
      "PRIVMSG" -> false
    end

    content = %{username: message.user.nick, message: message.trailing, moderator: moderator, private: private}

    {:ok, hostname} = :inet.gethostname
    response = :rpc.call(:"kuma@#{hostname}", KumaServer, :handle_call, [:message, content])

    case response do
      nil -> nil
      {:badrpc, {action, {reason, _}}} -> Logger.error "#{action}: #{reason}"
      {:badrpc, :nodedown} -> Logger.error "Unable to connect to server"
      response -> reply response
    end
  end
end
