defmodule Passme.Bot do
  @bot :passme

  use ExGram.Bot,
    name: @bot

  middleware(ExGram.Middleware.IgnoreUsername)
  def bot(), do: @bot

  ########### Server ###########


  def handle({:message, message}, _ctx) do
    IO.inspect("Handle message")
    IO.inspect(message)
  end

  def handle({:regex, key, msg}, _ctx) do
    IO.inspect("Handle message")
    IO.inspect(key)
    IO.inspect(msg)
  end

  def handle({:callback_query, %{data: "list"} = data}, _context) do
    Passme.Chat.Server.print_list(get_chat_process(data.message.chat.id))
  end

  def handle({:callback_query, %{data: "new_record"} = data}, _context) do
    # Start script at user message from
    get_chat_process(data.from.id)
    |> Passme.Chat.Server.script_new_record(data)
  end

  def handle({:text, text, data}, _context) do
    pid = get_chat_process(data.chat.id)
    is_wait = Passme.Chat.Server.is_wait_for_input(pid)
    if is_wait do
      GenServer.cast(pid, {:input, text, data})
    end
  end

  def handle({:command, "start", _data}, context) do

    markup = %ExGram.Model.InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %ExGram.Model.InlineKeyboardButton{
            text: "Список записей",
            callback_data: "list"
          }
        ],
        [
          %ExGram.Model.InlineKeyboardButton{
            text: "Добавить новую запись",
            callback_data: "new_record"
          }
        ]
      ]
    }

    answer(context, "
    Этот бот умеет хранить записи добавленные пользователями, при этом обращаясь к записи - бот опрашивает создателя записи можно ли ее показать запросившему пользователю.
    \nСписок доступных комманд",
      [
        parse_mode: "Markdown",
        reply_markup: markup
      ])

  end

  def handle({:command, cmd, data}, _context) do
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

# %{description: "Forbidden: bot can't initiate conversation with a user", error_code: 403, ok: false}
# iex(1)> "Handle message"
# iex(1)> %{
#   chat: %{
#     id: -1001281900555,
#     title: "@#$%& ╤А╨╡╨╝╨╡╤Б╨╗╨╡╨╜╨╜╨╕╨║╨╕",
#     type: "supergroup"
#   },
#   date: 1582099419,
#   from: %{
#     first_name: "Maria",
#     id: 267429173,
#     is_bot: false,
#     language_code: "ru",
#     last_name: "Guseva",
#     username: "shadow_of_mastermind"
#   },
#   left_chat_member: %{
#     first_name: "Remind my mind",
#     id: 796318981,
#     is_bot: true,
#     username: "MoncyPasswordsBot"
#   },
#   left_chat_participant: %{
#     first_name: "Remind my mind",
#     id: 796318981,
#     is_bot: true,
#     username: "MoncyPasswordsBot"
#   },
#   message_id: 152822
# }
