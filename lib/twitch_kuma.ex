defmodule TwitchKuma do
  use Kaguya.Module, "main"
  import TwitchKuma.Util
  require Logger

  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/commands"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuus")
  end

  handle "PRIVMSG" do
    match "!kuma", :kuma
    match_all :make_call
  end

  handle "WHISPER", do: match_all :make_call

  handle "JOIN", do: viewer_join(message)
  handle "PART", do: viewer_part(message)
  handle "PING", do: viewer_payout

  defh make_call do
    user = if message.command == "PRIVMSG" do
      [chan] = message.args
      pid = Kaguya.Util.getChanPid(chan)
      GenServer.call(pid, {:get_user, message.user.nick})
    end

    moderator = cond do
      user == nil -> false
      #message.user.nick == "rekyuus" -> true
      true -> if Map.has_key?(user, :mode) do
        user.mode == :op
      else
        false
      end
    end

    {channel, private} = case message.command do
      "WHISPER" -> {"private", true}
      "PRIVMSG" -> {"rekyuus", nil}
    end

    data = %{
      protocol: "irc",
      guild: %{id: nil, name: "twitch"},
      channel: %{id: nil, name: channel, private: private, nsfw: private},
      user: %{
        id: nil,
        avatar: nil,
        name: message.user.nick,
        moderator: moderator
      },
      message: %{id: nil, text: message.trailing, image: nil}
    } |> Poison.encode!

    headers = %{
      "Authorization" => Application.get_env(:twitch_kuma, :server_auth),
      "Content-Type" => "application/json"
    }
    
    request = HTTPoison.post!("http://kuma.riichi.me/api", data, headers)

    case request |> Map.fetch!(:body) |> parse() do
      %{text: text, image: image} ->
        case message.command do
          "WHISPER" -> Kaguya.Util.sendPM("/w #{message.user.nick} #{image.source}", "#jtv")
          "PRIVMSG" -> reply image.source
        end
      %{text: text} ->
        case message.command do
          "WHISPER" -> Kaguya.Util.sendPM("/w #{message.user.nick} #{text}", "#jtv")
          "PRIVMSG" -> reply text
        end
      response -> IO.inspect response, label: "unknown response"
    end
  end

  defh kuma do
    IO.inspect message
    reply "Kuma~!"
  end

  def viewer_join(message) do
    url = "https://decapi.me/twitch/uptime?channel=rekyuus"
    request =  HTTPoison.get! url

    case request.body do
      "rekyuus is offline" -> nil
      _ ->
        current_time = DateTime.utc_now |> DateTime.to_unix
        store_data(:viewers, message.user.nick, current_time)
    end
  end

  def viewer_part(message) do
    viewers = query_all_data(:viewers)

    case viewers do
      nil -> nil
      _viewers ->
        rate_per_minute = query_data(:casino, :rate_per_minute)
        join_time = query_data(:viewers, message.user.nick)
        current_time = DateTime.utc_now |> DateTime.to_unix
        total_time = current_time - join_time
        payout = (total_time / 60) * rate_per_minute

        pay_user(message.user.nick, round(payout))
        delete_data(:viewers, message.user.nick)
    end
  end

  def viewer_payout do
    url = "https://decapi.me/twitch/uptime?channel=rekyuus"
    request =  HTTPoison.get! url

    rate_per_minute = query_data(:casino, :rate_per_minute)
    current_time = DateTime.utc_now |> DateTime.to_unix
    viewers = query_all_data(:viewers)

    case viewers do
      nil -> nil
      viewers ->
        case request.body do
          "rekyuus is offline" ->
            for viewer <- viewers do
              {user, join_time} = viewer
              total_time = current_time - join_time
              payout = (total_time / 60) * rate_per_minute

              pay_user(user, round(payout))
              delete_data(:viewers, user)
            end
          _ ->
            for viewer <- viewers do
              {user, join_time} = viewer
              total_time = current_time - join_time
              payout = (total_time / 60) * rate_per_minute

              pay_user(user, round(payout))
              store_data(:viewers, user, current_time)
            end
        end
    end
  end

  def parse(map) do
    case map do
      "" -> nil
      map -> Poison.Parser.parse!(keys: :atoms)
    end
  end
end
