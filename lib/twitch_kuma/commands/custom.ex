defmodule TwitchKuma.Commands.Custom do
  import Kaguya.Module
  import TwitchKuma.{Module, Util}

  defh custom_command do
    action = query_data(:commands, message.trailing)

    case action do
      nil -> nil
      action -> replylog action
    end
  end

  defh set_custom_command(%{"command" => command, "action" => action}) do
    exists = query_data(:commands, "!#{command}")
    store_data(:commands, "!#{command}", action)

    case exists do
      nil -> replylog "Alright! Type !#{command} to use."
      _   -> replylog "Done, command !#{command} updated."
    end
  end

  defh delete_custom_command(%{"command" => command}) do
    action = query_data(:commands, "!#{command}")

    case action do
      nil -> replylog "Command does not exist."
      _   ->
        delete_data(:commands, "!#{command}")
        replylog "Command !#{command} removed."
    end
  end
end
