# Design Token Architecture

## Overview

Design token architecture defines how design decisions are captured, structured, and distributed across platforms. Tokens bridge the gap between design intent and code implementation by encoding visual properties — colors, spacing, typography, motion — as platform-agnostic, structured data. This reference covers architectural principles, multi-tier token organization, theming strategies, and the W3C specification that underpins modern token systems.

For detailed specification guidance including JSON format, Style Dictionary configuration, CI/CD pipelines, and Token Studio workflows, see `token-specification-guide.md`.

---

## Architectural Principles

### Single Source of Truth

All design decisions must originate from one canonical token set. Whether stored in a Git repository, a design tool plugin, or a dedicated platform, only one system holds the authoritative token values. Every consumer — web CSS, iOS Swift, Android Kotlin, design tools — derives its values from this single source through automated transformation pipelines.

### Separation of Concerns: Primitive, Semantic, Component

Organize tokens into three tiers:

- **Primitive (Tier 1):** Raw values with no design intent. Color hex codes, pixel values, font stacks. These are exhaustive and context-free.
- **Semantic (Tier 2):** Design decisions that map primitives to purpose. "Primary text color" maps to a specific neutral shade. "Interactive surface" maps to a specific blue. Semantic tokens encode intent and enable theming.
- **Component (Tier 3):** Optional per-component overrides that reference semantic tokens. Use sparingly — only when a component genuinely diverges from the semantic default.

### Platform-Agnostic Source, Platform-Native Output

Store tokens in a platform-agnostic format (JSON following the W3C DTCG specification). Transform them into platform-native formats at build time: CSS custom properties for web, Swift constants for iOS, Kotlin objects for Android, XML resources for legacy Android, Sass/Less variables where needed.

---

## W3C Design Tokens 2025 Update

### W3C DTCG October 2025 Stable Release

The W3C Design Tokens Community Group published the stable release of the Design Tokens specification on October 28, 2025. This milestone transitions the specification from draft to production-ready, providing a formal standard that tooling vendors, design platforms, and development teams can adopt with confidence. The stable release resolves ambiguities present in earlier drafts and formalizes several capabilities that were previously handled inconsistently across tools.

### The `$extensions` Namespace

The stable specification formalizes `$extensions` as the designated namespace for vendor-specific and tool-specific metadata. Any data that falls outside the core specification — theming mode indicators, platform override hints, tool configuration, organizational metadata — belongs inside `$extensions`, namespaced by a reverse-domain identifier to prevent collisions between tools.

```json
{
  "color": {
    "$type": "color",
    "primary": {
      "500": {
        "$value": "#6366f1",
        "$extensions": {
          "com.tokens-studio": {
            "modify": { "type": "lighten", "value": "0.1", "space": "oklch" }
          },
          "com.example.design-system": {
            "themeOverrides": {
              "dark": "#818cf8",
              "high-contrast": "#4338ca"
            },
            "platformOverrides": {
              "ios": "oklch(0.585 0.233 264.1)",
              "android": "#6366f1"
            }
          }
        }
      }
    }
  }
}
```

This approach keeps the core token definition clean and interoperable while allowing each tool in the pipeline to store its own configuration alongside the token. `$extensions` data is preserved through transformation but not interpreted by tools that do not recognize the specific namespace.

### Composite Token Types

The stable specification formally defines composite token types that combine multiple sub-values into a single token. These types eliminate the need for fragmented, loosely-coupled individual tokens:

**Typography** combines `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, and `letterSpacing` into a single atomic token. This ensures that typographic decisions are always applied as a complete unit, preventing mismatches where font size changes but line height does not.

```json
{
  "typography": {
    "$type": "typography",
    "body-md": {
      "$value": {
        "fontFamily": "{font.family.body}",
        "fontSize": "{font.size.md}",
        "fontWeight": "{font.weight.regular}",
        "lineHeight": "{line-height.normal}",
        "letterSpacing": "{letter-spacing.normal}"
      }
    }
  }
}
```

**Shadow** supports single or layered shadow definitions with `color`, `offsetX`, `offsetY`, `blur`, and `spread` sub-values. Layered shadows use an array of shadow objects.

**Gradient** defines color gradients as an array of color stops, each with a `color` and `position` value.

**Border** combines `color`, `width`, and `style` into a single token, ensuring border definitions remain cohesive.

### Token Resolution and Aliasing

The `{reference}` syntax enables tokens to reference other tokens by their dot-separated path. Resolution follows a deterministic order: references are resolved depth-first, and circular references are invalid. The stable specification clarifies that references must resolve within the complete token set (across all included files), not just within the current file.

```json
{
  "interactive": {
    "$type": "color",
    "primary": { "$value": "{color.blue.600}" },
    "primary-hover": { "$value": "{color.blue.700}" }
  }
}
```

Alias chains (A references B, B references C) are valid to arbitrary depth but should be limited to 2-3 levels in practice to maintain debuggability. Each level of indirection adds cognitive overhead when tracing a resolved value back to its primitive source.

### Multi-File Token Organization with `$include` (Proposed)

The DTCG working group has proposed a `$include` mechanism for composing token sets from multiple files. While not yet part of the stable specification, this proposal is under active development and addresses the practical need to split large token sets across files:

```json
{
  "$include": ["./core/color.tokens.json", "./core/spacing.tokens.json"],
  "semantic": {
    "$type": "color",
    "surface-primary": { "$value": "{neutral.50}" }
  }
}
```

Until `$include` is standardized, tools like Style Dictionary handle multi-file composition through their own configuration (the `source` array), and Token Studio handles it through its multi-set architecture. Plan token file organization with eventual `$include` support in mind by maintaining clear, self-contained files that can be composed in any order.

---

## Cross-References

- For W3C specification details, `$type` values, file format, and validation tooling, see `token-specification-guide.md`.
- For governance, versioning, and scaling design systems, see `governance-scaling.md`.

## Key Sources

- W3C Design Tokens Community Group — Stable Specification (October 2025)
- Style Dictionary 4.x Documentation
- Token Studio for Figma — DTCG Format Alignment Documentation
- Nathan Curtis — "Tokens in Design Systems" (2024)
- Specify Platform — Design Token Interoperability Guide
