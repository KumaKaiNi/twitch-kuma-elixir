defmodule TwitchKuma.Commands.Random do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh coin_flip, do: replylog Enum.random(["Heads.", "Tails."])

  defh prediction(%{"question" => _q}) do
    predictions = [
      "It is certain.",
      "It is decidedly so.",
      "Without a doubt.",
      "Yes, definitely.",
      "You may rely on it.",
      "As I see it, yes.",
      "Most likely.",
      "Outlook good.",
      "Yes.",
      "Signs point to yes.",
      "Reply hazy, try again.",
      "Ask again later.",
      "Better not tell you now.",
      "Cannot predict now.",
      "Concentrate and ask again.",
      "Don't count on it.",
      "My replylog is no.",
      "My sources say no.",
      "Outlook not so good.",
      "Very doubtful."
    ]

    replylog Enum.random(predictions)
  end

  defh souls_message do
    url = "http://souls.riichi.me/api"
    request = HTTPoison.get!(url)
    response = Poison.Parser.parse!((request.body), keys: :atoms)

    replylog "#{response.message}"
  end
end
