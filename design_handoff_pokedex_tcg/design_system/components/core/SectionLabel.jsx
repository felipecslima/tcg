import React from "react";

export function SectionLabel({ onDark = false, children, style }) {
  return (
    <div style={{
      font: "var(--ds-type-label)",
      letterSpacing: "var(--ds-tracking-label)",
      textTransform: "uppercase",
      color: onDark ? "rgba(255,255,255,.85)" : "var(--ds-text-secondary)",
      ...style
    }}>{children}</div>
  );
}
