defmodule TwitchKuma.Util do
  def app_dir, do: "#{Application.app_dir(:twitch_kuma)}"

  def whisper(user, msg), do: Kaguya.Util.sendPM("/w #{user} #{msg}", "#jtv")

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def store_data(table, key, value) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])

    :dets.insert(table, {key, value})
    :dets.close(table)
  end

  def query_data(table, key) do
    file = '_db/#{table}.dets'
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

  def delete_data(table, key) do
    file = '_db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    response = :dets.delete(table, key)

    :dets.close(table)
    response
  end
end
