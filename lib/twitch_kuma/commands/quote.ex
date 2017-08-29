defmodule TwitchKuma.Commands.Quote do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh get_quote(%{"quote_id" => quote_id}) do
    case quote_id |> Integer.parse do
      {quote_id, _} ->
        case query_data(:quotes, quote_id) do
          nil -> replylog "Quote \##{quote_id} does not exist."
          quote_text -> replylog "[\##{quote_id}] #{quote_text}"
        end
      :error ->
        quotes = query_all_data(:quotes)
        {quote_id, quote_text} = Enum.random(quotes)

        replylog "[\##{quote_id}] #{quote_text}"
    end
  end

  defh get_quote do
    quotes = query_all_data(:quotes)
    {quote_id, quote_text} = Enum.random(quotes)

    replylog "[\##{quote_id}] #{quote_text}"
  end

  defh add_quote(%{"quote_text" => quote_text}) do
    quotes = case query_all_data(:quotes) do
      nil -> nil
      quotes -> quotes |> Enum.sort
    end

    quote_id = case quotes do
      nil -> 1
      _ ->
        {quote_id, _} = List.last(quotes)
        quote_id + 1
    end

    store_data(:quotes, quote_id, quote_text)
    replylog "Quote added! #{quote_id} quotes total."
  end

  defh del_quote(%{"quote_id" => quote_id}) do
    case quote_id |> Integer.parse do
      {quote_id, _} ->
        case query_data(:quotes, quote_id) do
          nil -> replylog "Quote \##{quote_id} does not exist."
          _ ->
            delete_data(:quotes, quote_id)
            replylog "Quote removed."
        end
      :error -> replylog "You didn't specify an ID number."
    end
  end
end
