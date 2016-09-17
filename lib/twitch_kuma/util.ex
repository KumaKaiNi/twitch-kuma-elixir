defmodule TwitchKuma.Util do
  def app_dir, do: Application.app_dir(:twitch_kuma) <> "/"

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def store_data(key, value), do: File.write!(app_dir <> key, value)
  def query_data(key), do: File.read!(app_dir <> key)
end
