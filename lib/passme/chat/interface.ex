defmodule Passme.Chat.Interface do
  @moduledoc false

  @spec record_link(Passme.Chat.Storage.Record) :: {String.t(), Keyword.t()}
  def record_link(record) do
    {
      "/r\\_#{record.id}",
      [parse_mode: "Markdown"]
    }
  end

  def record(record) do
    text = "
Detailed record:
=================================

Name: #{record.name}
Value: #{record.value}
Key: #{record.key}
Description: #{record.desc}

Created by [user](tg://user?id=#{record.author})

Edit record:
    "

    key_text =
      if is_nil(record.key) do
        "➕ Add key"
      else
        "✏️ Edit key"
      end

    desc_text =
      if is_nil(record.desc) do
        "➕ Add description"
      else
        "✏️ Edit description"
      end

    {
      text,
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "✏️ Edit name",
                callback_data: "record_edit_name_#{record.id}"
              },
              %ExGram.Model.InlineKeyboardButton{
                text: "✏️ Edit value",
                callback_data: "record_edit_value_#{record.id}"
              }
            ],
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "❌ Delete",
                callback_data: "record_action_delete_#{record.id}"
              },
              %ExGram.Model.InlineKeyboardButton{
                text: key_text,
                callback_data: "record_edit_key_#{record.id}"
              },
              %ExGram.Model.InlineKeyboardButton{
                text: desc_text,
                callback_data: "record_edit_desc_#{record.id}"
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
      |> Enum.reduce("", fn
        {_id, v}, acc ->
          {link, _} = record_link(v)
          acc <> "\n📋 Name: #{v.name}\n`Full record =>` #{link}\n"
      end)
      |> case do
        "" -> "List is empty"
        string -> "List of entries:" <> string
      end

    {
      text,
      parse_mode: "Markdown"
    }
  end

  def start() do
    {
      "
This bot can store records wich can be added by chat members.

List of commands:",
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "🗄 List of records",
                callback_data: "list"
              }
            ],
            [
              %ExGram.Model.InlineKeyboardButton{
                text: "📝 Add new record",
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
      "@#{username}\nThis bot reque to be in private chat to work with records.",
      []
    }
  end

  @spec script_step(Passme.Chat.Script.Step, boolean()) :: {binary(), Keyword.t()}
  def script_step(step, optional \\ false) do
    keyboard = [
      %ExGram.Model.InlineKeyboardButton{
        text: "Cancel script",
        callback_data: "script_abort"
      }
    ]

    keyboard =
      if optional do
        button = %ExGram.Model.InlineKeyboardButton{
          text: "Clear value",
          callback_data: "script_step_clean"
        }

        [button | keyboard]
      else
        keyboard
      end

    {
      step.text,
      [
        parse_mode: "Markdown",
        reply_markup: %ExGram.Model.InlineKeyboardMarkup{
          inline_keyboard: [
            keyboard
          ]
        }
      ]
    }
  end

  def on_start_new_record(_script) do
    {
      "Want to add new record?",
      [parse_mode: "Markdown"]
    }
  end

  def on_start_record_edit(script) do
    {action, text} =
      case script.data.previous do
        nil ->
          {"add", ""}

        _ ->
          {"change", "\n\nCurrent field value:\n#{script.data.previous}"}
      end

    {
      "Want to #{action} record field?#{text}",
      [parse_mode: "Markdown"]
    }
  end
end
