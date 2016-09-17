defmodule TwitchKuma do
  use Kaguya.Module, "main"
  import TwitchKuma.Util

  # Validator for mods
  def is_mod(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    if user == nil do
      false
    else
      user.mode == :op
    end
  end

  # Enable Twitch Messaging Interface
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})

    #Kaguya.Util.sendPM("Kuma~!", "#rekyuu_senkan")
  end

  # Commands list
  handle "PRIVMSG" do
    match "!uptime", :uptime
    match "!time", :local_time
    match ["!coin", "!flip"], :coin_flip
    match "!predict ~question", :prediction
    match "!fortune", :fortune
    match "!smug", :smug

    match ["hello", "hi", "hey", "sup"], :hello
    match ["same", "Same", "SAME"], :same
    match ["ty kuma", "thanks kuma", "thank you kuma"], :ty_kuma

    # Mod command list
    enforce :is_mod do
      match "!kuma", :ping
    end
  end

  # Command action handlers
  defh uptime do
    url = "https://decapi.me/twitch/uptime?channel=rekyuu_senkan"
    request =  HTTPoison.get! url

    case request.body do
      "Channel is not live." -> reply "Stream is not online!"
      time -> reply "Stream has been live for #{time}."
    end
  end

  defh local_time do
    {{_, _, _}, {hour, minute, _}} = :calendar.local_time
    reply "It is #{hour}:#{minute} rekyuu's time."
  end

  defh coin_flip, do: reply Enum.random(["Heads.", "Tails."])

  defh prediction(%{"question" => q}) do
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
      "My reply is no.",
      "My sources say no.",
      "Outlook not so good.",
      "Very doubtful."
    ]

    cond do
      length(q |> String.split) == 0 -> nil
      length(q |> String.split) >= 1 -> reply Enum.random(predictions)
    end
  end

  defh fortune do
    request = "http://fortunecookieapi.com/v1/cookie" |> HTTPoison.get!
    [response] = Poison.Parser.parse!((request.body), keys: :atoms)
    fortune = response.fortune.message

    reply fortune
  end

  defh smug do
    url = "https://api.imgur.com/3/album/zSNC1"
    auth = %{"Authorization" => "Client-ID #{Application.get_env(:twitch_kuma, :imgur_client_id)}"}

    request = HTTPoison.get!(url, auth)
    response = Poison.Parser.parse!((request.body), keys: :atoms)
    result = response.data.images |> Enum.random

    reply result.link
  end

  defh hello do
    replies = ["sup loser", "yo", "ay", "hi", "wassup"]
    if one_to(25) do
      reply Enum.random(replies)
    end
  end

  defh same do
    if one_to(25) do
      reply "same"
    end
  end

  defh ty_kuma do
    replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
    reply Enum.random(replies)
  end

  # Moderator action handlers
  defh ping, do: reply "Kuma~!"
end
