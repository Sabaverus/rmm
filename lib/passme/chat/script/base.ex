defmodule Passme.Chat.Script.Base do
  @moduledoc false

  defmacro __using__(ops) do
    import Passme.Chat.Util

    alias Passme.Chat.Interface, as: ChatInterface

    wait_time = :timer.seconds(30)

    steps =
      case Keyword.fetch(ops, :steps) do
        {:ok, l} when is_list(l) -> l
        _ -> []
      end

    quote do
      @behaviour Passme.Chat.Script.Handler

      defstruct module: __MODULE__,
                step: nil,
                timer: nil,
                parent_chat: nil,
                parent_user: nil,
                record: nil

      def new(user, chat, record \\ %Passme.Chat.Storage.Record{}) do
        %__MODULE__{
          step: first_step(),
          timer: Process.send_after(self(), :await_input_timeout, unquote(wait_time)),
          parent_chat: chat,
          parent_user: user,
          record: record
        }
      end

      def set_step_result(%{step: {_, step}} = script, value) do
        case validate_value(step, value) do
          :ok ->
            {
              :ok,
              script
              |> Map.put(:timer, reset_input_timer(script.timer))
              |> Map.put(:record, Map.put(script.record, get_field_key(script), escape(value)))
            }

          {:error, msg} ->
            {:error, msg}
        end
      end

      def start_step(%__MODULE__{step: step} = script) do
        case step do
          :end ->
            {:end, finish(script)}

          {:end, step} ->
            {:end, finish(script)}

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

      def next_step(%{step: step} = script) do
        Map.put(script, :step, get_next_step(step))
      end

      def abort_wr(%{timer: timer} = script) do
        cancel_timer(timer)
        abort(script)
      end

      defp validate_value(step, value) do
        if Map.has_key?(step, :validate) do
          apply(step.validate, [value])
        else
          :ok
        end
      end

      @spec get_next_step({atom(), map()}) :: {atom(), map()}
      defp get_next_step({_key, step}) do
        Enum.find(unquote(steps), :end, fn {x, _} ->
          x == step.next
        end)
      end

      defp finish(%{timer: timer} = script) do
        cancel_timer(timer)
        script
      end

      defp first_step, do: List.first(unquote(steps))

      defp cancel_timer(timer), do: Process.cancel_timer(timer, async: true, info: false)

      defp reset_input_timer(timer) do
        cancel_timer(timer)
        Process.send_after(self(), :await_input_timeout, unquote(wait_time))
      end

      defp get_field_key(%{step: {key, data}}) do
        if Map.has_key?(data, :field) do
          data.field
        else
          key
        end
      end

      defp escape(value) do
        value
        |> String.replace(~r/(\*|\\|\_|\-)/, "\\\\" <> "\\1")
      end
    end
  end
end
