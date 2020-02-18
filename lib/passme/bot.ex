defmodule Passme.Bot do
  @bot :passme

  use ExGram.Bot,
    name: @bot

  middleware(ExGram.Middleware.IgnoreUsername)
  def bot(), do: @bot

  ########### Server ###########

  def handle({:callback_query, %{data: "list"} = cbq}, _context) do
    Passme.User.Server.print_list(get_chat_process(cbq.from.id))
  end

  def handle({:callback_query, %{data: "new_record"} = cbq}, _context) do
    chat_id = cbq.message.chat.id
    Passme.User.Server.script_new_record(get_chat_process(chat_id), cbq)
  end

  def handle({:text, text, data}, _context) do
    pid = get_chat_process(data[:from][:id])
    is_wait = Passme.User.Server.is_wait_for_input(pid)
    if is_wait do
      GenServer.cast(pid, {:input, text, data})
    end
  end

  def handle({:command, "start", _data}, context) do

    markup = %ExGram.Model.InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %ExGram.Model.InlineKeyboardButton{
            text: "Вывести полный список",
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

    answer(context, "Список комманд",
      [
        parse_mode: "Markdown",
        reply_markup: markup
      ])

  end

  def handle({:command, cmd, data}, _context) do
    GenServer.call(get_chat_process(data[:from][:id]), {
      :command,
      cmd,
      data
    })
  end

  defp get_chat_process(user_id) do
    Passme.User.Supervisor.get_chat_process(user_id)
  end
end
