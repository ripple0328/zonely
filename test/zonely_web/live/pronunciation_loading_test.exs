defmodule ZonelyWeb.PronunciationLoadingTest do
  use ZonelyWeb.ComponentCase, async: true
  
  alias Zonely.Accounts.User

  test "pronunciation buttons render with loading state" do
    user = %User{
      id: "1",
      name: "John Doe",
      name_native: "جان دو",
      country: "US"
    }
    
    # Test normal state
    html = render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
      user: user,
      loading_pronunciation: nil
    })
    
    assert html =~ "data-testid=\"pronunciation-english\""
    assert html =~ "data-testid=\"pronunciation-native\""
    refute html =~ "animate-spin"
    refute html =~ "animate-pulse"
    
    # Test English loading state
    html_english_loading = render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
      user: user,
      loading_pronunciation: "english"
    })
    
    assert html_english_loading =~ "animate-spin"
    assert html_english_loading =~ "animate-pulse bg-blue-100 text-blue-600"
    
    # Test native loading state  
    html_native_loading = render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
      user: user,
      loading_pronunciation: "native"
    })
    
    assert html_native_loading =~ "animate-spin"
    assert html_native_loading =~ "animate-pulse bg-emerald-100 text-emerald-600"
  end
end