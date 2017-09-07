defmodule TwitchKuma.Commands.RPG do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

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
end
