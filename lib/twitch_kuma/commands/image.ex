defmodule TwitchKuma.Commands.Image do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh smug do
    url = "https://api.imgur.com/3/album/zSNC1"
    auth = %{"Authorization" => "Client-ID #{Application.get_env(:twitch_kuma, :imgur_client_id)}"}

    request = HTTPoison.get!(url, auth)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    result = response.data.images |> Enum.random

    replylog result.link
  end
end
