defmodule Passme.Chat.Util do
  @moduledoc false

  import Logger

  @spec reply(
          %{id: binary | integer, username: binary},
          map(),
          {String.t(), Keyword.t()} | String.t()
        ) :: :ok | :error
  def reply(target, from, {text, opts}) do
    ExGram.send_message(target.id, text, opts)
    |> process_result(target, from)
  end

  def reply(target, from, text) do
    ExGram.send_message(target.id, text)
    |> process_result(target, from)
  end

  @spec process_result({:ok | :error, ExGram.Model.Message.t() | ExGram.Error.t()}, map(), map()) ::
          :ok | :error
  defp process_result({:ok, _}, _, _) do
    :ok
  end

  defp process_result({:error, result}, target, from) do
    result
    |> process_ex_error(target, from)

    :error
  end

  defp process_ex_error(error, target, from) do
    case error.code do
      :response_status_not_match ->
        process_tg_message(error.message, target, from)

      _ ->
        debug("Undefined error on send_message")
        debug(error)
    end
  end

  @spec process_tg_error(map(), map(), map()) ::
          {:not_in_conversation, map()} | {:undefined, map()}
  defp process_tg_error(msg, target, from) do
    case msg do
      %{error_code: 403} ->
        # Preserve possible cyclic calls
        if target.id !== from.id do
          reply(
            from,
            target,
            Passme.Chat.Interface.not_in_conversation(target)
          )
        end

        {:not_in_conversation, msg}

      %{error_code: code} ->
        debug("Unexpected telegram code #{code}")
        {:undefined, msg}
    end
  end

  defp process_tg_message(message, target, from) do
    case Jason.decode(message, keys: :atoms) do
      {:ok, %{error_code: _} = msg} ->
        process_tg_error(msg, target, from)

      {:ok, msg} ->
        debug("Undefined error")
        debug(message)

        {:undefined, msg}

      {:error, %Jason.DecodeError{} = jason_error} ->
        debug("Unexpected error due parsing error json")
        debug(jason_error.data)

        {:error, jason_error.data}
    end
  end
end
