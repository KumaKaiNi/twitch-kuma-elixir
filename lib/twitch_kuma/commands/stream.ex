defmodule TwitchKuma.Commands.Stream do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh uptime do
    url = "https://decapi.me/twitch/uptime?channel=rekyuus"
    request =  HTTPoison.get! url

    case request.body do
      "rekyuus is offline" -> replylog "Stream is not online!"
      time -> replylog "Stream has been live for #{time}."
    end
  end

  defh local_time do
    {{_, _, _}, {hour, minute, _}} = :calendar.local_time

    h = cond do
      hour <= 9 -> "0#{hour}"
      true      -> "#{hour}"
    end

    m = cond do
      minute <= 9 -> "0#{minute}"
      true        -> "#{minute}"
    end

    replylog "It is #{h}:#{m} MST rekyuu's time."
  end

  defh lastfm_np do
    timeframe = :os.system_time(:seconds) - 180
    url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=rekyuu&api_key=#{Application.get_env(:twitch_kuma, :lastfm_key)}&format=json&limit=1&from=#{timeframe}"

    request = HTTPoison.get!(url)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    track = response.recenttracks.track

    case List.first(track) do
      nil -> nil
      song -> replylog "#{song.artist.'#text'} - #{song.name} [#{song.album.'#text'}]"
    end
  end
end
