defmodule Zonely.NameCards do
  @moduledoc """
  Context for managing personal name cards.
  """

  import Ecto.Query, warn: false
  alias Zonely.Repo
  alias Zonely.NameCards.NameCard

  @doc """
  Gets the single name card (one per app for now, no auth).
  Returns nil if none exists.
  """
  def get_name_card do
    NameCard
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets a name card by its share token.
  """
  def get_name_card_by_token(token) when is_binary(token) do
    Repo.get_by(NameCard, share_token: token, is_public: true)
  end

  def get_name_card_by_token(_), do: nil

  @doc """
  Creates or updates the name card.
  If one exists, updates it. Otherwise creates a new one.
  """
  def save_name_card(attrs) do
    case get_name_card() do
      nil ->
        %NameCard{}
        |> NameCard.changeset(attrs)
        |> Repo.insert()

      card ->
        card
        |> NameCard.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Returns a changeset for tracking changes.
  """
  def change_name_card(%NameCard{} = card, attrs \\ %{}) do
    NameCard.changeset(card, attrs)
  end

  @doc """
  Deletes a name card.
  """
  def delete_name_card(%NameCard{} = card) do
    Repo.delete(card)
  end

  @doc """
  Regenerates the share token for a name card.
  """
  def regenerate_share_token(%NameCard{} = card) do
    token = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    card
    |> Ecto.Changeset.change(%{share_token: token})
    |> Repo.update()
  end
end
