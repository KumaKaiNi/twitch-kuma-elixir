defmodule TwitchKuma.Util do
  def app_dir, do: "#{Application.app_dir(:twitch_kuma)}"

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def pay_user(user, n) do
    bonus = query_data(:casino, :bonus)
    bank = query_data(:bank, user)
    earnings = n * bonus

    coins = case bank do
      nil -> earnings
      bank -> bank + earnings
    end

    store_data(:bank, user, coins)
  end

  def get_user_stats(username) do
    stats = query_data(:stats, username)
    stats = case stats do
      nil -> %{level: 1, vit: 10, end: 10, str: 10, dex: 10, int: 10, luck: 10}
      stats -> stats
    end

    next_lvl = stats.level + 1
    next_lvl_cost =
      :math.pow((3.741657388 * next_lvl), 2) + (100 * next_lvl) |> round

    {stats, next_lvl_cost}
  end

  def bingo_builder(category, len) do
    seed = Float.ceil(999999 * :rand.uniform) |> round

    base = case category do
      "short"   -> "http://botw.site11.com/?seed=#{seed}&mode=short"
      "normal"  -> "http://botw.site11.com/?seed=#{seed}"
      "long"    -> "http://botw.site11.com/?seed=#{seed}&mode=long"
      "plateau" -> "http://botw.site11.com/gp.html?seed=#{seed}"
      "korok"   -> "http://botw.site11.com/korok.html?seed=#{seed}"
      "shrine"  -> "http://botw.site11.com/shrine.html?seed=#{seed}"
      "comp"    -> "http://botw.site11.com/comp.html?seed=#{seed}"
      _ -> nil
    end

    case len do
      nil -> base
      len -> base <> "&mode=#{len}"
    end
  end

  def store_data(table, key, value) do
    file = '/home/bowan/bots/_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])

    :dets.insert(table, {key, value})
    :dets.close(table)
  end

  def query_data(table, key) do
    file = '/home/bowan/bots/_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    result = :dets.lookup(table, key)

    response =
      case result do
        [{_, value}] -> value
        [] -> nil
      end

    :dets.close(table)
    response
  end

  def query_all_data(table) do
    file = '/home/bowan/bots/_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    result = :dets.match_object(table, {:"$1", :"$2"})

    response =
      case result do
        [] -> nil
        values -> values
      end

    :dets.close(table)
    response
  end

  def delete_data(table, key) do
    file = '/home/bowan/bots/_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    response = :dets.delete(table, key)

    :dets.close(table)
    response
  end

  def log_to_file(msg) do
    logfile = "/home/bowan/bots/_db/twitch.log"
    time = DateTime.utc_now |> DateTime.to_iso8601
    logline = "[#{time}] KumaKaiNi: #{msg}\n"
    File.write!(logfile, logline, [:append])
  end
end
