import React from "react";

export function Chip({ selected = false, onClick, children, style }) {
  return (
    <button
      onClick={onClick}
      style={{
        flex: "none",
        padding: "9px 14px",
        borderRadius: "var(--ds-radius-pill)",
        border: "1px solid " + (selected ? "var(--ds-action)" : "var(--ds-border-strong)"),
        background: selected ? "var(--ds-tint-strong)" : "var(--ds-surface)",
        color: selected ? "var(--ds-purple-900)" : "var(--ds-text-secondary)",
        font: "500 13px/1 var(--ds-font-body)",
        cursor: "pointer",
        ...style
      }}
    >{children}</button>
  );
}
