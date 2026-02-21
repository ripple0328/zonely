defmodule ZonelyWeb.ExploreLive do
  use ZonelyWeb, :live_view

  alias Zonely.Analytics

  @impl true
  def mount(_params, _session, socket) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -30, :day)

    total_pronunciations = Analytics.total_pronunciations(start_date, end_date)
    top_names = Analytics.top_requested_names(start_date, end_date, 10)

    # top_languages returns [{lang, count}, ...]
    top_languages_raw = Analytics.top_languages(start_date, end_date, 8)

    top_languages =
      Enum.map(top_languages_raw, fn {lang, count} -> %{lang: lang || "Unknown", count: count} end)

    # geographic_distribution returns [{country, count}, ...]
    geo_distribution_raw = Analytics.geographic_distribution(start_date, end_date, 12)

    geo_distribution =
      Enum.map(geo_distribution_raw, fn {country, count} ->
        %{country: country || "Unknown", count: count}
      end)

    language_count = length(top_languages)

    {:ok,
     socket
     |> assign(:page_title, "Explore")
     |> assign(:total_pronunciations, total_pronunciations)
     |> assign(:language_count, language_count)
     |> assign(:top_names, top_names)
     |> assign(:top_languages, top_languages)
     |> assign(:geo_distribution, geo_distribution)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Hero stat --%>
      <div class="rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-700 p-6 text-white shadow-lg">
        <p class="text-4xl font-bold">{@total_pronunciations |> format_number()}</p>
        <p class="mt-1 text-blue-100">
          names pronounced across {@language_count} languages
        </p>
      </div>

      <%!-- Trending Names --%>
      <section aria-labelledby="trending-heading">
        <div class="flex items-center justify-between mb-3">
          <h2 id="trending-heading" class="text-lg font-semibold text-gray-900">
            🔥 Trending Names
          </h2>
        </div>
        <div class="rounded-xl border border-gray-200 bg-white shadow-sm overflow-hidden">
          <%= if Enum.empty?(@top_names) do %>
            <div class="px-4 py-8 text-center text-sm text-gray-500">
              No data yet — start pronouncing names!
            </div>
          <% else %>
            <%= for {name_data, idx} <- Enum.with_index(@top_names, 1) do %>
              <div class={[
                "flex items-center gap-3 px-4 py-3",
                if(idx < length(@top_names), do: "border-b border-gray-100", else: "")
              ]}>
                <span class="w-6 text-right text-sm font-medium text-gray-400">{idx}</span>
                <span class="flex-1 font-medium text-gray-900">{name_data.name}</span>
                <span class="text-xs text-gray-500">{name_data.count}</span>
              </div>
            <% end %>
          <% end %>
        </div>
      </section>

      <%!-- Names Around the World --%>
      <section aria-labelledby="geo-heading">
        <h2 id="geo-heading" class="text-lg font-semibold text-gray-900 mb-3">
          🌍 Names Around the World
        </h2>
        <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <%= if Enum.empty?(@geo_distribution) do %>
            <p class="text-center text-sm text-gray-500 py-4">No geographic data yet</p>
          <% else %>
            <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
              <%= for geo <- @geo_distribution do %>
                <div class="flex items-center gap-2 rounded-lg bg-gray-50 px-3 py-2">
                  <span class="text-lg">{country_flag(geo.country)}</span>
                  <div>
                    <span class="text-sm font-medium text-gray-900">{geo.country}</span>
                    <span class="ml-1 text-xs text-gray-500">{geo.count}</span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </section>

      <%!-- Popular Languages --%>
      <section aria-labelledby="languages-heading">
        <h2 id="languages-heading" class="text-lg font-semibold text-gray-900 mb-3">
          📊 Popular Languages
        </h2>
        <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <%= if Enum.empty?(@top_languages) do %>
            <p class="text-center text-sm text-gray-500 py-4">No language data yet</p>
          <% else %>
            <% max_count = Enum.max_by(@top_languages, & &1.count).count %>
            <%= for lang <- @top_languages do %>
              <div>
                <div class="flex items-center justify-between mb-1">
                  <span class="text-sm font-medium text-gray-700">{lang.lang}</span>
                  <span class="text-xs text-gray-500">{lang.count}</span>
                </div>
                <div class="h-2 w-full rounded-full bg-gray-100 overflow-hidden">
                  <div
                    class="h-2 rounded-full bg-blue-500"
                    style={"width: #{if max_count > 0, do: round(lang.count / max_count * 100), else: 0}%"}
                  >
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  defp format_number(n) when is_integer(n) and n >= 1000 do
    "#{Float.round(n / 1000, 1)}k"
  end

  defp format_number(n) when is_integer(n), do: Integer.to_string(n)
  defp format_number(_), do: "0"

  defp country_flag(country_code) when is_binary(country_code) and byte_size(country_code) == 2 do
    country_code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 - ?A + 0x1F1E6))
    |> List.to_string()
  end

  defp country_flag(_), do: "🌐"
end
