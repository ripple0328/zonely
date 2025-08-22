defmodule Zonely.AvatarServiceTest do
  use ExUnit.Case, async: true
  
  alias Zonely.AvatarService

  describe "generate_avatar_url/3" do
    test "generates consistent URLs for the same name" do
      url1 = AvatarService.generate_avatar_url("John Doe")
      url2 = AvatarService.generate_avatar_url("John Doe")
      
      assert url1 == url2
    end
    
    test "generates different URLs for different names" do
      url1 = AvatarService.generate_avatar_url("John Doe")
      url2 = AvatarService.generate_avatar_url("Jane Smith")
      
      assert url1 != url2
    end
    
    test "includes proper DiceBear API parameters" do
      url = AvatarService.generate_avatar_url("Test User", 48)
      
      assert url =~ "api.dicebear.com"
      assert url =~ "avataaars"
      assert url =~ "seed=test-user"
      assert url =~ "size=48"
      assert url =~ "backgroundColor=b6e3f4,c0aede,d1d4f9"
    end
    
    test "accepts custom size parameter" do
      url_32 = AvatarService.generate_avatar_url("User", 32)
      url_128 = AvatarService.generate_avatar_url("User", 128)
      
      assert url_32 =~ "size=32"
      assert url_128 =~ "size=128"
    end
    
    test "accepts custom style parameter" do
      url = AvatarService.generate_avatar_url("User", 64, "big-smile")
      
      assert url =~ "big-smile"
      refute url =~ "avataaars"
    end
    
    test "normalizes names for consistent seeding" do
      url1 = AvatarService.generate_avatar_url("María García")
      url2 = AvatarService.generate_avatar_url("MARÍA GARCÍA")
      
      # Special characters are removed, accented characters become base characters
      assert url1 =~ "seed=mara-garca"
      assert url2 =~ "seed=mara-garca"
    end
    
    test "removes special characters from names" do
      url = AvatarService.generate_avatar_url("John O'Connor-Smith")
      
      # Special characters are removed, spaces become dashes, resulting in "john-oconnorsmith"
      assert url =~ "seed=john-oconnorsmith"
    end
  end

  describe "generate_initials_avatar/2" do
    test "extracts initials from single name" do
      result = AvatarService.generate_initials_avatar("Madonna")
      
      assert result.initials == "M"
      assert result.class =~ "bg-gradient"
    end
    
    test "extracts initials from full name" do
      result = AvatarService.generate_initials_avatar("John Doe")
      
      assert result.initials == "JD"
    end
    
    test "extracts maximum two initials" do
      result = AvatarService.generate_initials_avatar("Mary Jane Watson Smith")
      
      assert result.initials == "MJ"
    end
    
    test "handles names with extra spaces" do
      result = AvatarService.generate_initials_avatar("  John   Doe  ")
      
      assert result.initials == "JD"
    end
    
    test "accepts custom CSS class" do
      result = AvatarService.generate_initials_avatar("Test User", "custom-class")
      
      assert result.class == "custom-class"
    end
    
    test "uppercases initials" do
      result = AvatarService.generate_initials_avatar("alice smith")
      
      assert result.initials == "AS"
    end
  end

  describe "generate_complete_avatar/2" do
    test "returns both URL and fallback data" do
      result = AvatarService.generate_complete_avatar("John Doe", 48)
      
      assert Map.has_key?(result, :url)
      assert Map.has_key?(result, :fallback)
      assert result.url =~ "api.dicebear.com"
      assert result.fallback.initials == "JD"
    end
    
    test "uses default size when not specified" do
      result = AvatarService.generate_complete_avatar("Test User")
      
      assert result.url =~ "size=64"
    end
  end

  describe "generate_avatar_variants/2" do
    test "returns multiple avatar styles" do
      variants = AvatarService.generate_avatar_variants("John Doe", 32)
      
      assert length(variants) == 5
      assert Enum.all?(variants, &Map.has_key?(&1, :style))
      assert Enum.all?(variants, &Map.has_key?(&1, :url))
    end
    
    test "includes expected avatar styles" do
      variants = AvatarService.generate_avatar_variants("Test User")
      styles = Enum.map(variants, & &1.style)
      
      assert "avataaars" in styles
      assert "big-smile" in styles
      assert "bottts" in styles
      assert "croodles" in styles
      assert "fun-emoji" in styles
    end
    
    test "all variants use the same size" do
      variants = AvatarService.generate_avatar_variants("User", 48)
      
      assert Enum.all?(variants, fn variant ->
        String.contains?(variant.url, "size=48")
      end)
    end
    
    test "all variants use the same seed" do
      variants = AvatarService.generate_avatar_variants("John Doe")
      
      assert Enum.all?(variants, fn variant ->
        String.contains?(variant.url, "seed=john-doe")
      end)
    end
  end
end