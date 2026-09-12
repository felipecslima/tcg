import React from "react";

export function CardArt({ src, width = 46, empty = false, label, radius = "var(--ds-radius-xs)", style }) {
  const height = Math.round(width / .72);
  return (
    <div style={{
      width, height, borderRadius: radius, flex: "none",
      background: empty ? "var(--ds-placeholder)" : (src || "var(--ds-grad-node)"),
      border: empty ? "1px dashed var(--ds-border-strong)" : "none",
      display: "flex", alignItems: "flex-end", justifyContent: "center", paddingBottom: 6,
      font: "400 8px/1 var(--ds-font-mono)",
      color: empty ? "var(--ds-text-secondary)" : "rgba(255,255,255,.7)",
      ...style
    }}>{label}</div>
  );
}
