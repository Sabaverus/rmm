defmodule Passme.Chat.Script.Base do
  @moduledoc false

  defmacro __using__(ops) do
    import Logger

    alias Passme.Chat.Interface, as: ChatInterface
    alias Passme.Chat.Script.Step
    alias Passme.Bot

    wait_time = :timer.seconds(30)

    script_input_timeout = :script_input_timeout

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
                data: nil,
                messages: []

      def new(user, chat, data \\ %{}) do
        %__MODULE__{
          step: first_step(),
          timer: Process.send_after(self(), unquote(script_input_timeout), unquote(wait_time)),
          parent_chat: chat,
          parent_user: user,
          data: data
        }
        |> init()
      end

      def init(script) do
        on_start(script)
        |> case do
          %__MODULE__{} = script -> script
          _ -> raise "#{__MODULE__}.on_start/1 must return instance of #{__MODULE__}"
        end
      end

      def on_start(script) do
        script
      end

      def set_step_result(%{step: {_, step}} = script, value) do
        case validate_value(step, value) do
          :ok ->
            {
              :ok,
              script
              |> Map.put(:timer, reset_input_timer(script.timer))
              |> Map.put(:data, Map.put(script.data, get_field_key(script), escape(value)))
            }

          {:error, msg} ->
            {:error, msg}
        end
      end

      def start_step(%__MODULE__{step: :end} = script), do: finish(script)
      def start_step(%__MODULE__{step: {:end, _}} = script), do: finish(script)
      def start_step(%__MODULE__{step: {_, %{processing: true}}} = script), do: script

      def start_step(%__MODULE__{step: {key, step}} = script) do
        can_be_empty = get_step_key_value(step, :can_be_empty, get_field_key(script))
        # If user tried to start script from group-chat, bot doesn't added to private chat
        # telegram returns error 403 "Not in conversation"
        case Bot.msg(script.parent_user, ChatInterface.script_step(step, can_be_empty)) do
          {:ok, reply_data} ->
            script
            |> Map.put(:timer, reset_input_timer(script.timer))
            |> Map.put(:step, {key, Map.put(step, :processing, true)})
            |> Map.put(:messages, [reply_data.message_id | script.messages])

          {:not_in_conversation, _} = reply ->
            info("Target user not added this bot to private chat to start script")
            Bot.private_chat_requested(reply, script.parent_chat.id, script.parent_user)
            script
        end
      end

      def next_step(%{step: step} = script) do
        Map.put(script, :step, get_next_step(step))
      end

      def abort_wr(%{timer: timer} = script) do
        cancel_timer(timer)
        abort(script)
      end

      def end?(%__MODULE__{step: :end}), do: true
      def end?(%__MODULE__{step: {:end, _}}), do: true
      def end?(%__MODULE__{step: _}), do: false

      def cleanup(script) do
        spawn(fn ->
          Enum.each(script.messages, fn msg_id ->
            ExGram.delete_message(script.parent_user.id, msg_id)
          end)
        end)
        script
        |> Map.put(:messages, [])
      end

      defp validate_value(%Step{validate: nil}, _), do: :ok

      defp validate_value(%Step{validate: fun}, value) when is_function(fun),
        do: apply(fun, [value])

      defp validate_value(%Step{validate: fun}, _),
        do: raise("#{Step} key validate must be function")

      @spec get_next_step({atom(), Step.t()}) :: {atom(), Step.t()}
      defp get_next_step({_key, step}) do
        unquote(steps)
        |> Enum.find(:end, fn {x, _} ->
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
        Process.send_after(self(), unquote(script_input_timeout), unquote(wait_time))
      end

      defp get_field_key(%__MODULE__{step: {key, data}} = script) do
        if Map.has_key?(data, :field) and not is_nil(data.field) do
          data.field
        else
          key
        end
      end

      @spec get_step_key_value(Step.t(), atom()) :: any()
      defp get_step_key_value(step, field) do
        Map.get(step, field)
      end

      @spec get_step_key_value(Step.t(), atom(), any()) :: any()
      defp get_step_key_value(step, field, arg) do
        field_value = Map.get(step, field)

        if is_function(field_value) do
          field_value.(arg)
        else
          field_value
        end
      end

      defp escape(nil), do: nil

      defp escape(value) do
        value
        |> String.replace(~r/\*|\\|\_/, ~S(\\) <> "\\0")
      end

      defoverridable get_field_key: 1, on_start: 1
    end
  end
end
