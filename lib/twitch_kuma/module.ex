defmodule TwitchKuma.Module do
  defmacro __using__(_opts) do
    quote do
      import TwitchKuma.Module
      import TwitchKuma.Util
    end
  end

  defmacro replylog(response) do
    quote do
      log_to_file unquote(response)
      reply unquote(response)
    end
  end

  defmacro whisper(username, response) do
    quote do
      Kaguya.Util.sendPM("/w #{unquote(username)} #{unquote(response)}", "#jtv")
    end
  end

  defmacro whisper(response) do
    quote do
      Kaguya.Util.sendPM("/w #{var!(message).user.nick} #{unquote(response)}", "#jtv")
    end
  end
end
