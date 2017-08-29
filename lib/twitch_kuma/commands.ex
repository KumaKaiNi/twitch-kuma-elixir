defmodule TwitchKuma.Commands do
  defmacro __using__(_opts) do
    quote do
      import TwitchKuma.Commands.{Casino, Moderate}
    end
  end
end
