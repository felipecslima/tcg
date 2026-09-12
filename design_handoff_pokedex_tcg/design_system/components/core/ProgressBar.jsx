import React from "react";

export function ProgressBar({ value = 0, height = 6, onDark = false, style }) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div style={{
      height, borderRadius: "var(--ds-radius-pill)", overflow: "hidden",
      background: onDark ? "rgba(255,255,255,.25)" : "var(--ds-tint)", ...style
    }}>
      <div style={{
        height: "100%", width: pct + "%", borderRadius: "var(--ds-radius-pill)",
        background: onDark ? "#fff" : "var(--ds-grad-progress)"
      }} />
    </div>
  );
}
