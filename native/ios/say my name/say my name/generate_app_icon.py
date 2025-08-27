#!/usr/bin/env python3
"""
Generate a stunning app icon for "Say My Name" pronunciation app
Combines sound waves with multilingual elements in modern iOS style
"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_app_icon():
    # iOS app icon size (1024x1024 for App Store)
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Modern gradient background (deep blue to purple)
    for y in range(size):
        # Create gradient from top-left to bottom-right
        ratio = (y + (size - y) * 0.3) / size
        r = int(79 * (1 - ratio) + 139 * ratio)    # 79 -> 139
        g = int(70 * (1 - ratio) + 69 * ratio)     # 70 -> 69  
        b = int(229 * (1 - ratio) + 234 * ratio)   # 229 -> 234
        
        for x in range(size):
            x_ratio = x / size
            # Add some horizontal variation
            r2 = int(r * (1 - x_ratio * 0.1))
            g2 = int(g * (1 - x_ratio * 0.05))
            b2 = int(b * (1 + x_ratio * 0.1))
            
            draw.point((x, y), (r2, g2, b2, 255))
    
    # Add subtle radial highlight
    center = size // 2
    max_radius = size * 0.7
    
    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x - center) ** 2 + (y - center) ** 2)
            if dist < max_radius:
                # Add radial highlight
                highlight_strength = (1 - dist / max_radius) * 0.3
                pixel = img.getpixel((x, y))
                new_r = min(255, int(pixel[0] + highlight_strength * 60))
                new_g = min(255, int(pixel[1] + highlight_strength * 40))
                new_b = min(255, int(pixel[2] + highlight_strength * 30))
                draw.point((x, y), (new_r, new_g, new_b, 255))
    
    # Draw sound waves (multiple arcs representing pronunciation)
    center_x, center_y = size // 2, size // 2
    
    # Central microphone/speaker element
    mic_width = size // 8
    mic_height = size // 6
    mic_x = center_x - mic_width // 2
    mic_y = center_y - mic_height // 2
    
    # Draw microphone body with gradient
    draw.ellipse([
        mic_x, mic_y, 
        mic_x + mic_width, mic_y + mic_height
    ], fill=(255, 255, 255, 240), outline=(220, 220, 220, 255), width=3)
    
    # Draw sound waves radiating outward
    wave_colors = [
        (255, 255, 255, 200),  # White, most opaque
        (255, 255, 255, 150),  # Less opaque
        (255, 255, 255, 100),  # Even less
        (255, 255, 255, 60),   # Most transparent
    ]
    
    wave_distances = [size//5, size//3.5, size//2.5, size//1.8]
    wave_widths = [8, 6, 4, 3]
    
    for i, (distance, width, color) in enumerate(zip(wave_distances, wave_widths, wave_colors)):
        # Draw multiple arc segments to represent sound waves
        for angle_offset in [0, 60, 120, 180, 240, 300]:
            start_angle = angle_offset - 15
            end_angle = angle_offset + 15
            
            # Calculate arc bounds
            arc_bounds = [
                center_x - distance, center_y - distance,
                center_x + distance, center_y + distance
            ]
            
            # Draw arc
            draw.arc(arc_bounds, start_angle, end_angle, fill=color, width=width)
    
    # Add language symbols around the icon
    # Chinese character for "name" (名)
    # We'll use geometric shapes to represent different languages
    
    # Top: Geometric shape representing Chinese characters
    char_size = size // 12
    top_y = size // 4
    draw.rectangle([
        center_x - char_size, top_y,
        center_x + char_size, top_y + char_size // 3
    ], fill=(255, 255, 255, 180))
    draw.rectangle([
        center_x - char_size // 2, top_y + char_size // 2,
        center_x + char_size // 2, top_y + char_size
    ], fill=(255, 255, 255, 180))
    
    # Bottom: Geometric shape representing Latin characters
    bottom_y = size * 3 // 4
    draw.rectangle([
        center_x - char_size, bottom_y,
        center_x + char_size, bottom_y + char_size // 4
    ], fill=(255, 255, 255, 160))
    draw.ellipse([
        center_x - char_size // 3, bottom_y + char_size // 3,
        center_x + char_size // 3, bottom_y + char_size
    ], fill=(255, 255, 255, 160))
    
    # Left: Arabic-style shape (flowing curves)
    left_x = size // 4
    curve_points = []
    for i in range(20):
        angle = i * math.pi / 10
        x = left_x + int(char_size * 0.6 * math.cos(angle))
        y = center_y + int(char_size * 0.3 * math.sin(angle * 2))
        curve_points.append((x, y))
    
    if len(curve_points) >= 3:
        draw.polygon(curve_points[:10], fill=(255, 255, 255, 140))
    
    # Right: Geometric pattern for other scripts
    right_x = size * 3 // 4
    for i in range(3):
        y_offset = (i - 1) * char_size // 2
        draw.ellipse([
            right_x - char_size // 4, center_y + y_offset - char_size // 6,
            right_x + char_size // 4, center_y + y_offset + char_size // 6
        ], fill=(255, 255, 255, 120 - i * 20))
    
    # Add subtle inner glow to central element
    glow_radius = mic_width + 20
    for i in range(10):
        alpha = 30 - i * 3
        if alpha > 0:
            draw.ellipse([
                center_x - glow_radius - i * 2, center_y - glow_radius - i * 2,
                center_x + glow_radius + i * 2, center_y + glow_radius + i * 2
            ], outline=(255, 255, 255, alpha), width=1)
    
    # Apply iOS-style corner radius (22% of size for App Store icons)
    corner_radius = int(size * 0.22)
    
    # Create mask for rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=255)
    
    # Apply mask
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)
    
    return output

def create_icon_set():
    """Create the full set of iOS app icons"""
    base_icon = create_app_icon()
    
    # iOS icon sizes needed
    sizes = [
        (1024, "AppIcon-1024"),      # App Store
        (180, "AppIcon-60@3x"),      # iPhone @3x
        (120, "AppIcon-60@2x"),      # iPhone @2x
        (152, "AppIcon-76@2x"),      # iPad @2x
        (76, "AppIcon-76"),          # iPad @1x
    ]
    
    for size, name in sizes:
        resized = base_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(f"/Users/qingbo/Projects/Personal/zonely/native/ios/say my name/say my name/Assets.xcassets/AppIcon.appiconset/{name}.png", "PNG")
        print(f"Generated {name}.png ({size}x{size})")
    
    # Also save a preview version
    preview = base_icon.resize((512, 512), Image.Resampling.LANCZOS)
    preview.save(f"/Users/qingbo/Projects/Personal/zonely/native/ios/say my name/say my name/app_icon_preview.png", "PNG")
    print("Generated app_icon_preview.png (512x512)")

if __name__ == "__main__":
    create_icon_set()
    print("✅ App icon set generated successfully!")
    print("📱 The new icons combine:")
    print("   • Modern iOS gradient background")
    print("   • Sound waves for pronunciation theme") 
    print("   • Multilingual script representations")
    print("   • Clean, scalable design")
    print("   • Professional App Store quality")