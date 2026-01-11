#!/usr/bin/env python3
"""
Скрипт для создания PNG favicon из SVG (опционально)
Требует: pip install cairosvg pillow
"""

try:
    import cairosvg
    from PIL import Image
    import io
    
    sizes = [16, 32, 48, 64, 128, 256]
    
    for size in sizes:
        png_data = cairosvg.svg2png(
            url='static/favicon.svg',
            output_width=size,
            output_height=size
        )
        
        img = Image.open(io.BytesIO(png_data))
        img.save(f'static/favicon-{size}.png', 'PNG')
        print(f'✓ Created favicon-{size}.png')
    
    # Создаем .ico файл (комбинация размеров)
    img_16 = Image.open('static/favicon-16.png')
    img_32 = Image.open('static/favicon-32.png')
    img_48 = Image.open('static/favicon-48.png')
    
    img_16.save('static/favicon.ico', format='ICO', sizes=[(16,16), (32,32), (48,48)])
    print('✓ Created favicon.ico')
    
except ImportError:
    print('⚠ cairosvg или pillow не установлены')
    print('Установите: pip install cairosvg pillow')
    print('SVG favicon работает в большинстве современных браузеров')
