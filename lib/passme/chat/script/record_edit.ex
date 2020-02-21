defmodule Passme.Chat.ChatScript.EditRecord do
  @moduledoc false

  use Passme.Chat.Script.Base,
    steps: [
      {:field,
       %{
         text: "Enter new value for selected field",
         next: :value
       }},
      {:end,
       %{
         text: "Field updated!"
       }}
    ]
end
