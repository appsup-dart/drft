# DRFT Logo Files

This directory contains the DRFT logo in various formats:

- `logo.svg` - Horizontal logo (200x50) for headers and documentation
- `logo-square.svg` - Square logo (128x128) for app icons and social media
- `logo-icon-only.svg` - Icon-only version (50x50) for small spaces
- `favicon.svg` - Small favicon (32x32) for browser tabs

## Design

The logo features:
- Code brackets `[ ]` representing code-as-infrastructure
- An arrow `→` in the middle showing transformation/execution
- Dart blue color scheme (#0175C2) matching the Dart brand
- Clean, modern design suitable for technical documentation

## Usage

### For docs.page

Once the repository is pushed to GitHub, update `docs.json` with GitHub raw URLs:

```json
{
  "logo": "https://raw.githubusercontent.com/appsup-dart/drft/main/logo.svg",
  "favicon": "https://raw.githubusercontent.com/appsup-dart/drft/main/favicon.svg"
}
```

### For GitHub

GitHub will automatically use `logo.svg` in the repository root for the repository's social preview.

### For Other Uses

- Use `logo.svg` for documentation headers
- Use `logo-square.svg` for app icons, social media, or square formats
- Use `logo-icon-only.svg` for favicons or icon-only contexts
- Use `favicon.svg` for website favicons

## Customization

All logos are SVG format and can be easily customized:
- Colors: Edit the `#0175C2` and `#00D4FF` color values
- Size: SVG scales to any size without quality loss
- Text: Modify the "DRFT" text styling as needed

