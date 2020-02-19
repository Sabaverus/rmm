defmodule Passme.Chat.ChatScript do
  defstruct step: nil, timer: nil, parent_chat: nil, parent_user: nil, record: nil

  @input_await_time :timer.seconds(30)

  @new_record_script [
    {:key, %{
      text: "Enter record key",
      next: :value
    }},
    {:value, %{
      text: "Enter record value",
      next: :desc
    }},
    {:desc, %{
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
    IO.puts("Set step result")
    IO.inspect value
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
    IO.puts("Start step")
    IO.inspect(script)
    case step do
      :end ->
        {
          :end,
          finish(script)
        }
      {:end, step} ->
        {
          :end,
          finish(script, step.text)
        }
      {key, data} ->
        ExGram.send_message(script.parent_user.id, data.text)
        |> case do
          {:ok, _msg} ->
            {
              :ok,
              script
              |> Map.put(:timer, reset_input_timer(script.timer))
              |> Map.put(:step, {key, Map.put(data, :processing, true)})
            }
          {:error, error} ->
            case process_ex_error(error) do
              :not_in_conversation ->
                ExGram.send_message(script.parent_chat.id, "
                @#{script.parent_user.username}
                Для добавления записи добавьте бота в приватный чат @MoncyPasswordsBot")
              {_, _msg} ->
                ExGram.send_message(script.parent_chat.id, "Неопознанный формат ответа")
            end
            {
              :ok,
              script
            }
        end
    end
  end

  def next_step(script) do
    IO.puts("Next step")
    IO.inspect(script)
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

  defp finish(%{
    timer: timer,
    parent_chat: pc,
    parent_user: pu} = script,
    text \\ "Success!"
  ) do
    ExGram.send_message(pu.id, text)
    if(pc !== pu) do
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

  defp process_ex_error(error) do
    case error.code do
      :response_status_not_match ->
        case Jason.decode(error.message, keys: :atoms) do
          {:ok, %{error_code: 403}} ->
            :not_in_conversation
          {:ok, msg} ->
            IO.inspect(msg)
            {
              :undefined,
              msg
            }
          _ ->
            IO.puts("Undefined error on send message")
            IO.inspect(error)
        end
      _ ->
        IO.puts("Undefined error on send message")
        IO.inspect(error)
    end
  end
end

# The pattern
# {'ok', #{'ok':='false', 'error_code':=403}}
#  can never match the type
#  {'error',#{'__exception__':=_, '__struct__':='Elixir.ExGram.Error', 'code':=atom() | number(), 'message':=_, 'metadata':=_}}
#  {'ok', #{'__struct__':='Elixir.ExGram.Model.Message', 'animation':=#{'__struct__':='Elixir.ExGram.Model.Animation', 'duration':=integer(), 'file_id':=binary(), 'file_name':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'height':=integer(), 'mime_type':=binary(), 'thumb':=map(), 'width':=integer()}, 'audio':=#{'__struct__':='Elixir.ExGram.Model.Audio', 'duration':=integer(), 'file_id':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'mime_type':=binary(), 'performer':=binary(), 'thumb':=map(), 'title':=binary()}, 'author_signature':=binary(), 'caption':=binary(), 'caption_entities':=[map()], 'channel_chat_created':=boolean(), 'chat':=#{'__struct__':='Elixir.ExGram.Model.Chat', 'can_set_sticker_set':=boolean(), 'description':=binary(), 'first_name':=binary(), 'id':=integer(), 'invite_link':=binary(), 'last_name':=binary(), 'permissions':=map(), 'photo':=map(), 'pinned_message':=map(), 'slow_mode_delay':=integer(), 'sticker_set_name':=binary(), 'title':=binary(), 'type':=binary(), 'username':=binary()}, 'connected_website':=binary(), 'contact':=#{'__struct__':='Elixir.ExGram.Model.Contact', 'first_name':=binary(), 'last_name':=binary(), 'phone_number':=binary(), 'user_id':=integer(), 'vcard':=binary()}, 'date':=integer(), 'delete_chat_photo':=boolean(), 'document':=#{'__struct__':='Elixir.ExGram.Model.Document', 'file_id':=binary(), 'file_name':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'mime_type':=binary(), 'thumb':=map()}, 'edit_date':=integer(), 'entities':=[map()], 'forward_date':=integer(), 'forward_from':=#{'__struct__':='Elixir.ExGram.Model.User', 'first_name':=binary(), 'id':=integer(), 'is_bot':=boolean(), 'language_code':=binary(), 'last_name':=binary(), 'username':=binary()}, 'forward_from_chat':=#{'__struct__':='Elixir.ExGram.Model.Chat', 'can_set_sticker_set':=boolean(), 'description':=binary(), 'first_name':=binary(), 'id':=integer(), 'invite_link':=binary(), 'last_name':=binary(), 'permissions':=map(), 'photo':=map(), 'pinned_message':=map(), 'slow_mode_delay':=integer(), 'sticker_set_name':=binary(), 'title':=binary(), 'type':=binary(), 'username':=binary()}, 'forward_from_message_id':=integer(), 'forward_sender_name':=binary(), 'forward_signature':=binary(), 'from':=#{'__struct__':='Elixir.ExGram.Model.User', 'first_name':=binary(), 'id':=integer(), 'is_bot':=boolean(), 'language_code':=binary(), 'last_name':=binary(), 'username':=binary()}, 'game':=#{'__struct__':='Elixir.ExGram.Model.Game', 'animation':=map(), 'description':=binary(), 'photo':=[any()], 'text':=binary(), 'text_entities':=[any()], 'title':=binary()}, 'group_chat_created':=boolean(), 'invoice':=#{'__struct__':='Elixir.ExGram.Model.Invoice', 'currency':=binary(), 'description':=binary(), 'start_parameter':=binary(), 'title':=binary(), 'total_amount':=integer()}, 'left_chat_member':=#{'__struct__':='Elixir.ExGram.Model.User', 'first_name':=binary(), 'id':=integer(), 'is_bot':=boolean(), 'language_code':=binary(), 'last_name':=binary(), 'username':=binary()}, 'location':=#{'__struct__':='Elixir.ExGram.Model.Location', 'latitude':=float(), 'longitude':=float()}, 'media_group_id':=binary(), 'message_id':=integer(), 'migrate_from_chat_id':=integer(), 'migrate_to_chat_id':=integer(), 'new_chat_members':=[map()], 'new_chat_photo':=[map()], 'new_chat_title':=binary(), 'passport_data':=#{'__struct__':='Elixir.ExGram.Model.PassportData', 'credentials':=map(), 'data':=[any()]}, 'photo':=[map()], 'pinned_message':=#{'__struct__':='Elixir.ExGram.Model.Message', 'animation':=map(), _=>_}, 'poll':=#{'__struct__':='Elixir.ExGram.Model.Poll', 'id':=binary(), 'is_closed':=boolean(), 'options':=[any()], 'question':=binary()}, 'reply_markup':=#{'__struct__':='Elixir.ExGram.Model.InlineKeyboardMarkup', 'inline_keyboard':=[any()]}, 'reply_to_message':=#{'__struct__':='Elixir.ExGram.Model.Message', 'animation':=map(), _=>_}, 'sticker':=#{'__struct__':='Elixir.ExGram.Model.Sticker', 'emoji':=binary(), 'file_id':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'height':=integer(), 'is_animated':=boolean(), 'mask_position':=map(), 'set_name':=binary(), 'thumb':=map(), 'width':=integer()}, 'successful_payment':=#{'__struct__':='Elixir.ExGram.Model.SuccessfulPayment', 'currency':=binary(), 'invoice_payload':=binary(), 'order_info':=map(), 'provider_payment_charge_id':=binary(), 'shipping_option_id':=binary(), 'telegram_payment_charge_id':=binary(), 'total_amount':=integer()}, 'supergroup_chat_created':=boolean(), 'text':=binary(), 'venue':=#{'__struct__':='Elixir.ExGram.Model.Venue', 'address':=binary(), 'foursquare_id':=binary(), 'foursquare_type':=binary(), 'location':=map(), 'title':=binary()}, 'video':=#{'__struct__':='Elixir.ExGram.Model.Video', 'duration':=integer(), 'file_id':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'height':=integer(), 'mime_type':=binary(), 'thumb':=map(), 'width':=integer()}, 'video_note':=#{'__struct__':='Elixir.ExGram.Model.VideoNote', 'duration':=integer(), 'file_id':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'length':=integer(), 'thumb':=map()}, 'voice':=#{'__struct__':='Elixir.ExGram.Model.Voice', 'duration':=integer(), 'file_id':=binary(), 'file_size':=integer(), 'file_unique_id':=binary(), 'mime_type':=binary()}}}
# Peek Problem
# No quick fixes available
# Find
