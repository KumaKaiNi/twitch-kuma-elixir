defmodule TwitchKuma.Commands.Markov do
  import Kaguya.Module
  import TwitchKuma.Module

  defh get_markov do
    reply gen_markov("/home/bowan/bots/_db/twitch.log")
  end

  defp gen_markov(input_file, word_count \\ 0, start_word \\ nil) do
    alias TwitchKuma.Markov.Dictionary
    alias TwitchKuma.Markov.Generator

    :random.seed(:os.timestamp)

    filepath = input_file
    file = File.read!(filepath)

    lines = file |> String.split("\n")
    lines = (for line <- lines do
      case Regex.named_captures(~r/\[.*\] (?<username>.*): (?<capture>.*)/, line) do
        nil -> nil
        %{"username" => username, "capture" => capture} ->
          unless username == "kumakaini" do
            link_check = capture |> String.split(":") |> List.first

            case link_check do
              "http" -> nil
              "https" -> nil
              _ -> capture
            end
          end
      end
    end |> Enum.uniq) -- [nil]

    words = lines |> Enum.join(" ")

    markov_length = case word_count do
      0 ->
        average = round(length(words |> String.split) / length(lines))
        average + :random.uniform(average)
      count -> count
    end

    markov_start = case start_word do
      nil -> words |> String.split |> Enum.random
      literally_anything_else -> literally_anything_else
    end

    Dictionary.new
    |> Dictionary.parse(lines |> Enum.join("\n"))
    |> Generator.generate_words(markov_start, markov_length)
  end
end
