defmodule TwitchKuma.Commands.Casino do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh get_jackpot do
    jackpot = query_data(:bank, "kumakaini")
    replylog "There are #{jackpot} coins in the jackpot."
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
end
