defmodule Passme.Chat.Script.NewRecord do
  @moduledoc false

  use Passme.Chat.Script.Base,
    steps: [
      {:key,
       %{
         text: "Enter record key",
         next: :value
       }},
      {:value,
       %{
         text: "Enter record value",
         next: :desc
       }},
      {:desc,
       %{
         text: "Enter description of record",
         next: :end
       }}
    ]
end
