import React from "react";

export function Card({ tone = "surface", padding = 18, children, style }) {
  const tones = {
    surface: { background: "var(--ds-surface)", border: "1px solid var(--ds-border)", color: "var(--ds-text-primary)" },
    tinted: { background: "var(--ds-tint-soft)", border: "1px solid var(--ds-border-strong)", color: "var(--ds-text-primary)" },
    hero: { background: "var(--ds-grad-hero)", border: "1px solid var(--ds-border-strong)", color: "var(--ds-text-on-purple)" }
  };
  return (
    <div style={{ borderRadius: "var(--ds-radius-xl)", padding, ...tones[tone], ...style }}>{children}</div>
  );
}
