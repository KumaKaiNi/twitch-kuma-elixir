defmodule TwitchKuma.Commands.Casino do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

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

  defh gift_all_coins(%{"gift" => gift}) do
    {gift, _} = gift |> Integer.parse

    cond do
      gift <= 0 -> reply "Please gift 1 coin or more."
      true ->
        users = query_all_data(:bank)

        for {username, coins} <- users do
          whisper username, "You have been gifted #{gift} coins!"
          store_data(:bank, username, coins + gift)
        end

        reply "Gifted everyone #{gift} coins!"
    end
  end

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
                reel = ["⚓", "⭐", "🍋", "🍊", "🍒", "🌸"]

                {col1, col2, col3} = {Enum.random(reel), Enum.random(reel), Enum.random(reel)}

                bonus = case {col1, col2, col3} do
                  {"🌸", "🌸", "⭐"} -> 2
                  {"🌸", "⭐", "🌸"} -> 2
                  {"⭐", "🌸", "🌸"} -> 2
                  {"🌸", "🌸", _}    -> 1
                  {"🌸", _, "🌸"}    -> 1
                  {_, "🌸", "🌸"}    -> 1
                  {"🍒", "🍒", "🍒"} -> 4
                  {"🍊", "🍊", "🍊"} -> 6
                  {"🍋", "🍋", "🍋"} -> 8
                  {"⚓", "⚓", "⚓"} -> 10
                  _ -> 0
                end

                whisper "#{col1} #{col2} #{col3}"

                case bonus do
                  0 ->
                    {stats, _} = get_user_stats(message.user.nick)
                    odds =
                      1250 * :math.pow(1.02256518256, -1 * stats.luck)
                      |> round

                    if one_to(odds) do
                      whisper "You didn't win, but the machine gave you your money back."
                    else
                      store_data(:bank, message.user.nick, bank - bet)

                      kuma = query_data(:bank, "kumakaini")
                      store_data(:bank, "kumakaini", kuma + bet)

                      whisper "Sorry, you didn't win anything."
                    end
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

  defh level_up(%{"stat" => stat}) do
    {stats, next_lvl_cost} = get_user_stats(message.user.nick)
    bank = query_data(:bank, message.user.nick)

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
            stats = %{stats | level: stats.level + 1}

            store_data(:bank, message.user.nick, bank - next_lvl_cost)
            store_data(:stats, message.user.nick, stats)
            whisper "You are now Level #{stats.level}! You have #{bank - next_lvl_cost} coins left."
        end
    end
  end

  defh check_level do
    {stats, next_lvl_cost} = get_user_stats(message.user.nick)
    bank = query_data(:bank, message.user.nick)

    whisper "You are Level #{stats.level}. It will cost #{next_lvl_cost} coins to level up. You currently have #{bank} coins. Type `!level <stat>` to do so."
  end

  defh check_stats do
    bank = query_data(:bank, message.user.nick)
    {stats, next_lvl_cost} = get_user_stats(message.user.nick)

    whisper "[Level #{stats.level}] [Coins: #{bank}] [Level Up Cost: #{next_lvl_cost}] [Vitality: #{stats.vit}] [Endurance: #{stats.end}] [Strength: #{stats.str}] [Dexterity: #{stats.dex}] [Intelligence: #{stats.int}] [Luck: #{stats.luck}]"
  end

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
end
