defmodule Passme.Bot do
  @moduledoc false
  @bot :passme

  import Logger

  use ExGram.Bot,
    name: @bot

  middleware(ExGram.Middleware.IgnoreUsername)

  def bot(), do: @bot

  ########### Server ###########

  def handle({:regex, _key, _msg}, _ctx) do
    debug("Handle message")
  end

  def handle({:callback_query, %{data: "list"} = data}, _context) do
    get_chat_process(data.message.chat.id)
    |> Passme.Chat.Server.print_list()
  end

  def handle({:callback_query, %{data: "new_record"} = data}, _context) do
    # Start script at user message from
    get_chat_process(data.from.id)
    |> Passme.Chat.Server.script_new_record(data)
  end

  def handle(
        {
          :callback_query,
          %{data: "record_action_" <> action} = data
        },
        _context
      ) do
    {type, record_id} =
      case action do
        "delete_" <> record_id -> {:delete, record_id}
        _ -> {:error, "Undefined action"}
      end

    get_chat_process(data.from.id)
    |> Passme.Chat.Server.script_record_action(data, type, record_id)
  end

  def handle(
        {
          :callback_query,
          %{data: "record_edit_" <> command} = data
        },
        _context
      ) do
    {type, record_id} =
      case command do
        "name_" <> record_id -> {:name, record_id}
        "key_" <> record_id -> {:key, record_id}
        "value_" <> record_id -> {:value, record_id}
        _ -> {:error, "Undefined edit command"}
      end

    get_chat_process(data.from.id)
    |> Passme.Chat.Server.script_record_edit(data, type, record_id)
  end

  def handle(
        {
          :callback_query,
          %{data: "script_abort"} = data
        },
        _context
      ) do

    get_chat_process(data.from.id)
    |> Passme.Chat.Server.script_abort()
  end

  def handle({:text, text, data}, _context) do
    pid = get_chat_process(data.chat.id)
    is_wait = Passme.Chat.Server.is_wait_for_input(pid)

    if is_wait do
      GenServer.cast(pid, {:input, text, data})
    end
  end

  def handle({:command, "start", _data}, context) do
    {text, opts} = Passme.Chat.Interface.start()
    answer(context, text, opts)
  end

  def handle({:command, "rec_" <> record_id, data}, _ctx) do
    get_chat_process(data.chat.id)
    |> Passme.Chat.Server.show_record(String.to_integer(record_id), data)
  end

  def handle({:command, cmd, data}, _ctx) do
    get_chat_process(data.chat.id)
    |> GenServer.call({
      :command,
      cmd,
      data
    })
  end

  defp get_chat_process(chat_id) do
    Passme.Chat.Supervisor.get_chat_process(chat_id)
  end
end
