defmodule Passme.Chat.Script.Interface do
  @doc false

  alias Passme.Chat.Script.Step
  alias Passme.Chat.Script.Commands
  alias ExGram.Model.InlineKeyboardMarkup
  alias ExGram.Model.InlineKeyboardButton

  def step(step, optional \\ false)

  def step(%Step{message: text}, optional) when is_binary(text) do
    keyboard = step_keyboard(optional)

    {
      text,
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

  def step(
        %Step{message: [text: text, parse_mode: _, reply_markup: markup] = parameters},
        optional
      ) do
    keyboard = step_keyboard(optional)
    markup_keyboard = Map.get(markup, :inline_keyboard) ++ [keyboard]

    {
      text,
      Keyword.put(parameters, :reply_markup, Map.put(markup, :inline_keyboard, markup_keyboard))
    }
  end

  defp step_keyboard(optional) do
    keyboard = [
      %InlineKeyboardButton{
        text: "Cancel script",
        callback_data: "script_abort"
      }
    ]

    if optional do
      button = %InlineKeyboardButton{
        text: "Clear value",
        callback_data: "script_step_clean"
      }

      [button | keyboard]
    else
      keyboard
    end
  end

  def yes_no(text) do
    [
      text: text,
      parse_mode: "Markdown",
      reply_markup: %InlineKeyboardMarkup{
        inline_keyboard: [
          [
            %InlineKeyboardButton{
              text: "Y - Yes",
              callback_data: Commands.get(:callback) <> "_y"
            },
            %InlineKeyboardButton{
              text: "N - No",
              callback_data: Commands.get(:callback) <> "_n"
            }
          ]
        ]
      }
    ]
  end
end
