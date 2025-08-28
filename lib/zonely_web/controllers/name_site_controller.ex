defmodule ZonelyWeb.NameSiteController do
  use ZonelyWeb, :controller

  alias Zonely.PronunceName
  alias Zonely.AvatarService

  def index(conn, params) do
    # URL state encoded as base64 JSON in `s` query param for bookmarking
    state = decode_state(params["s"]) || []

    render(conn, :index, names: state)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end

  def pronounce(conn, %{"name" => name, "lang" => lang}) do
    case PronunceName.play(name, lang) do
      {:play_audio, %{url: url}} ->
        json(conn, %{type: "audio", url: absolute_url(conn, url)})

      {:play_tts_audio, %{url: url}} ->
        json(conn, %{type: "tts_audio", url: absolute_url(conn, url)})

      {:play_tts, %{text: text, lang: tts_lang}} ->
        json(conn, %{type: "tts", text: text, lang: tts_lang})

      {:play_sequence, %{urls: urls}} ->
        json(conn, %{type: "sequence", urls: Enum.map(urls, &absolute_url(conn, &1))})
    end
  end

  defp decode_state(nil), do: nil
  defp decode_state(""), do: nil

  defp decode_state(b64) do
    # Hard size limit to prevent excessively long URLs
    if byte_size(b64) > 4096 do
      []
    else
      with {:ok, json} <- Base.url_decode64(b64, padding: false),
           {:ok, list} <- Jason.decode(json) do
        Enum.flat_map(list, fn item ->
          cond do
            # Preferred shape: {name, entries: [%{"lang"=>code, "text"=>string}, ...]}
            is_map(item) and is_binary(item["name"]) and is_list(item["entries"]) ->
              name = item["name"]

              entries =
                item["entries"]
                |> Enum.flat_map(fn e ->
                  case e do
                    %{"lang" => lang, "text" => text} when is_binary(lang) and is_binary(text) ->
                      [%{lang: lang, text: text}]

                    %{"lang" => lang} when is_binary(lang) ->
                      [%{lang: lang, text: name}]

                    _ ->
                      []
                  end
                end)

              avatar = AvatarService.generate_avatar_url(name, 48)
              [%{name: name, entries: entries, avatar: avatar}]

            # Back-compat: {name, langs: ["en-US","zh-CN"]}
            is_map(item) and is_binary(item["name"]) and is_list(item["langs"]) ->
              name = item["name"]

              entries =
                Enum.flat_map(item["langs"], fn lang ->
                  if is_binary(lang), do: [%{lang: lang, text: name}], else: []
                end)

              avatar = AvatarService.generate_avatar_url(name, 48)
              [%{name: name, entries: entries, avatar: avatar}]

            # Back-compat: {name, lang}
            is_map(item) and is_binary(item["name"]) and is_binary(item["lang"]) ->
              name = item["name"]
              entries = [%{lang: item["lang"], text: name}]
              avatar = AvatarService.generate_avatar_url(name, 48)
              [%{name: name, entries: entries, avatar: avatar}]

            true ->
              []
          end
        end)
      else
        _ -> []
      end
    end
  end

  # AASA endpoint for Universal Links
  def aasa(conn, _params) do
    aasa = %{
      "applinks" => %{
        "apps" => [],
        "details" => [
          %{
            "appIDs" => ["E9FM8NGZM2.us.qingbo.saymyname"],
            "components" => [
              %{"/" => "/", "comment" => "all paths"}
            ]
          }
        ]
      }
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Phoenix.Controller.text(Jason.encode!(aasa))
  end

  defp absolute_url(conn, path) when is_binary(path) do
    case URI.parse(path) do
      %URI{scheme: nil} ->
        Phoenix.VerifiedRoutes.unverified_path(ZonelyWeb.Endpoint, conn, path)

      %URI{scheme: _} ->
        path
    end
  end
end
