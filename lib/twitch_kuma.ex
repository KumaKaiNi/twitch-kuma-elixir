defmodule TwitchKuma do
  use Kaguya.Module, "main"
  
  handle "PRIVMSG" do
    match ["!ping", "!p"], :pingHandler
    match "hi", :hiHandler
    match "!say ~message", :sayHandler
  end

  defh pingHandler, do: reply "pong!"
  defh hiHandler(%{user: %{nick: nick}}), do: reply "hi #{nick}!"
  defh sayHandler(%{"message" => response}), do: reply response
end
