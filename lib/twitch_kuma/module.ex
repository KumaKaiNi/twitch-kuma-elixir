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
end
