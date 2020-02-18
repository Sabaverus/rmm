defmodule Passme.Repo.Migrations.ChatRecords do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:chat_records) do
      add :key,         :string
      add :desc,        :string
      add :value,       :string
      add :author,      :integer
      add :chat_id,     :integer

      timestamps()
    end
  end
end
