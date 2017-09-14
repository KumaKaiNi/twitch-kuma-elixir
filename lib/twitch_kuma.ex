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
    user = if message.command == "PRIVMSG" do
      [chan] = message.args
      pid = Kaguya.Util.getChanPid(chan)
      GenServer.call(pid, {:get_user, message.user.nick})
    end

    moderator = cond do
      user == nil -> false
      message.user.nick == "rekyuus" -> true
      true -> message.user.mode == :op
    end

    {channel, private} = case message.command do
      "WHISPER" -> {"private", true}
      "PRIVMSG" -> {"rekyuus", nil}
    end

    data = %{
      auth: Application.get_env(:twitch_kuma, :server_auth),
      type: "message",
      content: %{
        source: %{
          protocol: "irc",
          guild: %{name: "twitch", id: nil},
          channel: %{name: channel, id: nil, private: private, nsfw: private},
        user: %{
          id: nil,
          avatar: nil,
          name: message.user.nick,
          moderator: moderator},
        message: %{text: message.trailing, id: nil}
    } |> Poison.encode!

    conn = :gen_tcp.connect({127,0,0,1}, 5862, [:binary, packet: 0, active: false])

    case conn do
      {:ok, socket} ->
        case :gen_tcp.send(socket, data) do
          :ok ->
            case :gen_tcp.recv(socket, 0) do
              {:ok, response} ->
                case response |> Poison.Parser.parse!(keys: :atoms) do
                  %{reply: true, message: text} ->
                    case message.command do
                      "WHISPER" -> Kaguya.Util.sendPM("/w #{message.user.nick} #{text}", "#jtv")
                      "PRIVMSG" -> reply text
                    end
                  _ -> nil
                end
              {:error, reason} -> Logger.error "Receive error: #{reason}"
            end
          {:error, reason} -> Logger.error "Send error: #{reason}"
        end

        :gen_tcp.close(socket)
      {:error, reason} -> Logger.error "Connection error: #{reason}"
    end
  end
end
