defmodule Zonely.HttpClient do
  @moduledoc """
  Behaviour for HTTP client used by pronunciation module for testability.
  """

  @callback get(String.t()) :: {:ok, %{status: non_neg_integer(), body: any()}} | {:error, any()}
  @callback get(String.t(), list()) :: {:ok, %{status: non_neg_integer(), body: any()}} | {:error, any()}
end

defmodule Zonely.HttpClient.Req do
  @behaviour Zonely.HttpClient

  @impl true
  def get(url) when is_binary(url) do
    Req.get(url)
  end

  @impl true
  def get(url, headers) when is_binary(url) and is_list(headers) do
    Req.request(method: :get, url: url, headers: headers)
  end
end
