defmodule TwitchKuma.Util do
  def app_dir, do: Application.app_dir(:twitch_kuma) <> "/"

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def store_data(table, key, value) do
    {:ok, db} = :dets.open_file(table, [type: :set, file: app_dir <> "#{table}.dets"])
    :dets.insert(db, {key, value})
    :dets.close(db)
  end

  def query_data(table, key) do
    {:ok, db} = :dets.open_file(table, [type: :set, file: app_dir <> "#{table}.dets"])
    result = :dets.lookup(db, key)

    response =
      case result do
        [{_, value}] -> value
        [] -> nil
      end

    :dets.close(db)
    response
  end

  def delete_data(table, key) do
    {:ok, db} = :dets.open_file(table, [type: :set, file: app_dir <> "#{table}.dets"])
    response = :dets.delete(db, key)

    :dets.close(db)
    response
  end
end
