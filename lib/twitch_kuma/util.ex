defmodule TwitchKuma.Util do
  def app_dir, do: "#{Application.app_dir(:twitch_kuma)}"

  def whisper(user, msg), do: Kaguya.Util.sendPM("/w #{user} #{msg}", "#jtv")

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

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
end
