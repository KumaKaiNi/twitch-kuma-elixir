defmodule TwitchKuma.Commands.Betting do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

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
end
