defmodule TwitchKuma.Commands do
  defmacro __using__(_opts) do
    quote do
      import TwitchKuma.Commands.{
        Bank,
        Betting,
        Casino,
        Custom,
        General,
        Image,
        Markov,
        Moderate,
        Quote,
        Random,
        RPG,
        Shop,
        Stream
      }
    end
  end
end
