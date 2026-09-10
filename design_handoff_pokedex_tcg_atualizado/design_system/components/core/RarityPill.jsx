import React from "react";

export function RarityPill({ children, style }) {
  return (
    <span style={{
      display: "inline-block", padding: "5px 11px", borderRadius: "var(--ds-radius-pill)",
      background: "var(--ds-gold-surface)", color: "var(--ds-gold)",
      font: "var(--ds-type-label)", letterSpacing: ".08em", textTransform: "uppercase", ...style
    }}>{children}</span>
  );
}
