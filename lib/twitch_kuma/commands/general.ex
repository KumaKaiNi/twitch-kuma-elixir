defmodule TwitchKuma.Commands.General do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh ping, do: replylog "Kuma~!"

  defh help, do: replylog "https://github.com/KumaKaiNi/twitch-kuma-elixir"

  defh hello do
    replies = ["sup loser", "yo", "ay", "hi", "wassup"]
    if one_to(25) do
      replylog Enum.random(replies)
    end
  end

  defh same do
    if one_to(25) do
      replylog "same"
    end
  end

  defh emote do
    if one_to(25) do
      replylog message.trailing
    end
  end

  defh ty_kuma do
    replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
    replylog Enum.random(replies)
  end
end
