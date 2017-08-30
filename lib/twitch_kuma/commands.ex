defmodule TwitchKuma.Commands do
  defmacro __using__(_opts) do
    quote do
      import TwitchKuma.Commands.{
        Betting,
        Casino,
        Custom,
        General,
        Image,
        Markov,
        Moderate,
        Quote,
        Random,
        Stream
      }
    end
  end
end
