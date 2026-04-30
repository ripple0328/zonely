defmodule Zonely.SayMyNameShareClientTest do
  use ExUnit.Case, async: false

  alias Zonely.Accounts.User
  alias Zonely.SayMyNameShareClient

  setup do
    previous_request_fun = Application.get_env(:zonely, :say_my_name_share_request_fun)
    previous_api_key = System.get_env("PRONUNCIATION_API_KEY")

    System.put_env("PRONUNCIATION_API_KEY", "test-share-key")

    on_exit(fn ->
      if previous_request_fun do
        Application.put_env(:zonely, :say_my_name_share_request_fun, previous_request_fun)
      else
        Application.delete_env(:zonely, :say_my_name_share_request_fun)
      end

      if previous_api_key do
        System.put_env("PRONUNCIATION_API_KEY", previous_api_key)
      else
        System.delete_env("PRONUNCIATION_API_KEY")
      end
    end)

    :ok
  end

  test "production_base_url/0 is fixed to production" do
    assert SayMyNameShareClient.production_base_url() == "https://saymyname.qingbo.us"
  end

  test "preview_image_url_from_share_url/1 maps share links to canonical SayMyName OG images" do
    assert SayMyNameShareClient.preview_image_url_from_share_url(
             "https://saymyname.qingbo.us/card/card-token"
           ) ==
             "https://saymyname.qingbo.us/og/card/card-token?smn_pv=1"

    assert SayMyNameShareClient.preview_image_url_from_share_url(
             "https://saymyname.qingbo.us/list/list-token"
           ) ==
             "https://saymyname.qingbo.us/og/list/list-token?smn_pv=1"

    assert SayMyNameShareClient.preview_image_url_from_share_url(
             "https://saymyname.qingbo.us/card?e=encoded"
           ) ==
             "https://saymyname.qingbo.us/og/card?e=encoded&smn_pv=1"

    assert SayMyNameShareClient.preview_image_url_from_share_url("/share/legacy-token") ==
             "https://saymyname.qingbo.us/og/card/legacy-token?smn_pv=1"

    refute SayMyNameShareClient.preview_image_url_from_share_url("https://example.com/profile/1")
  end

  test "create_card_share/1 posts a canonical card payload with bearer auth" do
    user = %User{
      id: "user-1",
      name: "Qingbo",
      name_native: "清波",
      native_language: "zh-CN",
      country: "CN"
    }

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-card-shares"
      assert opts[:headers] == [{"authorization", "Bearer test-share-key"}]
      assert opts[:retry] == false
      assert opts[:receive_timeout] == 3_000
      assert opts[:connect_options] == [timeout: 1_000]

      assert opts[:json] == %{
               "id" => "user-1",
               "display_name" => "Qingbo",
               "variants" => [
                 %{"lang" => "en-US", "text" => "Qingbo"},
                 %{"lang" => "zh-CN", "text" => "清波"}
               ]
             }

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "card-token",
           "share_url" => "https://saymyname.qingbo.us/card/card-token",
           "preview_image_url" => "https://saymyname.qingbo.us/og/card/card-token?smn_pv=1"
         }
       }}
    end)

    assert {:ok,
            %{
              "share_url" => "https://saymyname.qingbo.us/card/card-token",
              "preview_image_url" => "https://saymyname.qingbo.us/og/card/card-token?smn_pv=1"
            }} =
             SayMyNameShareClient.create_card_share(user)
  end

  test "create_list_share/2 posts entries payload" do
    users = [%User{id: "user-1", name: "Alice", country: "US"}]

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-list-shares"
      assert opts[:json]["name"] == "Zonely Team"
      assert hd(opts[:json]["entries"])["display_name"] == "Alice"

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "list-token",
           "share_url" => "https://saymyname.qingbo.us/list/list-token"
         }
       }}
    end)

    assert {:ok, %{"share_url" => "https://saymyname.qingbo.us/list/list-token"}} =
             SayMyNameShareClient.create_list_share("Zonely Team", users)
  end

  test "get_card_share/1 requests the authenticated snapshot endpoint" do
    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :get
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-card-shares/card-token"
      refute Keyword.has_key?(opts, :json)

      {:ok,
       %{
         status: 200,
         body: %{"share_token" => "card-token", "payload" => %{"display_name" => "Qingbo"}}
       }}
    end)

    assert {:ok, %{"payload" => %{"display_name" => "Qingbo"}}} =
             SayMyNameShareClient.get_card_share("card-token")
  end

  test "returns validation failures as tagged tuples" do
    Application.put_env(:zonely, :say_my_name_share_request_fun, fn _opts ->
      {:ok, %{status: 422, body: %{"error" => "validation_failed"}}}
    end)

    assert {:error, {:validation_failed, %{"error" => "validation_failed"}}} =
             SayMyNameShareClient.create_card_share(%{"display_name" => "", "variants" => "bad"})
  end

  test "returns unauthorized errors as tagged tuples" do
    Application.put_env(:zonely, :say_my_name_share_request_fun, fn _opts ->
      {:ok, %{status: 401, body: %{"error" => "missing api key"}}}
    end)

    assert {:error, :unauthorized} =
             SayMyNameShareClient.get_list_share("list-token")
  end

  test "returns unexpected successful response shape as tagged tuple" do
    Application.put_env(:zonely, :say_my_name_share_request_fun, fn _opts ->
      {:ok, %{status: 200, body: ["unexpected"]}}
    end)

    assert {:error, {:unexpected_response, ["unexpected"]}} =
             SayMyNameShareClient.get_card_share("card-token")
  end

  test "does not make requests without PRONUNCIATION_API_KEY" do
    System.delete_env("PRONUNCIATION_API_KEY")

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn _opts ->
      flunk("request should not be made")
    end)

    assert {:error, :missing_api_key} =
             SayMyNameShareClient.get_card_share("card-token")
  end
end
