defmodule Passme.Chat.Interface do
  @moduledoc false

  alias ExGram.Model.InlineKeyboardMarkup
  alias ExGram.Model.InlineKeyboardButton

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
        reply_markup: %InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %InlineKeyboardButton{
                text: "✏️ Edit name",
                callback_data: "record_edit_name_#{record.id}"
              },
              %InlineKeyboardButton{
                text: "✏️ Edit value",
                callback_data: "record_edit_value_#{record.id}"
              }
            ],
            [
              %InlineKeyboardButton{
                text: "❌ Delete",
                callback_data: "record_action_delete_#{record.id}"
              },
              %InlineKeyboardButton{
                text: key_text,
                callback_data: "record_edit_key_#{record.id}"
              },
              %InlineKeyboardButton{
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
        string -> "List of records:" <> string
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
        reply_markup: %InlineKeyboardMarkup{
          inline_keyboard: [
            [
              %InlineKeyboardButton{
                text: "🗄 List of records",
                callback_data: "list"
              }
            ],
            [
              %InlineKeyboardButton{
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
      %InlineKeyboardButton{
        text: "Cancel script",
        callback_data: "script_abort"
      }
    ]

    keyboard =
      if optional do
        button = %InlineKeyboardButton{
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
        reply_markup: %InlineKeyboardMarkup{
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

  def record_private(record) do
    {
      "Requested record is private and reque permisson to view.\nWould you like ask administator for permission?",
      [
        parse_mode: "Markdown",
        reply_markup: %{
          inline_keyboard: [
            [
              %InlineKeyboardButton{
                text: "Yes, please",
                callback_data: "record_action_getperm_#{record.id}"
              }
            ]
          ]
        }
      ]
    }
  end

  def record_permitted_admin() do
    {
      "Record is unlocked for user.",
      [parse_mode: "Markdown"]
    }
  end

  def record_permitted_requisting(user_id, record) do
    {
      "[You](tg://user?id=#{user_id}) request permission for record\n\n`#{record.name}`.\n\nPermission is granted.",
      [parse_mode: "Markdown"]
    }
  end

  def record_getperm_request(user, record, perm_id) do
    {
      "User [click](tg://user?id=#{user.id}) request for view record:\n`#{record.name}`",
      [
        parse_mode: "Markdown",
        reply_markup: %{
          inline_keyboard: [
            [
              %InlineKeyboardButton{
                text: "Allow record to user",
                callback_data: "record_action_allow_#{perm_id}"
              }
            ]
            # [
            #   %InlineKeyboardButton{
            #     text: "Show record to group",
            #     callback_data: "record_action_show_#{perm_id}"
            #   }
            # ]
          ]
        }
      ]
    }
  end

  def record_perm_pending do
    {
      "Request to access record already sent",
      [parse_mode: "Markdown"]
    }
  end
end
