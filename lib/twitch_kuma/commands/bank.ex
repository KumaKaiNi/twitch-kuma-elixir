defmodule TwitchKuma.Commands.Bank do
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

  defh give_user_coins(%{"username" => username, "amount" => amount}) do
    amount = amount |> Integer.parse
    from_bank = query_data(:bank, message.user.nick)
    to_bank = query_data(:bank, username)

    case amount do
      :error -> whisper "That is not a valid amount."
      {amount, _} ->
        case to_bank do
          nil -> whisper "That user does not exist."
          to_bank ->
            cond do
              amount <= 0 -> whisper "Please change your gift to an amount greater than 0."
              from_bank < amount -> whisper "You do not have enough coins."
              true ->
                store_data(:bank, message.user.nick, from_bank - amount)
                store_data(:bank, username, to_bank + amount)

                whisper "You gifted #{username} #{amount} coins."
                whisper username, "#{message.user.nick} gifted you #{amount} coins!"
            end
        end
    end
  end
end
