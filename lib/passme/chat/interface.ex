defmodule Passme.Chat.Interface do
  def record(record) do
    text = "
Detailed record:
------------------------

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
                callback_data: "record_delete_#{record.id}"
              }
            ]
          ]
        }
      ]
    }
  end

  def list(records) do
    text =
      Enum.reduce(records, "List of entries:", fn
        {_id, v}, acc ->
          acc <> "\nKey: #{v.key}\n`Click >>>` /rec\\_#{v.id}\n"
      end)

    {
      text,
      parse_mode: "Markdown"
    }
  end

  def start() do
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
  end
end
