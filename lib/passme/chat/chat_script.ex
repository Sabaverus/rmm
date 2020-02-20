defmodule Passme.Chat.ChatScript do
  @moduledoc false
  defstruct step: nil, timer: nil, parent_chat: nil, parent_user: nil, record: nil

  import Passme.Chat.Util

  alias Passme.Chat.Interface, as: ChatInterface

  @input_await_time :timer.seconds(30)

  @new_record_script [
    {:key,
     %{
       text: "Enter record key",
       next: :value
     }},
    {:value,
     %{
       text: "Enter record value",
       next: :desc
     }},
    {:desc,
     %{
       text: "Enter description of record",
       next: :end
     }}
  ]

  def new(user, chat) do
    %Passme.Chat.ChatScript{
      step: first_step(),
      timer: Process.send_after(self(), :await_input_timeout, @input_await_time),
      parent_chat: chat,
      parent_user: user,
      record: %Passme.Chat.Storage.Record{}
    }
  end

  def set_step_result(%{step: {key, step}} = script, value) do
    case validate_value(step, value) do
      :ok ->
        {
          :ok,
          script
          |> Map.put(:timer, reset_input_timer(script.timer))
          |> Map.put(:record, Map.put(script.record, key, value))
        }

      {:error, msg} ->
        {:error, msg}
    end
  end

  def start_step(%Passme.Chat.ChatScript{step: step} = script) do
    case step do
      :end ->
        {:end, finish(script)}

      {:end, step} ->
        {:end, finish(script, step.text)}

      {key, data} ->
        case reply(script.parent_user, script.parent_chat, ChatInterface.script_step(script)) do
          :ok ->
            {
              :ok,
              script
              |> Map.put(:timer, reset_input_timer(script.timer))
              |> Map.put(:step, {key, Map.put(data, :processing, true)})
            }

          :error ->
            {:ok, script}
        end
    end
  end

  def next_step(script) do
    Map.put(script, :step, get_next_step(script.step))
  end

  defp validate_value(step, value) do
    if Map.has_key?(step, :validate) do
      apply(step.validate, [value])
    else
      :ok
    end
  end

  defp get_next_step({_key, step}) do
    Enum.find(@new_record_script, :end, fn {x, _} ->
      x == step.next
    end)
  end

  defp finish(
         %{timer: timer, parent_chat: pc, parent_user: pu} = script,
         text \\ "Success!"
       ) do
    ExGram.send_message(pu.id, text)

    if pc.id !== pu.id do
      ExGram.send_message(pc.id, "Record was added by user @#{pu.username}")
    end

    cancel_timer(timer)
    script
  end

  defp first_step, do: List.first(@new_record_script)

  defp cancel_timer(timer), do: Process.cancel_timer(timer, async: true, info: false)

  defp reset_input_timer(timer) do
    cancel_timer(timer)
    Process.send_after(self(), :await_input_timeout, @input_await_time)
  end
end
