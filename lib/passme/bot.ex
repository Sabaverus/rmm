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
    Passme.Chat.Server.print_list(data.message.chat.id)
  end

  def handle({:callback_query, %{data: "new_record"} = data}, _context) do
    Passme.Chat.Server.script_new_record(data.from.id, data)
  end

  def handle(
        {:callback_query, %{data: "record_action_" <> action} = data},
        _context
      ) do
    {type, record_id} =
      case action do
        "delete_" <> record_id -> {:delete, String.to_integer(record_id)}
        _ -> {:error, "Undefined action"}
      end

    Passme.Chat.Server.script_record_action(data.from.id, data, type, record_id)
  end

  def handle(
        {:callback_query, %{data: "record_edit_" <> command} = data},
        context
      ) do
    {field, record_id} =
      case command do
        "name_" <> record_id ->
          {:name, record_id}

        "key_" <> record_id ->
          {:key, record_id}

        "value_" <> record_id ->
          {:value, record_id}

        _ ->
          answer(context, "Undefined edit command")
          {nil, command}
      end

    id = String.to_integer(record_id)

    if is_atom(field) do
      if Passme.Chat.Storage.Record.has_field?(field) do
        Passme.Chat.Server.script_record_edit(data.from.id, data, field, id)
      else
        answer(context, "Record field doesn't exists or not allowed to edit (#{field})")
      end
    end
  end

  def handle(
        {:callback_query, %{data: "script_abort"} = data},
        _context
      ) do
    Passme.Chat.Server.script_abort(data.from.id)
  end

  def handle({:callback_query, _data}, context) do
    answer(context, "Undefined query")
  end

  def handle({:text, text, data}, _context) do
    Passme.Chat.Server.input_handler(data.chat.id, text, data)
  end

  def handle({:command, "start", _data}, context) do
    {text, opts} = Passme.Chat.Interface.start()
    answer(context, text, opts)
  end

  def handle({:command, "r_" <> record_id, data}, _ctx) do
    Passme.Chat.Server.show_record(data.chat.id, String.to_integer(record_id), data)
  end

  def handle({:command, cmd, data}, _ctx) do
    Passme.Chat.Server.handle_command(data.chat.id, cmd, data)
  end
end
