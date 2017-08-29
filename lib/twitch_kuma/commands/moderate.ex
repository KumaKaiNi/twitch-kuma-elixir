defmodule TwitchKuma.Commands.Moderate do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh moderate do
    words = message.trailing |> String.split
    stats = query_data(:stats, message.user.nick)
    coins = query_data(:bank, message.user.nick)

    unless stats do
      unless coins >= 256 do
        links = for word <- words do
          uri = case URI.parse(word) do
            %URI{host: nil, path: path} ->
              if length((path |> String.split(".")) -- [""]) >= 2 do
                path = "www." <> path
                Logger.warn "Banning for posting link: #{path}"
                :inet.gethostbyname(String.to_charlist(path))
              else
                nil
              end
            %URI{host: host} ->
              Logger.warn "Banning for posting link: #{host}"
              :inet.gethostbyname(String.to_charlist(host))
            uri -> nil
          end

          case uri do
            {:ok, _} -> true
            {:error, _} -> false
            nil -> false
          end
        end

        if links do
          if Enum.member?(links, true) do
            reply "/timeout #{message.user.nick} 1 You must be Level 2 to post links."
          end
        end
      end
    end
  end
end
