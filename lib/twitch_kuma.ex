defmodule TwitchKuma do
  use Kaguya.Module, "main"
  use TwitchKuma.{Module, Commands}
  import TwitchKuma.Util
  require Logger

  unless File.exists?("/home/bowan/bots/_db"), do: File.mkdir("/home/bowan/bots/_db")

  # Enable Twitch Messaging Interface and whispers
  handle "001" do
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/membership"}})
    GenServer.call(Kaguya.Core, {:send, %Kaguya.Core.Message{command: "CAP", args: ["REQ"], trailing: "twitch.tv/commands"}})

    Kaguya.Util.sendPM("Kuma~!", "#rekyuus")
  end

  # Commands list
  handle "PRIVMSG" do
    match_all :logger
    match_all :moderate

    enforce :rate_limit do
      match "!help", :help
      match "!uptime", :uptime
      match "!time", :local_time
      match ["!coin", "!flip"], :coin_flip
      match "!predict ~question", :prediction
      match "!smug", :smug
      match "!np", :lastfm_np
      match "!guidance", :souls_message
      match "!quote :quote_id", :get_quote
      match "!quote", :get_quote
      match "!jackpot", :get_jackpot
      match "!bet :amount :betname ~choice", :make_bet
      match_all :custom_command
      match ["ty kuma", "thanks kuma", "thank you kuma"], :ty_kuma
    end

    match ["hello", "hi", "hey", "sup"], :hello
    match ["same", "Same", "SAME"], :same
    match ["PogChamp", "Kappa", "FrankerZ", "Kreygasm", "BibleThump", "PunOko", "KonCha", "TehePelo", "DontAtMe", "Exploded", "FeelsAkariMan", "IffyLewd", "KuNai", "OmegaKuNai", "OMEGALUL", "MegaLUL", "LUL", "servSugoi"], :emote

    # Mod command list
    enforce :is_mod do
      match ["!kuma", "!ping"], :ping
      match "!add :command ~action", :set_custom_command
      match "!del :command", :delete_custom_command
      match "!addquote ~quote_text", :add_quote
      match "!delquote :quote_id", :del_quote
      match "!newbet :betname ~choices", :create_new_bet
      match "!close :betname", :close_bet
      match "!winner :betname ~choice", :finalize_bet
      match "!draw", :lottery_drawing
      match "!giftall :gift", :gift_all_coins
    end

    enforce :rekyuu do
      match "!mincoins :multiplier", :set_rate_per_minute
      match "!msgcoins :multiplier", :set_rate_per_message
      match "!bonus :multiplier", :set_bonus
    end

    match_all :payout
  end

  # Whisper commands
  handle "WHISPER" do
    match "!coins", :coins
    match "!level :stat", :level_up
    match "!level", :check_level
    match "!stats", :check_stats
    match "!slots :bet", :slot_machine
    match "!lottery ~numbers", :buy_lottery_ticket
  end

  handle "JOIN", do: viewer_join(message)
  handle "PART", do: viewer_part(message)
  handle "PING", do: viewer_payout

  def is_mod(%{user: %{nick: nick}, args: [chan]}) do
    pid = Kaguya.Util.getChanPid(chan)
    user = GenServer.call(pid, {:get_user, nick})

    cond do
      user == nil -> false
      nick == "rekyuus" -> true
      true -> user.mode == :op
    end
  end

  def rekyuu(%{user: %{nick: nick}}), do: nick == "rekyuus"

  def rate_limit(msg) do
    {rate, _} = ExRated.check_rate(msg.trailing, 10_000, 1)

    case rate do
      :ok    -> true
      :error -> false
    end
  end
end
