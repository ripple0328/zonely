defmodule Zonely.PronunceName.NegativeCache do
  @moduledoc false
  @table :pronunce_negative_cache

  @doc """
  Returns true if the given provider/name/language has a recent definitive failure recorded.
  """
  @spec failed_recently?(atom(), String.t(), String.t()) :: boolean()
  def failed_recently?(provider, name, language) do
    ensure_table!()

    key = key(provider, name, language)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, {ts, reason}}] when is_integer(ts) ->
        if now - ts <= ttl_ms(reason) do
          true
        else
          :ets.delete(@table, key)
          false
        end

      _ ->
        false
    end
  end

  @doc """
  Record a definitive failure for provider/name/language with reason.
  Only store if the reason is considered definitive (e.g., :not_found, :no_items, :partial_only).
  """
  @spec put_failure(atom(), String.t(), String.t(), atom()) :: :ok
  def put_failure(provider, name, language, reason) when is_atom(reason) do
    if definitive_reason?(reason) do
      ensure_table!()
      key = key(provider, name, language)
      now = System.monotonic_time(:millisecond)
      :ets.insert(@table, {key, {now, reason}})
      :ok
    else
      :ok
    end
  end

  defp definitive_reason?(reason) do
    reason in [:not_found, :no_items, :partial_only, :timeout]
  end

  defp key(provider, name, language) do
    normalized_name =
      name
      |> String.downcase()
      |> String.trim()
      |> String.replace(~r/\s+/, " ")

    {provider, normalized_name, language}
  end

  defp ttl_ms(:timeout), do: Application.get_env(:zonely, :negative_cache_soft_ttl_ms, 600_000)
  defp ttl_ms(_), do: Application.get_env(:zonely, :negative_cache_ttl_ms, 86_400_000)

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true])
      _ ->
        :ok
    end
  end
end
