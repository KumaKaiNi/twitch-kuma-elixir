defmodule TwitchKuma do
  use Kaguya.Module, "main"
  import TwitchKuma.Util

  unless File.exists?("_db"), do: File.mkdir("_db")

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

  # Validator for rate limiting
  def rate_limit(msg) do
    {rate, _} = ExRated.check_rate(msg.trailing, 10_000, 1)

    case rate do
      :ok    -> true
      :error -> false
    end
  end

  # Enable Twitch Messaging Interface
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuu_senkan")
  end

  # Commands list
  handle "PRIVMSG" do
    enforce :rate_limit do
      match "!uptime", :uptime
      match "!time", :local_time
      match ["!coin", "!flip"], :coin_flip
      match "!predict ~question", :prediction
      match "!fortune", :fortune
      match "!smug", :smug
      match "!np", :lastfm_np
      match "!anime", :anime
      match_all :custom_command
      match ["ty kuma", "thanks kuma", "thank you kuma"], :ty_kuma
    end

    match ["hello", "hi", "hey", "sup"], :hello
    match ["same", "Same", "SAME"], :same

    # Mod command list
    enforce :is_mod do
      match ["!kuma", "!ping"], :ping
      match "!setanime ~anime", :set_anime
      match "!set :command ~action", :set_custom_command
      match "!del :command", :delete_custom_command
    end
  end

  # Command action handlers
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

  defh coin_flip, do: reply Enum.random(["Heads.", "Tails."])

  defh prediction(%{"question" => q}) do
    predictions = [
      "It is certain.",
      "It is decidedly so.",
      "Without a doubt.",
      "Yes, definitely.",
      "You may rely on it.",
      "As I see it, yes.",
      "Most likely.",
      "Outlook good.",
      "Yes.",
      "Signs point to yes.",
      "Reply hazy, try again.",
      "Ask again later.",
      "Better not tell you now.",
      "Cannot predict now.",
      "Concentrate and ask again.",
      "Don't count on it.",
      "My reply is no.",
      "My sources say no.",
      "Outlook not so good.",
      "Very doubtful."
    ]

    cond do
      length(q |> String.split) == 0 -> nil
      length(q |> String.split) >= 1 -> reply Enum.random(predictions)
    end
  end

  defh fortune do
    request = "http://fortunecookieapi.com/v1/cookie" |> HTTPoison.get!
    [response] = Poison.Parser.parse!((request.body), keys: :atoms)
    fortune = response.fortune.message

    reply fortune
  end

  defh smug do
    url = "https://api.imgur.com/3/album/zSNC1"
    auth = %{"Authorization" => "Client-ID #{Application.get_env(:twitch_kuma, :imgur_client_id)}"}

    request = HTTPoison.get!(url, auth)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    result = response.data.images |> Enum.random

    reply result.link
  end

  defh lastfm_np do
    timeframe = :os.system_time(:seconds) - 180
    url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=rekyuu&api_key=#{Application.get_env(:twitch_kuma, :lastfm_key)}&format=json&limit=1&from=#{timeframe}"

    request = HTTPoison.get!(url)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    track = response.recenttracks.track

    case List.first(track) do
      nil -> nil
      song -> reply "#{song.artist.'#text'} - #{song.name} [#{song.album.'#text'}]"
    end
  end

  defh anime do
    anime = query_data(:main, "anime")
    reply "Anime is #{anime}"
  end

  defh custom_command do
    action = query_data(:commands, message.trailing)

    case action do
      nil -> nil
      action -> reply action
    end
  end

  defh hello do
    replies = ["sup loser", "yo", "ay", "hi", "wassup"]
    if one_to(25) do
      reply Enum.random(replies)
    end
  end

  defh same do
    if one_to(25) do
      reply "same"
    end
  end

  defh ty_kuma do
    replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
    reply Enum.random(replies)
  end

  # Moderator action handlers
  defh ping, do: reply "Kuma~!"

  defh set_anime(%{"anime" => anime}) do
    store_data(:main, "anime", anime)
    reply "All set!"
  end

  defh set_custom_command(%{"command" => command, "action" => action}) do
    store_data(:commands, "!#{command}", action)
    reply "Alright! Type !#{command} to use."
  end

  defh delete_custom_command(%{"command" => command}) do
    action = query_data(:commands, "!#{command}")

    case action do
      nil -> reply "Command does not exist."
      _   ->
        delete_data(:commands, "!#{command}")
        reply "Command !#{command} removed."
    end
  end
end
