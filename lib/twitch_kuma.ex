defmodule TwitchKuma do
  use Kaguya.Module, "main"
  use TwitchKuma.Module

  unless File.exists?("/home/bowan/bots/_db"), do: File.mkdir("/home/bowan/bots/_db")

  # Validator for mods
  def is_mod(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    cond do
      user == nil -> false
      nick == "rekyuus" -> true
      true -> user.mode == :op
    end
  end

  # Validator for rekyuu
  def rekyuu(%{user: %{nick: nick}}) do
    nick == "rekyuus"
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
    match_all :moderate

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
      match "!jackpot", :get_jackpot
      match "!bet :amount :betname ~choice", :make_bet
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
      match "!newbet :betname ~choices", :create_new_bet
      match "!close :betname", :close_bet
      match "!winner :betname ~choice", :finalize_bet
      match "!draw", :lottery_drawing
    end

    enforce :rekyuu do
      match "!mincoins :multiplier", :set_rate_per_minute
      match "!msgcoins :multiplier", :set_rate_per_message
      match "!bonus :multiplier", :set_bonus
    end

    match_all :payout
  end

  # Whisper commands
  handle "WHISPER" do
    match "!coins", :coins
    match "!level :stat", :level_up
    match "!level", :check_level
    match "!stats", :check_stats
    match "!slots :bet", :slot_machine
    match "!lottery ~numbers", :buy_lottery_ticket
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

  handle "PING" do
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

  # Chat logging
  defh logger do
    logfile = "/home/bowan/bots/_db/twitch.log"
    time = DateTime.utc_now |> DateTime.to_iso8601
    logline = "[#{time}] #{message.user.nick}: #{message.trailing}\n"
    File.write!(logfile, logline, [:append])
  end

  defh moderate do
    words = message.trailing |> String.split
    stats = query_data(:stats, message.user.nick)

    if stats.level == 4 do
      links = for word <- words do
        uri = case URI.parse(word) do
          %URI{host: nil, path: path} ->
            if length(path |> String.split(".")) >= 2 do
              :inet.gethostbyname(String.to_charlist(path))
            else
              nil
            end
          %URI{host: host} ->
            :inet.gethostbyname(String.to_charlist(host))
          uri -> nil
        end

        case uri do
          {:ok, _} -> true
          {:error, _} -> false
          nil -> false
        end
      end

      if links do
        if Enum.member?(links, true) do
          reply "/purge #{message.user.nick}"
        end
      end
    end
  end

  # Casino Stuff
  defh payout do
    rate_per_message = query_data(:casino, :rate_per_message)

    case String.first(message.trailing) do
      "!" -> nil
      _   -> pay_user(message.user.nick, rate_per_message)
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

  defh get_jackpot do
    jackpot = query_data(:bank, "kumakaini")
    replylog "There are #{jackpot} coins in the jackpot."
  end

  # Betting
  defh create_new_bet(%{"betname" => betname, "choices" => choices}) do
    choices = choices |> String.split(", ")
    store_data(:bets, betname, %{choices: choices, users: [], closed: false})
    reply "Bet created! Make bets by using !bet <amount> #{betname} <choice>"
  end

  defh make_bet(%{"amount" => amount, "betname" => betname, "choice" => choice}) do
    bet = query_data(:bets, betname)

    cond do
      bet.closed == false ->
        cond do
          Enum.member?(bet.choices, choice) ->
            bank = query_data(:bank, message.user.nick)
            {amount, _} = amount |> Integer.parse

            cond do
              amount > bank -> whisper "You do not have enough coins to make your bet. You have #{bank} coins."
              amount <= 0 -> nil
              true ->
                users = bet.users ++ [{message.user.nick, choice, amount}]

                store_data(:bank, message.user.nick, bank - amount)
                store_data(:bets, betname, %{choices: bet.choices, users: users, closed: false})

                whisper "You placed #{amount} coins on #{choice}. You now have #{bank - amount} coins."
            end
          true -> whisper "#{choice} is not a valid selection for #{betname}."
        end
      true -> whisper "Bets for #{betname} are closed, sorry!"
    end
  end

  defh close_bet(%{"betname" => betname}) do
    bet = query_data(:bets, betname)

    cond do
      bet.closed == false ->
        store_data(:bets, betname, %{choices: bet.choices, users: bet.users, closed: true})
        reply "Bets for #{betname} are now closed!"
      true ->
        store_data(:bets, betname, %{choices: bet.choices, users: bet.users, closed: false})
        reply "Bets for #{betname} have been re-opened!"
    end
  end

  defh finalize_bet(%{"betname" => betname, "choice" => choice}) do
    bet = query_data(:bets, betname)

    cond do
      Enum.member?(bet.choices, choice) ->
        for {username, user_choice, bet_amount} <- bet.users do
          cond do
            user_choice == choice ->
              pay_user(username, bet_amount * 2)
              whisper(username, "#{choice} has won! You've earned #{bet_amount * 2} coins.")
            true ->
              jackpot = query_data(:bank, "kumakaini")
              store_data(:bank, "kumakaini", jackpot + bet_amount)
          end
        end

        delete_data(:bets, betname)
        reply "#{choice} has won! Winnings have been distributed."
      true -> reply "#{choice} is not a valid selection for #{betname}."
    end
  end

  # Casino games
  defh slot_machine(%{"bet" => bet}) do
    bet = bet |> Integer.parse

    case bet do
      {bet, _} ->
        cond do
          bet > 25  -> whisper "You must bet between 1 and 25 coins."
          bet < 1   -> whisper "You must bet between 1 and 25 coins."
          true ->
            bank = query_data(:bank, message.user.nick)

            cond do
              bank < bet -> whisper "You do not have enough coins."
              true ->
                reel = ["⚓", "💎", "🍋", "🍊", "🍒", "🌸"]

                {col1, col2, col3} = {Enum.random(reel), Enum.random(reel), Enum.random(reel)}

                bonus = case {col1, col2, col3} do
                  {"⚓", "⚓", "⚓"} -> 10
                  {"🍋", "🍋", "🍋"} -> 8
                  {"🍊", "🍊", "🍊"} -> 6
                  {"🍒", "🍒", "🍒"} -> 4
                  {"🌸", "🌸", "💎"} -> 2
                  {"🌸", "💎", "🌸"} -> 2
                  {"💎", "🌸", "🌸"} -> 2
                  {"🌸", "🌸", _}    -> 1
                  {"🌸", _, "🌸"}    -> 1
                  {_, "🌸", "🌸"}    -> 1
                  _ -> 0
                end

                whisper "#{col1} #{col2} #{col3}"

                case bonus do
                  0 ->
                    store_data(:bank, message.user.nick, bank - bet)

                    kuma = query_data(:bank, "kumakaini")
                    store_data(:bank, "kumakaini", kuma + bet)

                    whisper "Sorry, you didn't win anything."
                  bonus ->
                    payout = bet * bonus
                    store_data(:bank, message.user.nick, bank - bet + payout)
                    whisper "Congrats, you won #{payout} coins!"
                end
            end
        end
      :error -> whisper "Usage: !slots <bet>, where <bet> is a number between 1 and 25."
    end
  end

  # Lottery tickets
  defh buy_lottery_ticket(%{"numbers" => choices}) do
    ticket = query_data(:lottery, message.user.nick)

    case ticket do
      nil ->
        bank = query_data(:bank, message.user.nick)

        cond do
          bank < 50 -> whisper "You do not have 50 coins to purchase a lottery ticket."
          true ->
            choices = choices |> String.split
            {_, safeguard} = choices |> Enum.join |> Integer.parse
            numbers = choices |> Enum.join |> String.length

            case safeguard do
              "" ->
                cond do
                  length(choices) == 3 and numbers == 3 ->
                    jackpot = query_data(:bank, "kumakaini")

                    store_data(:bank, message.user.nick, bank - 50)
                    store_data(:bank, "kumakaini", jackpot + 50)

                    store_data(:lottery, message.user.nick, choices |> Enum.join(" "))

                    whisper "Your lottery ticket of #{choices |> Enum.join(" ")} has been purchased for 50 coins."
                  true -> whisper "Please send me three numbers, ranging between 0-9."
                end
              _ -> whisper "Please only send me three numbers, ranging between 0-9."
            end
        end
      ticket -> whisper "You've already purchased a ticket of #{ticket}. Please wait for the next drawing to buy again."
    end
  end

  defh lottery_drawing do
    winning_ticket = "#{Enum.random(0..9)} #{Enum.random(0..9)} #{Enum.random(0..9)}"

    reply "The winning numbers today are #{winning_ticket}!"

    winners = for {username, ticket} <- query_all_data(:lottery) do
      delete_data(:lottery, username)

      cond do
        ticket == winning_ticket -> username
        true -> nil
      end
    end

    jackpot = query_data(:bank, "kumakaini")
    winners = Enum.uniq(winners) -- [nil]

    case length(winners) do
      0 -> reply "There are no winners."
      _ ->
        winnings = jackpot / length(winners) |> round

        for winner <- winners do
          pay_user(winner, winnings)
          reply "#{winner} has won #{winnings} coins!"
          whisper winner, "You won the jackpot of #{winnings} coins! Congratulations!!"
        end

        reply "Congratulations!!"

        store_data(:bank, "kumakaini", 0)
    end
  end

  # Leveling
  defh level_up(%{"stat" => stat}) do
    stats = query_data(:stats, message.user.nick)
    bank = query_data(:bank, message.user.nick)

    stats = case stats do
      nil -> %{level: 1, vit: 10, end: 10, str: 10, dex: 10, int: 10, luck: 10}
      stats -> stats
    end

    next_lvl = stats.level + 1
    next_lvl_cost =
      :math.pow((3.741657388 * next_lvl), 2) + (100 * next_lvl) |> round

    cond do
      next_lvl_cost > bank -> whisper "You do not have enough coins. #{next_lvl_cost} coins are required. You currently have #{bank} coins."
      true ->
        stat = case stat do
          "vit" -> "vitality"
          "end" -> "endurance"
          "str" -> "strength"
          "dex" -> "dexterity"
          "int" -> "intelligence"
          stat -> stat
        end

        stats = case stat do
          "vitality"      -> %{stats | vit: stats.vit + 1}
          "endurance"     -> %{stats | end: stats.end + 1}
          "strength"      -> %{stats | str: stats.str + 1}
          "dexterity"     -> %{stats | dex: stats.dex + 1}
          "intelligence"  -> %{stats | int: stats.int + 1}
          "luck"          -> %{stats | luck: stats.luck + 1}
          _ -> :error
        end

        case stats do
          :error -> whisper "That is not a valid stat. Valid stats are vit, end, str, dex, int, luck."
          stats ->
            stats = %{stats | level: next_lvl}

            store_data(:bank, message.user.nick, bank - next_lvl_cost)
            store_data(:stats, message.user.nick, stats)
            whisper "You are now Level #{stats.level}! You have #{bank - next_lvl_cost} coins left."
        end
    end
  end

  defh check_level do
    stats = query_data(:stats, message.user.nick)
    bank = query_data(:bank, message.user.nick)

    stats = case stats do
      nil -> %{level: 1, vit: 10, end: 10, str: 10, dex: 10, int: 10, luck: 10}
      stats -> stats
    end

    next_lvl = stats.level + 1
    next_lvl_cost =
      :math.pow((3.741657388 * next_lvl), 2) + (100 * next_lvl) |> round

    whisper "You are Level #{stats.level}. It will cost #{next_lvl_cost} coins to level up. You currently have #{bank} coins. Type `!level <stat>` to do so."
  end

  defh check_stats do
    stats = query_data(:stats, message.user.nick)
    stats = case stats do
      nil -> %{level: 1, vit: 10, end: 10, str: 10, dex: 10, int: 10, luck: 10}
      stats -> stats
    end

    next_lvl = stats.level + 1
    next_lvl_cost =
      :math.pow((3.741657388 * next_lvl), 2) + (100 * next_lvl) |> round

    whisper "[Level #{stats.level}] [Vitality: #{stats.vit}] [Endurance: #{stats.end}] [Strength: #{stats.str}] [Dexterity: #{stats.dex}] [Intelligence: #{stats.int}] [Luck: #{stats.luck}] [#{next_lvl_cost} coins for Level #{next_lvl}]"
  end

  # Administrative Casino Commands
  defh set_bonus(%{"multiplier" => multiplier}) do
    store_data(:casino, :bonus, multiplier |> String.to_integer)
    reply "Bonus multiplier of x#{multiplier} set!"
  end

  defh set_rate_per_minute(%{"multiplier" => multiplier}) do
    store_data(:casino, :rate_per_minute, multiplier |> String.to_integer)
    reply "Done, users will earn #{multiplier} coins per minute."
  end

  defh set_rate_per_message(%{"multiplier" => multiplier}) do
    store_data(:casino, :rate_per_message, multiplier |> String.to_integer)
    reply "Done, users will earn #{multiplier} coins per message."
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

  defh prediction(%{"question" => _q}) do
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
