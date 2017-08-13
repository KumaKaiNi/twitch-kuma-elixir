defmodule TwitchKuma do
  use Kaguya.Module, "main"
  use TwitchKuma.Module

  unless File.exists?("/home/bowan/bots/_db"), do: File.mkdir("/home/bowan/bots/_db")

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

  # Validator for rekyuu
  def rekyuu do
    message.user.nick == "rekyuus"
  end

  # Validator for rate limiting
  def rate_limit(msg) do
    {rate, _} = ExRated.check_rate(msg.trailing, 10_000, 1)

    case rate do
      :ok    -> true
      :error -> false
    end
  end

  # Enable Twitch Messaging Interface and whispers
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/commands"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuus")
  end

  # Commands list
  handle "PRIVMSG" do
    match_all :logger

    enforce :rate_limit do
      match "!help", :help
      match "!uptime", :uptime
      match "!time", :local_time
      match ["!coin", "!flip"], :coin_flip
      match "!predict ~question", :prediction
      match "!smug", :smug
      match "!np", :lastfm_np
      match "!guidance", :souls_message
      match "!souls :game", :get_souls_run
      match "!botw ~variables", :get_botw_bingo
      match "!botw", :get_botw_bingo
      match "!quote :quote_id", :get_quote
      match "!quote", :get_quote
      match_all :custom_command
      match ["ty kuma", "thanks kuma", "thank you kuma"], :ty_kuma
    end

    match ["hello", "hi", "hey", "sup"], :hello
    match ["same", "Same", "SAME"], :same
    match ["PogChamp", "Kappa", "FrankerZ", "Kreygasm", "BibleThump", "PunOko", "KonCha", "TehePelo", "DontAtMe", "Exploded", "FeelsAkariMan", "IffyLewd", "KuNai", "OmegaKuNai", "OMEGALUL", "MegaLUL", "LUL", "servSugoi"], :emote

    # Mod command list
    enforce :is_mod do
      match ["!kuma", "!ping"], :ping
      match "!add :command ~action", :set_custom_command
      match "!del :command", :delete_custom_command
      match "!addquote ~quote_text", :add_quote
      match "!delquote :quote_id", :del_quote
    end

    enforce :rekyuu do
      match "!wage :multiplier", :set_wage
      match "!bonus :multiplier", :set_bonus
    end

    match_all :payout
  end

  # Whisper commands
  handle "WHISPER" do
    match "!help", :help_whisper
    match "!coins", :coins
  end

  # Payout helper for viewing
  handle "JOIN" do
    url = "https://decapi.me/twitch/uptime?channel=rekyuus"
    request =  HTTPoison.get! url

    case request.body do
      "rekyuus is offline" -> nil
      _ ->
        current_time = DateTime.utc_now |> DateTime.to_unix
        store_data(:viewers, message.user.nick, current_time)
    end
  end

  handle "PART" do
    wage = query_data(:casino, :wage)
    join_time = query_data(:viewers, message.user.nick)
    current_time = DateTime.utc_now |> DateTime.to_unix
    total_time = current_time - join_time
    payout = (total_time / 60) * wage

    pay_user(message.user.nick, round(payout))
    delete_data(:viewers, message.user.nick)
  end

  handle "PING" do
    url = "https://decapi.me/twitch/uptime?channel=rekyuus"
    request =  HTTPoison.get! url

    wage = query_data(:casino, :wage)
    current_time = DateTime.utc_now |> DateTime.to_unix
    viewers = query_all_data(:viewers)

    case request.body do
      "rekyuus is offline" ->
        for viewer <- viewers do
          {user, join_time} = viewer
          total_time = current_time - join_time
          payout = (total_time / 60) * wage

          pay_user(user, round(payout))
          delete_data(:viewers, user)
        end
      _ ->
        for viewer <- viewers do
          {user, join_time} = viewer
          total_time = current_time - join_time
          payout = (total_time / 60) * wage

          pay_user(user, round(payout))
          store_data(:viewers, user, current_time)
        end
    end
  end

  defh help_whisper, do: whisper "Sorry, I don't have any whisper features yet. https://github.com/KumaKaiNi/twitch-kuma-elixir"

  # Chat logging
  defh logger do
    logfile = "/home/bowan/bots/_db/twitch.log"
    time = DateTime.utc_now |> DateTime.to_iso8601
    logline = "[#{time}] #{message.user.nick}: #{message.trailing}\n"
    File.write!(logfile, logline, [:append])
  end

  # Casino Stuff
  defh payout do
    case String.first(message.trailing) do
      "!" -> nil
      _   -> pay_user(message.user.nick, String.length(message.trailing))
    end
  end

  defh coins do
    bank = query_data(:bank, message.user.nick)

    amount = case bank do
      nil -> "no"
      bank -> bank
    end

    whisper "You have #{amount} coins."
  end

  # Administrative Casino Commands
  defh set_bonus(%{"multiplier" => multiplier}) do
    store_data(:casino, :multiplier, multiplier)
    reply "Bonus of x#{multiplier} set!"
  end

  defh set_wage(%{"multiplier" => multiplier}) do
    store_data(:casino, :wage, multiplier)
    reply "Wage of #{multiplier} coins per minute set!"
  end

  # Command action handlers
  defh help, do: replylog "https://github.com/KumaKaiNi/twitch-kuma-elixir"

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

  defh coin_flip, do: replylog Enum.random(["Heads.", "Tails."])

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
      "My replylog is no.",
      "My sources say no.",
      "Outlook not so good.",
      "Very doubtful."
    ]

    replylog Enum.random(predictions)
  end

  defh smug do
    url = "https://api.imgur.com/3/album/zSNC1"
    auth = %{"Authorization" => "Client-ID #{Application.get_env(:twitch_kuma, :imgur_client_id)}"}

    request = HTTPoison.get!(url, auth)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    result = response.data.images |> Enum.random

    replylog result.link
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

  defh souls_message do
    url = "http://souls.riichi.me/api"
    request = HTTPoison.get!(url)
    response = Poison.Parser.parse!((request.body), keys: :atoms)

    replylog "#{response.message}"
  end

  defh get_souls_run(%{"game" => game}) do
    url = "http://souls.riichi.me/api/#{game}"
    request = HTTPoison.get!(url)
    response = Poison.Parser.parse!((request.body), keys: :atoms)

    try do
      replylog "http://souls.riichi.me/#{game}/#{response.seed}"
    rescue
      KeyError -> replylog "#{response.message}"
    end
  end

  defh get_botw_bingo(%{"variables" => variables}) do
    cond do
      length(variables |> String.split) == 1 ->
        replylog bingo_builder(variables, nil)
      length(variables |> String.split) == 2 ->
        [category, len] = variables |> String.split
        replylog bingo_builder(category, len)
      true -> nil
    end
  end

  defh get_botw_bingo do
    seed = Float.ceil(999999 * :rand.uniform) |> round
    replylog "http://botw.site11.com/?seed=#{seed}"
  end

  defh get_quote(%{"quote_id" => quote_id}) do
    case quote_id |> Integer.parse do
      {quote_id, _} ->
        case query_data(:quotes, quote_id) do
          nil -> replylog "Quote \##{quote_id} does not exist."
          quote_text -> replylog "[\##{quote_id}] #{quote_text}"
        end
      :error ->
        quotes = query_all_data(:quotes)
        {quote_id, quote_text} = Enum.random(quotes)

        replylog "[\##{quote_id}] #{quote_text}"
    end
  end

  defh get_quote do
    quotes = query_all_data(:quotes)
    {quote_id, quote_text} = Enum.random(quotes)

    replylog "[\##{quote_id}] #{quote_text}"
  end

  defh custom_command do
    action = query_data(:commands, message.trailing)

    case action do
      nil -> nil
      action -> replylog action
    end
  end

  defh hello do
    replies = ["sup loser", "yo", "ay", "hi", "wassup"]
    if one_to(25) do
      replylog Enum.random(replies)
    end
  end

  defh same do
    if one_to(25) do
      replylog "same"
    end
  end

  defh emote do
    if one_to(25) do
      replylog message.trailing
    end
  end

  defh ty_kuma do
    replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
    replylog Enum.random(replies)
  end

  # Moderator action handlers
  defh ping, do: replylog "Kuma~!"

  defh set_custom_command(%{"command" => command, "action" => action}) do
    exists = query_data(:commands, "!#{command}")
    store_data(:commands, "!#{command}", action)

    case exists do
      nil -> replylog "Alright! Type !#{command} to use."
      _   -> replylog "Done, command !#{command} updated."
    end
  end

  defh delete_custom_command(%{"command" => command}) do
    action = query_data(:commands, "!#{command}")

    case action do
      nil -> replylog "Command does not exist."
      _   ->
        delete_data(:commands, "!#{command}")
        replylog "Command !#{command} removed."
    end
  end

  defh add_quote(%{"quote_text" => quote_text}) do
    quotes = case query_all_data(:quotes) do
      nil -> nil
      quotes -> quotes |> Enum.sort
    end

    quote_id = case quotes do
      nil -> 1
      _ ->
        {quote_id, _} = List.last(quotes)
        quote_id + 1
    end

    store_data(:quotes, quote_id, quote_text)
    replylog "Quote added! #{quote_id} quotes total."
  end

  defh del_quote(%{"quote_id" => quote_id}) do
    case quote_id |> Integer.parse do
      {quote_id, _} ->
        case query_data(:quotes, quote_id) do
          nil -> replylog "Quote \##{quote_id} does not exist."
          _ ->
            delete_data(:quotes, quote_id)
            replylog "Quote removed."
        end
      :error -> replylog "You didn't specify an ID number."
    end
  end
end
