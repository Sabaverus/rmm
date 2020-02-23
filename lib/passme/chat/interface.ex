defmodule Passme.Chat.Interface do
  @moduledoc false
  def record(record) do
    text = "
Detailed record:
=================================

Name: #{record.desc}
Key: #{record.key}
Value: #{record.value}

Created by [user](tg://user?id=#{record.author})

Edit record:
    "

    {
      text,
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "Edit name",
                callback_data: "record_edit_name_#{record.id}"
              },
              %ExGram.Model.InlineKeyboardButton{
                text: "Edit key",
                callback_data: "record_edit_key_#{record.id}"
              },
              %ExGram.Model.InlineKeyboardButton{
                text: "Edit value",
                callback_data: "record_edit_value_#{record.id}"
              }
            ],
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "Delete",
                callback_data: "record_action_delete_#{record.id}"
              }
            ]
          ]
        }
      ]
    }
  end

  def list(records) do
    text =
      records
      |> Enum.filter(fn
        {_id, v} -> is_nil(v.archived)
      end)
      |> Enum.reduce("List of entries:", fn
        {_id, v}, acc ->
          acc <> "\nKey: #{v.key}\n`Click >>>` /rec\\_#{v.id}\n"
      end)

    {
      text,
      parse_mode: "Markdown"
    }
  end

  def start() do
    {
      "
Бот умеет хранить записи добавленные пользователями, при этом обращаясь к записи - бот
опрашивает создателя записи можно ли ее показать запросившему пользователю.

Список доступных комманд:",
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
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
      ]
    }
  end

  @spec not_in_conversation(map()) :: {String.t(), Keyword.t()}
  def not_in_conversation(%{username: username}) do
    {
      "@#{username}\n
Для добавления записи добавьте бота в приватный чат @MoncyPasswordsBot
      ",
      []
    }
  end

  def script_step(%{step: step} = _script) do
    {_key, data} = step

    {
      data.text,
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "Cancel script",
                callback_data: "script_abort"
              }
            ]
          ]
        }
      ]
    }
  end
end
