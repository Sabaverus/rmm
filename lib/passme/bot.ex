defmodule Passme.Bot do
  @moduledoc false
  @bot :passme

  import Logger

  alias Passme.Chat.ChatActivity, as: Metrica

  use ExGram.Bot,
    name: @bot

  middleware(ExGram.Middleware.IgnoreUsername)

  def bot(), do: @bot

  ########### Client ###########

  def msg(%{id: chat_id}, text) when is_bitstring(text), do: msg(chat_id, text, [])
  def msg(%{id: chat_id}, {text, opts}), do: msg(chat_id, text, opts)
  def msg(chat_id, text) when is_bitstring(text), do: msg(chat_id, text, [])
  def msg(chat_id, {text, opts}), do: msg(chat_id, text, opts)

  @spec msg(integer() | %{id: String.t() | integer()}, String.t(), Keyword.t())
     :: {:ok, map()} |
        {:not_in_conversation, map()} |
        {:undefined, String.t(), map()} |
        {:error, String.t(), map()}
  @doc """
    Send message to target chat
  """
  def msg(%{id: chat_id}, text, opts), do: msg(chat_id, text, opts)
  def msg(chat_id, text, opts) when is_integer(chat_id) do
    ExGram.send_message(chat_id, text, opts)
    |> process_result()
  end

  @doc """
  Send message with information "bot must be added in private chat" if bot not added to private chat
  """
  def private_chat_requested({:not_in_conversation, _}, chat_id, user) do
    unless chat_id == user.id do
      msg(chat_id, Passme.Chat.Interface.not_in_conversation(user))
    end
    true
  end
  def private_chat_requested(_, _, _), do: false

  ########### Server ###########

  def handle({:regex, _key, _msg}, _ctx) do
    debug("Handle message")
  end

  def handle({:callback_query, %{data: "list"} = data}, context) do
    Metrica.request(context)
    Passme.Chat.Server.print_list(data.message.chat.id)
  end

  def handle({:callback_query, %{data: "new_record"} = data}, context) do
    Metrica.request(context)
    Passme.Chat.Server.script_new_record(data.from.id, data)
  end

  def handle(
        {:callback_query, %{data: "record_action_" <> action} = data},
        context
      ) do
    Metrica.request(context)
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
    Metrica.request(context)

    {field, record_id} =
      case command do
        "name_" <> record_id ->
          {:name, record_id}

        "value_" <> record_id ->
          {:value, record_id}

        "key_" <> record_id ->
          {:key, record_id}

        "desc_" <> record_id ->
          {:desc, record_id}

        _ ->
          answer(context, "Undefined edit command")
          {nil, command}
      end

    unless is_nil(field) do
      if Passme.Chat.Storage.Record.has_field?(field) do
        id = String.to_integer(record_id)
        Passme.Chat.Server.script_record_edit(data.from.id, data, field, id)
      else
        answer(context, "Record field doesn't exists or not allowed to edit (#{field})")
      end
    end
  end

  def handle(
        {:callback_query, %{data: "script_" <> action} = data},
        context
      ) do
    Metrica.request(context)
    case action do
      "step_clean" ->
        Passme.Chat.Server.input_handler(data.from.id, nil, context)

      "abort" ->
        Passme.Chat.Server.script_abort(data.from.id)
    end
  end

  def handle({:callback_query, _data}, context) do
    Metrica.request(context)
    answer(context, "Undefined query")
  end

  def handle({:text, text, data}, context) do
    Metrica.request(context)
    Passme.Chat.Server.input_handler(data.chat.id, text, data)
  end

  def handle({:command, "start", _data}, context) do
    Metrica.request(context)
    {text, opts} = Passme.Chat.Interface.start()
    answer(context, text, opts)
  end

  def handle({:command, "r_" <> record_id, data}, context) do
    Metrica.request(context)
    Passme.Chat.Server.show_record(data.chat.id, String.to_integer(record_id), data)
  end

  def handle({:command, cmd, data}, context) do
    Metrica.request(context)
    Passme.Chat.Server.handle_command(data.chat.id, cmd, data)
  end

  ########### Private ###########

  defp process_result({:ok, message}), do: {:ok, message}
  defp process_result({:error, result}) do
    result
    |> process_ex_error()
  end

  defp process_ex_error(error) do
    case error.code do
      :response_status_not_match ->
        process_tg_message(error.message)

      _ ->
        {:undefined, "Undefined error from ExGram.send_message()", error}
    end
  end

  defp process_tg_message(message) do
    case Jason.decode(message, keys: :atoms) do
      {:ok, %{error_code: _} = msg} ->
        process_tg_error(msg)

      {:ok, msg} ->
        {:undefined, "Undefined telegram message", msg}

      {:error, %Jason.DecodeError{} = jason_error} ->
        {:error, "Unexpected error due parsing error json", jason_error.data}
    end
  end

  defp process_tg_error(msg) do
    case msg do
      %{error_code: 403} ->
        {:not_in_conversation, msg}

      %{error_code: code} ->
        {:undefined, "Unexpected telegram code #{code}", msg}
    end
  end
end
