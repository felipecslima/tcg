import React from "react";

export function RadioRow({ selected = false, label, trailing, onClick, style }) {
  return (
    <button onClick={onClick} style={{
      display: "flex", alignItems: "center", gap: 12, width: "100%", textAlign: "left",
      padding: "13px 14px", borderRadius: "var(--ds-radius-md)",
      border: "1px solid " + (selected ? "var(--ds-action)" : "var(--ds-border)"),
      background: selected ? "var(--ds-tint-strong)" : "var(--ds-surface)",
      color: selected ? "var(--ds-purple-900)" : "var(--ds-text-secondary)",
      font: "500 14px/1 var(--ds-font-body)", cursor: "pointer", ...style
    }}>
      <span style={{
        width: 18, height: 18, borderRadius: "var(--ds-radius-pill)", flex: "none",
        border: "2px solid " + (selected ? "var(--ds-action)" : "var(--ds-border-strong)"),
        background: selected ? "var(--ds-action)" : "transparent",
        display: "flex", alignItems: "center", justifyContent: "center",
        fontSize: 10, color: "#fff"
      }}>{selected ? "✓" : ""}</span>
      <span style={{ flex: 1 }}>{label}</span>
      {trailing && <span style={{ font: "400 12px/1 var(--ds-font-mono)", color: "var(--ds-text-secondary)" }}>{trailing}</span>}
    </button>
  );
}
