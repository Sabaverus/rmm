defmodule Passme.Repo.Migrations.ChatRecords do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:chat_records) do
      add :key, :string
      add :desc, :string
      add :value, :string
      add :author, :bigint
      add :chat_id, :bigint

      timestamps()
    end
  end
end
