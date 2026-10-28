# Branding

Master image: `assets/branding/app-icon.png`. Built-in ImageGen was used; no API key or CLI fallback was used. The result was inspected and copied into this repository, then `dart run flutter_launcher_icons` produced the Android launcher/adaptive and iOS icon sizes. Do not crop rounded corners into the master image.

Final generation prompt:

> Use case: logo-brand. Asset type: square launcher icon for MusicBackyard, a calm professional Dutch musician's songbook and songwriting app. Create one polished flat vector-like symbol: a cream musical beamed note whose upper stem subtly becomes a small sage leaf, suggesting music growing in a backyard. Forest green #183329 full-bleed square background, warm cream #F7F4EC primary symbol, a restrained amber #E3A96B detail and sage #D9E8D7 leaf. Bold, geometric, memorable silhouette legible at 32 pixels. Center symbol within central 65 percent safe area, generous margin. No text, no letters, no border, no mockup, no shadows, no gradients, no rounded outer corners (operating system applies the mask). Deliver a single crisp square icon.

Bundled PDF typefaces are Noto Sans regular/bold, licensed under the SIL OFL; the license is included in `assets/fonts/OFL.txt`.
